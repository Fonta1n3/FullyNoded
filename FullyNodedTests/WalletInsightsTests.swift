//
//  WalletInsightsTests.swift
//  FullyNodedTests
//
//  The wallet screens' plain answers, from replies shaped like the node's.
//

import XCTest
@testable import FullyNoded

final class WalletInsightsTests: XCTestCase {

    func testBalancePartsReadWhatTheHeadlineLeavesOut() throws {
        // As an avoid_reuse wallet reports a payment to a used address: under `used`, with nothing pending.
        let parts = try XCTUnwrap(WalletBalanceParts(
            balances: ["mine": ["trusted": 1.0, "untrusted_pending": 0.0, "immature": 50.0, "used": 0.25]],
            utxos: [["amount": 0.25, "confirmations": 0, "safe": false],
                    // Our own change, waiting to confirm, is already in the balance.
                    ["amount": 0.5, "confirmations": 0, "safe": true],
                    ["amount": 1.0, "confirmations": 6, "safe": true]]))
        XCTAssertEqual(parts.incoming, 0.25)
        XCTAssertEqual(parts.immature, 50)
        XCTAssertFalse(parts.isEmpty)
        XCTAssertTrue(try XCTUnwrap(WalletBalanceParts(balances: ["mine": ["trusted": 1.0]], utxos: [])).isEmpty)
        XCTAssertNil(WalletBalanceParts(balances: [:], utxos: []))
    }

    private func entry(fee: Double, vsize: Int, ancestorFee: Double? = nil, ancestorSize: Int? = nil, ancestors: Int = 1,
                       descendantFee: Double? = nil, descendantSize: Int? = nil, descendants: Int = 1) -> [String: Any] {
        ["vsize": vsize, "ancestorcount": ancestors, "descendantcount": descendants,
         "ancestorsize": ancestorSize ?? vsize, "descendantsize": descendantSize ?? vsize,
         "fees": ["base": fee, "ancestor": ancestorFee ?? fee, "descendant": descendantFee ?? fee]]
    }

    func testEffectiveRateOfALoneTransactionIsItsOwn() throws {
        let position = try XCTUnwrap(MempoolPosition(entry: entry(fee: 0.00001, vsize: 100)))
        XCTAssertEqual(position.effectiveRate, 10, accuracy: 0.0001)
        XCTAssertEqual(position.unconfirmedParents, 0)
    }

    func testACheapParentDragsTheRateDown() throws {
        let position = try XCTUnwrap(MempoolPosition(entry: entry(fee: 0.00001, vsize: 100, ancestorFee: 0.00001, ancestorSize: 200, ancestors: 2)))
        XCTAssertEqual(position.ownRate, 10, accuracy: 0.0001)
        XCTAssertEqual(position.effectiveRate, 5, accuracy: 0.0001)
        XCTAssertEqual(position.unconfirmedParents, 1)
    }

    func testAChildPayingMoreLiftsTheRate() throws {
        let position = try XCTUnwrap(MempoolPosition(entry: entry(fee: 0.000001, vsize: 100, descendantFee: 0.000021, descendantSize: 200, descendants: 2)))
        XCTAssertEqual(position.ownRate, 1, accuracy: 0.0001)
        XCTAssertEqual(position.effectiveRate, 10.5, accuracy: 0.0001)
        XCTAssertEqual(position.unconfirmedChildren, 1)
    }

    func testACheapChildChangesNothing() throws {
        let position = try XCTUnwrap(MempoolPosition(entry: entry(fee: 0.00001, vsize: 100, descendantFee: 0.000011, descendantSize: 200, descendants: 2)))
        XCTAssertEqual(position.effectiveRate, 10, accuracy: 0.0001)
    }

    func testAPaidForParentAndChildAreOnePackage() throws {
        // A cheap parent (100 vB, 1 sat/vB), this one, and a child paying for all three.
        let position = try XCTUnwrap(MempoolPosition(entry: entry(fee: 0.000001, vsize: 100, ancestorFee: 0.000002, ancestorSize: 200, ancestors: 2,
                                                                  descendantFee: 0.000031, descendantSize: 200, descendants: 2)))
        XCTAssertEqual(position.effectiveRate, 32.0 / 3, accuracy: 0.0001)
    }

    func testAnExpensiveParentDoesNotLiftTheRate() throws {
        let position = try XCTUnwrap(MempoolPosition(entry: entry(fee: 0.00001, vsize: 100, ancestorFee: 0.00005, ancestorSize: 200, ancestors: 2)))
        XCTAssertEqual(position.effectiveRate, 10, accuracy: 0.0001)
    }

    func testOutlook() throws {
        let position = try XCTUnwrap(MempoolPosition(entry: entry(fee: 0.00001, vsize: 100)))
        let estimates: (Double, Double, Double) -> [Int: Double] = { [1: $0, 6: $1, 144: $2] }
        XCTAssertEqual(position.outlook(estimates: [:], inTemplate: true), .inNextBlock)
        XCTAssertEqual(position.outlook(estimates: estimates(10, 5, 2), inTemplate: false), .likelyNextBlock)
        XCTAssertEqual(position.outlook(estimates: estimates(20, 10, 2), inTemplate: false), .withinAnHour)
        XCTAssertEqual(position.outlook(estimates: estimates(40, 20, 10), inTemplate: false), .withinADay)
        XCTAssertEqual(position.outlook(estimates: estimates(40, 20, 15), inTemplate: false), .slow)
        XCTAssertEqual(position.outlook(estimates: [:], inTemplate: false), .unknown)
    }

    func testSpendCost() throws {
        // 68 vB at 10 sat/vB is 680 sats, of a 6,800 sat coin.
        let cost = try XCTUnwrap(UTXOSpendCost(amountBtc: 0.000068, scriptType: .segwit, feeRate: 10))
        XCTAssertEqual(cost.sats, 680, accuracy: 0.001)
        XCTAssertEqual(cost.fraction, 0.1, accuracy: 0.0001)
        XCTAssertGreaterThan(try XCTUnwrap(UTXOSpendCost(amountBtc: 0.000001, scriptType: .legacy, feeRate: 10)).fraction, 1)
        // A script's size isn't known, and no rate means no answer.
        XCTAssertNil(UTXOSpendCost(amountBtc: 1, scriptType: .script, feeRate: 10))
        XCTAssertNil(UTXOSpendCost(amountBtc: 1, scriptType: nil, feeRate: 10))
        XCTAssertNil(UTXOSpendCost(amountBtc: 1, scriptType: .segwit, feeRate: 0))
    }

    func testAddressGroupsKeepOnlyLinkedOnesLargestFirst() {
        let groups = AddressGroup.linked(from: [
            [["alone", 1.0]],
            [["a", 0.5, "rent"], ["b", 0.25]],
            [["c", 1], ["d", 0], ["e", 2, ""]]
        ])
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].entries.map(\.address), ["c", "d", "e"])
        XCTAssertEqual(groups[0].total, 3)
        XCTAssertNil(groups[0].entries[2].label)
        XCTAssertEqual(groups[1].entries[0].label, "rent")
    }

    func testReusedAddressesNeedMoreThanOneTransaction() {
        let reused = ReusedAddress.from(response: [
            ["address": "once", "amount": 1.0, "txids": ["a"]],
            ["address": "twice", "amount": 2.0, "label": "", "txids": ["a", "b"]],
            ["address": "thrice", "amount": 3, "label": "shop", "txids": ["a", "b", "c"]]
        ])
        XCTAssertEqual(reused.map(\.address), ["thrice", "twice"])
        XCTAssertEqual(reused[0].label, "shop")
        XCTAssertNil(reused[1].label)
    }

    func testPrivacyRatingOfACleanSpend() {
        let rating = TransactionPrivacyRating(inputs: ["bc1qa"], outputs: [("bc1qb", 0.12345678), ("bc1qc", 0.2345)])
        XCTAssertEqual(rating.grade, .good)
        XCTAssertEqual(rating.score, 100)
    }

    func testPrivacyRatingPenalties() {
        // Change back to the address being spent.
        let back = TransactionPrivacyRating(inputs: ["bc1qa"], outputs: [("bc1qb", 0.12345678), ("bc1qa", 0.2345)])
        XCTAssertEqual(back.score, 65)
        XCTAssertEqual(back.grade, .fair)
        // Four addresses linked, a round payment, and taproot change beside a legacy payment.
        let linked = TransactionPrivacyRating(inputs: ["bc1pa", "bc1pb", "bc1pc", "bc1pd"], outputs: [("1Payee", 0.5), ("bc1pe", 0.12345678)])
        XCTAssertEqual(linked.score, 40)
        XCTAssertEqual(linked.grade, .poor)
        XCTAssertEqual(linked.findings.filter { !$0.isGood }.count, 3)
        let reused = TransactionPrivacyRating(inputs: ["bc1qa"], outputs: [("bc1qb", 0.12345678)], reusedOutputs: ["bc1qb"])
        XCTAssertEqual(reused.score, 75)
    }

    func testPrivacyRatingCredits() {
        let coinjoin = TransactionPrivacyRating(inputs: ["bc1qa", "bc1qb", "bc1qc", "bc1qd", "bc1qe"], outputs: Array(repeating: ("bc1qz", 0.1), count: 5))
        XCTAssertEqual(coinjoin.grade, .good)
        let payjoin = TransactionPrivacyRating(inputs: ["bc1qa", "bc1qb"], outputs: [("bc1qc", 0.12345678), ("bc1qd", 0.2345)], isPayjoin: true)
        XCTAssertEqual(payjoin.score, 100)
    }

    func testAddressKinds() {
        XCTAssertEqual(TransactionPrivacyRating.addressKind("bc1p5d7rjq7g6rdk2yhzks9smlaqtedr4dekq08ge8ztwac72sfr9rusxg3297"), "taproot")
        XCTAssertEqual(TransactionPrivacyRating.addressKind("bcrt1qsshu89pqh7tan826g4wr7uaplszgj4zwxw25vu"), "segwit")
        XCTAssertEqual(TransactionPrivacyRating.addressKind("3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy"), "nested")
        XCTAssertEqual(TransactionPrivacyRating.addressKind("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"), "legacy")
        XCTAssertNil(TransactionPrivacyRating.addressKind(""))
    }

    func testSignButtonGoesOnlyWhenNoSignerIsCertain() {
        let noSigner: [String: Any] = ["canSign": false, "signers": [String](), "fingerprints": ["aabbccdd"]]
        XCTAssertTrue(VerifyTransactionViewController.knownToHaveNoSigner(noSigner))
        XCTAssertTrue(VerifyTransactionViewController.knownToHaveNoSigner(["canSign": false, "signers": [String](), "spFetch": "notFound"]))

        var hot = noSigner
        hot["hotWallet"] = true
        XCTAssertFalse(VerifyTransactionViewController.knownToHaveNoSigner(hot), "The node has the keys")
        var passphrase = noSigner
        passphrase["canSign"] = nil
        XCTAssertFalse(VerifyTransactionViewController.knownToHaveNoSigner(passphrase), "Keys depend on the passphrase")
        var matched = noSigner
        matched["signers"] = ["Mine [aabbccdd]"]
        XCTAssertFalse(VerifyTransactionViewController.knownToHaveNoSigner(matched), "A signer was found")
        XCTAssertFalse(VerifyTransactionViewController.knownToHaveNoSigner(["canSign": false, "signers": [String]()]), "Unable to determine")
        XCTAssertFalse(VerifyTransactionViewController.knownToHaveNoSigner(["canSign": false, "fingerprints": ["aabbccdd"]]), "Still checking")
    }

    func testSelfTransferFromTheWalletsRecord() {
        XCTAssertTrue(WalletSelfTransfer.matches(walletTransaction: ["amount": 0.0, "details": [["category": "send"], ["category": "receive"]]]))
        // Paid someone else.
        XCTAssertFalse(WalletSelfTransfer.matches(walletTransaction: ["amount": -0.5, "details": [["category": "send"]]]))
        // Nothing sent: an incoming payment of nothing isn't a transfer.
        XCTAssertFalse(WalletSelfTransfer.matches(walletTransaction: ["amount": 0.0, "details": [["category": "receive"]]]))
        XCTAssertFalse(WalletSelfTransfer.matches(walletTransaction: [:]))
    }

    func testSelfTransferFromAddresses() {
        let mine: [String: Any] = ["isMine": true]
        let theirs: [String: Any] = ["isMine": false]
        XCTAssertTrue(WalletSelfTransfer.matches(inputs: [mine], outputs: [mine, mine]))
        XCTAssertFalse(WalletSelfTransfer.matches(inputs: [mine], outputs: [mine, theirs]))
        XCTAssertFalse(WalletSelfTransfer.matches(inputs: [theirs], outputs: [mine]), "Someone paying this wallet")
        // Not looked up, e.g. an OP_RETURN output.
        XCTAssertFalse(WalletSelfTransfer.matches(inputs: [mine], outputs: [mine, [:]]))
        XCTAssertFalse(WalletSelfTransfer.matches(inputs: [], outputs: []))
    }

    func testChangesSinceCountTransactionsNotRows() throws {
        let changes = try XCTUnwrap(WalletChangesSince(response: [
            "lastblock": "tip",
            "transactions": [
                ["txid": "in", "category": "receive", "amount": 0.25, "confirmations": 1],
                ["txid": "in", "category": "receive", "amount": 0.25, "confirmations": 1],
                ["txid": "reward", "category": "generate", "amount": 1.0, "confirmations": 2],
                ["txid": "out", "category": "send", "amount": -0.1, "confirmations": 3],
                // To yourself: sent, not also received.
                ["txid": "self", "category": "send", "amount": -0.2, "confirmations": 1],
                ["txid": "self", "category": "receive", "amount": 0.2, "confirmations": 1],
                // Unconfirmed: the wallet's list already shows it.
                ["txid": "new", "category": "receive", "amount": 9.0, "confirmations": 0]
            ],
            "removed": [["txid": "gone"], ["txid": "gone"]]
        ]))
        XCTAssertEqual(changes.lastBlock, "tip")
        XCTAssertEqual(changes.receivedCount, 2)
        XCTAssertEqual(changes.receivedBtc, 1.5, accuracy: 0.0001)
        XCTAssertEqual(changes.sentCount, 2)
        XCTAssertEqual(changes.droppedCount, 1)
        XCTAssertFalse(changes.isEmpty)
        XCTAssertTrue(changes.summary.contains("2 sent"))
        XCTAssertTrue(try XCTUnwrap(WalletChangesSince(response: ["lastblock": "tip", "transactions": []])).isEmpty)
        XCTAssertNil(WalletChangesSince(response: ["transactions": []]))
    }

    func testPSBTNextStep() throws {
        let signer = try XCTUnwrap(PSBTNextStep(response: [
            "next": "signer",
            "inputs": [["missing": ["signatures": ["aa", "bb"]]], ["missing": ["signatures": ["cc"]]], ["has_utxo": true]]
        ]))
        XCTAssertEqual(signer.missingSignatures, 3)
        XCTAssertEqual(signer.step, "Needs signing")
        XCTAssertEqual(try XCTUnwrap(PSBTNextStep(response: ["next": "extractor"])).missingSignatures, 0)
        XCTAssertNil(PSBTNextStep(response: ["error": "bad"]))
    }
}
