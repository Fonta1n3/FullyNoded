//
//  RegtestTests.swift
//  FullyNodedUITests
//
//  End-to-end flows against a local regtest node, in the order a user meets them. Run them
//  with regtest/run.sh (one node build) or regtest/matrix.sh (every installed Core / Knots
//  build, on two simulators). See regtest/README.md.
//

import XCTest

/// One simulator: node, wallet, receive, send, silent payment send, recovery.
final class RegtestTests: XCTestCase {
    private static var pasteAllowed = false

    private var node: RegtestNode!
    private var fn: FNUI!

    /// Per-simulator notes shared between the tests of a run (seed, receive address).
    private var notesPath: String? {
        FNUIEnv.sharedDir.map { "\($0)/wallet-\(ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? "sim").json" }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        node = try RegtestNode()
        if !Self.pasteAllowed {
            // Tried again before the next test on a new install, once the app has launched.
            Self.pasteAllowed = FNUI.allowPasteFromOtherApps()
        }
        fn = FNUI()
    }

    override func tearDown() {
        if let fn = fn, testRun?.hasSucceeded == false { add(fn.screenshot("failure")) }
        super.tearDown()
    }

    private func saveNotes(_ notes: [String: Any]) {
        guard let path = notesPath, let data = try? JSONSerialization.data(withJSONObject: notes) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }

    private func loadNotes() throws -> [String: Any] {
        guard let path = notesPath, let data = FileManager.default.contents(atPath: path),
              let notes = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw XCTSkip("Run test1_ConnectNodeAndCreateWallet first (it creates the wallet the other tests use).")
        }
        return notes
    }

    func test1_ConnectNodeAndCreateWallet() throws {
        fn.connectNode()
        XCTAssertTrue(fn.exists(nodeVersionLabel), "Home screen doesn't show the node's version \(nodeVersionLabel)")

        let words = fn.createWallet()
        XCTAssertEqual(words.count, 12, "Seed words: \(words)")
        let address = fn.receiveAddress()
        XCTAssertTrue(address.hasPrefix("bcrt1q"), "Receive address: \(address)")
        saveNotes(["seed": words, "address": address])

        try node.pay(address, 1.0)
        try node.pay(address, 0.5)
        // The wallet tab can show the balance from before the payments for a refresh or two.
        var balance: Double?
        for _ in 0..<6 {
            balance = fn.balance()
            if let balance, abs(balance - 1.5) < 0.000_000_01 { break }
            Thread.sleep(forTimeInterval: 3)
        }
        XCTAssertEqual(try XCTUnwrap(balance, "No balance shown"), 1.5, accuracy: 0.000_000_01)
    }

    func test2_SendNormally() throws {
        _ = try loadNotes()
        fn.connectNode()
        let recipient = try node.newMinerAddress()
        let sent = try XCTUnwrap(fn.send(to: recipient, amount: "0.1"), "No txid after sending")
        XCTAssertTrue(try node.mempool().contains(sent.txid), "\(sent.txid) isn't in the node's mempool")
        let tx = try node.decode(sent.txid)
        let paid = (tx["vout"] as? [[String: Any]] ?? []).contains {
            ($0["scriptPubKey"] as? [String: Any])?["address"] as? String == recipient && abs(($0["value"] as? Double ?? 0) - 0.1) < 0.000_000_01
        }
        XCTAssertTrue(paid, "The transaction doesn't pay 0.1 to \(recipient): \(tx)")
        try node.mine()
    }

    func test3_SendToSilentPaymentAddress() throws {
        _ = try loadNotes()
        fn.connectNode()
        let address = fn.silentPaymentAddress()
        XCTAssertTrue(address.hasPrefix("tsp1"), "Silent payment address on regtest: \(address)")
        let sent = try XCTUnwrap(fn.send(to: address, amount: "0.05"), "No txid after sending")
        let tx = try node.decode(sent.txid)
        let taproot = (tx["vout"] as? [[String: Any]] ?? []).contains {
            ($0["scriptPubKey"] as? [String: Any])?["type"] as? String == "witness_v1_taproot" && abs(($0["value"] as? Double ?? 0) - 0.05) < 0.000_000_01
        }
        XCTAssertTrue(taproot, "No 0.05 taproot output (the silent payment): \(tx)")
        try node.mine()
    }

    /// Removes the wallet from Fully Noded, deletes it from the node, recovers it from the seed.
    func test4_RecoverAfterDeletingWallet() throws {
        let notes = try loadNotes()
        let words = try XCTUnwrap(notes["seed"] as? [String])
        let address = try XCTUnwrap(notes["address"] as? String)
        fn.connectNode()
        let before = try XCTUnwrap(fn.balance(), "No balance before deleting")

        // The node wallet that owns the receive address.
        let wallet = try XCTUnwrap(try node.fullyNodedWallets().first { name in
            ((try? node.call("getaddressinfo", [address], wallet: name)) as? [String: Any])?["ismine"] as? Bool == true
        }, "No node wallet owns \(address)")

        fn.removeActiveWallet()
        try node.unload(wallet)
        try deleteNodeWallet(wallet)
        XCTAssertFalse(try node.fullyNodedWallets().contains(wallet))

        fn.recoverWallet(words: words)
        XCTAssertTrue(try node.fullyNodedWallets().contains(wallet), "Recovery made a different node wallet than \(wallet)")
        // The rescan runs in the background: wait for the balance to come back.
        var after: Double?
        for _ in 0..<12 {
            after = fn.balance()
            if let after, abs(after - before) < 0.000_000_01 { break }
            Thread.sleep(forTimeInterval: 5)
        }
        XCTAssertEqual(try XCTUnwrap(after), before, accuracy: 0.000_000_01, "Balance after recovery")
    }

    /// A new block arrives while watching, then a transaction in it is traced back to its source.
    func test5_BlockExplorer() throws {
        fn.connectNode()
        fn.step("Block explorer")
        fn.require("NEXT", timeout: 30, "Opening the explorer")

        // Mines a block with this payment in it.
        let txid = try node.pay(try node.newMinerAddress(), 0.01)
        fn.require("MINED", timeout: 40, "Seeing the new block")

        // Below the block's stats and map.
        fn.require("Block map of", timeout: 30, "Loading the block map")
        fn.app.swipeUp()
        fn.step(txid, timeout: 30)
        fn.require("> INPUTS", timeout: 20, "Opening the transaction")
        let vin = try node.decode(txid)["vin"] as? [[String: Any]]
        let parent = try XCTUnwrap(vin?.first?["txid"] as? String)

        fn.step("from ", timeout: 20)
        fn.require(parent, timeout: 20, "Tracing the input back to its source")
    }

    func test6_ChainDashboard() {
        fn.connectNode()
        fn.step("Dashboard")
        fn.require("Halving at", timeout: 30, "Loading the difficulty period and halving")
        fn.require("Next block", timeout: 30, "Loading the fee ladder")
        fn.require("Verified", timeout: 30, "Loading chain health")
        fn.require("Bringing blocks", timeout: 30, "Loading the peer race")
    }

    /// An unconfirmed payment shows outside the balance and says whether it will confirm; once
    /// mined the wallet says what's new; and an address paid twice shows as reused.
    func test7_WalletInsights() throws {
        let notes = try loadNotes()
        let address = try XCTUnwrap(notes["address"] as? String)
        fn.connectNode()
        fn.openWalletTab()

        let txid = try node.pay(address, 0.25, confirm: false)
        XCTAssertTrue(try node.mempool().contains(txid))
        // A tap while the last refresh is still running changes nothing, so keep asking.
        refreshUntilShown("incoming, unconfirmed")
        fn.step("+0.25", timeout: 30)
        fn.require("> WILL IT CONFIRM?", timeout: 30, "The unconfirmed transaction's outlook")
        fn.app.navigationBars.buttons.firstMatch.tap()

        try node.mine()
        refreshUntilShown("Since you last looked")

        try node.ensureFeeEstimate()
        fn.step("UTXO'S")
        fn.require("to spend", timeout: 30, "What the coins cost to spend")
        fn.app.navigationBars.buttons.firstMatch.tap()

        fn.step("Privacy checkup", timeout: 30)
        fn.require("> REUSED ADDRESSES", timeout: 20, "The privacy screen")
        fn.require(address, timeout: 30, "The address test 1 paid twice")

        // Skipping to a block holding this wallet's coins, then tracing one.
        fn.connectNode()
        fn.step("Block explorer")
        fn.step("Explorer tools", timeout: 30)
        fn.step("Your coins", timeout: 10)
        let block = fn.app.cells.matching(NSPredicate(format: "label BEGINSWITH 'BLOCK '")).firstMatch
        XCTAssertTrue(block.waitForExistence(timeout: 30), "The blocks holding the wallet's coins")
        let height = String(block.label.prefix { $0 != "," }).replacingOccurrences(of: "BLOCK ", with: "")
        fn.press(block)
        fn.require("BLOCK \(height)", timeout: 20, "The strip moving to that block")
        fn.require("Block map of", timeout: 30, "That block's details")
    }

    private func refreshUntilShown(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<8 {
            if fn.exists(text) { return }
            if fn.waitThrough("Refresh", timeout: 15) { fn.press(fn.element("Refresh")) }
            if fn.waitThrough(text, timeout: 6) { return }
        }
        XCTFail("\"\(text)\" never appeared after refreshing.", file: file, line: line)
    }

    /// Start of the version the home screen shows, e.g. "Satoshi:32.1" for "/Satoshi:32.1.0/".
    private var nodeVersionLabel: String {
        let version = node.version
        return "Satoshi:\(version / 10000).\(version / 100 % 100)"
    }

    /// The runner reaches the Mac's filesystem; node.sh tells it where the node's data is.
    private func deleteNodeWallet(_ wallet: String) throws {
        guard let datadir = FNUIEnv.value("FNUI_NODE_DATADIR") else {
            throw XCTSkip("FNUI_NODE_DATADIR not set (run through regtest/run.sh).")
        }
        try FileManager.default.removeItem(atPath: "\(datadir)/wallets/\(wallet)")
    }
}

/// Two simulators: one receives a payjoin, the other pays it. regtest/run.sh payjoin runs both.
final class PayjoinTests: XCTestCase {
    private var node: RegtestNode!
    private var fn: FNUI!

    private var invoicePath: String {
        get throws {
            guard let dir = FNUIEnv.sharedDir else { throw XCTSkip("FNUI_SHARED_DIR not set (run through regtest/run.sh).") }
            return "\(dir)/payjoin-invoice.txt"
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        node = try RegtestNode()
        FNUI.allowPasteFromOtherApps()
        fn = FNUI()
    }

    override func tearDown() {
        if let fn = fn, testRun?.hasSucceeded == false { add(fn.screenshot("failure")) }
        super.tearDown()
    }

    /// A fresh wallet with confirmed coins (a payjoin receiver adds one of its own).
    private func fundedWallet() throws {
        fn.connectNode()
        fn.waitForTor()
        fn.createWallet()
        let address = fn.receiveAddress()
        XCTAssertTrue(address.hasPrefix("bcrt1"), "No receive address for the new wallet: \(address)")
        try node.pay(address, 0.3)
        try node.pay(address, 1.0)
    }

    func testReceive() throws {
        let path = try invoicePath
        try? FileManager.default.removeItem(atPath: path)
        try fundedWallet()
        let invoice = try XCTUnwrap(fn.startPayjoinReceive(), "No payjoin invoice")
        try invoice.write(toFile: path, atomically: true, encoding: .utf8)
        let address = invoice.replacingOccurrences(of: "bitcoin:", with: "").components(separatedBy: "?").first ?? ""

        // Keep the screen open until the payer broadcasts (the listener only runs meanwhile).
        let deadline = Date().addingTimeInterval(600)
        var payjoin: [String: Any]?
        while Date() < deadline && payjoin == nil {
            for txid in (try? node.mempool()) ?? [] {
                let tx = (try? node.decode(txid)) ?? [:]
                let pays = (tx["vout"] as? [[String: Any]] ?? []).contains { ($0["scriptPubKey"] as? [String: Any])?["address"] as? String == address }
                if pays { payjoin = tx }
            }
            if payjoin == nil { Thread.sleep(forTimeInterval: 3) }
        }
        let tx = try XCTUnwrap(payjoin, "Nothing paid \(address) within 10 minutes")
        XCTAssertGreaterThanOrEqual((tx["vin"] as? [Any])?.count ?? 0, 2, "Paid without payjoin (only the payer's inputs)")
        // The receiver's own confirmation, after the "signed" card.
        if fn.waitThrough("Payjoin signed", timeout: 5) { fn.dismissCard() }
        fn.require("Payjoin broadcast", timeout: 60, "Seeing the payjoin broadcast on the receiver")
        try? FileManager.default.removeItem(atPath: path)
    }

    func testSend() throws {
        let path = try invoicePath
        let started = Date()
        try fundedWallet()
        // Wait for this run's invoice from the receiving simulator.
        var invoice: String?
        let deadline = Date().addingTimeInterval(600)
        while Date() < deadline && invoice == nil {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
               let modified = attributes[.modificationDate] as? Date, modified > started.addingTimeInterval(-30) {
                invoice = try? String(contentsOfFile: path, encoding: .utf8)
            }
            if invoice == nil { Thread.sleep(forTimeInterval: 3) }
        }
        let request = try XCTUnwrap(invoice, "The receiver never published an invoice")
        let sent = try XCTUnwrap(fn.send(to: request, amount: "0.2"), "No txid after sending")
        XCTAssertTrue(sent.payjoin)
        let tx = try node.decode(sent.txid)
        XCTAssertGreaterThanOrEqual((tx["vin"] as? [Any])?.count ?? 0, 2, "Broadcast without the receiver's input")
    }
}
