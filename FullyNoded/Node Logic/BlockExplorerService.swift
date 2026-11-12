//
//  BlockExplorerService.swift
//  FullyNoded
//
//  The explorer's calls to the node, and a small cache: blocks don't change (until a reorg, see
//  `forget`), and the node may be a slow Tor hop away. Completions run on the main queue.
//

import Foundation

final class BlockExplorerService {
    struct ChainTip: Equatable {
        let height: Int
        let hash: String
        let pruneHeight: Int?
        let chain: String
    }

    private var summaries: [Int: ExplorerBlockSummary] = [:]
    private var details: [String: ExplorerBlockDetail] = [:]
    private var miners: [Int: (name: String, isKnown: Bool)] = [:]
    private var soloHeights = Set<Int>()
    private var maps: [String: [ExplorerMapTx]] = [:]
    private var mapOrder: [String] = []
    private var loading = Set<Int>()
    private var wanted: [Int] = []
    /// Requests running at once, so a fast swipe can't stack up dozens over Tor.
    private var running = 0
    private static let maxRunning = 3
    private static let cachedMaps = 3
    private static let maxFilledInputs = 25
    private var lastTipHeight: Int?
    private var lastChain: String?

    func call(_ method: BTC_CLI_COMMAND, completion: @escaping (Any?, String?) -> Void) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: method) { response, error in
            DispatchQueue.main.async { completion(response, error) }
        }
    }

    /// Whether heavy calls are cheap: not Tor and not a Nostr relay.
    var isFastConnection: Bool {
        guard let node = MakeRPCCall.sharedInstance.activeNode, node.nostrConnect == nil,
              let encrypted = node.onionAddress else { return false }
        return !decryptedValue(encrypted).contains(".onion")
    }

    func tip(completion: @escaping (Result<ChainTip, ExplorerError>) -> Void) {
        call(.getblockchaininfo) { [weak self] response, error in
            guard let info = response as? [String: Any], let height = RPCValue.int(info["blocks"]),
                  let hash = RPCValue.string(info["bestblockhash"]) else {
                completion(.failure(ExplorerError(error ?? "The node didn't answer.")))
                return
            }
            let chain = RPCValue.string(info["chain"]) ?? "main"
            self?.lastTipHeight = height
            self?.lastChain = chain
            let pruned = RPCValue.bool(info["pruned"]) == true
            completion(.success(ChainTip(height: height, hash: hash, pruneHeight: pruned ? RPCValue.int(info["pruneheight"]) : nil,
                                         chain: chain)))
        }
    }

    func cachedSummary(_ height: Int) -> ExplorerBlockSummary? { summaries[height] }

    func cachedMiner(_ height: Int) -> (name: String, isKnown: Bool)? { miners[height] }

    func isCachedSolo(_ height: Int) -> Bool { soloHeights.contains(height) }

    private func noteCoinbase(_ hex: String, height: Int) {
        miners[height] = ExplorerMiner.identify(coinbaseHex: hex)
        if ExplorerMiner.isSolo(coinbaseHex: hex) { soloHeights.insert(height) }
    }

    /// Whether a new block is a solo win, and its reward in BTC if the node can say. Only asked of
    /// blocks arriving while the explorer's open, so about one a block. Quiet on any failure: at
    /// worst a celebration is missed.
    func checkSoloWin(height: Int, completion: @escaping (_ isSolo: Bool, _ rewardBtc: Double?) -> Void) {
        blockHash(height: height, fresh: true) { [weak self] result in
            guard let self = self, case .success(let hash) = result else {
                completion(false, nil)
                return
            }
            self.detail(hash: hash) { [weak self] _ in
                guard let self = self, self.isCachedSolo(height) else {
                    completion(false, nil)
                    return
                }
                self.call(.getblockstats(Get_Block_Stats(height: height, stats: ["subsidy", "totalfee"]))) { response, _ in
                    let stats = response as? [String: Any]
                    let sats = (RPCValue.int(stats?["subsidy"]) ?? 0) + (RPCValue.int(stats?["totalfee"]) ?? 0)
                    completion(true, sats > 0 ? Double(sats) / 100_000_000 : nil)
                }
            }
        }
    }

    /// The active wallet's recent transactions. nil without one: there's just nothing to mark.
    func walletActivity(completion: @escaping (ExplorerWalletActivity?) -> Void) {
        guard UserDefaults.standard.string(forKey: "walletName") != nil else {
            completion(nil)
            return
        }
        call(.listtransactions(List_Transactions(["count": 1000]))) { response, _ in
            completion((response as? [[String: Any]]).map { ExplorerWalletActivity(transactions: $0) })
        }
    }

    /// Where the strip's next-block item is, once the tip is known.
    var nextBlockHeight: Int? { lastTipHeight.map { $0 + 1 } }

    /// The active wallet's coins by block. Heights come from counting back from the tip, so a block
    /// arriving mid-way would put every coin one off: if the tip moves, ask again.
    func walletCoins(attempt: Int = 0, completion: @escaping (Result<[ExplorerCoinBlock], ExplorerError>) -> Void) {
        tip { [weak self] before in
            guard let self = self else { return }
            guard case .success(let start) = before else {
                completion(.failure(ExplorerError("Your node didn't answer.")))
                return
            }
            self.call(.listunspent(List_Unspent(["minconf": 0, "include_immature_coinbase": true]))) { [weak self] response, error in
                guard let self = self else { return }
                guard let utxos = response as? [[String: Any]] else {
                    completion(.failure(ExplorerError(error ?? "Your node didn't answer.")))
                    return
                }
                self.tip { [weak self] after in
                    if case .success(let end) = after, end.hash != start.hash, attempt < 2 {
                        self?.walletCoins(attempt: attempt + 1, completion: completion)
                    } else {
                        completion(.success(ExplorerCoinBlock.group(utxos: utxos, tipHeight: start.height)))
                    }
                }
            }
        }
    }

    /// The difficulty period's pace and the halving (headers only, so this works when pruned).
    func schedule(tip: ChainTip, completion: @escaping (ExplorerChainSchedule) -> Void) {
        let start = tip.height - tip.height % ExplorerChainSchedule.retargetInterval
        let time: (String, @escaping (Int?) -> Void) -> Void = { [weak self] hash, done in
            self?.call(.getblockheader(Get_Block_Header(blockhash: hash))) { header, _ in
                done(RPCValue.int((header as? [String: Any])?["time"]))
            }
        }
        time(tip.hash) { [weak self] tipTime in
            self?.blockHash(height: start) { result in
                guard case .success(let hash) = result else {
                    completion(ExplorerChainSchedule(height: tip.height, chain: tip.chain, tipTime: tipTime, periodStartTime: nil))
                    return
                }
                time(hash) { startTime in
                    completion(ExplorerChainSchedule(height: tip.height, chain: tip.chain, tipTime: tipTime, periodStartTime: startTime))
                }
            }
        }
    }

    /// Asks for these heights' summaries, nearest the end of the list first; heights no longer in
    /// the latest call are dropped from the queue. `completion` runs for each one that arrives.
    func requestSummaries(_ heights: [Int], completion: @escaping (ExplorerBlockSummary) -> Void) {
        wanted = heights.filter { summaries[$0] == nil && !loading.contains($0) }
        drain(completion)
    }

    private func drain(_ completion: @escaping (ExplorerBlockSummary) -> Void) {
        while running < Self.maxRunning, let height = wanted.popLast() {
            running += 1
            loading.insert(height)
            loadSummary(height) { [weak self] summary in
                guard let self = self else { return }
                self.running -= 1
                self.loading.remove(height)
                if let summary = summary {
                    self.summaries[height] = summary
                    completion(summary)
                }
                self.drain(completion)
            }
        }
    }

    /// Stats if the node has the block's undo data, otherwise just the header (which a pruned
    /// node always keeps).
    private func loadSummary(_ height: Int, completion: @escaping (ExplorerBlockSummary?) -> Void) {
        call(.getblockstats(Get_Block_Stats(height: height, stats: ExplorerBlockSummary.statNames))) { [weak self] response, _ in
            if let stats = response as? [String: Any], let summary = ExplorerBlockSummary(stats: stats) {
                completion(summary)
                return
            }
            guard let self = self else { return }
            self.call(.getblockhash(Get_Block_Hash(["height": height]))) { hash, _ in
                guard let hash = hash as? String else { completion(nil); return }
                self.call(.getblockheader(Get_Block_Header(blockhash: hash))) { header, _ in
                    completion((header as? [String: Any]).flatMap { ExplorerBlockSummary(header: $0) })
                }
            }
        }
    }

    /// `fresh` asks the node even if a hash is cached: a reorg can change it.
    func blockHash(height: Int, fresh: Bool = false, completion: @escaping (Result<String, ExplorerError>) -> Void) {
        if !fresh, let hash = summaries[height]?.hash {
            completion(.success(hash))
            return
        }
        call(.getblockhash(Get_Block_Hash(["height": height]))) { response, error in
            if let hash = response as? String { completion(.success(hash)) } else { completion(.failure(ExplorerError(error ?? "No block at that height."))) }
        }
    }

    func detail(hash: String, completion: @escaping (Result<ExplorerBlockDetail, ExplorerError>) -> Void) {
        if let cached = details[hash] {
            completion(.success(cached))
            return
        }
        call(.getblock(Get_Block(["blockhash": hash, "verbosity": 1]))) { [weak self] response, error in
            guard let block = response as? [String: Any], let detail = ExplorerBlockDetail(block: block) else {
                completion(.failure(ExplorerError(error ?? "The node couldn't read that block.")))
                return
            }
            self?.details[hash] = detail
            // Core 29+ includes the coinbase; older nodes need one more small call.
            if let hex = RPCValue.string((block["coinbase_tx"] as? [String: Any])?["coinbase"]) {
                self?.noteCoinbase(hex, height: detail.height)
                completion(.success(detail))
            } else if let coinbase = detail.txids.first, let self = self {
                self.call(.getrawtransaction(param: Get_Raw_Tx(["txid": coinbase, "verbosity": 1, "blockhash": hash]))) { [weak self] raw, _ in
                    let vin = ((raw as? [String: Any])?["vin"] as? [[String: Any]])?.first
                    if let hex = RPCValue.string(vin?["coinbase"]) { self?.noteCoinbase(hex, height: detail.height) }
                    completion(.success(detail))
                }
            } else {
                completion(.success(detail))
            }
        }
    }

    func cachedMap(hash: String) -> [ExplorerMapTx]? { maps[hash] }

    /// Every transaction with its size and fee (`getblock` verbosity 2, many megabytes). Only
    /// the compact result is kept, for the last few blocks opened.
    func map(hash: String, completion: @escaping (Result<[ExplorerMapTx], ExplorerError>) -> Void) {
        if let cached = maps[hash] {
            completion(.success(cached))
            return
        }
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getblock(Get_Block(["blockhash": hash, "verbosity": 2]))) { [weak self] response, error in
            guard let block = response as? [String: Any] else {
                DispatchQueue.main.async { completion(.failure(ExplorerError(error ?? "The node couldn't read that block."))) }
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let map = ExplorerMapTx.fromBlock(block)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.maps[hash] = map
                    self.mapOrder.append(hash)
                    while self.mapOrder.count > Self.cachedMaps { self.maps[self.mapOrder.removeFirst()] = nil }
                    completion(.success(map))
                }
            }
        }
    }

    func mempool(completion: @escaping ([String: Any]?) -> Void) {
        call(.getmempoolinfo) { response, _ in completion(response as? [String: Any]) }
    }

    /// The block the node would mine now (no block found yet, so never cached). Asks with the
    /// signet rule on signet, and once more with it if a node of unknown chain asks for it.
    func template(signet: Bool? = nil, completion: @escaping (Result<[ExplorerMapTx], ExplorerError>) -> Void) {
        let isSignet = signet ?? (lastChain == "signet")
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getblocktemplate(Get_Block_Template(signet: isSignet))) { [weak self] response, error in
            guard let template = response as? [String: Any] else {
                if !isSignet, error?.lowercased().contains("signet") == true {
                    DispatchQueue.main.async { self?.template(signet: true, completion: completion) }
                    return
                }
                DispatchQueue.main.async { completion(.failure(ExplorerError(error ?? "The node didn't return a template."))) }
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let map = ExplorerMapTx.fromTemplate(template)
                DispatchQueue.main.async { completion(.success(map)) }
            }
        }
    }

    /// A transaction with its inputs' prevouts. Without txindex a confirmed one needs its block's
    /// hash; a mempool one doesn't.
    func transaction(txid: String, blockhash: String?, completion: @escaping (Result<(ExplorerTx, [String: Any]), ExplorerError>) -> Void) {
        var param: [String: Any] = ["txid": txid, "verbosity": 2]
        if let blockhash = blockhash { param["blockhash"] = blockhash }
        call(.getrawtransaction(param: Get_Raw_Tx(param))) { [weak self] response, error in
            guard let raw = response as? [String: Any], let tx = ExplorerTx(raw: raw) else {
                completion(.failure(ExplorerError(error ?? "The node couldn't find that transaction.")))
                return
            }
            guard tx.confirmations == 0 else {
                completion(.success((tx, raw)))
                return
            }
            self?.fillInMempool(tx) { completion(.success(($0, raw))) }
        }
    }

    /// The node gives prevouts and the fee only for confirmed transactions. For one still in the
    /// mempool: the fee from its entry, and each input from the chain's UTXO set, or from its
    /// parent if that's unconfirmed too. Whatever can't be found stays unknown.
    private func fillInMempool(_ tx: ExplorerTx, completion: @escaping (ExplorerTx) -> Void) {
        var filled = tx
        let group = DispatchGroup()
        group.enter()
        call(.getmempoolentry(Get_Mempool_Entry(txid: tx.txid))) { response, _ in
            let fees = (response as? [String: Any])?["fees"] as? [String: Any]
            filled.feeBtc = RPCValue.double(fees?["base"])
            group.leave()
        }
        // Enough to read; a huge transaction shouldn't send hundreds of calls over Tor.
        for (index, input) in tx.inputs.enumerated().prefix(Self.maxFilledInputs) {
            guard let txid = input.txid, let vout = input.vout, !input.coinbase else { continue }
            group.enter()
            fillInput(txid: txid, vout: vout) { value, address, type, height in
                filled.inputs[index].valueBtc = value
                filled.inputs[index].address = address
                filled.inputs[index].scriptType = type
                filled.inputs[index].sourceHeight = height
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(filled) }
    }

    private func fillInput(txid: String, vout: Int, completion: @escaping (Double?, String?, String?, Int?) -> Void) {
        call(.gettxout(Get_Tx_Out(txid: txid, n: vout, includeMempool: false))) { [weak self] response, _ in
            if let out = response as? [String: Any] {
                let script = out["scriptPubKey"] as? [String: Any]
                // The tip's height minus its confirmations gives the block it was created in.
                let height = RPCValue.int(out["confirmations"]).flatMap { confirmations in
                    self?.lastTipHeight.map { $0 - confirmations + 1 }
                }
                completion(RPCValue.double(out["value"]), RPCValue.string(script?["address"]), RPCValue.string(script?["type"]), height)
                return
            }
            // Not in the chain's UTXO set: its parent is unconfirmed too.
            self?.call(.getrawtransaction(param: Get_Raw_Tx(["txid": txid, "verbosity": 1]))) { parent, _ in
                let output = (parent as? [String: Any]).flatMap { ExplorerTx(raw: $0) }?.outputs.first { $0.n == vout }
                completion(output?.valueBtc, output?.address, output?.scriptType, nil)
            }
        }
    }

    enum OutputStatus {
        case unspent
        case spentInMempool(by: String)
        /// Spent in a block. Core keeps no index of spends, so which one is unknown.
        case spent
    }

    func outputStatus(txid: String, n: Int, completion: @escaping (Result<OutputStatus, ExplorerError>) -> Void) {
        call(.gettxout(Get_Tx_Out(txid: txid, n: n))) { [weak self] response, error in
            if let error = error {
                completion(.failure(ExplorerError(error)))
                return
            }
            if response is [String: Any] {
                completion(.success(.unspent))
                return
            }
            guard let self = self else { return }
            self.call(.gettxspendingprevout(Get_Tx_Spending_Prevout(txid: txid, vout: n))) { spending, _ in
                if let spender = (spending as? [[String: Any]])?.first.flatMap({ RPCValue.string($0["spendingtxid"]) }) {
                    completion(.success(.spentInMempool(by: spender)))
                } else {
                    completion(.success(.spent))
                }
            }
        }
    }

    /// After a reorg: everything from this height up may be different.
    func forget(from height: Int) {
        for key in summaries.keys where key >= height {
            if let hash = summaries[key]?.hash {
                details[hash] = nil
                maps[hash] = nil
            }
            summaries[key] = nil
            miners[key] = nil
            soloHeights.remove(key)
        }
        mapOrder.removeAll { maps[$0] == nil }
    }
}

struct ExplorerError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
