//
//  Payjoin.swift
//  FullyNoded
//
//  BIP78 payjoin, sender side. After the payment is signed as usual (the "original", which
//  stays the fallback), this sends it to the receiver's `pj=` endpoint, checks the receiver's
//  proposal against BIP78's sender checklist, signs only our own inputs (P256K, OfflinePsbt)
//  and finalizes it with the node. Any failure leaves the original payment untouched.
//
//  Transport: over Tor whenever it's connected (always for .onion endpoints), with normal TLS
//  certificate validation for https. Plain http is only accepted to an onion.
//
//  We always ask the receiver not to substitute the payment output
//  (`disableoutputsubstitution=true`), so the address and amount you're paying can't change.
//

import Foundation
import BitcoinDevKit

enum Payjoin {

    /// A payjoin offered by a payment request (BIP21 `pj=`).
    struct Endpoint {
        let url: URL
        /// The address being paid: the proposal must still pay it, at least the same amount.
        let address: String
        /// `pjos=0`. We disable substitution anyway; kept for the record.
        let outputSubstitutionDisabled: Bool
    }

    struct Outcome {
        /// The signed payjoin transaction.
        let rawTx: String
        /// Inputs the receiver added (0: not really a payjoin, but still valid).
        let receiverInputs: Int
        /// Extra fee taken from our change, in sats.
        let feeContribution: Int64
    }

    struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    /// The whole sender flow. Completion on the main queue.
    static func attempt(endpoint: Endpoint, unsignedPsbt: String, signedRawTx: String, passphrase: String?,
                        completion: @escaping (Result<Outcome, Failure>) -> Void) {
        let finish: (Result<Outcome, Failure>) -> Void = { result in
            if case .failure(let error) = result { log("failed: \(error.errorDescription ?? "")") }
            DispatchQueue.main.async { completion(result) }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let original: Original
            do {
                original = try Original(unsignedPsbt: unsignedPsbt, signedRawTx: signedRawTx, paying: endpoint.address)
            } catch let error as Failure {
                finish(.failure(error)); return
            } catch {
                finish(.failure(Failure(error.localizedDescription))); return
            }
            log("original: \(original.inputs.count) inputs, fee \(original.fee) sats (\(String(format: "%.2f", original.feeRate)) sat/vB), payment output #\(original.paymentIndex)\(original.changeIndex.map { ", change #\($0)" } ?? "")")

            post(endpoint.url, psbt: original.psbt.base64EncodedString(), query: original.query) { response in
                switch response {
                case .failure(let error):
                    finish(.failure(error))
                case .success(let proposalText):
                    guard let proposal = Data(base64Encoded: proposalText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                        finish(.failure(Failure("The receiver's reply isn't a PSBT.")))
                        return
                    }
                    let checked: (psbt: Data, receiverInputs: Int, contribution: Int64)
                    do {
                        checked = try check(proposal, against: original)
                    } catch let error as Failure {
                        finish(.failure(error)); return
                    } catch {
                        finish(.failure(Failure("The receiver's proposal can't be read: \(error.localizedDescription)"))); return
                    }
                    log("proposal passed every check: \(checked.receiverInputs) receiver input(s), \(checked.contribution) sats from our change")
                    sign(checked.psbt, passphrase: passphrase) { signed in
                        switch signed {
                        case .failure(let error):
                            finish(.failure(error))
                        case .success(let signedPsbt):
                            finalize(signedPsbt) { final in
                                finish(final.map { Outcome(rawTx: $0, receiverInputs: checked.receiverInputs, feeContribution: checked.contribution) })
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - The original

    /// Our signed payment as BIP78's original PSBT, and what the checks need to know about it.
    struct Original {
        /// Finalized, with only UTXO data and final scripts (no keypaths, xpubs or scripts).
        let psbt: Data
        /// The unsigned PSBT it came from (our derivations, to sign the proposal).
        let unsigned: SPPsbt
        let version: [UInt8]
        let locktime: [UInt8]
        let inputs: [(outpoint: [UInt8], sequence: [UInt8], prevout: SPTx.Output, scriptType: OfflinePsbt.ScriptType)]
        let outputs: [SPTx.Output]
        let fee: Int64
        let feeRate: Double
        let paymentIndex: Int
        /// Our change: where the receiver may take extra fee from.
        let changeIndex: Int?
        /// vsize of one more input of our type (for the fee contribution cap).
        let inputVsize: Int?

        var maxFeeContribution: Int64? {
            guard changeIndex != nil, let inputVsize else { return nil }
            return Int64((feeRate * Double(inputVsize)).rounded(.up))
        }

        /// BIP78 query parameters.
        var query: [URLQueryItem] {
            var items = [URLQueryItem(name: "v", value: "1"),
                         URLQueryItem(name: "disableoutputsubstitution", value: "true")]
            if let changeIndex, let max = maxFeeContribution {
                items.append(URLQueryItem(name: "additionalfeeoutputindex", value: "\(changeIndex)"))
                items.append(URLQueryItem(name: "maxadditionalfeecontribution", value: "\(max)"))
            }
            return items
        }

        init(unsignedPsbt: String, signedRawTx: String, paying address: String) throws {
            guard let unsignedData = Data(base64Encoded: unsignedPsbt.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let rawBytes = SPHexFN.decode(signedRawTx.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw Failure("The signed payment can't be read.")
            }
            let psbt = try SPPsbt(unsignedData)
            let signed = try SignedTx([UInt8](rawBytes))
            let tx = psbt.tx

            // The signed transaction must be exactly the PSBT's (only scripts and witnesses added).
            guard signed.inputs.count == tx.inputs.count, signed.outputs.count == tx.outputs.count,
                  signed.version == tx.version, signed.locktime == tx.locktime,
                  zip(signed.inputs, tx.inputs).allSatisfy({ $0.outpoint == $1.outpoint && $0.sequence == $1.sequence }),
                  zip(signed.outputs, tx.outputs).allSatisfy({ $0.serialized == $1.serialized }) else {
                throw Failure("The signed transaction doesn't match its PSBT.")
            }

            var inputs: [(outpoint: [UInt8], sequence: [UInt8], prevout: SPTx.Output, scriptType: OfflinePsbt.ScriptType)] = []
            for (i, input) in tx.inputs.enumerated() {
                let prevout = try psbt.prevout(input: i)
                let redeem = psbt.inputs[i].first { $0.key == [0x04] }?.value
                inputs.append((input.outpoint, input.sequence, prevout, OfflinePsbt.scriptType(spk: [UInt8](prevout.script), redeem: redeem)))
            }
            let totalIn = inputs.reduce(Int64(0)) { $0 + Int64(OfflinePsbt.amount($1.prevout)) }
            let totalOut = tx.outputs.reduce(Int64(0)) { $0 + Int64(OfflinePsbt.amount($1)) }

            // The payment output: the invoice's address.
            guard let network = WalletLogic.shared.bdkNetwork(),
                  let scriptData = try? Address(address: address, network: network).scriptPubkey().toBytes(),
                  let paymentIndex = tx.outputs.firstIndex(where: { [UInt8]($0.script) == [UInt8](scriptData) }) else {
                throw Failure("This transaction doesn't pay the invoice's address.")
            }

            // Our change: an output (not the payment) carrying our key derivation.
            let changeIndex = psbt.outputs.indices.first { o in
                o != paymentIndex && psbt.outputs[o].contains { ($0.key.first == 0x02 && $0.key.count == 34) || ($0.key.first == 0x07 && $0.key.count == 33) }
            }

            // One more input of our type (BIP78's table); unknown for scripts of varying size.
            let types = Set(inputs.map(\.scriptType))
            var inputVsize: Int?
            if types.count == 1 {
                switch types.first! {
                case .p2wpkh: inputVsize = 68
                case .p2shP2wpkh: inputVsize = 91
                case .p2tr: inputVsize = 58
                default: inputVsize = nil
                }
            }

            // BIP78 original: UTXO data and final scripts only.
            var original = psbt
            original.global = psbt.global.filter { $0.key == [SPPsbt.globalUnsignedTx] || $0.key == [SPPsbt.globalVersion] }
            for i in original.inputs.indices {
                var map = psbt.inputs[i].filter { $0.key == [SPPsbt.inNonWitnessUtxo] || $0.key == [SPPsbt.inWitnessUtxo] }
                if !signed.inputs[i].scriptSig.isEmpty { map.append((key: [0x07], value: signed.inputs[i].scriptSig)) }
                if !signed.inputs[i].witness.isEmpty {
                    var value = SPWriter.compactSize(signed.inputs[i].witness.count)
                    for item in signed.inputs[i].witness { value += SPWriter.compactSize(item.count) + item }
                    map.append((key: [SPPsbt.inFinalScriptWitness], value: value))
                }
                original.inputs[i] = map
            }
            for o in original.outputs.indices { original.outputs[o] = [] }

            self.psbt = original.serialize()
            self.unsigned = psbt
            self.version = tx.version
            self.locktime = tx.locktime
            self.inputs = inputs
            self.outputs = tx.outputs
            self.fee = totalIn - totalOut
            self.feeRate = Double(totalIn - totalOut) / Double(max(1, (signed.weight + 3) / 4))
            self.paymentIndex = paymentIndex
            self.changeIndex = changeIndex
            self.inputVsize = inputVsize
            guard fee > 0 else { throw Failure("The payment's fee can't be worked out.") }
        }
    }

    /// A signed transaction with its scriptSigs and witnesses (SPTx skips them).
    struct SignedTx {
        struct Input {
            let outpoint: [UInt8]
            let scriptSig: [UInt8]
            let sequence: [UInt8]
            var witness: [[UInt8]] = []
        }
        let version: [UInt8]
        var inputs: [Input]
        let outputs: [SPTx.Output]
        let locktime: [UInt8]
        /// BIP141 weight.
        let weight: Int

        init(_ bytes: [UInt8]) throws {
            var r = SPReader(bytes)
            version = try r.bytes(4)
            var segwit = false
            if r.peek(2) == [0x00, 0x01] { _ = try r.bytes(2); segwit = true }
            var ins: [Input] = []
            for _ in 0..<(try r.compactSize()) {
                let outpoint = try r.bytes(36)
                let scriptSig = try r.bytes(try r.compactSize())
                ins.append(Input(outpoint: outpoint, scriptSig: scriptSig, sequence: try r.bytes(4)))
            }
            var outs: [SPTx.Output] = []
            for _ in 0..<(try r.compactSize()) { outs.append(try SPTx.readOutput(&r)) }
            let witnessStart = bytes.count - r.remaining
            if segwit {
                for i in ins.indices {
                    for _ in 0..<(try r.compactSize()) { ins[i].witness.append(try r.bytes(try r.compactSize())) }
                }
            }
            let witnessBytes = bytes.count - r.remaining - witnessStart
            locktime = try r.bytes(4)
            guard r.atEnd else { throw Failure("Trailing bytes after the transaction.") }
            inputs = ins
            outputs = outs
            let base = bytes.count - witnessBytes - (segwit ? 2 : 0)
            weight = base * 3 + bytes.count
        }
    }

    // MARK: - Checking the proposal (BIP78 sender checklist)

    /// The proposal with our derivations restored (ready to sign), how many inputs the receiver
    /// added and how much extra fee came out of our change. Throws on the first failed check.
    static func check(_ data: Data, against original: Original) throws -> (psbt: Data, receiverInputs: Int, contribution: Int64) {
        var proposal = try SPPsbt(data)
        let tx = proposal.tx

        func fail(_ what: String) -> Failure { Failure("The receiver's proposal failed a check (\(what)), so it wasn't used.") }
        func has(_ map: [SPPsbt.Entry], _ type: UInt8, count: Int? = nil) -> Bool {
            map.contains { $0.key.first == type && (count == nil || $0.key.count == count!) }
        }

        // Transaction: version and locktime unchanged.
        guard tx.version == original.version else { throw fail("version changed") }
        guard tx.locktime == original.locktime else { throw fail("locktime changed") }

        // Inputs: every original input, in the original order, sequences unchanged; all equal.
        var senderIndices: [Int] = []
        for input in original.inputs {
            guard let i = tx.inputs.firstIndex(where: { $0.outpoint == input.outpoint }) else { throw fail("one of your inputs was removed") }
            guard tx.inputs[i].sequence == input.sequence else { throw fail("your input's sequence changed") }
            senderIndices.append(i)
        }
        guard senderIndices == senderIndices.sorted() else { throw fail("inputs were reordered") }
        let sequence = tx.inputs.first?.sequence
        guard tx.inputs.allSatisfy({ $0.sequence == sequence }) else { throw fail("inputs don't share one sequence number") }

        let senderSet = Set(senderIndices)
        var amounts: [Int64] = []
        var receiverInputs = 0
        for (i, map) in proposal.inputs.enumerated() {
            // No keypaths, no partial signatures anywhere.
            guard !has(map, 0x06, count: 34), !has(map, 0x16, count: 33) else { throw fail("an input carries key paths") }
            guard !has(map, 0x02, count: 34), !has(map, 0x13), !has(map, 0x14) else { throw fail("an input carries partial signatures") }
            let finalized = has(map, 0x07) || has(map, 0x08)
            if senderSet.contains(i) {
                guard !finalized else { throw fail("your input was finalized by the receiver") }
                let ours = original.inputs[senderIndices.firstIndex(of: i)!]
                amounts.append(Int64(OfflinePsbt.amount(ours.prevout)))
            } else {
                // Receiver's inputs: finalized, with UTXO data, of our script type.
                guard finalized else { throw fail("the receiver's input isn't finalized") }
                guard let prevout = try? proposal.prevout(input: i) else { throw fail("the receiver's input has no UTXO data") }
                let redeem = map.first { $0.key == [0x04] }?.value
                let type = OfflinePsbt.scriptType(spk: [UInt8](prevout.script), redeem: redeem)
                if Set(original.inputs.map(\.scriptType)).count == 1, type != original.inputs[0].scriptType {
                    throw fail("the receiver's input is a different script type")
                }
                amounts.append(Int64(OfflinePsbt.amount(prevout)))
                receiverInputs += 1
            }
        }

        // Outputs: no keypaths; every original output still there, in order.
        for map in proposal.outputs {
            guard !has(map, 0x02, count: 34), !has(map, 0x07, count: 33) else { throw fail("an output carries key paths") }
        }
        var outputIndices: [Int] = []
        var contribution: Int64 = 0
        for (o, output) in original.outputs.enumerated() {
            guard let p = tx.outputs.indices.first(where: { tx.outputs[$0].script == output.script && !outputIndices.contains($0) }) else {
                throw fail(o == original.paymentIndex ? "the payment output was removed or changed" : "one of your outputs was removed")
            }
            outputIndices.append(p)
            let before = Int64(OfflinePsbt.amount(output)), after = Int64(OfflinePsbt.amount(tx.outputs[p]))
            if o == original.paymentIndex {
                // Output substitution is disabled: the payment may only grow.
                guard after >= before else { throw fail("the payment was reduced") }
            } else if o == original.changeIndex, after < before {
                contribution = before - after
            } else {
                guard after >= before else { throw fail("one of your outputs was reduced") }
            }
        }
        guard outputIndices == outputIndices.sorted() else { throw fail("outputs were reordered") }

        // Fee: never lower; our extra contribution within every BIP78 cap.
        let fee = amounts.reduce(0, +) - tx.outputs.reduce(Int64(0)) { $0 + Int64(OfflinePsbt.amount($1)) }
        guard fee >= original.fee else { throw fail("the fee went down") }
        if contribution > 0 {
            guard let max = original.maxFeeContribution, let inputVsize = original.inputVsize else { throw fail("fee taken from your change without permission") }
            guard contribution <= max else { throw fail("more fee taken from your change than allowed") }
            guard contribution <= fee - original.fee else { throw fail("fee taken from your change wasn't used as fee") }
            let addedInputs = Int64(tx.inputs.count - original.inputs.count)
            guard Double(contribution) <= original.feeRate * Double(inputVsize) * Double(addedInputs) + 1 else {
                throw fail("more fee taken from your change than the added inputs need")
            }
        }

        // Ready to sign: put our derivations and UTXO data back on our inputs.
        for (k, i) in senderIndices.enumerated() {
            for entry in original.unsigned.inputs[k] where ![0x02, 0x07, 0x08, 0x13, 0x14].contains(entry.key.first ?? 0)
                && !proposal.inputs[i].contains(where: { $0.key == entry.key }) {
                proposal.inputs[i].append(entry)
            }
        }
        return (proposal.serialize(), receiverInputs, contribution)
    }

    // MARK: - Signing and finalizing

    /// Signs our inputs with the signers on this device (typed, stored, then no passphrase).
    static func sign(_ psbt: Data, passphrase: String?, completion: @escaping (Result<Data, Failure>) -> Void) {
        let fingerprints = Set(OfflinePsbt.fingerprints(in: psbt))
        CoreDataService.retrieveEntity(entityName: .signers) { signers in
            var current = psbt
            var added = 0
            for dict in signers ?? [] {
                let signer = SignerStruct(dictionary: dict)
                guard let encrypted = signer.words, var wordsData = Crypto.decrypt(encrypted), var words = wordsData.utf8String else { continue }
                defer {
                    wordsData.secureZero()
                    words.secureWipe()
                }
                var candidates: [String] = []
                if let passphrase { candidates.append(passphrase) }
                if let stored = signer.passphrase, var data = Crypto.decrypt(stored), let text = data.utf8String {
                    candidates.append(text)
                    data.secureZero()
                }
                candidates.append("")
                for candidate in candidates {
                    guard let keys = OfflineSeedKeys(words: words, passphrase: candidate), fingerprints.contains(keys.fingerprint) else { continue }
                    do {
                        let result = try OfflinePsbt.sign(current, keys: keys)
                        current = result.psbt
                        added += result.added
                    } catch {
                        completion(.failure(Failure("Signing the payjoin failed: \(error.localizedDescription)")))
                        return
                    }
                    break
                }
            }
            guard added > 0 else {
                completion(.failure(Failure("None of your signers could sign the payjoin.")))
                return
            }
            log("signed \(added) input(s)")
            completion(.success(current))
        }
    }

    /// The node finalizes it, and it must be accepted by the mempool before we hand it over.
    static func finalize(_ psbt: Data, completion: @escaping (Result<String, Failure>) -> Void) {
        let param = Finalize_Psbt(["psbt": psbt.base64EncodedString()])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .finalizepsbt(param)) { response, error in
            guard let dict = response as? [String: Any], dict["complete"] as? Bool == true, let hex = dict["hex"] as? String else {
                completion(.failure(Failure("The payjoin couldn't be fully signed on this device\(error.map { ": \($0)" } ?? ".")")))
                return
            }
            let test = Test_Mempool_Accept(["rawtxs": [hex]])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .testmempoolaccept(test)) { response, error in
                let result = (response as? [[String: Any]])?.first
                guard result?["allowed"] as? Bool == true else {
                    let reason = result?["reject-reason"] as? String ?? error ?? "unknown"
                    completion(.failure(Failure("Your node wouldn't accept the payjoin transaction (\(reason)).")))
                    return
                }
                completion(.success(hex))
            }
        }
    }

    // MARK: - Transport

    /// POSTs the original PSBT (BIP78: text/plain base64). Over Tor when it's connected, and
    /// always for onions; https certificates are validated normally either way.
    static func post(_ endpoint: URL, psbt: String, query: [URLQueryItem], completion: @escaping (Result<String, Failure>) -> Void) {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            completion(.failure(Failure("The payjoin address is invalid.")))
            return
        }
        components.queryItems = (components.queryItems ?? []) + query
        guard let url = components.url else {
            completion(.failure(Failure("The payjoin address is invalid.")))
            return
        }

        let isOnion = endpoint.host?.lowercased().hasSuffix(".onion") == true
        let useTor = TorClient.sharedInstance.state == .connected
        guard useTor || !isOnion else {
            completion(.failure(Failure("This payjoin needs Tor, which isn't connected yet.")))
            return
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 90
        if useTor {
            configuration.connectionProxyDictionary = [kCFProxyTypeKey: kCFProxyTypeSOCKS,
                                                       kCFStreamPropertySOCKSProxyHost: "localhost",
                                                       kCFStreamPropertySOCKSProxyPort: TorClient.socksPort]
        }
        let session = URLSession(configuration: configuration)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(psbt.utf8)
        log("→ POST \(endpoint.host ?? "") \(useTor ? "over Tor" : "directly (Tor not connected)")")

        session.dataTask(with: request) { data, response, error in
            session.finishTasksAndInvalidate()
            if let error {
                completion(.failure(Failure("Couldn't reach the receiver's payjoin service: \(error.localizedDescription)")))
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            log("← HTTP \(status), \(data?.count ?? 0) bytes")
            if status == 200 {
                completion(.success(body))
                return
            }
            // Only BIP78's well-known errors are shown, in our words: unknown text from the
            // receiver could be phishing (logged for debugging only).
            let code = ((try? JSONSerialization.jsonObject(with: data ?? Data())) as? [String: Any])?["errorCode"] as? String
            log("receiver error \(code ?? "?"): \(body.prefix(300))")
            switch code {
            case "unavailable": completion(.failure(Failure("The receiver's payjoin service is unavailable right now.")))
            case "not-enough-money": completion(.failure(Failure("The receiver couldn't add funds to make a payjoin.")))
            case "version-unsupported": completion(.failure(Failure("The receiver uses a payjoin version this app doesn't support.")))
            case "original-psbt-rejected": completion(.failure(Failure("The receiver's wallet turned this payment down for a payjoin (for example, it spends coins that wallet owns, or doesn't match the invoice).")))
            default: completion(.failure(Failure("The receiver couldn't make a payjoin.")))
            }
        }.resume()
    }

    /// Console log for payjoin (debug builds only).
    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[payjoin] \(message())")
        #endif
    }
}
