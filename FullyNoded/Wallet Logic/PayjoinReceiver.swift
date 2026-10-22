//
//  PayjoinReceiver.swift
//  FullyNoded
//
//  BIP78 payjoin, receiver side, hosted on this device while the invoice screen is open:
//
//  • A one-time onion service (Tor `ADD_ONION … Flags=DiscardPK`) forwards to a small HTTP
//    listener on 127.0.0.1. The invoice offers `pj=http://<onion>/pj&pjos=0`; Tor provides the
//    encryption and authentication, so plain http to the onion is what BIP78 expects.
//  • The payer POSTs its signed, broadcastable payment (the "original"). We check it, add one
//    of this wallet's coins (same script type: P2WPKH or taproot key path), raise our payment
//    output by its value less the extra fee, sign and finalize only our input, and reply with
//    the proposal. The payer signs and broadcasts it, or falls back to the original.
//  • The original is kept: if the payer never broadcasts anything, it can be broadcast from
//    the invoice screen.
//

import Foundation
import Network
import BitcoinDevKit

// MARK: - HTTP listener (loopback only)

/// A minimal HTTP/1.1 server for the onion service: one request per connection.
final class PayjoinHTTPServer {
    struct Request {
        let method: String
        let path: String
        let query: [String: String]
        let body: Data
    }

    /// Replies with status, content type and body.
    typealias Respond = (_ status: Int, _ contentType: String, _ body: String) -> Void

    var handler: ((Request, @escaping Respond) -> Void)?

    private let queue = DispatchQueue(label: "FullyNoded.PayjoinHTTPServer")
    private var listener: NWListener?
    private static let maxRequestSize = 512 * 1024

    /// Listens on 127.0.0.1 (a free port). Completion on the main queue with the port.
    func start(completion: @escaping (Result<UInt16, Error>) -> Void) {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        parameters.allowLocalEndpointReuse = true
        do {
            let listener = try NWListener(using: parameters)
            var reported = false
            listener.stateUpdateHandler = { [weak listener] state in
                guard !reported else { return }
                switch state {
                case .ready:
                    reported = true
                    let port = listener?.port?.rawValue ?? 0
                    DispatchQueue.main.async { completion(.success(port)) }
                case .failed(let error):
                    reported = true
                    DispatchQueue.main.async { completion(.failure(error)) }
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            completion(.failure(error))
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            var buffer = buffer
            if let data = data { buffer.append(data) }
            guard buffer.count <= Self.maxRequestSize else {
                self.send(connection, 413, "text/plain", "Request too large")
                return
            }
            if let request = Self.parse(buffer) {
                guard let handler = self.handler else {
                    self.send(connection, 503, "text/plain", "Unavailable")
                    return
                }
                handler(request) { [weak self] status, type, body in
                    self?.queue.async { self?.send(connection, status, type, body) }
                }
                return
            }
            if error != nil || isComplete {
                connection.cancel()
                return
            }
            self.receive(connection, buffer: buffer)
        }
    }

    /// The request once its headers and the whole body (Content-Length) have arrived.
    private static func parse(_ data: Data) -> Request? {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: data[..<headerEnd.lowerBound], encoding: .utf8) else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let parts = lines.first?.split(separator: " ") ?? []
        guard parts.count >= 2 else { return Request(method: "", path: "", query: [:], body: Data()) }
        var length = 0
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1)
            if pair.count == 2, pair[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                length = Int(pair[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        let bodyStart = headerEnd.upperBound
        guard data.count - bodyStart >= length else { return nil }
        let target = String(parts[1])
        let components = URLComponents(string: target)
        var query: [String: String] = [:]
        for item in components?.queryItems ?? [] { query[item.name.lowercased()] = item.value ?? "" }
        return Request(method: String(parts[0]).uppercased(), path: components?.path ?? target, query: query,
                       body: data.subdata(in: bodyStart..<(bodyStart + length)))
    }

    private func send(_ connection: NWConnection, _ status: Int, _ type: String, _ body: String) {
        let reason: String = [200: "OK", 400: "Bad Request", 404: "Not Found", 413: "Payload Too Large", 503: "Service Unavailable"][status] ?? "Error"
        let bytes = Data(body.utf8)
        let header = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(type)\r\nContent-Length: \(bytes.count)\r\n"
            + "Access-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(header.utf8) + bytes, completion: .contentProcessed { _ in connection.cancel() })
    }
}

// MARK: - Receiver logic

extension Payjoin {

    /// A BIP78 error reply.
    struct ReceiverError: Error {
        let code: String
        let message: String
        static func rejected(_ message: String) -> ReceiverError { ReceiverError(code: "original-psbt-rejected", message: message) }
        static func unavailable(_ message: String) -> ReceiverError { ReceiverError(code: "unavailable", message: message) }
    }

    /// What the receiver accepted and replied with.
    struct ReceivedPayjoin {
        let proposal: String
        /// The payer's original, fully signed (the fallback).
        let originalHex: String
        let contributedSats: Int64
    }

    enum Receiver {
        /// Outpoints of every original seen (a proposal can't be replayed as a new original).
        private static let seenKey = "payjoinSeenOutpoints"

        /// Checks the payer's original and builds our signed proposal. Completion on any queue.
        static func respond(originalBase64: String, query: [String: String], address: String, amountSats: Int64?,
                            walletName: String, passphrase: String?,
                            completion: @escaping (Result<ReceivedPayjoin, ReceiverError>) -> Void) {
            // Protocol version.
            if let v = query["v"], v != "1" {
                completion(.failure(ReceiverError(code: "version-unsupported", message: "This receiver supports version 1.")))
                return
            }
            guard let raw = Data(base64Encoded: originalBase64.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let original = try? SPPsbt(raw) else {
                completion(.failure(.rejected("Not a PSBT.")))
                return
            }
            let tx = original.tx

            // Every input finalized, with UTXO data.
            var prevouts: [SPTx.Output] = []
            var types = Set<OfflinePsbt.ScriptType>()
            for (i, map) in original.inputs.enumerated() {
                guard map.contains(where: { $0.key == [0x07] || $0.key == [0x08] }),
                      let prevout = try? original.prevout(input: i) else {
                    completion(.failure(.rejected("Every input must be finalized, with its UTXO.")))
                    return
                }
                prevouts.append(prevout)
                let redeem = map.first { $0.key == [0x04] }?.value
                types.insert(OfflinePsbt.scriptType(spk: [UInt8](prevout.script), redeem: redeem))
            }
            guard types.count == 1, let type = types.first, type == .p2wpkh || type == .p2tr else {
                completion(.failure(.rejected("Only all-P2WPKH or all-taproot payments can be payjoined here.")))
                return
            }

            // Pays our address, at least the invoice amount.
            guard let network = WalletLogic.shared.bdkNetwork(),
                  let scriptData = try? Address(address: address, network: network).scriptPubkey().toBytes(),
                  let paymentIndex = tx.outputs.firstIndex(where: { [UInt8]($0.script) == [UInt8](scriptData) }) else {
                completion(.failure(.rejected("It doesn't pay this invoice's address.")))
                return
            }
            let paid = Int64(OfflinePsbt.amount(tx.outputs[paymentIndex]))
            if let amountSats, paid < amountSats {
                completion(.failure(.rejected("It pays less than the invoice amount.")))
                return
            }

            // Never seen before (replays and reentrant payjoins).
            let outpoints = tx.inputs.map { "\($0.txidDisplay):\($0.vout)" }
            let seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
            guard outpoints.allSatisfy({ !seen.contains($0) }) else {
                completion(.failure(.rejected("These inputs were already used in a payjoin.")))
                return
            }

            // Broadcastable (the node finalizes and accepts it): defends against UTXO probing.
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .finalizepsbt(Finalize_Psbt(["psbt": originalBase64])), walletName: walletName) { response, _ in
                guard let dict = response as? [String: Any], dict["complete"] as? Bool == true, let originalHex = dict["hex"] as? String,
                      let signed = try? Payjoin.SignedTx([UInt8](SPHexFN.decode(originalHex) ?? Data())) else {
                    completion(.failure(.rejected("The payment isn't fully signed.")))
                    return
                }
                MakeRPCCall.sharedInstance.executeRPCCommand(method: .testmempoolaccept(Test_Mempool_Accept(["rawtxs": [originalHex]]))) { response, _ in
                    guard (response as? [[String: Any]])?.first?["allowed"] as? Bool == true else {
                        completion(.failure(.rejected("The payment can't be broadcast.")))
                        return
                    }
                    // Remember these inputs, then pick a coin of ours.
                    UserDefaults.standard.set(Array(seen.union(outpoints).suffix(5_000)), forKey: seenKey)
                    let originalFee = prevouts.reduce(Int64(0)) { $0 + Int64(OfflinePsbt.amount($1)) }
                        - tx.outputs.reduce(Int64(0)) { $0 + Int64(OfflinePsbt.amount($1)) }
                    let vsize = (signed.weight + 3) / 4
                    chooseCoin(type: type, excluding: Set(outpoints), payment: paid, walletName: walletName) { coin in
                        guard let coin = coin else {
                            completion(.failure(ReceiverError(code: "not-enough-money", message: "No coin to contribute.")))
                            return
                        }
                        build(original: original, prevouts: prevouts, paymentIndex: paymentIndex, coin: coin, type: type,
                              originalFee: originalFee, originalVsize: vsize, query: query, walletName: walletName,
                              passphrase: passphrase) { result in
                            completion(result.map { ReceivedPayjoin(proposal: $0.proposal, originalHex: originalHex, contributedSats: $0.contributed) })
                        }
                    }
                }
            }
        }

        struct Coin {
            let txid: String
            let vout: Int
            let sats: Int64
            let script: [UInt8]
        }

        /// A confirmed coin of this wallet of the payer's script type, signable here. Prefers one
        /// of a similar size to the payment, so the coin doesn't look obviously unnecessary.
        static func chooseCoin(type: OfflinePsbt.ScriptType, excluding: Set<String>, payment: Int64, walletName: String,
                               completion: @escaping (Coin?) -> Void) {
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .listunspent(List_Unspent(["minconf": 1])), walletName: walletName) { response, _ in
                let prefix = type == .p2wpkh ? "wpkh(" : "tr("
                let coins: [Coin] = ((response as? [[String: Any]]) ?? []).compactMap { u in
                    guard let txid = u["txid"] as? String, let vout = u["vout"] as? Int,
                          let amount = u["amount"] as? Double, let spk = u["scriptPubKey"] as? String,
                          (u["solvable"] as? Bool) == true, (u["desc"] as? String)?.hasPrefix(prefix) == true,
                          !excluding.contains("\(txid):\(vout)"), let script = SPHexFN.decode(spk) else { return nil }
                    let sats = Int64((amount * 100_000_000).rounded())
                    return sats >= 10_000 ? Coin(txid: txid, vout: vout, sats: sats, script: [UInt8](script)) : nil
                }
                let similar = coins.filter { $0.sats >= payment / 2 && $0.sats <= payment * 2 }
                completion((similar.isEmpty ? coins : similar).randomElement())
            }
        }

        /// The proposal: our coin added at a random position, our output raised, signed and our
        /// input finalized; the payer's inputs back to unfinalized with their UTXOs.
        static func build(original: SPPsbt, prevouts: [SPTx.Output], paymentIndex: Int, coin: Coin, type: OfflinePsbt.ScriptType,
                          originalFee: Int64, originalVsize: Int, query: [String: String], walletName: String, passphrase: String?,
                          completion: @escaping (Result<(proposal: String, contributed: Int64), ReceiverError>) -> Void) {
            let tx = original.tx
            let inputVsize = type == .p2wpkh ? 68 : 58
            let feeRate = Double(originalFee) / Double(max(originalVsize, 1))
            var extraFee = Int64((feeRate * Double(inputVsize)).rounded(.up))
            if let min = query["minfeerate"].flatMap(Double.init) {
                let needed = Int64((min * Double(originalVsize + inputVsize)).rounded(.up)) - originalFee
                extraFee = max(extraFee, needed)
            }

            // The payer may pay part of it from one of its outputs, within its limit.
            var outputs = tx.outputs.map { OfflinePsbt.amount($0) }.map(Int64.init)
            var fromPayer: Int64 = 0
            if let index = query["additionalfeeoutputindex"].flatMap(Int.init), index != paymentIndex, outputs.indices.contains(index),
               let max = query["maxadditionalfeecontribution"].flatMap(Int64.init), max > 0 {
                fromPayer = min(max, extraFee, outputs[index] - 546)
                if fromPayer > 0 { outputs[index] -= fromPayer } else { fromPayer = 0 }
            }
            let contributed = coin.sats - (extraFee - fromPayer)
            guard contributed > 0 else {
                completion(.failure(ReceiverError(code: "not-enough-money", message: "The coin doesn't cover its own fee.")))
                return
            }
            outputs[paymentIndex] += contributed

            // The new transaction: same version, locktime and sequence; our input at a random spot.
            let ourIndex = Int.random(in: 0...tx.inputs.count)
            let sequence = tx.inputs.first?.sequence ?? [0xFD, 0xFF, 0xFF, 0xFF]
            let ourOutpoint = Array([UInt8](SPHexFN.decode(coin.txid) ?? Data()).reversed()) + SPWriter.le32(UInt32(coin.vout))
            var inputs = tx.inputs.map { (outpoint: $0.outpoint, sequence: $0.sequence) }
            inputs.insert((ourOutpoint, sequence), at: ourIndex)
            var unsigned = tx.version + SPWriter.compactSize(inputs.count)
            for input in inputs { unsigned += input.outpoint + [0x00] + input.sequence }
            unsigned += SPWriter.compactSize(outputs.count)
            for (o, output) in tx.outputs.enumerated() {
                unsigned += (0..<8).map { UInt8(truncatingIfNeeded: UInt64(outputs[o]) >> (8 * UInt64($0))) }
                    + SPWriter.compactSize(output.script.count) + [UInt8](output.script)
            }
            unsigned += tx.locktime

            // PSBT: the payer's inputs keep only their UTXOs; ours gets a witness UTXO for now.
            let ourWitnessUtxo = (0..<8).map { UInt8(truncatingIfNeeded: UInt64(coin.sats) >> (8 * UInt64($0))) }
                + SPWriter.compactSize(coin.script.count) + coin.script
            var maps: [[SPPsbt.Entry]] = original.inputs.map { map in map.filter { $0.key == [0x00] || $0.key == [0x01] } }
            maps.insert([(key: [0x01], value: ourWitnessUtxo)], at: ourIndex)
            var bytes: [UInt8] = [0x70, 0x73, 0x62, 0x74, 0xFF] + [0x01, 0x00] + SPWriter.compactSize(unsigned.count) + unsigned + [0x00]
            for map in maps {
                for e in map { bytes += SPWriter.compactSize(e.key.count) + e.key + SPWriter.compactSize(e.value.count) + e.value }
                bytes.append(0x00)
            }
            for _ in tx.outputs { bytes.append(0x00) }
            let draft = Data(bytes).base64EncodedString()

            // The node adds our key derivations; we sign with the signer on this device.
            let process = Wallet_Process_PSBT(["psbt": draft, "sign": false, "sighashtype": "ALL", "bip32derivs": true])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .walletprocesspsbt(param: process), walletName: walletName) { response, error in
                guard let processed = (response as? [String: Any])?["psbt"] as? String, let processedData = Data(base64Encoded: processed),
                      var prepared = try? SPPsbt(processedData) else {
                    completion(.failure(.unavailable("Couldn't prepare our input: \(error ?? "unknown")")))
                    return
                }
                // The node knows the payer's inputs only if they're ours: refuse (BIP78), and in
                // any case leave nothing on them that would let us sign them.
                for i in prepared.inputs.indices where i != ourIndex {
                    if prepared.inputs[i].contains(where: { $0.key.first == 0x06 || $0.key.first == 0x16 }) {
                        completion(.failure(.rejected("The payment spends this wallet's own coins.")))
                        return
                    }
                    prepared.inputs[i] = prepared.inputs[i].filter { $0.key == [0x00] || $0.key == [0x01] }
                }
                Payjoin.sign(prepared.serialize(), passphrase: passphrase) { signed in
                    switch signed {
                    case .failure(let failure):
                        completion(.failure(.unavailable(failure.errorDescription ?? "Couldn't sign our input.")))
                    case .success(let signedData):
                        do {
                            completion(.success((try finalizeOurInput(signedData, index: ourIndex, type: type), contributed)))
                        } catch {
                            completion(.failure(.unavailable("Couldn't finalize our input.")))
                        }
                    }
                }
            }
        }

        /// Our input: its signature becomes the final witness; everything but UTXO data goes.
        /// Every other input and output carries no key paths, scripts or signatures.
        static func finalizeOurInput(_ data: Data, index: Int, type: OfflinePsbt.ScriptType) throws -> String {
            var psbt = try SPPsbt(data)
            let ours = psbt.inputs[index]
            var witness: [[UInt8]] = []
            if type == .p2wpkh, let partial = ours.first(where: { $0.key.first == 0x02 && $0.key.count == 34 }) {
                witness = [partial.value, Array(partial.key.dropFirst())]
            } else if type == .p2tr, let sig = ours.first(where: { $0.key == [0x13] }) {
                witness = [sig.value]
            }
            guard !witness.isEmpty else { throw Payjoin.Failure("No signature for our input.") }
            var final = SPWriter.compactSize(witness.count)
            for item in witness { final += SPWriter.compactSize(item.count) + item }
            for i in psbt.inputs.indices {
                psbt.inputs[i] = psbt.inputs[i].filter { $0.key == [0x00] || $0.key == [0x01] }
            }
            psbt.inputs[index].append((key: [0x08], value: final))
            for o in psbt.outputs.indices { psbt.outputs[o] = [] }
            psbt.global = psbt.global.filter { $0.key == [SPPsbt.globalUnsignedTx] }
            return psbt.serialize().base64EncodedString()
        }
    }
}

// MARK: - Session (one invoice)

/// Hosts the payjoin endpoint for one invoice while the screen is open.
final class PayjoinReceiveSession {
    /// Setting the endpoint up, in order.
    enum Step: Int, CaseIterable {
        case listener, onion, publishing, reachable
    }

    enum Status: Equatable {
        case step(Step)
        /// The one-time onion address, as soon as Tor made it (before it's reachable).
        case onion(String)
        /// Reachable over Tor: put this in the invoice.
        case ready(URL)
        case handling
        /// A payer's payment was refused (our own reason, safe to show); still live for others.
        case refused(String)
        case sent(contributedSats: Int64)
        case failed(String)
    }

    let address: String
    /// Updated when the invoice amount changes.
    var amountSats: Int64?
    let walletName: String
    private let passphrase: String?
    var onStatus: ((Status) -> Void)?

    private let server = PayjoinHTTPServer()
    private var onion: String?
    private var stopped = false
    /// The one payjoin this invoice makes; a retry of the same original gets the same reply.
    private var answered: (original: String, proposal: String)?
    /// The payer's payment, if a payjoin was proposed (to broadcast if the payer doesn't).
    private(set) var originalHex: String?

    init(address: String, amountSats: Int64?, walletName: String, passphrase: String?) {
        self.address = address
        self.amountSats = amountSats
        self.walletName = walletName
        self.passphrase = passphrase
    }

    func start() {
        guard TorClient.sharedInstance.state == .connected else {
            report(.failed("Tor isn't connected yet."))
            return
        }
        report(.step(.listener))
        server.handler = { [weak self] request, respond in self?.handle(request, respond) }
        server.start { [weak self] result in
            guard let self = self, !self.stopped else { return }
            switch result {
            case .failure(let error):
                self.report(.failed("Couldn't start the payjoin service: \(error.localizedDescription)"))
            case .success(let port):
                self.report(.step(.onion))
                TorClient.sharedInstance.addOnionService(localPort: port) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .failure(let error):
                        self.report(.failed(error.localizedDescription))
                    case .success(let host):
                        if self.stopped { TorClient.sharedInstance.removeOnionService(host); return }
                        self.onion = host
                        Payjoin.log("receiving at \(host)")
                        self.report(.onion(host))
                        self.report(.step(.publishing))
                        self.waitUntilReachable(host, attempt: 0)
                    }
                }
            }
        }
    }

    func stop() {
        stopped = true
        server.stop()
        if let onion { TorClient.sharedInstance.removeOnionService(onion) }
        onion = nil
    }

    /// Fetches our own onion through Tor until it answers: then payers can reach it too.
    private func waitUntilReachable(_ host: String, attempt: Int) {
        guard !stopped else { return }
        guard attempt < 30, let url = URL(string: "http://\(host)/health") else {
            report(.failed("The onion address didn't come up. Try again."))
            return
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.connectionProxyDictionary = [kCFProxyTypeKey: kCFProxyTypeSOCKS,
                                                   kCFStreamPropertySOCKSProxyHost: "localhost",
                                                   kCFStreamPropertySOCKSProxyPort: TorClient.socksPort]
        let session = URLSession(configuration: configuration)
        session.dataTask(with: url) { [weak self] _, response, _ in
            session.finishTasksAndInvalidate()
            DispatchQueue.main.async {
                guard let self = self, !self.stopped else { return }
                if (response as? HTTPURLResponse)?.statusCode == 200, let pj = URL(string: "http://\(host)/pj") {
                    Payjoin.log("onion reachable after \(attempt + 1) attempt(s)")
                    self.report(.step(.reachable))
                    self.report(.ready(pj))
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { self.waitUntilReachable(host, attempt: attempt + 1) }
                }
            }
        }.resume()
    }

    private func handle(_ request: PayjoinHTTPServer.Request, _ respond: @escaping PayjoinHTTPServer.Respond) {
        if request.method == "GET" {
            respond(request.path == "/health" ? 200 : 404, "text/plain", request.path == "/health" ? "ok" : "Not found")
            return
        }
        guard request.method == "POST", let original = String(data: request.body, encoding: .utf8) else {
            respond(404, "text/plain", "Not found")
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let answered = self.answered {
                // The same payer retrying gets the same proposal; anything else is refused.
                if answered.original == original.trimmingCharacters(in: .whitespacesAndNewlines) {
                    respond(200, "text/plain", answered.proposal)
                } else {
                    respond(503, "application/json", Self.errorJSON("unavailable", "This invoice already made a payjoin."))
                }
                return
            }
            self.report(.handling)
            Payjoin.log("← original from a payer, \(request.body.count) bytes, query \(request.query)")
            Payjoin.Receiver.respond(originalBase64: original, query: request.query, address: self.address, amountSats: self.amountSats,
                                     walletName: self.walletName, passphrase: self.passphrase) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let payjoin):
                        self.answered = (original.trimmingCharacters(in: .whitespacesAndNewlines), payjoin.proposal)
                        self.originalHex = payjoin.originalHex
                        Payjoin.log("→ proposal sent, contributed \(payjoin.contributedSats) sats")
                        respond(200, "text/plain", payjoin.proposal)
                        self.report(.sent(contributedSats: payjoin.contributedSats))
                    case .failure(let error):
                        Payjoin.log("→ refused: \(error.code) (\(error.message))")
                        respond(error.code == "unavailable" ? 503 : 400, "application/json", Self.errorJSON(error.code, error.message))
                        self.report(.refused(error.message))
                    }
                }
            }
        }
    }

    /// Broadcasts the payer's original payment (when the payer broadcast nothing).
    func broadcastOriginal(completion: @escaping (String?) -> Void) {
        guard let hex = originalHex else { completion("There's no payment to broadcast."); return }
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .sendrawtransaction(Send_Raw_Transaction(["hexstring": hex]))) { _, error in
            DispatchQueue.main.async { completion(error) }
        }
    }

    private func report(_ status: Status) {
        DispatchQueue.main.async { [weak self] in self?.onStatus?(status) }
    }

    private static func errorJSON(_ code: String, _ message: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: ["errorCode": code, "message": message])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
