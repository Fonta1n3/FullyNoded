//
//  BlockExplorerTests.swift
//  FullyNodedTests
//
//  Reading the node's block and transaction replies, including what a pruned node leaves out,
//  and the block map's layout.
//

import XCTest
@testable import FullyNoded

final class BlockExplorerTests: XCTestCase {

    func testSummaryFromStats() throws {
        let summary = try XCTUnwrap(ExplorerBlockSummary(stats: [
            "height": 974866, "blockhash": "abc", "time": 1794004756, "txs": 3286,
            "total_weight": 3991942, "total_size": 1580000, "totalfee": 2245245, "feerate_percentiles": [0, 1, 2, 2, 3]
        ]))
        XCTAssertEqual(summary.size, 1_580_000)
        XCTAssertEqual(summary.medianFeeRate, 2)
        XCTAssertEqual(summary.txCount, 3286)
        XCTAssertEqual(try XCTUnwrap(summary.fullness), 0.998, accuracy: 0.001)
    }

    /// A pruned block has no stats: the header is all there is, and it must still show.
    func testSummaryFromHeaderHasNoFeeData() throws {
        let summary = try XCTUnwrap(ExplorerBlockSummary(header: ["height": 5, "hash": "h", "time": 100, "nTx": 2]))
        XCTAssertNil(summary.medianFeeRate)
        XCTAssertNil(summary.fullness)
        XCTAssertEqual(summary.txCount, 2)
    }

    func testMapFromBlockComputesFeeRatesAndMarksCoinbase() {
        let map = ExplorerMapTx.fromBlock(["tx": [
            ["txid": "cb", "vsize": 200],
            ["txid": "a", "vsize": 100, "fee": 0.00001],
            ["txid": "nofee", "vsize": 100]
        ]])
        XCTAssertEqual(map.map(\.txid), ["cb", "a", "nofee"])
        XCTAssertTrue(map[0].isCoinbase)
        XCTAssertFalse(map[1].isCoinbase)
        XCTAssertEqual(try XCTUnwrap(map[1].feeRate), 10, accuracy: 0.0001)
        XCTAssertNil(map[2].feeRate)
    }

    func testMapFromTemplateUsesSatsAndWeight() {
        let map = ExplorerMapTx.fromTemplate(["transactions": [["txid": "t", "fee": 2000, "weight": 800]]])
        XCTAssertEqual(map.first?.vsize, 200)
        XCTAssertEqual(try XCTUnwrap(map.first?.feeRate), 10, accuracy: 0.0001)
    }

    func testTransactionReadsPrevoutsForTracing() throws {
        let tx = try XCTUnwrap(ExplorerTx(raw: [
            "txid": "t", "vsize": 141, "weight": 561, "fee": 0.00000282, "confirmations": 3,
            "vin": [["txid": "p", "vout": 1, "sequence": 4294967293,
                     "prevout": ["height": 700, "generated": false, "value": 0.5,
                                 "scriptPubKey": ["address": "bc1qsource", "type": "witness_v0_keyhash"]]]],
            "vout": [["n": 0, "value": 0.4, "scriptPubKey": ["address": "bc1qdest", "type": "witness_v0_keyhash"]],
                     ["n": 1, "value": 0, "scriptPubKey": ["type": "nulldata"]]]
        ]))
        XCTAssertEqual(tx.inputs[0].sourceHeight, 700)
        XCTAssertEqual(tx.inputs[0].txid, "p")
        XCTAssertEqual(tx.inputs[0].address, "bc1qsource")
        XCTAssertEqual(try XCTUnwrap(tx.feeRate), 2, accuracy: 0.0001)
        XCTAssertTrue(tx.signalsRBF)
        XCTAssertFalse(tx.isCoinbase)
        XCTAssertNil(tx.outputs[1].address)
        XCTAssertEqual(ExplorerTx.scriptName(tx.outputs[1].scriptType), "OP_RETURN data")
    }

    func testCoinbaseAndMissingPrevouts() throws {
        let coinbase = try XCTUnwrap(ExplorerTx(raw: ["txid": "c", "vin": [["coinbase": "03ab", "sequence": 4294967295]], "vout": []]))
        XCTAssertTrue(coinbase.isCoinbase)
        XCTAssertFalse(coinbase.signalsRBF)
        // No undo data for this block: no amount, no source height, but still readable.
        let noUndo = try XCTUnwrap(ExplorerTx(raw: ["txid": "n", "vin": [["txid": "p", "vout": 0]], "vout": []]))
        XCTAssertNil(noUndo.inputs[0].valueBtc)
        XCTAssertNil(noUndo.inputs[0].sourceHeight)
        XCTAssertNil(noUndo.feeRate)
    }

    func testBlockDetailListsTxids() throws {
        let detail = try XCTUnwrap(ExplorerBlockDetail(block: ["hash": "h", "height": 9, "time": 1, "tx": ["a", "b"], "nonce": 7, "size": 100]))
        XCTAssertEqual(detail.txids, ["a", "b"])
        XCTAssertEqual(detail.nonce, 7)
        XCTAssertNil(ExplorerBlockDetail(block: ["height": 9]))
    }

    func testFeeColorBuckets() {
        XCTAssertEqual(ExplorerFeeColor.color(0.5), ExplorerFeeColor.buckets[0].color)
        XCTAssertEqual(ExplorerFeeColor.color(2), ExplorerFeeColor.buckets[1].color)
        XCTAssertEqual(ExplorerFeeColor.color(1000), ExplorerFeeColor.buckets.last?.color)
        XCTAssertEqual(ExplorerFeeColor.color(nil), WalletTheme.dim)
    }

    func testETACountsDownToTheTargetThenSaysAnyMoment() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let ago = { (seconds: Int) in ExplorerFormat.eta(lastBlockTime: 1_000_000 - seconds, now: now) }
        XCTAssertEqual(ago(0), "~10m")
        XCTAssertEqual(ago(181), "~7m")
        XCTAssertEqual(ago(570), "<1m")
        XCTAssertEqual(ago(600), "any moment")
        XCTAssertEqual(ago(3000), "any moment")
        // A block's time can be ahead of this clock.
        XCTAssertEqual(ago(-900), "~10m")
    }

    func testAgoShowsTwoUnits() {
        let now = Date(timeIntervalSince1970: 1_000_000_000)
        let ago = { (seconds: Int) in ExplorerFormat.ago(1_000_000_000 - seconds, now: now) }
        XCTAssertEqual(ago(0), "just now")
        XCTAssertEqual(ago(59), "just now")
        XCTAssertEqual(ago(60), "1m ago")
        XCTAssertEqual(ago(59 * 60 + 59), "59m ago")
        XCTAssertEqual(ago(3600), "1h ago")
        XCTAssertEqual(ago(119 * 60), "1h 59m ago")
        XCTAssertEqual(ago(86_400), "1d ago")
        XCTAssertEqual(ago(2 * 86_400 + 5 * 3600 + 59), "2d 5h ago")
        XCTAssertEqual(ago(365 * 86_400), "1y ago")
        XCTAssertEqual(ago(3 * 365 * 86_400 + 20 * 86_400), "3y 20d ago")
        // A block's time can be ahead of this clock.
        XCTAssertEqual(ago(-500), "just now")
    }

    func testBlockSizeLine() {
        XCTAssertEqual(ExplorerFormat.blockSize(size: 1_580_000, weight: 3_990_000), "1.58 MB · 3.99 MWU")
        XCTAssertEqual(ExplorerFormat.blockSize(size: 471, weight: 1449), "0.0005 MB · 0.0014 MWU")
        XCTAssertEqual(ExplorerFormat.blockSize(size: nil, weight: 3_990_000), "3.99 MWU")
        XCTAssertNil(ExplorerFormat.blockSize(size: nil, weight: nil))
    }

    func testETAUsesTheRecentPace() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(ExplorerFormat.eta(lastBlockTime: 1_000_000 - 60, spacing: 480, now: now), "~7m")
    }

    func testMinerFromARealCoinbase() throws {
        // Mainnet, read from a real block: text runs into the script's numbers.
        let hex = "0320e00e041b90ee6a537069646572506f6f6c2f3531382ffabe6d6d8a4681175b7c546393b5074cb9f4a6646c48afa8ab7096cf752ae665a040165b0800000053f220786674a22b392bdf621100000000000000"
        let miner = try XCTUnwrap(ExplorerMiner.identify(coinbaseHex: hex))
        XCTAssertEqual(miner.name, "SpiderPool")
        XCTAssertTrue(miner.isKnown)
    }

    func testSoloWins() throws {
        // Mainnet block 974,893: "ckpool ue/solo.ckpool.org/".
        let real = "032de00e000460aeee6a0472c4bc3a0cb9aaec6aa1140000000000000a636b706f6f6c1375652f736f6c6f2e636b706f6f6c2e6f72672f"
        XCTAssertTrue(ExplorerMiner.isSolo(coinbaseHex: real))
        XCTAssertEqual(ExplorerMiner.identify(coinbaseHex: real)?.name, "CKPool Solo")
        let tagged = { (text: String) in ExplorerMiner.isSolo(coinbaseHex: "03010203" + Data(text.utf8).hexString) }
        XCTAssertTrue(tagged("Public-Pool"))
        XCTAssertTrue(tagged("Futurebit Solo"))
        XCTAssertTrue(tagged("/solo/"))
        // Pools, and names that only contain the letters.
        XCTAssertFalse(tagged("Foundry USA Pool"))
        XCTAssertFalse(tagged("Mined by AntPool"))
        XCTAssertFalse(tagged("Solomon"))
        XCTAssertFalse(tagged("consolo"))
        XCTAssertFalse(ExplorerMiner.isSolo(coinbaseHex: "not hex"))
    }

    func testUnknownMinerShowsItsTextAndNoTextIsNil() throws {
        let unknown = try XCTUnwrap(ExplorerMiner.identify(coinbaseHex: "03010203" + Data("My Garage Rig".utf8).hexString))
        XCTAssertFalse(unknown.isKnown)
        XCTAssertTrue(unknown.name.contains("My Garage Rig"))
        XCTAssertNil(ExplorerMiner.identify(coinbaseHex: "0301020304"))
        XCTAssertNil(ExplorerMiner.identify(coinbaseHex: "not hex"))
    }

    func testCoinsGroupByBlockNewestFirst() {
        let blocks = ExplorerCoinBlock.group(utxos: [
            ["txid": "old", "vout": 0, "amount": 1.0, "confirmations": 100],
            ["txid": "tip", "vout": 1, "amount": 0.5, "confirmations": 1],
            ["txid": "tip2", "vout": 0, "amount": 2.0, "confirmations": 1, "label": "rent"],
            ["txid": "new", "vout": 0, "amount": 0.1, "confirmations": 0],
            ["vout": 0, "amount": 9.0, "confirmations": 1]
        ], tipHeight: 1000)
        XCTAssertEqual(blocks.map(\.height), [nil, 1000, 901])
        // The one confirmation is in the tip itself.
        XCTAssertEqual(blocks[1].coins.map(\.txid), ["tip2", "tip"])
        XCTAssertEqual(blocks[1].totalBtc, 2.5, accuracy: 0.0001)
        XCTAssertEqual(blocks[1].coins[0].label, "rent")
        XCTAssertEqual(blocks[1].coins[1].vout, 1)
        XCTAssertEqual(ExplorerCoinBlock.group(utxos: [], tipHeight: 10), [])
    }

    func testMegabytes() {
        XCTAssertEqual(ExplorerFormat.megabytes(222), "0.00022 MB")
        XCTAssertEqual(ExplorerFormat.megabytes(45_000), "0.045 MB")
        XCTAssertEqual(ExplorerFormat.megabytes(3_900_000), "3.900 MB")
    }

    func testShapeCategories() {
        XCTAssertEqual(ExplorerTxCategory.shape(inputs: 5, outputValues: [0.1, 0.1, 0.1, 0.1, 0.1])?.name, "CoinJoin")
        XCTAssertEqual(ExplorerTxCategory.shape(inputs: 8, outputValues: [1.0])?.name, "Consolidation")
        XCTAssertEqual(ExplorerTxCategory.shape(inputs: 6, outputValues: [1.0, 0.2])?.name, "Consolidation")
        XCTAssertEqual(ExplorerTxCategory.shape(inputs: 1, outputValues: Array(repeating: 0, count: 9) + [0.5, 0.2])?.name, "Batch payment")
        XCTAssertEqual(ExplorerTxCategory.shape(inputs: 1, outputValues: [1.0])?.name, "No change")
        // An ordinary payment with change is nothing special, and neither are equal amounts
        // from too few inputs (an exchange paying out).
        XCTAssertNil(ExplorerTxCategory.shape(inputs: 1, outputValues: [0.5, 0.2]))
        XCTAssertNil(ExplorerTxCategory.shape(inputs: 2, outputValues: [0.1, 0.1, 0.1]))
    }

    func testQuickNameSpotsDataWithoutDecoding() {
        let runes: [String: Any] = ["vin": [["txid": "a"]], "vout": [["value": 0, "scriptPubKey": ["hex": "6a5d0100"]], ["value": 1.0, "scriptPubKey": ["hex": "0014"]]]]
        XCTAssertEqual(ExplorerTxCategory.quickName(rawTx: runes), ExplorerTxCategory.dataName)
        let inscription: [String: Any] = ["vin": [["txinwitness": ["ab", "20aaac0063036f7264010168"]]], "vout": [["value": 0.1, "scriptPubKey": ["hex": "51"]], ["value": 0.2, "scriptPubKey": ["hex": "51"]]]]
        XCTAssertEqual(ExplorerTxCategory.quickName(rawTx: inscription), ExplorerTxCategory.dataName)
        let plain: [String: Any] = ["vin": [["txinwitness": ["ab"]]], "vout": [["value": 0.1, "scriptPubKey": ["hex": "0014"]], ["value": 0.2, "scriptPubKey": ["hex": "0014"]]]]
        XCTAssertNil(ExplorerTxCategory.quickName(rawTx: plain))
    }

    private func spend(fromHeight height: Int, to address: String = "bc1qsomeone") throws -> ExplorerTx {
        try XCTUnwrap(ExplorerTx(raw: [
            "txid": "t", "vin": [["txid": "p", "vout": 0, "prevout": ["height": height, "value": 1.0, "scriptPubKey": ["address": "bc1qsource"]]]],
            "vout": [["n": 0, "value": 0.5, "scriptPubKey": ["address": address]], ["n": 1, "value": 0.4, "scriptPubKey": ["address": "bc1qchange"]]]
        ]))
    }

    func testOldCoins() throws {
        let height = 900_000
        XCTAssertEqual(ExplorerTxCategory.all(tx: try spend(fromHeight: 100_000), embedded: [], height: height).first?.name, "Very old coins")
        XCTAssertEqual(ExplorerTxCategory.all(tx: try spend(fromHeight: 500_000), embedded: [], height: height).first?.name, "Old coins")
        XCTAssertEqual(ExplorerTxCategory.all(tx: try spend(fromHeight: 800_000), embedded: [], height: height), [])
    }

    func testKnownAddressesAndData() throws {
        let tagged = ExplorerTxCategory.all(tx: try spend(fromHeight: 800_000, to: "1FeexV6bAHb8ybZjqQMjJrcCrHGW9sb6uF"), embedded: [], height: 900_000)
        XCTAssertEqual(tagged.first?.name, "Mt. Gox theft (1Feex)")
        let inscription = ExplorerEmbeddedData(location: .input(0), name: "BRC-20", details: [], size: 50)
        let memo = ExplorerEmbeddedData(location: .output(0), name: "Cross-chain swap memo", details: [], size: 50)
        let large = ExplorerEmbeddedData(location: .input(0), name: "Large witness data", details: [], size: 5000)
        XCTAssertEqual(ExplorerTxCategory.all(tx: try spend(fromHeight: 800_000), embedded: [inscription], height: 900_000).first?.name, ExplorerTxCategory.dataName)
        XCTAssertEqual(ExplorerTxCategory.all(tx: try spend(fromHeight: 800_000), embedded: [memo, large], height: 900_000), [])
    }

    func testFamousScanResult() throws {
        // As the node replied for block 1's key, trimmed.
        let found = try XCTUnwrap(ExplorerFamous.ScanResult(response: ["success": true, "total_amount": 50.00005777, "unspents": [["height": 1], ["height": 2], ["height": 3]]]))
        XCTAssertEqual(found.coins, 3)
        XCTAssertTrue(found.summary.contains("in 3 coins"))
        let empty = try XCTUnwrap(ExplorerFamous.ScanResult(response: ["success": true, "total_amount": 0, "unspents": [Any]()]))
        XCTAssertEqual(empty.summary, "Empty right now")
        XCTAssertNil(ExplorerFamous.ScanResult(response: ["success": false, "total_amount": 1.0]))
    }

    func testFamousBlocksAreInOrder() {
        let heights = ExplorerFamous.blocks.map(\.height)
        XCTAssertEqual(heights, heights.sorted())
        XCTAssertEqual(heights.first, 0)
    }

    func testCompactNumbers() {
        XCTAssertEqual(ExplorerFormat.compactNumber(950), "950")
        XCTAssertEqual(ExplorerFormat.compactNumber(1_234), "1.2K")
        XCTAssertEqual(ExplorerFormat.compactNumber(238_400), "238K")
        XCTAssertEqual(ExplorerFormat.compactNumber(2_500_000), "2.5M")
        XCTAssertEqual(ExplorerFormat.compactNumber(3_000_000_000), "3.0B")
    }

    func testRewardNeedsBothParts() throws {
        let full = try XCTUnwrap(ExplorerBlockSummary(stats: ["height": 1, "time": 1, "txs": 2, "subsidy": 312_500_000, "totalfee": 2_500_000]))
        XCTAssertEqual(try XCTUnwrap(full.rewardBtc), 3.15, accuracy: 0.000001)
        let partial = try XCTUnwrap(ExplorerBlockSummary(stats: ["height": 1, "time": 1, "txs": 2, "totalfee": 2_500_000]))
        XCTAssertNil(partial.rewardBtc)
    }

    func testWalletActivity() {
        let activity = ExplorerWalletActivity(transactions: [
            ["txid": "a", "blockheight": 10, "confirmations": 5],
            ["txid": "b", "confirmations": 0]
        ])
        XCTAssertEqual(activity.heights, [10])
        XCTAssertEqual(activity.txids, ["a", "b"])
        XCTAssertTrue(activity.hasUnconfirmed)
    }

    func testRetargetProjection() throws {
        // 1008 blocks at 9 minutes each.
        let schedule = ExplorerChainSchedule(height: 2016 * 480 + 1008, chain: "main", tipTime: 1_000_000 + 1008 * 540, periodStartTime: 1_000_000)
        let retarget = try XCTUnwrap(schedule.retarget)
        XCTAssertEqual(retarget.blocksDone, 1008)
        XCTAssertEqual(retarget.blocksLeft, 1008)
        XCTAssertEqual(try XCTUnwrap(retarget.averageSpacing), 540, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(retarget.projectedChange), 11.11, accuracy: 0.01)
        XCTAssertEqual(schedule.spacing, 540, accuracy: 0.001)
    }

    func testRetargetIsCappedAndNeedsEnoughBlocks() throws {
        let capped = ExplorerChainSchedule(height: 100, chain: "main", tipTime: 1000 + 100 * 10, periodStartTime: 1000)
        XCTAssertEqual(try XCTUnwrap(capped.retarget?.projectedChange), 300, accuracy: 0.001)
        let early = ExplorerChainSchedule(height: 2016 * 2 + 3, chain: "main", tipTime: 2000, periodStartTime: 1000)
        XCTAssertNil(early.retarget?.averageSpacing)
        XCTAssertEqual(early.spacing, 600)
    }

    func testHalvingOnMainnetAndRegtest() {
        let main = ExplorerChainSchedule(height: 974_880, chain: "main", tipTime: nil, periodStartTime: nil)
        XCTAssertEqual(main.halvingHeight, 1_050_000)
        XCTAssertEqual(main.blocksToHalving, 75_120)
        XCTAssertEqual(main.subsidyNow, 3.125)
        XCTAssertEqual(main.subsidyAfter, 1.5625)
        let regtest = ExplorerChainSchedule(height: 200, chain: "regtest", tipTime: nil, periodStartTime: nil)
        XCTAssertEqual(regtest.halvingHeight, 300)
        XCTAssertNil(regtest.retarget)
    }

    // MARK: - Block map layout

    func testTreemapFillsTheAreaWithoutOverlap() {
        let size = CGSize(width: 300, height: 240)
        let areas = (1...400).map { Double(401 - $0) }
        let rects = ExplorerTreemap.layout(areas: areas, in: size)
        XCTAssertEqual(rects.count, areas.count)

        let covered = rects.reduce(CGFloat(0)) { $0 + $1.width * $1.height }
        XCTAssertEqual(covered, size.width * size.height, accuracy: 1)
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -0.5, dy: -0.5)
        for rect in rects { XCTAssertTrue(bounds.contains(rect), "\(rect) is outside") }
        // Areas stay proportional.
        XCTAssertEqual(rects[0].width * rects[0].height / (rects[399].width * rects[399].height), 400, accuracy: 1)
        for (i, a) in rects.prefix(60).enumerated() {
            for b in rects.prefix(60).dropFirst(i + 1) {
                XCTAssertLessThan(a.insetBy(dx: 0.01, dy: 0.01).intersection(b.insetBy(dx: 0.01, dy: 0.01)).width, 0.01)
            }
        }
    }

    func testTreemapEdgeCases() {
        XCTAssertEqual(ExplorerTreemap.layout(areas: [], in: CGSize(width: 10, height: 10)), [])
        XCTAssertEqual(ExplorerTreemap.layout(areas: [5], in: .zero), [.zero])
        XCTAssertEqual(ExplorerTreemap.layout(areas: [5], in: CGSize(width: 10, height: 20)).first?.size, CGSize(width: 10, height: 20))
    }

    /// A busy block: thousands of transactions must lay out in well under a frame's worth of work.
    func testTreemapHandlesAFullBlock() {
        let areas = (0..<6000).map { Double(6000 - $0) }
        measure { _ = ExplorerTreemap.layout(areas: areas, in: CGSize(width: 340, height: 270)) }
    }
}
