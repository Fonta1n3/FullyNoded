//
//  ImportReviewViewController.swift
//  FullyNoded
//
//  The last step of every wallet import or recovery: what the wallet is, its full addresses
//  to check against the other wallet or device, then Import or Cancel.
//
//  Addresses are derived on this device (BDK, no node) and compared with what the node
//  derives. A mismatch blocks the import: one of the two is wrong, and importing would
//  watch addresses that aren't the wallet's.
//

import UIKit

/// What an import review shows. `receiveDescriptor` is the descriptor being imported; the
/// change descriptor is worked out from it unless given.
struct ImportReview {
    var title: String
    /// Where the wallet came from ("Pasted descriptor", "Coldcard file", "Wallet backup"…).
    var source: String
    var receiveDescriptor: String
    var changeDescriptor: String?
    /// The wallet's name, editable on the screen. nil: no name field.
    var label: String?
    /// Extra rows for the summary card, e.g. ("Backup updated", "3 Nov 2026").
    var details: [(String, String)] = []
    var confirmTitle = "Import wallet"
}

extension UIViewController {
    /// Shows `review` and calls `onConfirm` with the (possibly edited) name once the user taps
    /// Import. Nothing is imported before that; Cancel calls `onCancel`.
    func presentImportReview(_ review: ImportReview,
                             onCancel: (() -> Void)? = nil,
                             onConfirm: @escaping (String) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let vc = ImportReviewViewController(review: review)
            vc.onConfirm = onConfirm
            vc.onCancel = onCancel
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true)
        }
    }
}

final class ImportReviewViewController: UIViewController, UITextFieldDelegate {
    var onConfirm: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private let review: ImportReview
    private let tint = WalletTheme.Tint.create
    private let receive: String
    private let change: String

    private enum Branch: Int { case receive, change }
    private enum Check {
        case checking
        case matched
        /// Derived here; the node couldn't check (reason).
        case deviceOnly(String)
        /// Couldn't derive here (reason): the node's addresses only.
        case nodeOnly(String)
        case mismatch
        case failed(String)
    }

    private var branch = Branch.receive
    /// Addresses per branch wanted, and how many have been asked for so far.
    private var shown = ImportReviewViewController.pageSize
    private var loaded = 0
    private var local: (receive: [String], change: [String]) = ([], [])
    private var node: (receive: [String], change: [String]) = ([], [])
    private var localError: String?
    private var check = Check.checking
    private var descriptorRevealed = false

    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let nameField = UITextField()
    private let descriptorLabel = UILabel()
    private let descriptorToggle = UIButton(type: .system)
    private let branchControl = UISegmentedControl(items: ["Receive", "Change"])
    private let addressStack = UIStackView()
    private let moreButton = UIButton(type: .system)
    private let checkIcon = UIImageView()
    private let checkLabel = UILabel()
    private let confirmButton = UIButton(type: .system)

    private static let pageSize = 5
    private static let maxShown = 100

    init(review: ImportReview) {
        self.review = review
        let pair = Self.branches(review.receiveDescriptor, change: review.changeDescriptor)
        receive = pair.receive
        change = pair.change
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = review.title
        buildLayout()
        WalletTheme.apply(to: self, tint: tint)
        renderCheck()
        loadMore()
    }

    // MARK: - Descriptors

    /// Receive and change descriptors without checksums (BDK and the node get them as plain
    /// text; a `<0;1>` multipath is split into its two branches).
    static func branches(_ receive: String, change: String?) -> (receive: String, change: String) {
        func plain(_ d: String) -> String {
            String(d.split(separator: "#").first ?? Substring(d))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "'", with: "h")
        }
        let r = plain(receive)
        if let change = change { return (plain(r.replacingOccurrences(of: "<0;1>", with: "0")), plain(change)) }
        if r.contains("<0;1>") {
            return (r.replacingOccurrences(of: "<0;1>", with: "0"), r.replacingOccurrences(of: "<0;1>", with: "1"))
        }
        return (r, r.replacingOccurrences(of: "/0/*", with: "/1/*"))
    }

    /// `[fingerprint/path]` of every key: ("a1b2c3d4", "m/84h/0h/0h").
    static func keyOrigins(_ descriptor: String) -> [(fingerprint: String, path: String)] {
        guard let regex = try? NSRegularExpression(pattern: #"\[([0-9a-fA-F]{8})((?:/[0-9]+[hH']?)*)\]"#) else { return [] }
        let ns = descriptor as NSString
        return regex.matches(in: descriptor, range: NSRange(location: 0, length: ns.length)).map {
            (ns.substring(with: $0.range(at: 1)).lowercased(),
             "m" + ns.substring(with: $0.range(at: 2)).replacingOccurrences(of: "'", with: "h").replacingOccurrences(of: "H", with: "h"))
        }
    }

    /// The descriptor with any private keys hidden.
    static func masked(_ descriptor: String) -> String {
        descriptor.replacingOccurrences(of: #"[xt]prv[1-9A-HJ-NP-Za-km-z]+"#, with: "•••private key hidden•••",
                                        options: .regularExpression)
    }

    // MARK: - Layout

    private func buildLayout() {
        view.backgroundColor = WalletTheme.bg
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(cancelTapped))
        navigationItem.leftBarButtonItem?.accessibilityLabel = "Cancel import"

        scroll.alwaysBounceVertical = true
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        let intro = UILabel()
        intro.text = "Check these addresses against the wallet or device you're importing from. Nothing is imported until you tap \(review.confirmTitle)."
        intro.font = WalletTheme.mono(12)
        intro.textColor = WalletTheme.dim
        intro.numberOfLines = 0
        stack.addArrangedSubview(intro)
        stack.setCustomSpacing(16, after: intro)

        if let label = review.label {
            stack.addArrangedSubview(WalletTheme.caption("> NAME", tint: tint))
            nameField.text = label
            nameField.placeholder = "Wallet name"
            nameField.font = WalletTheme.mono(15)
            nameField.autocorrectionType = .no
            nameField.spellCheckingType = .no
            nameField.smartDashesType = .no
            nameField.smartQuotesType = .no
            nameField.returnKeyType = .done
            nameField.keyboardAppearance = .dark
            nameField.clearButtonMode = .whileEditing
            nameField.delegate = self
            nameField.accessibilityIdentifier = "importReview.name"
            WalletTheme.styleField(nameField, tint: tint)
            nameField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            stack.addArrangedSubview(nameField)
            stack.setCustomSpacing(16, after: nameField)
        }

        stack.addArrangedSubview(WalletTheme.caption("> WALLET", tint: tint))
        let summary = summaryCard()
        stack.addArrangedSubview(summary)
        stack.setCustomSpacing(16, after: summary)

        stack.addArrangedSubview(WalletTheme.caption("> ADDRESSES", tint: tint))
        branchControl.selectedSegmentIndex = 0
        branchControl.addTarget(self, action: #selector(branchChanged), for: .valueChanged)
        WalletTheme.style(branchControl, tint: tint)

        checkIcon.contentMode = .scaleAspectFit
        checkIcon.setContentHuggingPriority(.required, for: .horizontal)
        checkIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        checkLabel.font = WalletTheme.mono(11, weight: .semibold)
        checkLabel.numberOfLines = 0
        let checkRow = UIStackView(arrangedSubviews: [checkIcon, checkLabel])
        checkRow.spacing = 8
        checkRow.alignment = .top
        checkRow.accessibilityIdentifier = "importReview.check"

        addressStack.axis = .vertical
        addressStack.spacing = 0

        moreButton.configuration = Self.chip("Show \(Self.pageSize) more", systemImage: "chevron.down", tint: tint)
        moreButton.addTarget(self, action: #selector(showMore), for: .touchUpInside)
        moreButton.isHidden = true

        let addressCard = WalletTheme.cardView([branchControl, checkRow, addressStack, moreButton], tint: tint, spacing: 12)
        stack.addArrangedSubview(addressCard)

        let hint = UILabel()
        hint.text = "Tap an address to copy it."
        hint.font = WalletTheme.mono(11)
        hint.textColor = WalletTheme.dim
        stack.addArrangedSubview(hint)

        // Pinned bottom bar: the one button that imports.
        WalletTheme.styleHero(confirmButton, title: review.confirmTitle, systemImage: "square.and.arrow.down", tint: tint)
        confirmButton.accessibilityIdentifier = "importReview.confirm"
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        confirmButton.isEnabled = false
        let bar = UIView()
        bar.backgroundColor = WalletTheme.bg
        bar.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        let rule = UIView()
        rule.backgroundColor = tint.line
        rule.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(rule)
        bar.addSubview(confirmButton)
        view.addSubview(bar)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: guide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bar.topAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),

            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            rule.topAnchor.constraint(equalTo: bar.topAnchor),
            rule.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            rule.heightAnchor.constraint(equalToConstant: 1),
            confirmButton.topAnchor.constraint(equalTo: bar.topAnchor, constant: 12),
            confirmButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            confirmButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            confirmButton.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -12)
        ])
    }

    private func summaryCard() -> UIView {
        let descriptor = Descriptor(receive)
        var rows: [UIView] = []

        let type: String
        if descriptor.isMulti {
            type = "\(descriptor.mOfNType) · \(descriptor.scriptType)"
        } else if descriptor.isTaproot {
            type = "Single sig · Taproot"
        } else if !descriptor.scriptType.isEmpty {
            type = descriptor.scriptType.prefix(1).uppercased() + descriptor.scriptType.dropFirst()
        } else {
            type = descriptor.format.isEmpty ? "Descriptor" : descriptor.format
        }
        rows.append(detailRow("Type", type))
        rows.append(detailRow("Network", Self.networkName))
        rows.append(detailRow("Keys", descriptor.isHot ? "Holds private keys (can spend)" : "Watch-only (can't spend)",
                              color: descriptor.isHot ? WalletTheme.pending : nil))
        rows.append(detailRow("Source", review.source))
        for (title, value) in review.details { rows.append(detailRow(title, value)) }

        let origins = Self.keyOrigins(receive)
        if !origins.isEmpty {
            rows.append(divider())
            for (i, origin) in origins.enumerated() {
                rows.append(detailRow(origins.count > 1 ? "Key \(i + 1)" : "Key", "\(origin.fingerprint)  \(origin.path)", mono: true))
            }
        }

        rows.append(divider())
        rows.append(checksumRow())

        descriptorLabel.font = WalletTheme.mono(12)
        descriptorLabel.textColor = WalletTheme.text
        descriptorLabel.numberOfLines = 0
        descriptorLabel.lineBreakMode = .byCharWrapping
        descriptorLabel.text = Self.masked(review.receiveDescriptor)
        descriptorLabel.isHidden = true
        descriptorLabel.isUserInteractionEnabled = true
        descriptorLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyDescriptor)))
        descriptorToggle.configuration = Self.chip("Show descriptor", systemImage: "chevron.down", tint: tint)
        descriptorToggle.addTarget(self, action: #selector(toggleDescriptor), for: .touchUpInside)
        let toggleRow = UIStackView(arrangedSubviews: [descriptorToggle, UIView()])
        rows.append(toggleRow)
        rows.append(descriptorLabel)

        return WalletTheme.cardView(rows, tint: tint, spacing: 8)
    }

    private func detailRow(_ title: String, _ value: String, color: UIColor? = nil, mono: Bool = false) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title.uppercased()
        titleLabel.font = WalletTheme.mono(10, weight: .bold)
        titleLabel.textColor = WalletTheme.dim
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.widthAnchor.constraint(equalToConstant: 72).isActive = true
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = WalletTheme.mono(mono ? 12 : 13, weight: mono ? .semibold : .regular)
        valueLabel.textColor = color ?? WalletTheme.text
        valueLabel.numberOfLines = 0
        let row = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        row.spacing = 10
        row.alignment = .firstBaseline
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(title): \(value)"
        return row
    }

    private func divider() -> UIView {
        let line = UIView()
        line.backgroundColor = tint.line.withAlphaComponent(0.4)
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    /// The checksum computed here (to compare with the other wallet's display), and a warning
    /// if the one written on the descriptor disagrees.
    private func checksumRow() -> UIView {
        guard let checksum = Descriptor.checksum(of: review.receiveDescriptor) else {
            return detailRow("Checksum", "Invalid characters in the descriptor", color: WalletTheme.danger)
        }
        if let stated = Descriptor.statedChecksum(of: review.receiveDescriptor), stated != checksum {
            return detailRow("Checksum", "#\(checksum)\nThe descriptor says #\(stated). It may have been altered or mistyped.",
                             color: WalletTheme.danger, mono: true)
        }
        return detailRow("Checksum", "#\(checksum)", mono: true)
    }

    private static var networkName: String {
        switch UserDefaults.standard.string(forKey: "chain") ?? "main" {
        case "main": return "Mainnet"
        case "test": return "Testnet3"
        case "testnet4": return "Testnet4"
        case "signet": return "Signet"
        case "regtest": return "Regtest"
        case let other: return other
        }
    }

    // MARK: - Addresses

    /// Derives addresses `loaded ..< shown` here and on the node.
    private func loadMore() {
        let from = loaded
        loaded = shown
        do {
            let derived = try WalletLogic.shared.previewAddresses(receive: receive, change: change, from: from, count: shown - from)
            local.receive += derived.receive
            local.change += derived.change
        } catch {
            localError = error.localizedDescription
        }
        renderAddresses()

        // The node derives the same range of both branches, independently.
        let range = [from, shown - 1]
        OnchainUtils.deriveAddresses(param: Derive_Addresses(["descriptor": receive, "range": range])) { [weak self] receiveAddresses, receiveError in
            OnchainUtils.deriveAddresses(param: Derive_Addresses(["descriptor": self?.change ?? "", "range": range])) { changeAddresses, changeError in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let r = receiveAddresses, let c = changeAddresses {
                        self.node.receive += r
                        self.node.change += c
                    }
                    self.updateCheck(nodeError: receiveAddresses == nil || changeAddresses == nil ? (receiveError ?? changeError ?? "no answer") : nil)
                }
            }
        }
    }

    private func updateCheck(nodeError: String?) {
        let haveLocal = localError == nil && !local.receive.isEmpty
        let haveNode = nodeError == nil && !node.receive.isEmpty && (!haveLocal || node.receive.count == local.receive.count)
        switch (haveLocal, haveNode) {
        case (true, true):
            let same = zip(local.receive + local.change, node.receive + node.change).allSatisfy { Self.sameAddress($0, $1) }
            check = same ? .matched : .mismatch
        case (true, false):
            check = .deviceOnly(nodeError ?? "no answer")
        case (false, true):
            check = .nodeOnly(localError ?? "unsupported descriptor")
        case (false, false):
            check = .failed(localError ?? nodeError ?? "unknown error")
        }
        renderCheck()
        renderAddresses()
    }

    /// Bech32(m) is case-insensitive; base58 isn't.
    private static func sameAddress(_ a: String, _ b: String) -> Bool {
        let lower = a.lowercased()
        if lower.hasPrefix("bc1") || lower.hasPrefix("tb1") || lower.hasPrefix("bcrt1") { return lower == b.lowercased() }
        return a == b
    }

    /// What's shown: this device's addresses, else (descriptors BDK can't read) the node's.
    private var displayed: [String] {
        let source = localError == nil ? local : node
        return branch == .receive ? source.receive : source.change
    }

    private func renderAddresses() {
        addressStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let addresses = displayed
        if addresses.isEmpty {
            let waiting = UILabel()
            waiting.text = "Deriving…"
            waiting.font = WalletTheme.mono(13)
            waiting.textColor = WalletTheme.dim
            addressStack.addArrangedSubview(waiting)
        }
        for (index, address) in addresses.enumerated() {
            if index > 0 { addressStack.addArrangedSubview(divider()) }
            addressStack.addArrangedSubview(addressRow(index: index, address: address))
        }
        moreButton.isHidden = addresses.isEmpty || shown >= Self.maxShown
    }

    private func addressRow(index: Int, address: String) -> UIView {
        let row = AddressRow(index: index, address: address, isChange: branch == .change, tint: tint)
        row.addTarget(self, action: #selector(copyAddress(_:)), for: .touchUpInside)
        return row
    }

    private func renderCheck() {
        let symbol: String
        let color: UIColor
        let text: String
        var canImport = true
        switch check {
        case .checking:
            symbol = "hourglass"; color = WalletTheme.dim
            text = "Derived on this device. Asking your node to derive them too…"
            canImport = false
        case .matched:
            symbol = "checkmark.seal.fill"; color = tint.accent
            text = "Derived on this device, and your node derives the same addresses."
        case .deviceOnly(let reason):
            symbol = "iphone"; color = WalletTheme.pending
            text = "Derived on this device. Your node couldn't check them (\(reason))."
        case .nodeOnly(let reason):
            symbol = "exclamationmark.triangle.fill"; color = WalletTheme.pending
            text = "Derived by your node only: this device can't read this descriptor (\(reason)). Check them carefully."
        case .mismatch:
            symbol = "xmark.octagon.fill"; color = WalletTheme.danger
            text = "Your node derives DIFFERENT addresses from this device. Don't import this wallet until you know why."
            canImport = false
        case .failed(let reason):
            symbol = "xmark.octagon.fill"; color = WalletTheme.danger
            text = "Couldn't derive any addresses: \(reason)"
            canImport = false
        }
        checkIcon.image = UIImage(systemName: symbol)
        checkIcon.tintColor = color
        checkLabel.text = text
        checkLabel.textColor = color
        confirmButton.isEnabled = canImport
    }

    private static func chip(_ title: String, systemImage: String, tint: WalletTheme.Tint) -> UIButton.Configuration {
        WalletTheme.chipConfiguration(title: title, systemImage: systemImage, tint: tint, fontSize: 12, imageSize: 11,
                                      imagePadding: 6, insets: NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
    }

    // MARK: - Actions

    @objc private func branchChanged() {
        branch = Branch(rawValue: branchControl.selectedSegmentIndex) ?? .receive
        renderAddresses()
    }

    @objc private func showMore() {
        shown = min(shown + Self.pageSize, Self.maxShown)
        check = .checking
        renderCheck()
        loadMore()
    }

    @objc private func copyAddress(_ sender: AddressRow) {
        UIPasteboard.general.string = sender.address
        SuccessView.toast("Address #\(sender.index) copied", in: self)
    }

    @objc private func toggleDescriptor() {
        descriptorRevealed.toggle()
        descriptorLabel.isHidden = !descriptorRevealed
        descriptorToggle.configuration = Self.chip(descriptorRevealed ? "Hide descriptor" : "Show descriptor",
                                                                       systemImage: descriptorRevealed ? "chevron.up" : "chevron.down",
                                                                       tint: tint)
    }

    @objc private func copyDescriptor() {
        // Never a private key: what's copied is what's shown.
        UIPasteboard.general.string = descriptorLabel.text
        SuccessView.toast("Descriptor copied", in: self)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true) { [onCancel] in onCancel?() }
    }

    @objc private func confirmTapped() {
        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? (review.label ?? "") : name
        dismiss(animated: true) { [onConfirm] in onConfirm?(label) }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
}

/// One address, whole: "#3" then every character, in groups of four that wrap (never cut
/// off), alternating colours so groups are easy to compare. Tap to copy.
private final class AddressRow: UIControl {
    let index: Int
    let address: String

    init(index: Int, address: String, isChange: Bool, tint: WalletTheme.Tint) {
        self.index = index
        self.address = address
        super.init(frame: .zero)

        let indexLabel = UILabel()
        indexLabel.text = "#\(index)"
        indexLabel.font = WalletTheme.mono(12, weight: .bold)
        indexLabel.textColor = WalletTheme.dim
        indexLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true

        let addressLabel = UILabel()
        addressLabel.attributedText = Self.grouped(address, tint: tint)
        addressLabel.numberOfLines = 0
        addressLabel.lineBreakMode = .byWordWrapping
        addressLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        let copy = UIImageView(image: UIImage(systemName: "doc.on.doc"))
        copy.tintColor = tint.accent.withAlphaComponent(0.7)
        copy.contentMode = .scaleAspectFit
        copy.widthAnchor.constraint(equalToConstant: 16).isActive = true

        let row = UIStackView(arrangedSubviews: [indexLabel, addressLabel, copy])
        row.spacing = 10
        row.alignment = .firstBaseline
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "\(isChange ? "Change" : "Receive") address \(index): \(address)"
        accessibilityHint = "Copies the address"
        accessibilityIdentifier = "importReview.address.\(index)"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? UIColor.white.withAlphaComponent(0.06) : .clear }
    }

    static func grouped(_ address: String, tint: WalletTheme.Tint) -> NSAttributedString {
        let font = WalletTheme.mono(15, weight: .medium)
        let text = NSMutableAttributedString()
        var start = address.startIndex
        var group = 0
        while start < address.endIndex {
            let end = address.index(start, offsetBy: 4, limitedBy: address.endIndex) ?? address.endIndex
            if group > 0 { text.append(NSAttributedString(string: " ", attributes: [.font: font])) }
            text.append(NSAttributedString(string: String(address[start..<end]), attributes: [
                .font: font,
                .foregroundColor: group % 2 == 0 ? WalletTheme.text : tint.accent
            ]))
            start = end
            group += 1
        }
        return text
    }
}
