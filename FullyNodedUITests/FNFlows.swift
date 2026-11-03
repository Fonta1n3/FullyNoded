//
//  FNFlows.swift
//  FullyNodedUITests
//
//  The user-level steps the regtest tests are made of: connecting the node, creating and
//  recovering wallets, receiving, sending (with or without payjoin). Each step waits for
//  what a person would wait for and answers the interstitials Fully Noded shows on the way.
//

import XCTest

extension FNUI {

    // MARK: Interstitials

    /// Alerts that can pop up in the middle of a flow and only need acknowledging.
    private static let interstitials: [(text: String, button: String)] = [
        ("You are not using the app securely...", "OK"),
        ("Your transaction fee rate has been set to", "OK"),
        // The active wallet from an earlier chain / node isn't on this node (node reset).
        ("Requested wallet does not exist or is not loaded", "OK"),
    ]

    /// Every label and value on screen, from ONE accessibility snapshot. Each query snapshots the
    /// whole tree and XCTest logs inside the app for every unusual element; querying several
    /// times a second gets that logging quarantined, which crashes the app under test.
    func screenText() -> String {
        guard let root = try? app.snapshot() else { return "" }
        var parts: [String] = []
        func walk(_ node: XCUIElementSnapshot) {
            parts.append(node.label)
            if let value = node.value as? String, node.elementType != .secureTextField { parts.append(value) }
            node.children.forEach(walk)
        }
        walk(root)
        return parts.joined(separator: "\n")
    }

    /// Dismisses any of `interstitials` showing in `screen` (default: a fresh snapshot).
    @discardableResult
    func dismissInterstitials(in screen: String? = nil) -> Bool {
        let screen = screen ?? screenText()
        var dismissed = false
        for (text, button) in Self.interstitials where screen.contains(text) {
            let target = app.buttons.matching(NSPredicate(format: "label == %@", button)).firstMatch
            if target.exists { press(target); dismissed = true }
        }
        return dismissed
    }

    /// Waits for `text`, answering interstitials meanwhile (one snapshot per poll).
    @discardableResult
    func waitThrough(_ text: String, timeout: TimeInterval = 60) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let screen = screenText()
            if screen.contains(text) { return true }
            if !dismissInterstitials(in: screen) { Thread.sleep(forTimeInterval: 1.5) }
        } while Date() < deadline
        return false
    }

    func require(_ text: String, timeout: TimeInterval = 60, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        if !waitThrough(text, timeout: timeout) {
            XCTFail("\(what): \"\(text)\" never appeared.\n\(visibleText())", file: file, line: line)
        }
    }

    /// Taps `text` after waiting for it through interstitials.
    func step(_ text: String, timeout: TimeInterval = 30, file: StaticString = #filePath, line: UInt = #line) {
        require(text, timeout: timeout, "Tapping \"\(text)\"", file: file, line: line)
        press(element(text))
    }

    // MARK: Node

    /// Launches the app and connects it to the regtest node (once per simulator).
    func connectNode() {
        launch()
        unlockIfNeeded()
        let connected = elements("BLOCK ").firstMatch
        let addNode = elements("Enter details manually").firstMatch
        _ = connected.waitForExistence(timeout: 20) || addNode.waitForExistence(timeout: 1)
        if addNode.exists {
            step("Enter details manually")
            if waitThrough("RPC credentials created", timeout: 5) { step("DONE") }
            type("Regtest", into: "My Node", clear: true)
            type(FNUIEnv.rpcAddress, into: "xxxx.onion:8332", clear: true)
            type(FNUIEnv.rpcUser, into: "FullyNoded", clear: true)
            type(FNUIEnv.rpcPassword ?? "", into: "Password", clear: true)
            // Ends editing so the keyboard doesn't cover Save.
            step("> RPC CREDENTIALS")
            step("SAVE NODE")
            if waitThrough("Node saved", timeout: 10) { step("DONE") }
            step("Back")
        }
        require("REGTEST", timeout: 60, "Connecting to the regtest node")
        require("BLOCK ", timeout: 60, "Loading the node")
    }

    /// The lock screen, when the app has an app password (FNUI_APP_PASSWORD).
    func unlockIfNeeded() {
        guard elements("> locked_").firstMatch.waitForExistence(timeout: 4) else { return }
        guard let password = FNUIEnv.value("FNUI_APP_PASSWORD") else {
            XCTFail("The app is locked: set FNUI_APP_PASSWORD (regtest/run.sh reads $FNUI_WORK/applock.secret).")
            return
        }
        type(password, into: "app password")
        step("UNLOCK")
    }

    /// Waits until the home screen shows Tor connected (payjoin needs it on both sides).
    func waitForTor() {
        require("TOR CONNECTED", timeout: 180, "Tor bootstrap")
    }

    // MARK: Wallets

    /// The wallet tab, backing out of pushed screens first (they hide the tab bar).
    func openWalletTab() {
        let tab = app.tabBars.buttons["bitcoinsign.square"]
        var backs = 0
        while !(tab.exists && tab.isHittable) && backs < 5 {
            dismissInterstitials()
            let back = app.navigationBars.buttons.firstMatch
            guard back.exists else { break }
            press(back)
            Thread.sleep(forTimeInterval: 0.8)
            backs += 1
        }
        step("bitcoinsign.square")
    }

    /// The Create Wallet screen: the empty state's button, or + while a wallet is active (a tap
    /// while the wallet tab is still loading can be lost, so it retries).
    func openWalletCreator() {
        openWalletTab()
        for _ in 0..<4 {
            let screen = screenText()
            if screen.contains("CREATE OR IMPORT A WALLET") {
                step("CREATE OR IMPORT A WALLET")
            } else {
                step("Add Slide")
            }
            if waitThrough(" Create single-sig", timeout: 8) { return }
        }
    }

    /// Creates a single-sig wallet with 12 seed words and returns them.
    @discardableResult
    func createWallet(type: String = "Segwit (BIP84)") -> [String] {
        openWalletCreator()
        step(" Create single-sig")
        step(type)
        step("12 words")
        // "I saved them" only works once the wallet is made on the node and saved.
        require("Wallet created", timeout: 120, "Creating the wallet")
        step("DONE")
        let words = seedWords()
        step("I saved them")
        require("> Single sig", timeout: 30, "The new wallet becoming active")
        return words
    }

    /// The 12 words on the seed screen ("1. word  2. word …").
    func seedWords() -> [String] {
        let view = app.textViews.firstMatch
        guard view.waitForExistence(timeout: 10), let text = view.value as? String else { return [] }
        return text.split(separator: " ").map(String.init).filter { !$0.hasSuffix(".") && !$0.isEmpty }
    }

    /// Removes the active wallet from Fully Noded (wallet detail → trash → Remove).
    func removeActiveWallet() {
        openWalletTab()
        step("info")
        step("trash")
        step("Remove")
        step("Done")
        require("No wallet active", timeout: 20, "Removing the wallet")
    }

    /// Wallet tab → Import by pasting text, with the seed on the pasteboard.
    func recoverWallet(words: [String], type: String = "Segwit single-sig") {
        UIPasteboard.general.string = words.joined(separator: " ")
        openWalletCreator()
        step(" Import by pasting text")
        step(type)
        require("First 5 addresses derived", timeout: 30, "Reading the pasted seed")
        let create = app.buttons.matching(NSPredicate(format: "label == %@", "Create Wallet")).allElementsBoundByIndex.last
        if let create { press(create) }
        require("Descriptor wallet created", timeout: 120, "Recreating the wallet on the node")
        step("DONE")
    }

    /// Wallet tab: the onchain balance in BTC, after a refresh.
    func balance() -> Double? {
        openWalletTab()
        // While the tab is loading its Refresh button is a spinner: tap it only if it's there.
        if waitThrough("Refresh", timeout: 20) { press(element("Refresh")) }
        require("ONCHAIN BALANCE", timeout: 90, "Loading the balance")
        Thread.sleep(forTimeInterval: 3)
        let label = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", " BTC")).firstMatch
        guard label.waitForExistence(timeout: 20) else { return nil }
        return Double(label.label.replacingOccurrences(of: " BTC", with: "").replacingOccurrences(of: " ", with: ""))
    }

    // MARK: Receiving

    /// Invoice → Address: the address in the BIP21 request.
    func receiveAddress() -> String {
        openWalletTab()
        step("INVOICE")
        step("Address")
        let request = elements("bitcoin:bcrt1").firstMatch
        _ = request.waitForExistence(timeout: 20)
        return request.label.replacingOccurrences(of: "bitcoin:", with: "").components(separatedBy: "?").first ?? ""
    }

    /// Invoice → Silent pay: acknowledges the heads-up if needed and returns the address.
    func silentPaymentAddress() -> String {
        openWalletTab()
        step("INVOICE")
        step("Silent pay")
        if waitThrough("I UNDERSTAND, SHOW MY ADDRESS", timeout: 5) { step("I UNDERSTAND, SHOW MY ADDRESS") }
        let address = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'tsp1' OR label BEGINSWITH 'sp1' OR label BEGINSWITH 'sprt1'")).firstMatch
        _ = address.waitForExistence(timeout: 20)
        return address.label
    }

    /// Invoice → Payjoin: waits for the endpoint and returns the BIP21 request with pj=.
    func startPayjoinReceive() -> String? {
        openWalletTab()
        step("INVOICE")
        step("Payjoin")
        require("Payjoin is live", timeout: 180, "Publishing the payjoin endpoint")
        let request = elements("pj=http").firstMatch
        _ = request.waitForExistence(timeout: 20)
        return request.exists ? request.label : nil
    }

    // MARK: Sending

    struct Sent {
        let txid: String
        let payjoin: Bool
    }

    /// Send screen → sign on this device → broadcast with the node. `recipient` is an address,
    /// a silent payment address or a BIP21 request (with pj= for payjoin).
    func send(to recipient: String, amount: String, feeRate: String = "2",
              file: StaticString = #filePath, line: UInt = #line) -> Sent? {
        UIPasteboard.general.string = recipient
        openWalletTab()
        step("SEND")
        type(amount, into: "0.00 000 000", clear: true)
        step("Paste")
        let payjoin = recipient.contains("pj=")
        if payjoin {
            require("Payjoin supported", timeout: 10, "Payment request sheet", file: file, line: line)
            step("CONTINUE")
            // The request had no amount: the field is empty again.
            type(amount, into: "0.00 000 000", clear: true)
        }
        // Ends editing the amount: on a small screen its keyboard covers the fee field.
        step("> FEE")
        type(feeRate, into: "custom sat/vB", clear: true)
        step("> FEE")
        dismissInterstitials()
        step("CREATE TRANSACTION")
        require("PSBT created", timeout: 120, "Creating and decoding the PSBT", file: file, line: line)
        step("DONE")
        step("Sign")
        if payjoin {
            require("REVIEW PAYJOIN", timeout: 150, "Payjoin negotiation", file: file, line: line)
            let summary = visibleText()
            step("REVIEW PAYJOIN")
            XCTAssertTrue(summary.contains("PAYJOIN READY"), "Payjoin fell back:\n\(summary)", file: file, line: line)
        } else {
            require("Transaction signed", timeout: 60, "Signing", file: file, line: line)
            step("DONE")
        }
        require("Signatures complete.", timeout: 60, "Fully signed review", file: file, line: line)
        step("send")
        step("Via my node")
        require(payjoin ? "Payjoin sent" : "Transaction sent", timeout: 60, "Broadcasting", file: file, line: line)
        let copy = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Copy '")).firstMatch
        let txid = copy.exists ? String(copy.label.dropFirst("Copy ".count)) : ""
        step("DONE")
        return txid.isEmpty ? nil : Sent(txid: txid, payjoin: payjoin)
    }
}
