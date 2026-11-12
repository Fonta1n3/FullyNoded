//
//  FNUI.swift
//  FullyNodedUITests
//
//  Helpers for driving Fully Noded in the simulator. The app has few accessibility
//  identifiers, so elements are found by their visible text (label, title, value or
//  placeholder), the same way a person finds them.
//

import XCTest

/// Settings passed to the test runner. xcodebuild forwards `TEST_RUNNER_<NAME>` from its own
/// environment as `<NAME>`, so `TEST_RUNNER_FNUI_RPC_PASSWORD=… xcodebuild test …` works and
/// nothing secret lives in the scheme or the repo. See regtest/README.md.
enum FNUIEnv {
    static func value(_ name: String) -> String? {
        let value = ProcessInfo.processInfo.environment[name]
        return (value?.isEmpty ?? true) ? nil : value
    }

    /// RPC address of the regtest node as the simulator sees it (the Mac's localhost).
    static var rpcAddress: String { value("FNUI_RPC_ADDRESS") ?? "127.0.0.1:18443" }
    static var rpcUser: String { value("FNUI_RPC_USER") ?? "fntest" }
    static var rpcPassword: String? { value("FNUI_RPC_PASSWORD") }
    /// Folder shared by the two simulators' runs (payjoin invoice handoff, logs).
    static var sharedDir: String? { value("FNUI_SHARED_DIR") }
    /// Launch argument for the second simulator so its Tor doesn't collide with the first's.
    static var torPortOffset: String? { value("FNUI_TOR_PORT_OFFSET") }
    /// The app password, for a simulator whose Fully Noded has an app lock.
    static var appPassword: String? { value("FNUI_APP_PASSWORD") }
}

struct FNUI {
    let app: XCUIApplication

    init(resetState: Bool = false) {
        app = XCUIApplication(bundleIdentifier: "com.fontaine.FullyNoded")
        var args: [String] = []
        if let offset = FNUIEnv.torPortOffset { args += ["-simTorPortOffset", offset] }
        app.launchArguments = args
    }

    func launch() {
        app.terminate()
        // Let the old process's Tor release its data directory first: a new Tor that finds
        // it still locked aborts the app.
        Thread.sleep(forTimeInterval: 4)
        app.launch()
    }

    // MARK: Finding

    /// Elements whose label, identifier, value or placeholder matches `text`.
    func elements(_ text: String, exact: Bool = false) -> XCUIElementQuery {
        let op = exact ? "==" : "CONTAINS[c]"
        let predicate = NSPredicate(format: "label \(op) %@ OR identifier \(op) %@ OR placeholderValue \(op) %@ OR (value != nil AND value \(op) %@)",
                                    text, text, text, text)
        return app.descendants(matching: .any).matching(predicate)
    }

    /// The best match for `text`: an exact button first (Fully Noded's buttons also contain a
    /// label with the same text, which doesn't always pass taps on), then any exact match, then
    /// a partial one. Few queries on purpose: each one snapshots the whole screen.
    func element(_ text: String) -> XCUIElement {
        let button = app.buttons.matching(NSPredicate(format: "label == %@", text)).firstMatch
        if button.exists { return button }
        let exact = elements(text, exact: true).firstMatch
        if exact.exists { return exact }
        return elements(text).firstMatch
    }

    @discardableResult
    func wait(_ text: String, timeout: TimeInterval = 30) -> Bool {
        elements(text).firstMatch.waitForExistence(timeout: timeout)
    }

    func exists(_ text: String) -> Bool { elements(text).firstMatch.exists }

    // MARK: Acting

    func tap(_ text: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        guard wait(text, timeout: timeout) else {
            XCTFail("No element matching \"\(text)\"\n\(visibleText())", file: file, line: line)
            return
        }
        press(element(text))
    }

    /// Taps an element, scrolling to it first. XCUITest refuses (and ends the test) when it
    /// judges an element not hittable, which Fully Noded's layered cards often trip, so that
    /// case taps the element's centre instead.
    func press(_ target: XCUIElement) {
        // XCUITest calls an element under the keyboard hittable, and the tap lands on a key.
        if !target.isHittable || underKeyboard(target) { scrollIntoView(target) }
        if target.isHittable {
            target.tap()
        } else {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Taps the text field found by `field` (placeholder or label) and types `text`.
    /// False if there's no such field (a failed tap would end the whole test).
    @discardableResult
    func type(_ text: String, into field: String? = nil, clear: Bool = false) -> Bool {
        if let field = field {
            let target = textField(field)
            guard target.waitForExistence(timeout: 10) else { return false }
            press(target)
            // An empty field reports its placeholder as its value; deleting that many is harmless.
            if clear, let current = target.value as? String, !current.isEmpty {
                target.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
            }
        }
        app.typeText(text)
        return true
    }

    func textField(_ text: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@ OR placeholderValue CONTAINS[c] %@", text, text, text)
        for type in [XCUIElement.ElementType.textField, .secureTextField, .textView] {
            let match = app.descendants(matching: type).matching(predicate).firstMatch
            if match.exists { return match }
        }
        return element(text)
    }

    /// Scrolls until the element's frame is on screen, by small drags (a full swipe can fling
    /// past it on a small screen like the iPhone SE's).
    func scrollIntoView(_ target: XCUIElement, attempts: Int = 10) {
        let window = app.windows.firstMatch.frame
        guard !window.isEmpty else { scrollTo(target); return }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        for _ in 0..<attempts {
            let frame = target.frame
            let keyboard = app.keyboards.firstMatch
            let bottom = keyboard.exists ? keyboard.frame.minY - 20 : window.maxY - 90
            if frame.minY >= window.minY + 90 && frame.maxY <= bottom { return }
            let dy: CGFloat = frame.midY > window.midY ? -window.height * 0.3 : window.height * 0.3
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: dy)))
        }
    }

    func underKeyboard(_ target: XCUIElement) -> Bool {
        let keyboard = app.keyboards.firstMatch
        return keyboard.exists && keyboard.frame.intersects(target.frame)
    }

    func scrollTo(_ target: XCUIElement, attempts: Int = 8) {
        var tries = 0
        while !target.isHittable && tries < attempts {
            app.swipeUp()
            tries += 1
        }
        tries = 0
        while !target.isHittable && tries < attempts {
            app.swipeDown()
            tries += 1
        }
    }

    /// Settings → Fully Noded → Paste from Other Apps → Allow. Without it every paste (the
    /// recipient on the Send screen) asks, and that prompt blocks the app while it's up.
    /// False if it couldn't: Settings has no such option until the app has launched once.
    @discardableResult
    static func allowPasteFromOtherApps() -> Bool {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.terminate()
        settings.launch()
        let search = settings.searchFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText("Fully Noded")
        }
        let app = settings.staticTexts.matching(NSPredicate(format: "label == %@", "Fully Noded")).element(boundBy: 0)
        if !app.waitForExistence(timeout: 5) {
            // Older layouts list apps at the bottom of the root page.
            for _ in 0..<12 where !app.exists { settings.swipeUp() }
        }
        guard app.exists else { return false }
        app.tap()
        let paste = settings.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "Paste from Other Apps")).firstMatch
        guard paste.waitForExistence(timeout: 5) else { return false }
        if (paste.value as? String)?.contains("Allow") == true && !((paste.value as? String)?.contains("Ask") ?? false) {
            settings.terminate()
            return true
        }
        paste.tap()
        let allow = settings.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Allow")).firstMatch
        let allowed = allow.waitForExistence(timeout: 5)
        if allowed { allow.tap() }
        settings.terminate()
        return allowed
    }

    /// Answers a system alert (notifications, camera…) if one is up.
    func dismissSystemAlert(_ button: String) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alertButton = springboard.alerts.buttons[button]
        if alertButton.waitForExistence(timeout: 2) { alertButton.tap() }
    }

    // MARK: Reading

    /// Every visible label, one per line with its type, for logs and failure messages.
    /// One accessibility snapshot of the whole tree (querying elements one by one floods the
    /// automation log until the system quarantines it, which crashed the app under test).
    /// Elements outside the screen are marked [off].
    func visibleText() -> String {
        guard let root = try? app.snapshot() else { return "(no snapshot)" }
        let screen = root.frame
        var lines: [String] = []
        func walk(_ node: XCUIElementSnapshot) {
            let label = node.label
            let value = (node.value as? String) ?? ""
            let placeholder = node.placeholderValue ?? ""
            if !label.isEmpty || !value.isEmpty || !placeholder.isEmpty {
                // Never print a secure field's value.
                let shownValue = node.elementType == .secureTextField ? "" : value
                let frame = node.frame
                let off = !screen.intersects(frame) || frame.isEmpty
                lines.append("\(node.elementType.name) \"\(label)\"\(shownValue.isEmpty || shownValue == label ? "" : " = \"\(shownValue)\"")\(placeholder.isEmpty ? "" : " (\(placeholder))") @\(Int(frame.midX)),\(Int(frame.midY))\(off ? " [off]" : "")")
            }
            node.children.forEach(walk)
        }
        walk(root)
        return lines.joined(separator: "\n")
    }

    func screenshot(_ name: String) -> XCTAttachment {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }
}

extension XCUIElement.ElementType {
    var name: String {
        switch self {
        case .button: return "button"
        case .staticText: return "text"
        case .textField: return "field"
        case .secureTextField: return "secure"
        case .textView: return "textview"
        case .cell: return "cell"
        case .switch: return "switch"
        case .navigationBar: return "navbar"
        case .alert: return "alert"
        case .image: return "image"
        case .segmentedControl: return "segments"
        case .tab: return "tab"
        case .tabBar: return "tabbar"
        case .table: return "table"
        case .other: return "other"
        default: return "el\(rawValue)"
        }
    }
}
