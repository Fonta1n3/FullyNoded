//
//  TextModalViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/7/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//
//  Shows a raw RPC response as syntax-highlighted JSON. Uses a UITextView (which only
//  renders what's on screen) rather than a UILabel: a label taller than the GPU's max
//  texture size, e.g. decodepsbt with many inputs, draws nothing at all.
//

import Foundation
import UIKit

class TextModalViewController: UIViewController {

    private let data: [String: Any]
    private let viewTitle: String
    private var prettyText: String = ""
    private var highlightGeneration = 0

    private static let fontSizeKey = "textModalFontSize"
    private static let minFontSize: CGFloat = 9
    private static let maxFontSize: CGFloat = 22

    private var fontSize: CGFloat = {
        let saved = CGFloat(UserDefaults.standard.double(forKey: TextModalViewController.fontSizeKey))
        return saved > 0 ? saved : 13
    }() {
        didSet {
            UserDefaults.standard.set(Double(fontSize), forKey: TextModalViewController.fontSizeKey)
            applyHighlighting()
        }
    }

    init(data: [String: Any], viewTitle: String) {
        self.data = data
        self.viewTitle = viewTitle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: UI Components
    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.alwaysBounceVertical = true
        tv.backgroundColor = .secondarySystemBackground
        tv.layer.cornerRadius = 12
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        tv.dataDetectorTypes = []
        tv.autocorrectionType = .no
        tv.smartQuotesType = .no
        tv.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 16.0, *) {
            tv.isFindInteractionEnabled = true
        }
        return tv
    }()

    private lazy var summaryLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    // MARK: View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = viewTitle

        setupUI()
        setupNavigationButtons()

        prettyText = prettyPrintedJSON(from: data)
        summaryLabel.text = summary()
        applyHighlighting()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyHighlighting()
        }
    }

    private func setupUI() {
        view.addSubview(summaryLabel)
        view.addSubview(textView)
        view.addSubview(spinner)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            summaryLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            summaryLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            summaryLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),

            textView.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),

            spinner.centerXAnchor.constraint(equalTo: textView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: textView.centerYAnchor)
        ])
    }

    private func setupNavigationButtons() {
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done,
                                         target: self,
                                         action: #selector(dismissModal))

        let copyButton = UIBarButtonItem(image: UIImage(systemName: "doc.on.doc"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(copyToClipboard))
        copyButton.accessibilityLabel = "Copy"

        let shareButton = UIBarButtonItem(barButtonSystemItem: .action,
                                          target: self,
                                          action: #selector(share(_:)))

        var tools: [UIBarButtonItem] = [copyButton, .flexibleSpace(), shareButton]
        if #available(iOS 16.0, *) {
            let findButton = UIBarButtonItem(image: UIImage(systemName: "magnifyingglass"),
                                             style: .plain,
                                             target: self,
                                             action: #selector(showFind))
            findButton.accessibilityLabel = "Find"
            tools += [.flexibleSpace(), findButton]
        }
        
        let textSize = UIBarButtonItem(image: UIImage(systemName: "textformat.size"), menu: UIMenu(children: [
            UIAction(title: "Larger Text", image: UIImage(systemName: "plus.magnifyingglass")) { [weak self] _ in
                self?.changeFontSize(by: 1)
            },
            UIAction(title: "Smaller Text", image: UIImage(systemName: "minus.magnifyingglass")) { [weak self] _ in
                self?.changeFontSize(by: -1)
            }
        ]))
        textSize.accessibilityLabel = "Text size"
        tools += [.flexibleSpace(), textSize]
        
        // Tools go in a bottom toolbar so the title (the RPC command) isn't truncated.
        navigationItem.rightBarButtonItem = doneButton
        toolbarItems = tools
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: false)
    }
    
    private func changeFontSize(by delta: CGFloat) {
        fontSize = min(Self.maxFontSize, max(Self.minFontSize, fontSize + delta))
    }

    @objc private func copyToClipboard() {
        UIPasteboard.general.string = prettyText

        let alert = UIAlertController(title: "Copied!", message: "Pretty-printed data copied to clipboard.", preferredStyle: .alert)
        present(alert, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    @objc private func share(_ sender: UIBarButtonItem) {
        let activity = UIActivityViewController(activityItems: [prettyText], applicationActivities: nil)
        activity.popoverPresentationController?.barButtonItem = sender
        present(activity, animated: true)
    }

    @available(iOS 16.0, *)
    @objc private func showFind() {
        textView.findInteraction?.presentFindNavigator(showingReplace: false)
    }

    @objc private func dismissModal() {
        dismiss(animated: true)
    }

    // MARK: Summary

    /// One line of context above the JSON, for the responses that have obvious counts.
    private func summary() -> String {
        var parts: [String] = []
        let tx = data["tx"] as? [String: Any]
        if let inputs = (data["inputs"] as? [Any]) ?? (tx?["vin"] as? [Any]) ?? (data["vin"] as? [Any]) {
            parts.append("\(inputs.count) input\(inputs.count == 1 ? "" : "s")")
        }
        if let outputs = (data["outputs"] as? [Any]) ?? (tx?["vout"] as? [Any]) ?? (data["vout"] as? [Any]) {
            parts.append("\(outputs.count) output\(outputs.count == 1 ? "" : "s")")
        }
        if let fee = data["fee"] as? Double {
            parts.append("fee \(String(format: "%.8f", fee)) BTC")
        }
        if let vsize = (data["vsize"] as? Int) ?? (tx?["vsize"] as? Int) {
            parts.append("\(vsize) vB")
        }
        parts.append(ByteCountFormatter.string(fromByteCount: Int64(prettyText.utf8.count), countStyle: .file))
        return parts.joined(separator: " · ")
    }

    // MARK: Highlighting

    private func applyHighlighting() {
        guard isViewLoaded else { return }
        highlightGeneration += 1
        let generation = highlightGeneration

        let text = prettyText
        let size = fontSize
        let palette = Palette(traits: traitCollection)

        // Plain text first so the content shows immediately, even for huge responses.
        if textView.text != text {
            textView.attributedText = NSAttributedString(string: text, attributes: palette.base(size: size))
        }
        spinner.startAnimating()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let highlighted = JSONHighlighter.highlight(text, size: size, palette: palette)
            DispatchQueue.main.async {
                guard let self = self, generation == self.highlightGeneration else { return }
                let offset = self.textView.contentOffset
                self.textView.attributedText = highlighted
                self.textView.layoutIfNeeded()
                self.textView.setContentOffset(offset, animated: false)
                self.spinner.stopAnimating()
            }
        }
    }

    // MARK: Pretty-Print Logic
    
    /// JSONSerialization writes doubles with 17 significant digits (1.17998138000000001,
    /// 1.444e-05); swap them for decimals in their shortest form (1.17998138, 0.00001444).
    private static func exactDecimals(_ value: Any) -> Any {
        switch value {
        case let dict as [String: Any]:
            return dict.mapValues { exactDecimals($0) }
        case let array as [Any]:
            return array.map { exactDecimals($0) }
        case let number as NSNumber where CFGetTypeID(number) != CFBooleanGetTypeID():
            let type = String(cString: number.objCType)
            guard type == "d" || type == "f", let decimal = Decimal(string: "\(number.doubleValue)") else { return number }
            return NSDecimalNumber(decimal: decimal)
        default:
            return value
        }
    }
    
    private func prettyPrintedJSON(from dictionary: [String: Any]) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: Self.exactDecimals(dictionary), options: [.prettyPrinted, .sortedKeys])
            var jsonString = String(data: jsonData, encoding: .utf8) ?? "Unable to format data."
            jsonString = jsonString.replacingOccurrences(of: "\\/", with: "/")

            return jsonString
        } catch {
            return "Error formatting data: \(error.localizedDescription)\n\nRaw: \(dictionary)"
        }
    }
}

// MARK: - JSON syntax highlighting

private struct Palette {
    let text: UIColor
    let key: UIColor
    let string: UIColor
    let number: UIColor
    let literal: UIColor
    let punctuation: UIColor

    init(traits: UITraitCollection) {
        func resolve(_ color: UIColor) -> UIColor { color.resolvedColor(with: traits) }
        text = resolve(.label)
        key = resolve(.systemBlue)
        string = resolve(.systemGreen)
        number = resolve(.systemOrange)
        literal = resolve(.systemPurple)
        punctuation = resolve(.tertiaryLabel)
    }

    func base(size: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        // Long hex strings (PSBTs, scripts, witnesses) wrap anywhere instead of overflowing.
        paragraph.lineBreakMode = .byCharWrapping
        paragraph.lineSpacing = 2
        return [
            .font: UIFont.monospacedSystemFont(ofSize: size, weight: .regular),
            .foregroundColor: text,
            .paragraphStyle: paragraph
        ]
    }
}

private enum JSONHighlighter {

    /// Colours keys, strings, numbers and literals in pretty-printed JSON with a single pass.
    static func highlight(_ text: String, size: CGFloat, palette: Palette) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: palette.base(size: size))
        let keyFont = UIFont.monospacedSystemFont(ofSize: size, weight: .semibold)
        let chars = Array(text.utf16)
        let count = chars.count
        var i = 0

        func color(_ range: NSRange, _ color: UIColor, font: UIFont? = nil) {
            result.addAttribute(.foregroundColor, value: color, range: range)
            if let font = font { result.addAttribute(.font, value: font, range: range) }
        }

        result.beginEditing()
        while i < count {
            let c = chars[i]
            switch c {
            case 0x22: // "
                let start = i
                i += 1
                while i < count && chars[i] != 0x22 {
                    i += chars[i] == 0x5C ? 2 : 1 // skip escaped characters
                }
                i = min(i + 1, count)
                let range = NSRange(location: start, length: i - start)
                // A string followed by ':' is a key.
                var j = i
                while j < count && chars[j] == 0x20 { j += 1 }
                if j < count && chars[j] == 0x3A {
                    color(range, palette.key, font: keyFont)
                } else {
                    color(range, palette.string)
                }
            case 0x2D, 0x30...0x39: // - or digit
                let start = i
                while i < count, isNumberChar(chars[i]) { i += 1 }
                color(NSRange(location: start, length: i - start), palette.number)
            case 0x74, 0x66, 0x6E: // t f n -> true false null
                let start = i
                while i < count, chars[i] >= 0x61 && chars[i] <= 0x7A { i += 1 }
                color(NSRange(location: start, length: i - start), palette.literal)
            case 0x7B, 0x7D, 0x5B, 0x5D, 0x2C, 0x3A: // { } [ ] , :
                color(NSRange(location: i, length: 1), palette.punctuation)
                i += 1
            default:
                i += 1
            }
        }
        result.endEditing()
        return result
    }

    private static func isNumberChar(_ c: UInt16) -> Bool {
        (c >= 0x30 && c <= 0x39) || c == 0x2E || c == 0x2D || c == 0x2B || c == 0x65 || c == 0x45
    }
}

extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
