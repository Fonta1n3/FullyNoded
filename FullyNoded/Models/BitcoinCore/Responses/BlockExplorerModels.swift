//
//  BlockExplorerModels.swift
//  FullyNoded
//
//  What the block explorer shows, read leniently from the node's replies: Core's fields vary by
//  version, and on a pruned node anything that needs a block's data can be missing.
//

import Foundation

/// One block in the strip. Stats are nil when the node can't compute them (a pruned block, or
/// the genesis block), and then only the header's facts are known.
struct ExplorerBlockSummary {
    let height: Int
    let hash: String?
    let time: Int
    let txCount: Int
    /// Both from getblockstats, which leaves out the coinbase: a block's true figures are a little more.
    let weight: Int?
    let size: Int?
    let totalFeeSats: Int?
    let subsidySats: Int?
    /// sat/vB at the 10th, 25th, 50th, 75th and 90th percentile of weight.
    let feeRatePercentiles: [Int]?

    static let statNames = ["height", "blockhash", "time", "txs", "total_weight", "total_size", "totalfee", "subsidy", "feerate_percentiles"]
    static let maxWeight = 4_000_000

    /// What the miner earned: new coins plus fees.
    var rewardBtc: Double? {
        guard let subsidy = subsidySats, let fees = totalFeeSats else { return nil }
        return Double(subsidy + fees) / 100_000_000
    }

    var medianFeeRate: Int? {
        guard let rates = feeRatePercentiles, rates.count == 5 else { return nil }
        return rates[2]
    }

    /// How full the block is, 0...1.
    var fullness: Double? {
        weight.map { min(Double($0) / Double(Self.maxWeight), 1) }
    }

    init?(stats: [String: Any]) {
        guard let height = RPCValue.int(stats["height"]), let time = RPCValue.int(stats["time"]), let txs = RPCValue.int(stats["txs"]) else { return nil }
        self.height = height
        hash = RPCValue.string(stats["blockhash"])
        self.time = time
        txCount = txs
        weight = RPCValue.int(stats["total_weight"])
        size = RPCValue.int(stats["total_size"])
        totalFeeSats = RPCValue.int(stats["totalfee"])
        subsidySats = RPCValue.int(stats["subsidy"])
        feeRatePercentiles = (stats["feerate_percentiles"] as? [Any])?.compactMap { RPCValue.int($0) }
    }

    init?(header: [String: Any]) {
        guard let height = RPCValue.int(header["height"]), let time = RPCValue.int(header["time"]) else { return nil }
        self.height = height
        hash = RPCValue.string(header["hash"])
        self.time = time
        txCount = RPCValue.int(header["nTx"]) ?? 0
        weight = nil
        size = nil
        totalFeeSats = nil
        subsidySats = nil
        feeRatePercentiles = nil
    }
}

/// `getblock` verbosity 1: the block's facts and its txids.
struct ExplorerBlockDetail {
    let hash: String
    let height: Int
    let time: Int
    let size: Int?
    let weight: Int?
    let difficulty: Double?
    let nonce: Int?
    let previousHash: String?
    let confirmations: Int?
    let txids: [String]

    init?(block: [String: Any]) {
        guard let hash = RPCValue.string(block["hash"]), let height = RPCValue.int(block["height"]) else { return nil }
        self.hash = hash
        self.height = height
        time = RPCValue.int(block["time"]) ?? 0
        size = RPCValue.int(block["size"])
        weight = RPCValue.int(block["weight"])
        difficulty = RPCValue.double(block["difficulty"])
        nonce = RPCValue.int(block["nonce"])
        previousHash = RPCValue.string(block["previousblockhash"])
        confirmations = RPCValue.int(block["confirmations"])
        txids = (block["tx"] as? [Any])?.compactMap { RPCValue.string($0) } ?? []
    }
}

/// One transaction on the block map: its area is `vsize`, its colour `feeRate`.
struct ExplorerMapTx {
    let txid: String
    let vsize: Int
    /// sat/vB. nil: the coinbase, or the node didn't say.
    let feeRate: Double?
    let isCoinbase: Bool
    /// Actual bytes. nil if the node didn't say.
    var size: Int? = nil
    /// What the shape of the transaction suggests (see ExplorerTxCategory.shape).
    var category: String? = nil

    /// Every transaction of a `getblock` verbosity 2 reply (fees need undo data, and can be absent).
    static func fromBlock(_ block: [String: Any]) -> [ExplorerMapTx] {
        ((block["tx"] as? [[String: Any]]) ?? []).enumerated().compactMap { index, tx in
            guard let txid = RPCValue.string(tx["txid"]) else { return nil }
            let vsize = RPCValue.int(tx["vsize"]) ?? 1
            let fee = RPCValue.double(tx["fee"])
            return ExplorerMapTx(txid: txid, vsize: max(vsize, 1),
                                 feeRate: fee.map { $0 * 100_000_000 / Double(max(vsize, 1)) },
                                 isCoinbase: index == 0,
                                 size: RPCValue.int(tx["size"]),
                                 category: index == 0 ? nil : ExplorerTxCategory.quickName(rawTx: tx))
        }
    }

    /// `getblocktemplate`'s transactions (no coinbase; fee in sats, size as weight).
    static func fromTemplate(_ template: [String: Any]) -> [ExplorerMapTx] {
        ((template["transactions"] as? [[String: Any]]) ?? []).compactMap { tx in
            guard let txid = RPCValue.string(tx["txid"]) else { return nil }
            let vsize = max(((RPCValue.int(tx["weight"]) ?? 4) + 3) / 4, 1)
            return ExplorerMapTx(txid: txid, vsize: vsize,
                                 feeRate: RPCValue.double(tx["fee"]).map { $0 / Double(vsize) }, isCoinbase: false,
                                 size: RPCValue.string(tx["data"]).map { $0.count / 2 })
        }
    }
}

/// `getrawtransaction` verbosity 2: a transaction with what each input spends.
struct ExplorerTx {
    struct Input {
        let txid: String?
        let vout: Int?
        let coinbase: Bool
        var valueBtc: Double?
        var address: String?
        var scriptType: String?
        /// The block the spent output was created in, which is how tracing finds it without txindex.
        var sourceHeight: Int?
        let sequence: Int?
    }

    struct Output {
        let n: Int
        let valueBtc: Double
        let address: String?
        let scriptType: String?
    }

    let txid: String
    let vsize: Int?
    let weight: Int?
    let size: Int?
    let locktime: Int?
    let version: Int?
    var feeBtc: Double?
    let blockhash: String?
    let blocktime: Int?
    let confirmations: Int
    var inputs: [Input]
    let outputs: [Output]

    var totalOutBtc: Double { outputs.reduce(0) { $0 + $1.valueBtc } }

    /// sat/vB.
    var feeRate: Double? {
        guard let fee = feeBtc, let vsize = vsize, vsize > 0 else { return nil }
        return fee * 100_000_000 / Double(vsize)
    }

    var isCoinbase: Bool { inputs.first?.coinbase == true }

    /// Replaceable if any input opts in (BIP125).
    var signalsRBF: Bool { inputs.contains { ($0.sequence ?? .max) < 0xFFFFFFFE } }

    init?(raw: [String: Any]) {
        guard let txid = RPCValue.string(raw["txid"]) else { return nil }
        self.txid = txid
        vsize = RPCValue.int(raw["vsize"])
        weight = RPCValue.int(raw["weight"])
        size = RPCValue.int(raw["size"])
        locktime = RPCValue.int(raw["locktime"])
        version = RPCValue.int(raw["version"])
        feeBtc = RPCValue.double(raw["fee"])
        blockhash = RPCValue.string(raw["blockhash"])
        blocktime = RPCValue.int(raw["blocktime"])
        confirmations = RPCValue.int(raw["confirmations"]) ?? 0
        inputs = ((raw["vin"] as? [[String: Any]]) ?? []).map { vin in
            let prevout = vin["prevout"] as? [String: Any]
            let script = prevout?["scriptPubKey"] as? [String: Any]
            return Input(txid: RPCValue.string(vin["txid"]),
                         vout: RPCValue.int(vin["vout"]),
                         coinbase: vin["coinbase"] != nil,
                         valueBtc: RPCValue.double(prevout?["value"]),
                         address: RPCValue.string(script?["address"]),
                         scriptType: RPCValue.string(script?["type"]),
                         sourceHeight: RPCValue.int(prevout?["height"]),
                         sequence: RPCValue.int(vin["sequence"]))
        }
        outputs = ((raw["vout"] as? [[String: Any]]) ?? []).enumerated().map { index, vout in
            let script = vout["scriptPubKey"] as? [String: Any]
            return Output(n: RPCValue.int(vout["n"]) ?? index,
                          valueBtc: RPCValue.double(vout["value"]) ?? 0,
                          address: RPCValue.string(script?["address"]),
                          scriptType: RPCValue.string(script?["type"]))
        }
    }

    /// What to call an output with no address.
    static func scriptName(_ type: String?) -> String {
        switch type {
        case "nulldata": return "OP_RETURN data"
        case "multisig": return "Bare multisig"
        case "pubkey": return "Pay to public key"
        case "witness_unknown": return "Unknown witness program"
        case "nonstandard": return "Non-standard script"
        case let other?: return other
        case nil: return "Unknown script"
        }
    }
}

/// Who mined a block, from the text miners put in the coinbase. Self-reported, and anyone can
/// write anything there.
enum ExplorerMiner {
    /// Text to find in the coinbase, and the pool's name.
    private static let knownPools: [(tag: String, name: String)] = [
        ("solo.ckpool", "CKPool Solo"), ("foundry", "Foundry USA"), ("antpool", "AntPool"), ("viabtc", "ViaBTC"), ("f2pool", "F2Pool"),
        ("spiderpool", "SpiderPool"), ("mara", "MARA Pool"), ("luxor", "Luxor"), ("ocean", "OCEAN"),
        ("sbicrypto", "SBI Crypto"), ("binance", "Binance Pool"), ("secpool", "SECPOOL"), ("braiins", "Braiins"),
        ("slush", "Braiins"), ("poolin", "Poolin"), ("whitepool", "WhitePool"), ("titan", "Titan"),
        ("miningsquared", "Mining Squared"), ("1thash", "1THash"), ("kucoin", "KuCoin Pool"),
        ("btc.com", "BTC.com"), ("bitfufu", "BitFuFu"), ("nicehash", "NiceHash"), ("pyblock", "PyBLOCK"),
        ("public-pool", "Public Pool"), ("ckpool", "CKPool"), ("solo", "Solo miner")
    ]

    /// Whether the coinbase says it's a solo win: one small miner taking a whole block reward, not
    /// a share of a pool's. Self-reported like any tag. "solo" must be a word of its own, so a
    /// name that merely contains it doesn't count.
    static func isSolo(coinbaseHex: String) -> Bool {
        guard let bytes = Hex.decode(coinbaseHex) else { return false }
        let text = bytes.split { $0 < 0x20 || $0 > 0x7E }
            .map { String(decoding: $0, as: UTF8.self) }.joined(separator: " ").lowercased()
        if ["solo.ckpool", "public-pool", "publicpool", "public pool"].contains(where: text.contains) { return true }
        return text.range(of: #"(^|[^a-z0-9])solo([^a-z0-9]|$)"#, options: .regularExpression) != nil
    }

    /// (name, whether it's a pool we recognise) from the coinbase script's hex.
    static func identify(coinbaseHex: String) -> (name: String, isKnown: Bool)? {
        guard let bytes = Hex.decode(coinbaseHex) else { return nil }
        // Runs of printable text; the rest of the script is numbers.
        let runs = bytes.split { $0 < 0x20 || $0 > 0x7E }
            .map { String(decoding: $0, as: UTF8.self) }
            .filter { $0.count >= 4 && $0.filter(\.isLetter).count >= 3 }
        let text = runs.joined(separator: " ").lowercased()
        if let pool = knownPools.first(where: { text.contains($0.tag) }) { return (pool.name, true) }
        guard let longest = runs.max(by: { $0.count < $1.count }) else { return nil }
        return (String(longest.prefix(24)), false)
    }
}

/// What kind of transaction this looks like. All of these are guesses from public data: a payment
/// can look like a consolidation, and nothing on-chain proves who owns an address.
struct ExplorerTxCategory: Equatable {
    let name: String
    let detail: String

    static let years5Blocks = 262_800
    static let blocksPerYear = 52_560
    /// The first subsidy era ended here, in late 2012.
    static let firstEraEnd = 210_000

    /// From inputs and outputs alone, which is all a block's transaction list has.
    static func shape(inputs: Int, outputValues: [Double]) -> ExplorerTxCategory? {
        let outputs = outputValues.count
        guard inputs > 0, outputs > 0 else { return nil }
        // The same amount to several outputs, from several inputs: what makes outputs unlinkable.
        var counts: [Int: Int] = [:]
        for value in outputValues where value > 0 { counts[Int((value * 100_000_000).rounded()), default: 0] += 1 }
        let equal = counts.values.max() ?? 0
        if equal >= 3, inputs >= 3 {
            return ExplorerTxCategory(name: "CoinJoin", detail: "\(equal) outputs of the same amount, from \(inputs) inputs. Likely a CoinJoin.")
        }
        if (inputs >= 5 && outputs <= 2) || (inputs >= 3 && outputs == 1) {
            return ExplorerTxCategory(name: "Consolidation", detail: "\(inputs) inputs into \(outputs) output\(outputs == 1 ? "" : "s"). Likely merging coins.")
        }
        if outputs >= 10 {
            return ExplorerTxCategory(name: "Batch payment", detail: "One transaction paying \(outputs) outputs.")
        }
        if outputs == 1 {
            return ExplorerTxCategory(name: "No change", detail: "Everything went to one output: a sweep, or a move between someone's own wallets.")
        }
        return nil
    }

    /// For a row in a block's list: the shape, or data found without decoding it. Runs off the main
    /// thread over thousands of transactions, so it only looks for fixed markers.
    static func quickName(rawTx tx: [String: Any]) -> String? {
        let vin = tx["vin"] as? [[String: Any]] ?? []
        let vout = tx["vout"] as? [[String: Any]] ?? []
        for output in vout {
            if ((output["scriptPubKey"] as? [String: Any])?["hex"] as? String)?.hasPrefix("6a5d") == true { return dataName }
        }
        for input in vin {
            for item in input["txinwitness"] as? [String] ?? [] where item.count > 12 && item.contains("0063036f7264") {
                return dataName
            }
        }
        return shape(inputs: vin.count, outputValues: vout.map { RPCValue.double($0["value"]) ?? 0 })?.name
    }

    static let dataName = "Data/spam"

    /// Everything known about a transaction once it's opened.
    /// `height`: the block it's in, or the next one while it's in the mempool.
    static func all(tx: ExplorerTx, embedded: [ExplorerEmbeddedData], height: Int?) -> [ExplorerTxCategory] {
        var categories: [ExplorerTxCategory] = []
        if !tx.isCoinbase, let shape = shape(inputs: tx.inputs.count, outputValues: tx.outputs.map(\.valueBtc)) {
            categories.append(shape)
        }
        var dataNames: [String] = []
        for item in embedded where item.isTokenOrInscription && !dataNames.contains(item.name) { dataNames.append(item.name) }
        if !dataNames.isEmpty {
            categories.append(ExplorerTxCategory(name: dataName, detail: "Carries \(dataNames.joined(separator: ", ")). Whether that's spam depends on who you ask."))
        }
        if let height = height, let oldest = tx.inputs.compactMap(\.sourceHeight).min() {
            let age = height - oldest
            if oldest < firstEraEnd, age >= years5Blocks {
                categories.append(ExplorerTxCategory(name: "Very old coins", detail: "Spends coins from block \(oldest.withCommas), in Bitcoin's first era (2009 to 2012)."))
            } else if age >= years5Blocks {
                categories.append(ExplorerTxCategory(name: "Old coins", detail: "Spends coins about \(age / blocksPerYear) years old, from block \(oldest.withCommas)."))
            }
        }
        let addresses = tx.inputs.compactMap(\.address) + tx.outputs.compactMap(\.address)
        var noted = Set<String>()
        for address in addresses where noted.insert(address).inserted {
            if let known = ExplorerKnownAddress.note(for: address) {
                categories.append(ExplorerTxCategory(name: known.name, detail: known.detail))
            }
        }
        return categories
    }
}

/// A short list of addresses that are famous, or publicly reported in connection with thefts or
/// seizures. Kept small on purpose, and only with a public record behind each: this isn't a
/// sanctions or risk list, and it says nothing about anyone merely sending to one of these.
enum ExplorerKnownAddress {
    private static let known: [String: (name: String, detail: String)] = [
        "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa": ("Genesis address", "The address of Bitcoin's first block. People still send it coins as a tribute."),
        "1BitcoinEaterAddressDontSendf59kuE": ("Burn address", "A vanity address nobody can have the key to. Coins sent here are gone."),
        "17SkEw2md5avVNyYgj6RiXuQKNwkXaxFyQ": ("Bitcoin Pizza", "Received the 10,000 BTC paid for two pizzas in May 2010."),
        "1FeexV6bAHb8ybZjqQMjJrcCrHGW9sb6uF": ("Mt. Gox theft (1Feex)", "Mt. Gox's former CEO says this address received about 79,956 BTC taken in March 2011. Its owner is unknown."),
        "bc1qazcm763858nkj2dj986etajv6wquslv8uxwczt": ("Bitfinex hack", "Reported as where the 2016 hack's funds were consolidated in 2022, now under US government control."),
        "1HQ3Go3ggs8pFnXuHVHRytPCq5fGG8Hbhx": ("Silk Road funds", "Held about 69,370 BTC taken from Silk Road, seized by the US government in 2020.")
    ]

    static func note(for address: String) -> (name: String, detail: String)? { known[address] }
}

/// Blocks and coins worth a look. Each coin is checked live, against the node's own UTXO set.
enum ExplorerFamous {
    struct Coin {
        let title: String
        let detail: String
        let descriptor: String
        /// So many outputs that the reply is many megabytes: not over Tor.
        var isLarge = false
    }

    struct Block {
        let height: Int
        let title: String
        let detail: String
    }

    static let coins: [Coin] = [
        Coin(title: "Satoshi's coins (block 1)",
             detail: "The first block mined after genesis, widely believed to be Satoshi's. Never spent. Anything above 50 BTC is dust people sent later.",
             descriptor: "pk(0496b538e853519c726a2c91e61ec11600ae1390813a627c66fb8be7947be63c52da7589379515d4e0a604f8141781e62294721166bf621e73a82cbf2342c858ee)"),
        Coin(title: "Genesis address",
             detail: "The first block's address. Its own 50 BTC can never be spent, so this is only tributes people sent.",
             descriptor: "addr(1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa)", isLarge: true),
        Coin(title: "Mt. Gox theft (1Feex)",
             detail: "Mt. Gox's former CEO says about 79,956 BTC taken in March 2011 landed here. Its owner is unknown.",
             descriptor: "addr(1FeexV6bAHb8ybZjqQMjJrcCrHGW9sb6uF)"),
        Coin(title: "Burn address",
             detail: "A vanity address nobody can have the key to. Coins here are gone for good.",
             descriptor: "addr(1BitcoinEaterAddressDontSendf59kuE)"),
        Coin(title: "Bitcoin Pizza recipient",
             detail: "Received the 10,000 BTC paid for two pizzas in 2010.",
             descriptor: "addr(17SkEw2md5avVNyYgj6RiXuQKNwkXaxFyQ)")
    ]

    static let blocks: [Block] = [
        Block(height: 0, title: "Genesis", detail: "Where it all began, January 2009."),
        Block(height: 1, title: "Block 1", detail: "The first block mined after genesis."),
        Block(height: 170, title: "First transaction", detail: "Satoshi sends Hal Finney 10 BTC."),
        Block(height: 57_043, title: "Bitcoin Pizza", detail: "10,000 BTC for two pizzas, May 2010."),
        Block(height: 74_638, title: "Value overflow", detail: "A bug created 184 billion BTC. Fixed within hours by a new chain."),
        Block(height: 210_000, title: "First halving", detail: "The reward drops from 50 to 25 BTC, 2012."),
        Block(height: 420_000, title: "Second halving", detail: "25 to 12.5 BTC, 2016."),
        Block(height: 481_824, title: "SegWit activates", detail: "August 2017."),
        Block(height: 630_000, title: "Third halving", detail: "12.5 to 6.25 BTC, 2020."),
        Block(height: 709_632, title: "Taproot activates", detail: "November 2021."),
        Block(height: 840_000, title: "Fourth halving", detail: "6.25 to 3.125 BTC, 2024.")
    ]

    /// `scantxoutset`'s reply.
    struct ScanResult: Equatable {
        let btc: Double
        let coins: Int

        init?(response: [String: Any]) {
            guard response["success"] as? Bool == true, let total = RPCValue.double(response["total_amount"]) else { return nil }
            btc = total
            coins = (response["unspents"] as? [Any])?.count ?? 0
        }

        var summary: String {
            coins == 0 ? "Empty right now" : "\(btc.btcBalanceWithSpaces) BTC in \(coins.withCommas) coin\(coins == 1 ? "" : "s")"
        }
    }
}

/// A block holding some of the active wallet's coins. nil height: not confirmed yet.
struct ExplorerCoinBlock: Equatable {
    struct Coin: Equatable {
        let txid: String
        let vout: Int
        let amountBtc: Double
        let confirmations: Int
        let label: String?
    }

    let height: Int?
    let coins: [Coin]
    var totalBtc: Double { coins.reduce(0) { $0 + $1.amountBtc } }

    /// `listunspent`'s rows by block: unconfirmed first, then newest to oldest. Its rows give
    /// confirmations, not a height, so `tipHeight` must be the tip they were counted from.
    static func group(utxos: [[String: Any]], tipHeight: Int) -> [ExplorerCoinBlock] {
        var byHeight: [Int?: [Coin]] = [:]
        for utxo in utxos {
            guard let txid = RPCValue.string(utxo["txid"]), let vout = RPCValue.int(utxo["vout"]) else { continue }
            let confirmations = max(RPCValue.int(utxo["confirmations"]) ?? 0, 0)
            let height: Int? = confirmations > 0 ? tipHeight - confirmations + 1 : nil
            let label = RPCValue.string(utxo["label"]).flatMap { $0.isEmpty ? nil : $0 }
            byHeight[height, default: []].append(Coin(txid: txid, vout: vout, amountBtc: RPCValue.double(utxo["amount"]) ?? 0,
                                                      confirmations: confirmations, label: label))
        }
        return byHeight.map { height, coins in
            ExplorerCoinBlock(height: height, coins: coins.sorted { $0.amountBtc > $1.amountBtc })
        }.sorted { ($0.height ?? .max) > ($1.height ?? .max) }
    }
}

/// The active wallet's transactions, to mark them in the explorer.
struct ExplorerWalletActivity {
    let heights: Set<Int>
    let txids: Set<String>
    let hasUnconfirmed: Bool

    init(transactions: [[String: Any]]) {
        heights = Set(transactions.compactMap { RPCValue.int($0["blockheight"]) })
        txids = Set(transactions.compactMap { RPCValue.string($0["txid"]) })
        hasUnconfirmed = transactions.contains { (RPCValue.int($0["confirmations"]) ?? 0) == 0 }
    }
}

/// The current difficulty period and the next halving, from the tip and when the period began.
struct ExplorerChainSchedule {
    static let retargetInterval = 2016
    static let targetSpacing: TimeInterval = 600

    let height: Int
    /// nil on regtest, which never retargets.
    let retarget: Retarget?
    let halvingHeight: Int
    let blocksToHalving: Int
    let subsidyNow: Double
    let subsidyAfter: Double

    struct Retarget {
        let blocksDone: Int
        let blocksLeft: Int
        /// Seconds per block so far this period. nil just after a retarget.
        let averageSpacing: TimeInterval?
        /// Percent the difficulty would change at this pace.
        let projectedChange: Double?
    }

    /// Spacing to use for estimates: this period's pace, or the target until it has one.
    var spacing: TimeInterval { retarget?.averageSpacing ?? Self.targetSpacing }

    init(height: Int, chain: String, tipTime: Int?, periodStartTime: Int?) {
        self.height = height
        let halvingInterval = chain == "regtest" ? 150 : 210_000
        let halvings = height / halvingInterval
        halvingHeight = (halvings + 1) * halvingInterval
        blocksToHalving = halvingHeight - height
        subsidyNow = 50 / pow(2, Double(halvings))
        subsidyAfter = subsidyNow / 2
        guard chain != "regtest" else {
            retarget = nil
            return
        }
        let done = height % Self.retargetInterval
        var spacing: TimeInterval?
        // A few blocks is too few to mean anything.
        if done >= 6, let tip = tipTime, let start = periodStartTime, tip > start {
            spacing = TimeInterval(tip - start) / TimeInterval(done)
        }
        retarget = Retarget(blocksDone: done, blocksLeft: Self.retargetInterval - done, averageSpacing: spacing,
                            // Each period's change is capped at a factor of four either way.
                            projectedChange: spacing.map { (min(max(Self.targetSpacing / $0, 0.25), 4) - 1) * 100 })
    }
}

/// Lays out rectangles of the given areas in `size`, most square first (squarified treemap).
/// `areas` must be sorted largest first; the result has the same order.
enum ExplorerTreemap {
    static func layout(areas: [Double], in size: CGSize) -> [CGRect] {
        let total = areas.reduce(0, +)
        guard total > 0, size.width > 0, size.height > 0 else { return areas.map { _ in .zero } }
        let scale = Double(size.width * size.height) / total
        var result: [CGRect] = []
        result.reserveCapacity(areas.count)
        var remaining = CGRect(origin: .zero, size: size)
        var start = 0

        func worst(_ sum: Double, _ smallest: Double, _ largest: Double, _ side: Double) -> Double {
            let s2 = sum * sum, w2 = side * side
            return max(w2 * largest / s2, s2 / (w2 * smallest))
        }

        while start < areas.count {
            let side = Double(min(remaining.width, remaining.height))
            var end = start
            var sum = 0.0
            let largest = areas[start] * scale
            var smallest = largest
            var currentWorst = Double.infinity
            while end < areas.count {
                let area = areas[end] * scale
                let nextSum = sum + area
                let nextSmallest = min(smallest, area)
                let nextWorst = worst(nextSum, nextSmallest, largest, side)
                if end > start && nextWorst > currentWorst { break }
                sum = nextSum
                smallest = nextSmallest
                currentWorst = nextWorst
                end += 1
            }
            // Lay the row along the shorter side.
            let thickness = CGFloat(sum / max(side, 0.0001))
            var offset: CGFloat = 0
            let horizontal = remaining.width >= remaining.height
            for index in start..<end {
                let length = CGFloat(areas[index] * scale / max(Double(thickness), 0.0001))
                if horizontal {
                    result.append(CGRect(x: remaining.minX, y: remaining.minY + offset, width: thickness, height: length))
                } else {
                    result.append(CGRect(x: remaining.minX + offset, y: remaining.minY, width: length, height: thickness))
                }
                offset += length
            }
            if horizontal {
                remaining = CGRect(x: remaining.minX + thickness, y: remaining.minY, width: max(remaining.width - thickness, 0), height: remaining.height)
            } else {
                remaining = CGRect(x: remaining.minX, y: remaining.minY + thickness, width: remaining.width, height: max(remaining.height - thickness, 0))
            }
            start = end
        }
        return result
    }
}
