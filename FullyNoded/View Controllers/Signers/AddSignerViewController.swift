//
//  AddSignerViewController.swift
//  BitSense
//
//  Created by Peter on 05/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

/// Add Signer, built in code: pick 12 or 24 words, enter them one at a time (BIP39
/// suggestions as you type), paste a whole phrase, or generate one. For the final word it
/// lists every word with a valid checksum (Keys.checksumWords), so a phrase made from
/// dice / your own entropy can be completed here. Saves the encrypted words as a signer.
class AddSignerViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {

    private var wordCount = 12
    private var words: [String] = []
    /// A filled slot being replaced (tap a word to fix it), else the next empty slot is filled.
    private var editingIndex: Int?
    private let bip39 = Words.valid
    private lazy var bip39Set = Set(bip39)
    /// Valid final words for the current first 11 / 23 words.
    private var checksumCandidates: [String] = []

    private let tint = WalletTheme.Tint.signer
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let lengthControl = UISegmentedControl(items: ["12 words", "24 words"])
    private let progressLabel = UILabel()
    private let grid = UIStackView()
    private let wordField = UITextField()
    private let suggestionRow = UIStackView()
    private var checksumContainer = UIView()
    private let checksumTitle = UILabel()
    private let checksumFlow = FlowView()
    private let statusLabel = UILabel()
    private let labelField = UITextField()
    private let saveButton = UIButton(type: .system)

    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        hidesBottomBarWhenPushed = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add Signer"
        navigationController?.delegate = self
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "questionmark.circle"), style: .plain,
                                                            target: self, action: #selector(showHelp))
        buildLayout()
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        WalletTheme.apply(to: self, tint: tint)
        render()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isMovingFromParent else { return }
        wipe()
    }

    // MARK: - Layout

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        // LENGTH
        lengthControl.selectedSegmentIndex = 0
        lengthControl.addTarget(self, action: #selector(lengthChanged), for: .valueChanged)
        WalletTheme.style(lengthControl, tint: tint)
        stack.addArrangedSubview(WalletTheme.cardView([
            WalletTheme.caption("> LENGTH", tint: tint),
            lengthControl,
            hint("12 words are easier to back up, 24 words have more entropy. Both are secure.")
        ], tint: tint, spacing: 8))

        // RECOVERY PHRASE
        progressLabel.font = WalletTheme.mono(11, weight: .semibold)
        progressLabel.textColor = WalletTheme.dim
        let header = UIStackView(arrangedSubviews: [WalletTheme.caption("> RECOVERY PHRASE", tint: tint), UIView(), progressLabel])
        grid.axis = .vertical
        grid.spacing = 6

        wordField.delegate = self
        wordField.autocapitalizationType = .none
        wordField.autocorrectionType = .no
        wordField.spellCheckingType = .no
        wordField.smartQuotesType = .no
        wordField.smartDashesType = .no
        wordField.keyboardType = .asciiCapable
        wordField.returnKeyType = .next
        wordField.clearButtonMode = .whileEditing
        wordField.font = WalletTheme.mono(15)
        wordField.heightAnchor.constraint(greaterThanOrEqualToConstant: 42).isActive = true
        wordField.addTarget(self, action: #selector(wordFieldChanged), for: .editingChanged)
        WalletTheme.styleField(wordField, tint: tint)

        suggestionRow.axis = .horizontal
        suggestionRow.spacing = 6
        let suggestionScroll = UIScrollView()
        suggestionScroll.showsHorizontalScrollIndicator = false
        suggestionScroll.addSubview(suggestionRow)
        suggestionRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            suggestionRow.topAnchor.constraint(equalTo: suggestionScroll.contentLayoutGuide.topAnchor),
            suggestionRow.bottomAnchor.constraint(equalTo: suggestionScroll.contentLayoutGuide.bottomAnchor),
            suggestionRow.leadingAnchor.constraint(equalTo: suggestionScroll.contentLayoutGuide.leadingAnchor),
            suggestionRow.trailingAnchor.constraint(equalTo: suggestionScroll.contentLayoutGuide.trailingAnchor),
            suggestionRow.heightAnchor.constraint(equalTo: suggestionScroll.frameLayoutGuide.heightAnchor),
            suggestionScroll.heightAnchor.constraint(equalToConstant: 34)
        ])

        stack.addArrangedSubview(WalletTheme.cardView([
            header, grid, wordField, suggestionScroll,
            buttonRow([
                chip("Paste", "doc.on.clipboard", #selector(pastePhrase)),
                chip("Generate", "dice", #selector(generate)),
                chip("Clear", "xmark", #selector(clearAll))
            ])
        ], tint: tint, spacing: 10))

        // FINAL WORD (checksum)
        checksumTitle.font = WalletTheme.mono(12)
        checksumTitle.textColor = WalletTheme.text
        checksumTitle.numberOfLines = 0
        checksumContainer = WalletTheme.cardView([
            WalletTheme.caption("> FINAL WORD · CHECKSUM", tint: tint),
            checksumTitle,
            checksumFlow,
            buttonRow([chip("Pick one at random", "shuffle", #selector(pickRandomChecksum))]),
            hint("The last word carries a checksum, so only these words complete your phrase. Picking at random is only safe if your other words came from a random source, such as dice.")
        ], tint: tint, spacing: 8)
        stack.addArrangedSubview(checksumContainer)

        // STATUS
        statusLabel.font = WalletTheme.mono(12, weight: .semibold)
        statusLabel.numberOfLines = 0
        stack.addArrangedSubview(statusLabel)

        // LABEL
        labelField.placeholder = "Optional · defaults to the fingerprint"
        labelField.autocorrectionType = .no
        labelField.font = WalletTheme.mono(14)
        labelField.returnKeyType = .done
        labelField.delegate = self
        labelField.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        WalletTheme.styleField(labelField, tint: tint)
        stack.addArrangedSubview(WalletTheme.cardView([WalletTheme.caption("> LABEL", tint: tint), labelField], tint: tint, spacing: 8))

        WalletTheme.styleHero(saveButton, title: "Save Signer", systemImage: "lock.fill", tint: tint)
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        stack.setCustomSpacing(20, after: stack.arrangedSubviews.last ?? stack)
        stack.addArrangedSubview(saveButton)
    }

    private func hint(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = WalletTheme.mono(11)
        label.textColor = WalletTheme.dim
        label.numberOfLines = 0
        return label
    }

    private func buttonRow(_ buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        return row
    }

    private func chip(_ title: String, _ image: String?, _ action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = WalletTheme.chipConfiguration(title: title, systemImage: image, tint: tint, fontSize: 12,
                                                             imageSize: 11, imagePadding: 5,
                                                             insets: NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8),
                                                             clipsTitle: true)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    /// A word chip (suggestion / checksum candidate): tapping it fills the current slot.
    private func wordChip(_ word: String) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = WalletTheme.chipConfiguration(title: word, systemImage: nil, tint: tint, fontSize: 13,
                                                             imageSize: 0, imagePadding: 0,
                                                             insets: NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        button.addAction(UIAction { [weak self] _ in self?.enter(word) }, for: .touchUpInside)
        button.accessibilityLabel = "Use \(word)"
        return button
    }

    // MARK: - Rendering

    /// Index of the slot the field fills: the word being fixed, else the next empty one.
    private var currentIndex: Int? {
        if let editingIndex { return editingIndex }
        return words.count < wordCount ? words.count : nil
    }

    private var isComplete: Bool { words.count == wordCount }
    private var isFinalSlot: Bool { currentIndex == wordCount - 1 }
    private var phrase: String { words.joined(separator: " ") }

    private func render() {
        lengthControl.selectedSegmentIndex = wordCount == 12 ? 0 : 1
        progressLabel.text = "\(words.count) / \(wordCount)"

        // The final word's candidates depend on all the others.
        checksumCandidates = words.count >= wordCount - 1 ? Keys.checksumWords(for: Array(words.prefix(wordCount - 1))) : []

        renderGrid()

        if let index = currentIndex {
            wordField.isEnabled = true
            wordField.placeholder = editingIndex == nil ? "word #\(index + 1)" : "replace word #\(index + 1)"
        } else {
            wordField.isEnabled = false
            wordField.placeholder = "all \(wordCount) words added"
        }
        renderSuggestions()
        renderChecksum()
        renderStatus()
    }

    private func renderGrid() {
        grid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let columns = 3
        for rowStart in stride(from: 0, to: wordCount, by: columns) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 6
            row.distribution = .fillEqually
            for i in rowStart..<min(rowStart + columns, wordCount) {
                row.addArrangedSubview(slot(i))
            }
            grid.addArrangedSubview(row)
        }
    }

    private func slot(_ i: Int) -> UIButton {
        let filled = i < words.count
        let current = i == currentIndex
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 6, bottom: 7, trailing: 6)
        let number = AttributedString(String(format: "%02d ", i + 1), attributes: AttributeContainer([
            .font: WalletTheme.mono(10), .foregroundColor: WalletTheme.dim]))
        let word = AttributedString(filled ? words[i] : "·····", attributes: AttributeContainer([
            .font: WalletTheme.mono(13, weight: filled ? .semibold : .regular),
            .foregroundColor: filled ? WalletTheme.text : WalletTheme.dim.withAlphaComponent(0.5)]))
        config.attributedTitle = number + word
        config.titleLineBreakMode = .byTruncatingTail
        config.background.backgroundColor = current ? tint.accent.withAlphaComponent(0.12) : WalletTheme.bg
        config.background.strokeColor = current ? tint.accent : WalletTheme.line.withAlphaComponent(filled ? 0.8 : 0.3)
        config.background.strokeWidth = 1
        config.background.cornerRadius = WalletTheme.radius

        let button = UIButton(configuration: config)
        button.contentHorizontalAlignment = .leading
        button.isEnabled = filled || current
        button.accessibilityLabel = filled ? "Word \(i + 1), \(words[i])" : "Word \(i + 1), empty"
        button.accessibilityHint = filled ? "Replace this word" : nil
        button.addAction(UIAction { [weak self] _ in self?.selectSlot(i) }, for: .touchUpInside)
        return button
    }

    private func renderSuggestions() {
        suggestionRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let typed = wordField.text?.lowercased().trimmingCharacters(in: .whitespaces) ?? ""
        let matches = suggestions(for: typed)
        wordField.textColor = !typed.isEmpty && matches.isEmpty ? WalletTheme.danger : WalletTheme.text
        matches.prefix(10).forEach { suggestionRow.addArrangedSubview(wordChip($0)) }
    }

    /// BIP39 words starting with `typed`; for the final slot only those with a valid checksum.
    private func suggestions(for typed: String) -> [String] {
        guard !typed.isEmpty else { return [] }
        let pool = isFinalSlot && !checksumCandidates.isEmpty ? checksumCandidates : bip39
        return pool.filter { $0.hasPrefix(typed) }
    }

    private func renderChecksum() {
        let show = isFinalSlot && !checksumCandidates.isEmpty
        checksumContainer.isHidden = !show
        guard show else { return }
        checksumTitle.text = "Only \(checksumCandidates.count) of the 2048 words give a valid word #\(wordCount). Tap one, or type to narrow them down."
        checksumFlow.setViews(checksumCandidates.map(wordChip))
    }

    private func renderStatus() {
        saveButton.isEnabled = false
        saveButton.alpha = 0.4
        guard isComplete else {
            let left = wordCount - words.count
            statusLabel.text = words.isEmpty
                ? "Enter your words, paste a phrase, or generate a new one."
                : "\(left) more word\(left == 1 ? "" : "s") to go."
            statusLabel.textColor = WalletTheme.dim
            return
        }
        guard Keys.validMnemonic(phrase),
              var mk = Keys.masterKey(words: phrase, coinType: "0", passphrase: ""),
              let fingerprint = Keys.fingerprint(masterKey: mk) else {
            statusLabel.text = "✗ The checksum doesn't match, so one of the words is wrong (often the last one). Tap a word to fix it."
            statusLabel.textColor = WalletTheme.danger
            return
        }
        mk.secureWipe()
        statusLabel.text = "✓ Valid BIP39 phrase · fingerprint \(fingerprint)"
        statusLabel.textColor = tint.accent
        labelField.placeholder = "Optional · defaults to \(fingerprint)"
        saveButton.isEnabled = true
        saveButton.alpha = 1
    }

    // MARK: - Input

    @objc private func wordFieldChanged() {
        var text = (wordField.text ?? "").lowercased()
        defer { text.secureWipe() }
        // A pasted / typed phrase: take all of it.
        if text.split(whereSeparator: { $0.isWhitespace }).count > 1 {
            wordField.text = ""
            takePhrase(text)
            return
        }
        let typed = text.trimmingCharacters(in: .whitespaces)
        // A complete word that no other word extends ("abandon", not "act" → "action"):
        // take it straight away.
        let matches = suggestions(for: typed)
        if matches.count == 1, matches[0] == typed {
            enter(typed)
        } else {
            renderSuggestions()
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField == wordField else { return true }
        // Letters and spaces only.
        return string.allSatisfy { $0.isLetter || $0.isWhitespace }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard textField == wordField else {
            textField.resignFirstResponder()
            return true
        }
        let typed = (wordField.text ?? "").lowercased().trimmingCharacters(in: .whitespaces)
        let matches = suggestions(for: typed)
        if matches.contains(typed) {
            enter(typed)
        } else if matches.count == 1 {
            enter(matches[0])
        } else {
            shake(wordField)
        }
        return false
    }

    /// Puts `word` in the current slot and moves on.
    private func enter(_ word: String) {
        guard bip39Set.contains(word), let index = currentIndex else { return }
        if index < words.count {
            words[index] = word
        } else {
            words.append(word)
        }
        editingIndex = nil
        wordField.text = ""
        impact()
        render()
        if isComplete {
            wordField.resignFirstResponder()
        } else {
            wordField.becomeFirstResponder()
        }
    }

    private func selectSlot(_ i: Int) {
        guard i < words.count else {
            wordField.becomeFirstResponder()
            return
        }
        editingIndex = editingIndex == i ? nil : i
        wordField.text = ""
        render()
        if editingIndex != nil { wordField.becomeFirstResponder() }
    }

    /// A whole phrase (paste, or several words typed at once): every word must be BIP39.
    private func takePhrase(_ text: String) {
        let parsed = text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        let invalid = parsed.enumerated().filter { !bip39Set.contains($0.element) }
        guard invalid.isEmpty else {
            let positions = invalid.prefix(3).map { "#\($0.offset + 1) \"\($0.element)\"" }.joined(separator: ", ")
            showAlert(vc: self, title: "Not BIP39 words", message: "These aren't in the BIP39 word list: \(positions). Check them, or enter the words one at a time.")
            return
        }
        guard parsed.count <= 24 else {
            showAlert(vc: self, title: "Too many words", message: "A recovery phrase here has 12 or 24 words; that was \(parsed.count).")
            return
        }
        if parsed.count > 12 { wordCount = 24 } else if parsed.count == 12 { wordCount = 12 }
        words = parsed
        editingIndex = nil
        render()
    }

    @objc private func pastePhrase() {
        guard var text = UIPasteboard.general.string, !text.isEmpty else {
            showAlert(vc: self, title: "", message: "The clipboard is empty.")
            return
        }
        takePhrase(text)
        text.secureWipe()
    }

    @objc private func generate() {
        let replace = { [weak self] in
            guard let self, var seed = Keys.seedWords(wordCount: self.wordCount) else { return }
            self.words = seed.components(separatedBy: " ")
            seed.secureWipe()
            self.editingIndex = nil
            self.render()
            showAlert(vc: self, title: "New recovery phrase", message: "Write these \(self.wordCount) words down in order and keep them offline. They're the only way to recover this signer.")
        }
        guard !words.isEmpty else {
            replace()
            return
        }
        let alert = UIAlertController(title: "Replace your words?", message: "This replaces the words entered so far with a new random phrase.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Replace", style: .destructive) { _ in replace() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func pickRandomChecksum() {
        guard !checksumCandidates.isEmpty else { return }
        var random: UInt32 = 0
        guard SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt32>.size, &random) == errSecSuccess else { return }
        // 8 and 128 divide 2^32, so the modulo is unbiased.
        enter(checksumCandidates[Int(random % UInt32(checksumCandidates.count))])
    }

    @objc private func clearAll() {
        wipe()
        render()
    }

    @objc private func lengthChanged() {
        let newCount = lengthControl.selectedSegmentIndex == 0 ? 12 : 24
        guard words.count <= newCount else {
            lengthControl.selectedSegmentIndex = wordCount == 12 ? 0 : 1
            showAlert(vc: self, title: "", message: "You've entered \(words.count) words. Clear some first to switch to 12 words.")
            return
        }
        wordCount = newCount
        editingIndex = nil
        render()
    }

    private func shake(_ view: UIView) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [-8, 8, -6, 6, -3, 3, 0]
        animation.duration = 0.35
        view.layer.add(animation, forKey: "shake")
    }

    @objc private func showHelp() {
        showAlert(vc: self, title: "Adding a signer",
                  message: "A signer is a BIP39 recovery phrase that Fully Noded encrypts and keeps on this device to sign your transactions.\n\nType each word (suggestions appear as you type), paste the whole phrase, or generate a new one. Tap a word to fix it.\n\nFor the last word Fully Noded shows every word with a valid checksum, which lets you finish a phrase you made yourself, e.g. with dice.")
    }

    // MARK: - Save

    @objc private func save() {
        var words = phrase
        var mnemonicData = words.dataUsingUTF8StringEncoding
        defer {
            words.secureWipe()
            mnemonicData.secureZero()
        }

        guard Keys.validMnemonic(words), var mk = Keys.masterKey(words: words, coinType: "0", passphrase: ""),
              let fingerprint = Keys.fingerprint(masterKey: mk) else {
            showAlert(vc: self, title: "Error", message: "That isn't a valid recovery phrase.")
            return
        }
        mk.secureWipe()

        guard var encryptedWords = Crypto.encrypt(mnemonicData) else {
            showAlert(vc: self, title: "Error", message: "Error encrypting your seed.")
            return
        }
        defer { encryptedWords.secureZero() }

        let label = labelField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var dict = ["id": UUID(), "words": encryptedWords, "added": Date(), "label": label.isEmpty ? fingerprint : label] as [String: Any]
        if let encryptedXfp = Crypto.encrypt(fingerprint.utf8) { dict["xfp"] = encryptedXfp }

        saveButton.isEnabled = false
        CoreDataService.saveEntity(dict: dict, entityName: .signers) { [weak self] success in
            DispatchQueue.main.async {
                guard let self else { return }
                guard success else {
                    self.saveButton.isEnabled = true
                    showAlert(vc: self, title: "Error", message: "Error saving the encrypted seed.")
                    return
                }
                self.wipe()
                SuccessView.show(in: self, title: "Signer saved", subtitle: "Encrypted and stored on this device.", onDismiss: { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                })
            }
        }
    }

    private func wipe() {
        for i in words.indices { words[i].secureWipe() }
        words.removeAll()
        checksumCandidates.removeAll()
        editingIndex = nil
        wordField.text = ""
        labelField.text = ""
    }
}

/// Lays its subviews out left to right, wrapping onto new rows (word chips).
private final class FlowView: UIView {
    private let spacing: CGFloat = 6

    func setViews(_ views: [UIView]) {
        subviews.forEach { $0.removeFromSuperview() }
        views.forEach(addSubview)
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = layout(width: bounds.width, apply: true)
        if abs(height - intrinsicContentSize.height) > 0.5 { invalidateIntrinsicContentSize() }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: layout(width: bounds.width > 0 ? bounds.width : 300, apply: false))
    }

    /// Positions the subviews (when `apply`) and returns the height they need.
    private func layout(width: CGFloat, apply: Bool) -> CGFloat {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            if apply { view.frame = CGRect(x: x, y: y, width: min(size.width, width), height: size.height) }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return subviews.isEmpty ? 0 : y + rowHeight
    }
}
