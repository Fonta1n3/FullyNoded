//
//  RegtestNode.swift
//  FullyNodedUITests
//
//  JSON-RPC to the regtest node from the test runner (the simulator reaches the Mac's
//  localhost), so tests can fund wallets, mine and check results without shell scripts.
//  Uses the "miner" wallet regtest/node.sh creates.
//

import XCTest

struct RegtestNode {
    struct RPCError: LocalizedError, CustomStringConvertible {
        var errorDescription: String? { description }
        let description: String
    }

    let address = FNUIEnv.rpcAddress
    let user = FNUIEnv.rpcUser
    let password: String

    init() throws {
        guard let password = FNUIEnv.rpcPassword else {
            throw XCTSkip("No regtest node: run regtest/node.sh <build> fresh, then the tests with regtest/run.sh.")
        }
        self.password = password
    }

    @discardableResult
    func call(_ method: String, _ params: [Any] = [], wallet: String? = nil, timeout: TimeInterval = 60) throws -> Any {
        var url = "http://\(address)"
        if let wallet = wallet {
            url += "/wallet/" + (wallet.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? wallet)
        }
        var request = URLRequest(url: URL(string: url)!, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("Basic " + Data("\(user):\(password)".utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["jsonrpc": "1.0", "id": "fnui", "method": method, "params": params])

        var result: Result<Any, Error> = .failure(RPCError(description: "\(method): no response"))
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, _, error in
            defer { done.signal() }
            if let error = error { result = .failure(error); return }
            guard let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                result = .failure(RPCError(description: "\(method): unreadable reply"))
                return
            }
            if let err = json["error"] as? [String: Any] {
                result = .failure(RPCError(description: "\(method): \(err["message"] as? String ?? "\(err)")"))
            } else {
                result = .success(json["result"] ?? NSNull())
            }
        }.resume()
        done.wait()
        return try result.get()
    }

    var version: Int { (try? call("getnetworkinfo") as? [String: Any])?["version"] as? Int ?? 0 }
    var blockCount: Int { (try? call("getblockcount")) as? Int ?? 0 }

    func ensureMiner() throws {
        if (try? call("getwalletinfo", wallet: "miner")) != nil { return }
        if (try? call("loadwallet", ["miner"])) != nil { return }
        try call("createwallet", ["miner"])
        try mine(150)
    }

    func mine(_ blocks: Int = 1) throws {
        let address = try call("getnewaddress", wallet: "miner") as! String
        try call("generatetoaddress", [blocks, address])
    }

    /// Sends from the miner wallet and (by default) confirms it.
    @discardableResult
    func pay(_ address: String, _ btc: Double, confirm: Bool = true) throws -> String {
        try ensureMiner()
        // As a string: JSON would write 0.3 as 0.29999999999999999, which Core rejects.
        let txid = try call("sendtoaddress", [address, String(format: "%.8f", btc)], wallet: "miner") as! String
        if confirm { try mine() }
        return txid
    }

    func newMinerAddress() throws -> String {
        try ensureMiner()
        return try call("getnewaddress", wallet: "miner") as! String
    }

    func mempool() throws -> [String] { try call("getrawmempool") as? [String] ?? [] }

    func decode(_ txid: String) throws -> [String: Any] {
        try call("getrawtransaction", [txid, true]) as? [String: Any] ?? [:]
    }

    /// The node's wallets named after Fully Noded's.
    func fullyNodedWallets() throws -> [String] {
        (try call("listwallets") as? [String] ?? []).filter { $0.hasPrefix("FullyNoded-") }
    }

    /// Unloads a wallet; its files are deleted by regtest/node.sh deletewallet (the runner
    /// can't reach the node's data directory).
    func unload(_ wallet: String) throws { try call("unloadwallet", [wallet]) }
}
