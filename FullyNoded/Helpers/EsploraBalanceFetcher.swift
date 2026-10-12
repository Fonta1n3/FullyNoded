//
//  EsploraBalanceFetcher.swift
//  FullyNoded
//
//  Created by Peter Denton on 12/6/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation
import BitcoinDevKit

/// The Esplora API (Blockstream's onion service; mempool.space's for testnet4, which
/// Blockstream doesn't serve) every nodeless feature uses, over Tor:
/// address utxos, transaction outputs, broadcasting.
enum EsploraAPI {
    static let blockstreamOnion = "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion"
    static let mempoolOnion = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion"

    enum APIError: LocalizedError {
        case unsupportedNetwork
        case badURL
        case http(Int, String)
        case badResponse(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedNetwork: return "Nodeless features aren't available on regtest (there's no public Esplora server for it)."
            case .badURL: return "Invalid Esplora URL."
            case .http(let status, let message): return message.isEmpty ? "HTTP \(status) from Esplora." : message
            case .badResponse(let message): return "Unexpected Esplora response: \(message)"
            }
        }
    }

    /// "<host>[/testnet|/testnet4|/signet]/api", no trailing slash. nil on regtest.
    static func apiBase(network: WalletLogic.BDKNetwork) -> String? {
        switch network {
        case .bitcoin: return "\(blockstreamOnion)/api"
        case .testnet: return "\(blockstreamOnion)/testnet/api"
        case .signet: return "\(blockstreamOnion)/signet/api"
        case .testnet4: return "\(mempoolOnion)/testnet4/api"
        default: return nil
        }
    }

    static func url(_ path: String, network: WalletLogic.BDKNetwork) throws -> URL {
        guard let base = apiBase(network: network) else { throw APIError.unsupportedNetwork }
        guard let url = URL(string: "\(base)\(path)") else { throw APIError.badURL }
        return url
    }

    /// A one-off session with Tor's proxy settings. The shared Tor session keeps connections
    /// alive between requests, and the onion service closes idle ones: reusing one after a pause
    /// (e.g. while an address is typed) fails with "The network connection was lost". A fresh
    /// session per request never reuses a stale connection. Invalidate it when done.
    static func freshSession() -> URLSession {
        URLSession(configuration: TorClient.sharedInstance.session.configuration)
    }

    /// GET, failing on anything but HTTP 200 (with Esplora's plain-text error as the message).
    /// Connection failures are retried twice (GETs are safe to repeat; Tor circuits drop).
    static func get(_ path: String, network: WalletLogic.BDKNetwork) async throws -> Data {
        let request = URLRequest(url: try url(path, network: network), timeoutInterval: 60)
        let retryable: Set<URLError.Code> = [.networkConnectionLost, .timedOut, .cannotConnectToHost, .cannotFindHost]
        var attempt = 0
        while true {
            let session = freshSession()
            defer { session.finishTasksAndInvalidate() }
            do {
                let (data, response) = try await session.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard status == 200 else {
                    throw APIError.http(status, String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                }
                return data
            } catch let error as URLError where attempt < 2 && retryable.contains(error.code) {
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_500_000_000)
            }
        }
    }

    // MARK: Through BDK's client (Tor's HTTP tunnel)

    /// Tor's HTTP tunnel port (TorClient's "HTTPTunnelPort"). BDK's Esplora client tunnels
    /// through it with CONNECT, which is the path that works reliably to the onion service;
    /// URLSession can't use it for http:// URLs (it sends plain proxied requests, which the
    /// tunnel rejects).
    static let tunnelProxy = "http://localhost:9080"

    /// BDK's Esplora client for `network`, through the Tor HTTP tunnel.
    static func client(network: WalletLogic.BDKNetwork) throws -> EsploraClient {
        guard let base = apiBase(network: network) else { throw APIError.unsupportedNetwork }
        // No trailing slash: the client appends paths that start with "/".
        return EsploraClient(url: base, proxy: tunnelProxy)
    }

    /// Runs a blocking client call off the main thread, retrying failures that are safe to
    /// repeat: any network failure for read-only calls (`retries`), and for every call Tor's
    /// tunnel refusing to connect (`tunnelRetries`), as then nothing reached the server.
    static func run<T>(retries: Int = 0, tunnelRetries: Int = 2, _ call: @escaping () throws -> T) async throws -> T {
        var attempt = 0
        while true {
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        continuation.resume(with: Result { try call() })
                    }
                }
            } catch let error as EsploraError where attempt < max(retries, isTunnelRefusal(error) ? tunnelRetries : 0)
                                                     && (isTunnelRefusal(error) || isNetworkFailure(error)) {
                attempt += 1
                // Give Tor time to build a new circuit to the onion service.
                try await Task.sleep(nanoseconds: UInt64(attempt) * 3_000_000_000)
            }
        }
    }

    /// `run` for callers already off the main thread (blocking; same retry rules).
    static func runBlocking<T>(retries: Int = 0, tunnelRetries: Int = 2, _ call: () throws -> T) throws -> T {
        var attempt = 0
        while true {
            do {
                return try call()
            } catch let error as EsploraError where attempt < max(retries, isTunnelRefusal(error) ? tunnelRetries : 0)
                                                     && (isTunnelRefusal(error) || isNetworkFailure(error)) {
                attempt += 1
                Thread.sleep(forTimeInterval: Double(attempt) * 3)
            }
        }
    }

    /// A funding transaction (blocking, retried on network failures).
    static func transaction(txid: String, network: WalletLogic.BDKNetwork) throws -> Transaction {
        let client = try client(network: network)
        let id = try Txid.fromString(hex: txid)
        do {
            guard let tx = try runBlocking(retries: 2, { try client.getTx(txid: id) }) else {
                throw APIError.badResponse("transaction \(txid) not found")
            }
            return tx
        } catch let error as EsploraError {
            throw APIError.badResponse(message(error))
        }
    }

    private static func isNetworkFailure(_ error: EsploraError) -> Bool {
        if case .Minreq = error { return true }
        return false
    }

    /// Tor's HTTP tunnel answers a CONNECT it couldn't complete with a bare 503 (no body): the
    /// onion service wasn't reached, so the request was never sent.
    static func isTunnelRefusal(_ error: Error) -> Bool {
        if case .HttpResponse(let status, let message)? = error as? EsploraError {
            return status == 503 && message.isEmpty
        }
        return false
    }

    /// Esplora's own message for an error (e.g. the node's reject reason on broadcast), never
    /// empty: the error kind (and HTTP status) is always included.
    static func message(_ error: Error) -> String {
        guard let error = error as? EsploraError else { return error.localizedDescription }
        let text: String
        switch error {
        case .HttpResponse(let status, let message) where status == 503 && message.isEmpty:
            text = "Tor couldn't reach the Esplora onion service (HTTP 503 from the Tor tunnel). Try again in a moment."
        case .HttpResponse(let status, let message):
            text = "HTTP \(status)" + (message.isEmpty ? "" : ": \(message)")
        case .Minreq(let message):
            text = "Connection error" + (message.isEmpty ? "" : ": \(message)")
        case .Parsing(let message), .StatusCode(let message):
            text = message.isEmpty ? "\(error)" : message
        case .TransactionNotFound:
            text = "Transaction not found."
        default:
            text = "\(error)"
        }
        #if DEBUG
        print("Esplora error: \(error)")
        #endif
        return text
    }

    /// One output of a confirmed or mempool transaction: its amount and script.
    struct TxOutput {
        let value: Int64
        let scriptPubKey: String   // hex
    }

    static func output(txid: String, vout: Int, network: WalletLogic.BDKNetwork) async throws -> TxOutput {
        let client = try client(network: network)
        let id = try Txid.fromString(hex: txid)
        do {
            guard let tx = try await run(retries: 2, { try client.getTx(txid: id) }) else {
                throw APIError.badResponse("transaction \(txid) not found")
            }
            let outputs = tx.output()
            guard outputs.indices.contains(vout) else {
                throw APIError.badResponse("transaction \(txid) has no output \(vout)")
            }
            let out = outputs[vout]
            return TxOutput(value: Int64(out.value.toSat()),
                            scriptPubKey: out.scriptPubkey.toBytes().map { String(format: "%02x", $0) }.joined())
        } catch let error as EsploraError {
            throw APIError.badResponse(message(error))
        }
    }

    /// Broadcasts a signed transaction (hex), returning its txid. Not retried: a failed attempt
    /// is reported as is.
    static func broadcast(rawTx: String, network: WalletLogic.BDKNetwork) async throws -> String {
        let client = try client(network: network)
        guard let bytes = Data(hexString: rawTx.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.badResponse("not a hex transaction")
        }
        let tx = try Transaction(transactionBytes: bytes)
        try await run { try client.broadcast(transaction: tx) }
        return tx.computeTxid().description
    }
}

class NodelessUtxoFetcher {

    static let shared = NodelessUtxoFetcher()

    private init() {}

    enum UtxosResult {
        case success(utxos: [Esplora_Utxo])
        case failure(errorMessage: String)
    }

    func fetchUtxos(for address: String, network: WalletLogic.BDKNetwork) async throws -> UtxosResult {
        do {
            let data = try await EsploraAPI.get("/address/\(address)/utxo", network: network)
            // An empty body is a valid "no utxos".
            guard !data.isEmpty else { return .success(utxos: []) }
            do {
                return .success(utxos: try JSONDecoder().decode([Esplora_Utxo].self, from: data))
            } catch {
                return .failure(errorMessage: "JSON decoding failed: \(error.localizedDescription)")
            }
        } catch let error as EsploraAPI.APIError {
            // e.g. "Address belongs to wrong network"
            return .failure(errorMessage: error.localizedDescription)
        } catch {
            // Network-level errors (timeout, no connection, etc.)
            return .failure(errorMessage: "Network error: \(error.localizedDescription)")
        }
    }
}
