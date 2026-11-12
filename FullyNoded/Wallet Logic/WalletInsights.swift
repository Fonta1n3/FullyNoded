//
//  WalletInsights.swift
//  FullyNoded
//
//  Reading the node's replies into plain answers for the wallet screens: what's outside the
//  headline balance, whether a transaction will confirm, what a coin costs to spend, which
//  addresses are linked or reused, what changed since the wallet was last opened, and what a PSBT
//  needs next. No networking and no UI, so all of it can be tested.
//

import Foundation

/// What the headline balance (`getbalance` with minconf 0) leaves out.
struct WalletBalanceParts: Equatable {
    /// Unconfirmed, from other people.
    let incoming: Double
    /// Mining rewards still maturing.
    let immature: Double

    /// `balances` from `getbalances`, `utxos` from `listunspent` with minconf 0. Incoming comes from
    /// the coins because in an avoid_reuse wallet a payment to an address already used is counted
    /// under `used`, not `untrusted_pending`, and those are the payments most worth pointing out.
    init?(balances: [String: Any], utxos: [[String: Any]]) {
        guard let mine = balances["mine"] as? [String: Any] else { return nil }
        incoming = utxos.reduce(0) { total, utxo in
            (RPCValue.int(utxo["confirmations"]) ?? 1) == 0 && utxo["safe"] as? Bool == false
                ? total + (RPCValue.double(utxo["amount"]) ?? 0) : total
        }
        immature = RPCValue.double(mine["immature"]) ?? 0
    }

    var isEmpty: Bool { incoming <= 0 && immature <= 0 }
}

/// A transaction's place in the mempool, from `getmempoolentry`.
struct MempoolPosition {
    let ownRate: Double
    /// What miners effectively see, in sat/vB: unconfirmed parents can drag it down, and a child
    /// paying more can lift it up.
    private(set) var effectiveRate: Double
    let unconfirmedParents: Int
    let unconfirmedChildren: Int

    enum Outlook: Equatable {
        case inNextBlock, likelyNextBlock, withinAnHour, withinADay, slow, unknown
    }

    init?(entry: [String: Any]) {
        guard let fees = entry["fees"] as? [String: Any],
              let vsize = RPCValue.double(entry["vsize"]), vsize > 0,
              let fee = RPCValue.double(fees["base"]) else { return nil }
        let own = fee * 100_000_000 / vsize
        // Each size and fee below includes this transaction.
        func rate(_ feeKey: String, _ sizeKey: String) -> Double? {
            guard let packageFee = RPCValue.double(fees[feeKey]),
                  let size = RPCValue.double(entry[sizeKey]), size > 0 else { return nil }
            return packageFee * 100_000_000 / size
        }
        ownRate = own
        // A cheaper parent has to be mined first, so it drags this down. A dearer one doesn't lift it.
        let withParents = min(rate("ancestor", "ancestorsize") ?? own, own)
        // A child paying more pulls this in with it, along with any unconfirmed parents. This
        // transaction is in both packages, so it's taken out of one. A cheaper child changes nothing.
        if rate("descendant", "descendantsize") ?? own > own,
           let ancestorFee = RPCValue.double(fees["ancestor"]), let ancestorSize = RPCValue.double(entry["ancestorsize"]),
           let descendantFee = RPCValue.double(fees["descendant"]), let descendantSize = RPCValue.double(entry["descendantsize"]) {
            let whole = (ancestorFee + descendantFee - fee) * 100_000_000 / (ancestorSize + descendantSize - vsize)
            effectiveRate = max(withParents, whole)
        } else {
            effectiveRate = withParents
        }
        unconfirmedParents = max((RPCValue.int(entry["ancestorcount"]) ?? 1) - 1, 0)
        unconfirmedChildren = max((RPCValue.int(entry["descendantcount"]) ?? 1) - 1, 0)
        // Core 32's cluster mempool says exactly what miners see: this transaction's chunk.
        if let chunkFee = RPCValue.double(fees["chunk"]), let chunkWeight = RPCValue.double(entry["chunkweight"]), chunkWeight > 0 {
            effectiveRate = chunkFee * 100_000_000 / (chunkWeight / 4)
        }
    }

    /// `estimates`: sat/vB by confirmation target in blocks. A guess, like any fee estimate, unless
    /// the transaction is in the node's own next block.
    func outlook(estimates: [Int: Double], inTemplate: Bool) -> Outlook {
        if inTemplate { return .inNextBlock }
        if let rate = estimates[1], effectiveRate >= rate { return .likelyNextBlock }
        if let rate = estimates[6], effectiveRate >= rate { return .withinAnHour }
        if let rate = estimates[144] {
            return effectiveRate >= rate ? .withinADay : .slow
        }
        return .unknown
    }

    static func describe(_ outlook: Outlook) -> String {
        switch outlook {
        case .inNextBlock: return "It's in the block your node would build right now."
        case .likelyNextBlock: return "It pays enough for the next block, going by your node's estimate."
        case .withinAnHour: return "Likely to confirm within about an hour, going by your node's estimate."
        case .withinADay: return "Likely to confirm within about a day, going by your node's estimate. You could bump its fee."
        case .slow: return "It pays less than your node's estimate for a day. Consider bumping its fee."
        case .unknown: return "Your node has no fee estimate to compare it with yet."
        }
    }
}

/// What a coin costs to spend at a fee rate. Only for single-key scripts, whose size is known.
struct UTXOSpendCost: Equatable {
    /// At or above this share of its value, a coin gets a warning.
    static let warningFraction = 0.1

    let sats: Double
    /// Of the coin's value: 1 or more means spending it loses money.
    let fraction: Double

    init?(amountBtc: Double, scriptType: UTXOTraits.ScriptType?, feeRate: Double) {
        guard let vbytes = Self.inputVBytes(scriptType), amountBtc > 0, feeRate > 0 else { return nil }
        sats = vbytes * feeRate
        fraction = sats / (amountBtc * 100_000_000)
    }

    static func inputVBytes(_ type: UTXOTraits.ScriptType?) -> Double? {
        switch type {
        case .taproot: return 57.5
        case .segwit: return 68
        case .nestedSegwit: return 91
        case .legacy: return 148
        // A script's size depends on what it does.
        case .segwitScript, .script, .none: return nil
        }
    }
}

/// `listaddressgroupings`: addresses visibly linked on-chain by being spent together or by change.
struct AddressGroup: Equatable {
    struct Entry: Equatable {
        let address: String
        let amount: Double
        let label: String?
    }
    let entries: [Entry]
    var total: Double { entries.reduce(0) { $0 + $1.amount } }

    /// Only groups of two or more link anything. Largest first.
    static func linked(from response: [[[Any]]]) -> [AddressGroup] {
        response.compactMap { group -> AddressGroup? in
            let entries = group.compactMap { row -> Entry? in
                guard let address = row.first as? String else { return nil }
                return Entry(address: address,
                             amount: row.count > 1 ? RPCValue.double(row[1]) ?? 0 : 0,
                             label: row.count > 2 ? (row[2] as? String).flatMap { $0.isEmpty ? nil : $0 } : nil)
            }
            return entries.count > 1 ? AddressGroup(entries: entries) : nil
        }.sorted { $0.entries.count > $1.entries.count }
    }
}

/// `listreceivedbyaddress`: addresses that received more than one transaction.
struct ReusedAddress: Equatable {
    let address: String
    let transactions: Int
    let amount: Double
    let label: String?

    /// Most used first.
    static func from(response: [[String: Any]]) -> [ReusedAddress] {
        response.compactMap { row -> ReusedAddress? in
            guard let address = row["address"] as? String,
                  let txids = row["txids"] as? [Any], txids.count > 1 else { return nil }
            let label = (row["label"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return ReusedAddress(address: address, transactions: txids.count,
                                 amount: RPCValue.double(row["amount"]) ?? 0, label: label)
        }.sorted { $0.transactions > $1.transactions }
    }
}

/// How much a transaction gives away on-chain, with the reasons. Common chain-analysis assumptions,
/// not facts: a good rating doesn't make a transaction private, and says nothing about how it was
/// broadcast.
struct TransactionPrivacyRating: Equatable {
    enum Grade: String {
        case good = "GOOD", fair = "FAIR", poor = "POOR"
    }

    struct Finding: Equatable {
        let isGood: Bool
        let text: String
    }

    let score: Int
    let findings: [Finding]

    var grade: Grade { score >= 80 ? .good : score >= 50 ? .fair : .poor }

    /// Rough script family from an address, on any network.
    static func addressKind(_ address: String) -> String? {
        let lower = address.lowercased()
        for prefix in ["bc1", "tb1", "bcrt1"] where lower.hasPrefix(prefix) {
            let rest = lower.dropFirst(prefix.count)
            if rest.hasPrefix("p") { return "taproot" }
            if rest.hasPrefix("q") { return lower.count > 50 ? "segwit script" : "segwit" }
            return nil
        }
        switch address.first {
        case "1", "m", "n": return "legacy"
        case "3", "2": return "nested"
        default: return nil
        }
    }

    /// `reusedOutputs`: output addresses the wallet has already seen receive something.
    init(inputs: [String], outputs: [(address: String, amountBtc: Double)], reusedOutputs: Set<String> = [], isPayjoin: Bool = false) {
        var score = 100
        var findings: [Finding] = []
        let spent = Set(inputs.filter { !$0.isEmpty })
        let shape = ExplorerTxCategory.shape(inputs: inputs.count, outputValues: outputs.map(\.amountBtc))?.name
        let isCoinJoin = shape == "CoinJoin"

        if isCoinJoin {
            findings.append(Finding(isGood: true, text: "Equal outputs make it hard to tell who received what."))
        } else if spent.count > 1 {
            score -= min(10 * (spent.count - 1), 30)
            findings.append(Finding(isGood: false, text: "Spending \(spent.count) addresses together suggests they have one owner."))
        } else if inputs.count == 1 {
            findings.append(Finding(isGood: true, text: "Spends one input, so it links none of your inputs together."))
        }

        let backToSender = outputs.filter { spent.contains($0.address) }
        if !backToSender.isEmpty {
            score -= 35
            findings.append(Finding(isGood: false, text: "An output goes back to an address being spent. That shows which one is your change."))
        }
        let reused = outputs.filter { reusedOutputs.contains($0.address) && !spent.contains($0.address) }
        if !reused.isEmpty {
            score -= 25
            findings.append(Finding(isGood: false, text: "Pays an address that has received before, which connects these payments."))
        }

        if outputs.count == 1 {
            findings.append(Finding(isGood: true, text: "No change output, so nothing to follow to your next spend."))
        } else if outputs.count == 2, !isCoinJoin {
            // Which output is change, if it can be told apart.
            let inputKinds = Set(spent.compactMap(Self.addressKind))
            let matching = outputs.filter { Self.addressKind($0.address).map(inputKinds.contains) ?? false }
            if inputKinds.count == 1, matching.count == 1 {
                score -= 15
                findings.append(Finding(isGood: false, text: "Only one output is the same address type as your inputs, so it's probably your change."))
            }
            let isRound: (Double) -> Bool = { amount in
                let sats = Int((amount * 100_000_000).rounded())
                return sats >= 100_000 && sats % 100_000 == 0
            }
            if outputs.filter({ isRound($0.amountBtc) }).count == 1 {
                score -= 15
                findings.append(Finding(isGood: false, text: "One round amount suggests the payment, and so the other output is your change."))
            }
        }

        if isPayjoin {
            score += 15
            findings.append(Finding(isGood: true, text: "Payjoin: inputs from both sides break the assumption that they share an owner."))
        }
        if isCoinJoin { score = max(score, 85) }
        self.score = min(max(score, 0), 100)
        self.findings = findings
    }
}

/// A transaction where nothing but the fee leaves the wallet.
enum WalletSelfTransfer {
    static let title = "Self transfer"
    static let detail = "Every output comes back to this wallet. Only the fee leaves it."

    /// From the wallet's own record (`gettransaction`), once it has the transaction.
    static func matches(walletTransaction wallet: [String: Any]) -> Bool {
        guard let details = wallet["details"] as? [[String: Any]],
              details.contains(where: { $0["category"] as? String == "send" }),
              let amount = RPCValue.double(wallet["amount"]) else { return false }
        return abs(amount) < 0.000_000_01
    }

    /// Before that, from what the node said about each address (`isMine`, its `ismine`). Anything
    /// it didn't confirm as ours, such as an OP_RETURN, means this can't be claimed.
    static func matches(inputs: [[String: Any]], outputs: [[String: Any]]) -> Bool {
        !inputs.isEmpty && !outputs.isEmpty
            && inputs.allSatisfy { $0["isMine"] as? Bool == true }
            && outputs.allSatisfy { $0["isMine"] as? Bool == true }
    }
}

/// `listsinceblock`: what's new in blocks since the wallet was last opened.
struct WalletChangesSince: Equatable {
    let receivedCount: Int
    let receivedBtc: Double
    let sentCount: Int
    let droppedCount: Int
    let lastBlock: String

    init?(response: [String: Any]) {
        guard let lastBlock = response["lastblock"] as? String else { return nil }
        self.lastBlock = lastBlock
        let rows = (response["transactions"] as? [[String: Any]] ?? []).filter { (RPCValue.int($0["confirmations"]) ?? 0) > 0 }
        // A transaction has a row per output it touches, and a payment to yourself has both kinds.
        let sent = Set(rows.filter { $0["category"] as? String == "send" }.compactMap { $0["txid"] as? String })
        let received = rows.filter {
            let category = $0["category"] as? String
            return (category == "receive" || category == "generate") && !sent.contains($0["txid"] as? String ?? "")
        }
        sentCount = sent.count
        receivedCount = Set(received.compactMap { $0["txid"] as? String }).count
        receivedBtc = received.reduce(0) { $0 + (RPCValue.double($1["amount"]) ?? 0) }
        droppedCount = Set((response["removed"] as? [[String: Any]] ?? []).compactMap { $0["txid"] as? String }).count
    }

    var isEmpty: Bool { receivedCount == 0 && sentCount == 0 && droppedCount == 0 }

    var summary: String {
        var parts: [String] = []
        if receivedCount > 0 { parts.append("\(receivedCount) received (\(receivedBtc.btcBalanceWithSpaces) BTC)") }
        if sentCount > 0 { parts.append("\(sentCount) sent") }
        if droppedCount > 0 { parts.append("\(droppedCount) dropped from the chain by a reorg") }
        return parts.joined(separator: " · ")
    }
}

/// `analyzepsbt`: what a PSBT needs next.
struct PSBTNextStep: Equatable {
    let step: String
    let missingSignatures: Int

    init?(response: [String: Any]) {
        guard let next = response["next"] as? String else { return nil }
        let inputs = response["inputs"] as? [[String: Any]] ?? []
        missingSignatures = inputs.reduce(0) {
            $0 + (($1["missing"] as? [String: Any])?["signatures"] as? [Any] ?? []).count
        }
        switch next {
        case "creator": step = "Needs creating"
        case "updater": step = "Needs updating with input details"
        case "signer": step = "Needs signing"
        case "finalizer": step = "Fully signed: ready to finalize"
        case "extractor": step = "Finalized: ready to broadcast"
        default: step = next
        }
    }
}
