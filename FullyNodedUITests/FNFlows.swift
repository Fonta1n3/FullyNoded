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

    /// Closes a SuccessView card. A tap while the card is still animating in is dropped
    /// (UIKit ignores touches on animating views), so tap again until it's gone.
    func dismissCard(_ button: String = "DONE", file: StaticString = #filePath, line: UInt = #line) {
        require(button, timeout: 30, "Tapping \"\(button)\"", file: file, line: line)
        let target = element(button)
        for _ in 0..<4 where target.exists {
            press(target)
            if target.waitForNonExistence(timeout: 1.5) { return }
        }
    }

    // MARK: Node

    /// Launches the app and connects it to the regtest node (once per simulator).
    func connectNode() {
        launch()
        unlockIfNeeded()
        // The first launch on this simulator opens on the welcome screen.
        if elements("GET STARTED").firstMatch.waitForExistence(timeout: 3) { step("GET STARTED") }
        let connected = elements("BLOCK ").firstMatch
        let addNode = elements("Enter details manually").firstMatch
        _ = connected.waitForExistence(timeout: 20) || addNode.waitForExistence(timeout: 1)
        if addNode.exists {
            step("Enter details manually")
            if waitThrough("RPC credentials created", timeout: 5) { dismissCard() }
            type("Regtest", into: "My Node", clear: true)
            type(FNUIEnv.rpcAddress, into: "xxxx.onion:8332", clear: true)
            type(FNUIEnv.rpcUser, into: "FullyNoded", clear: true)
            type(FNUIEnv.rpcPassword ?? "", into: "Password", clear: true)
            // Ends editing so the keyboard doesn't cover Save.
            step("> RPC CREDENTIALS")
            step("SAVE NODE")
            if waitThrough("Node saved", timeout: 10) { dismissCard() }
            step("Back")
            // The rest of the first launch's guide.
            if elements("STEP 2 OF 3").firstMatch.waitForExistence(timeout: 5) { step("Not now") }
            if elements("OPEN FULLY NODED").firstMatch.waitForExistence(timeout: 5) { step("OPEN FULLY NODED") }
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
        let tab = app.tabBars.buttons["Wallet"]
        var backs = 0
        while !(tab.exists && tab.isHittable) && backs < 5 {
            dismissInterstitials()
            let back = app.navigationBars.buttons.firstMatch
            guard back.exists else { break }
            press(back)
            Thread.sleep(forTimeInterval: 0.8)
            backs += 1
        }
        _ = tab.waitForExistence(timeout: 15)
        press(tab)
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
                step("Create wallet")
            }
            if waitThrough("Create single sig wallet", timeout: 8) { return }
        }
    }

    /// Creates a single-sig wallet with 12 seed words and returns them.
    @discardableResult
    func createWallet(type: String = "Segwit") -> [String] {
        openWalletCreator()
        step(type)
        step("12 words")
        step("Create single sig wallet")
        // "I saved them" only works once the wallet is made on the node and saved.
        require("Wallet created", timeout: 120, "Creating the wallet")
        dismissCard()
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

    /// iOS's "Allow Paste" prompt, which blocks the app while it's up. Settings usually allows
    /// pastes already (FNUI.allowPasteFromOtherApps), but not on an install that hadn't launched yet.
    func allowPasteIfAsked() {
        // The system's first: while the prompt is up the app can't answer a query at all.
        for owner in [XCUIApplication(bundleIdentifier: "com.apple.springboard"), app] {
            let allow = owner.buttons["Allow Paste"]
            if allow.waitForExistence(timeout: 1.5) { allow.tap(); return }
        }
    }

    /// Wallet tab → Import by pasting text, with the seed on the pasteboard.
    func recoverWallet(words: [String], type: String = "Segwit single-sig") {
        UIPasteboard.general.string = words.joined(separator: " ")
        openWalletCreator()
        step("Paste text")
        allowPasteIfAsked()
        step(type)
        confirmImportReview()
        require("Descriptor wallet created", timeout: 120, "Recreating the wallet on the node")
        dismissCard()
    }

    /// The import review: waits until its addresses are derived here and checked by the node
    /// (Import is enabled only then), and that they matched, then imports.
    func confirmImportReview(file: StaticString = #filePath, line: UInt = #line) {
        let confirm = app.buttons["importReview.confirm"]
        guard confirm.waitForExistence(timeout: 30) else {
            XCTFail("The import review never appeared.\n\(visibleText())", file: file, line: line)
            return
        }
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: confirm)
        guard XCTWaiter.wait(for: [enabled], timeout: 60) == .completed else {
            XCTFail("Import stayed disabled (addresses didn't check out).\n\(visibleText())", file: file, line: line)
            return
        }
        // For a look at the screen after the run: <shared dir>/import-review.png.
        if let dir = FNUIEnv.sharedDir {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/import-review.png"))
        }
        XCTAssertTrue(screenText().contains("your node derives the same addresses"),
                      "This device and the node should derive the same addresses.\n\(visibleText())", file: file, line: line)
        press(confirm)
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

    /// Invoice → Address: the address under "> ADDRESS" (shown grouped with dashes).
    func receiveAddress() -> String {
        openWalletTab()
        step("INVOICE")
        step("Address")
        let address = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'bcrt'")).firstMatch
        // A just-created wallet can take a while (the node is busy importing it).
        guard address.waitForExistence(timeout: 90) else { return "" }
        return address.label.replacingOccurrences(of: "-", with: "")
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
        allowPasteIfAsked()
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
        dismissCard()
        // Not while a payjoin banner has the top of the screen.
        if !payjoin { require("> NEXT STEP", timeout: 20, "What the PSBT needs next", file: file, line: line) }
        // Below the top of the screen on a small phone: not yet there to find, and looking for
        // "Sign" without it would match "Needs signing" instead.
        for _ in 0..<3 where !app.buttons["Sign"].exists { app.swipeUp() }
        step("Sign")
        if payjoin {
            require("REVIEW PAYJOIN", timeout: 150, "Payjoin negotiation", file: file, line: line)
            let summary = visibleText()
            step("REVIEW PAYJOIN")
            XCTAssertTrue(summary.contains("PAYJOIN READY"), "Payjoin fell back:\n\(summary)", file: file, line: line)
        } else {
            require("Transaction signed", timeout: 60, "Signing", file: file, line: line)
            dismissCard()
        }
        require("Signatures complete.", timeout: 60, "Fully signed review", file: file, line: line)
        step("send")
        step("Via my node")
        require(payjoin ? "Payjoin sent" : "Transaction sent", timeout: 60, "Broadcasting", file: file, line: line)
        let copy = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Copy '")).firstMatch
        let txid = copy.exists ? String(copy.label.dropFirst("Copy ".count)) : ""
        dismissCard()
        return txid.isEmpty ? nil : Sent(txid: txid, payjoin: payjoin)
    }
}
