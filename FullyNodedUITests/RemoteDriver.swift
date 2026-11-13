//
//  RemoteDriver.swift
//  FullyNodedUITests
//
//  An interactive driver for writing new UI tests: it watches a folder for numbered command
//  files and runs each against the app, writing the result (and a screenshot) back. Skipped
//  unless FNUI_COMMAND_DIR is set, so normal test runs never wait on it.
//
//    regtest/drive.sh <device> start          # runs this test in the background
//    regtest/drive.sh <device> '{"op":"tap","text":"Enter details manually"}'
//
//  Commands (JSON, one per file `cmd-<n>.json`, result in `out-<n>.txt` and `out-<n>.png`):
//    {"op":"launch"}                           relaunch the app
//    {"op":"tap","text":"…"}                   tap the element showing that text
//    {"op":"tapAt","x":…,"y":…}                tap a point (in points, from the top left)
//    {"op":"type","text":"…","field":"…"}      type, optionally into a field found by placeholder/label
//    {"op":"typeEnv","env":"FNUI_…","field":"…"}  type an environment value (never echoed)
//    {"op":"key","key":"delete","count":5}     return / delete (count repeats)
//    {"op":"swipe","dir":"up"}                 up / down / left / right
//    {"op":"wait","text":"…","timeout":30}     wait for text to appear
//    {"op":"alert","button":"Allow"}           answer a system alert
//    {"op":"home"} / {"op":"activate"}        background the app / bring it back
//    {"op":"allowPaste"}                       Settings → Fully Noded → Paste from Other Apps → Allow
//    {"op":"sleep","seconds":5}
//    {"op":"text"}                             list visible labels (every result includes this)
//    {"op":"quit"}                             end the test
//  Add "quiet":true to any command to skip the screen listing in its result (faster).
//

import XCTest

final class RemoteDriver: XCTestCase {

    func testRemoteControl() throws {
        guard let dir = FNUIEnv.value("FNUI_COMMAND_DIR") else {
            throw XCTSkip("Set TEST_RUNNER_FNUI_COMMAND_DIR to drive the app interactively.")
        }
        continueAfterFailure = true
        let fn = FNUI()
        fn.app.activate()
        let fm = FileManager.default
        var next = 1
        let deadline = Date().addingTimeInterval(TimeInterval(FNUIEnv.value("FNUI_DRIVER_MINUTES").flatMap(Int.init) ?? 240) * 60)
        try "ready".write(toFile: "\(dir)/ready", atomically: true, encoding: .utf8)

        while Date() < deadline {
            let path = "\(dir)/cmd-\(next).json"
            guard fm.fileExists(atPath: path),
                  let data = fm.contents(atPath: path),
                  let command = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let op = command["op"] as? String else {
                Thread.sleep(forTimeInterval: 0.25)
                continue
            }
            var result = "ok"
            switch op {
            case "launch":
                fn.launch()
            case "tap":
                let text = command["text"] as? String ?? ""
                if fn.wait(text, timeout: command["timeout"] as? Double ?? 10) {
                    fn.press(fn.element(text))
                } else {
                    result = "error: no element matching \"\(text)\""
                }
            case "tapAt":
                let x = command["x"] as? Double ?? 0, y = command["y"] as? Double ?? 0
                fn.app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap()
            case "type":
                if !fn.type(command["text"] as? String ?? "", into: command["field"] as? String, clear: command["clear"] as? Bool ?? false) {
                    result = "error: no field matching \"\(command["field"] as? String ?? "")\""
                }
            case "typeEnv":
                if let name = command["env"] as? String, let value = FNUIEnv.value(name) {
                    if !fn.type(value, into: command["field"] as? String, clear: command["clear"] as? Bool ?? false) {
                        result = "error: no field matching \"\(command["field"] as? String ?? "")\""
                    }
                } else {
                    result = "error: environment value not set"
                }
            case "key":
                switch command["key"] as? String {
                case "delete": fn.app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: command["count"] as? Int ?? 1))
                default: fn.app.typeText("\n")
                }
            case "swipe":
                switch command["dir"] as? String {
                case "down": fn.app.swipeDown()
                case "left": fn.app.swipeLeft()
                case "right": fn.app.swipeRight()
                default: fn.app.swipeUp()
                }
            case "wait":
                let text = command["text"] as? String ?? ""
                if !fn.wait(text, timeout: command["timeout"] as? Double ?? 30) { result = "error: timed out waiting for \"\(text)\"" }
            case "home":
                XCUIDevice.shared.press(.home)
            case "activate":
                fn.app.activate()
            case "allowPaste":
                FNUI.allowPasteFromOtherApps()
                fn.app.activate()
            case "alert":
                fn.dismissSystemAlert(command["button"] as? String ?? "Allow")
            case "sleep":
                Thread.sleep(forTimeInterval: command["seconds"] as? Double ?? 1)
            case "quit":
                try? "\(result)\n".write(toFile: "\(dir)/out-\(next).txt", atomically: true, encoding: .utf8)
                return
            case "text":
                break
            default:
                result = "error: unknown op \(op)"
            }
            Thread.sleep(forTimeInterval: 0.6)
            // "quiet": skip listing the screen (listing every element takes a few seconds).
            let report = command["quiet"] as? Bool == true ? "\(result)\n" : "\(result)\n---\n\(fn.visibleText())\n"
            try? fn.app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/out-\(next).png"))
            try? report.write(toFile: "\(dir)/out-\(next).txt", atomically: true, encoding: .utf8)
            next += 1
        }
    }
}
