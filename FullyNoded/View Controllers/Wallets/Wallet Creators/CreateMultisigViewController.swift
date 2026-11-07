//
//  CreateMultisigViewController.swift
//  FullyNoded
//
//  Created by Peter on 8/29/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

/// Multisig creator, built in code: pick the script type, add each cosigner's key (from a
/// signer on this phone, a new key, a QR, the clipboard or by hand), choose how many
/// signatures are needed, create. Then export the wallet file for the other cosigners.
class CreateMultisigViewController: UIViewController {
    // Pushed full height, without the tab bar.
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }

    /// One cosigner's account key.
    private struct Cosigner {
        let fingerprint: String
        let xpub: String
        /// Where it came from, e.g. "This phone · My signer", "Scanned", "Pasted".
        let source: String
    }

    private var isNested = false
    var blockheight = 0
    var cosigner: Descriptor?
    var isTaproot = false
    private var cosigners = [Cosigner]()
    private var threshold = 0
    /// True once the user picks the threshold, so adding a key no longer moves it.
    private var thresholdPicked = false
    private var derivationPath = ""
    private var isDone = false
    private var walletText = ""
    private var qrToExport = ""
    /// Source label for keys arriving from the scanner / clipboard.
    private var pendingSource = "Imported"
    /// Signer picked in Signers, derived once this screen is visible again.
    private var pendingSigner: SignerStruct?
    let jsonDecoder = JSONDecoder()

    private let tint = WalletTheme.Tint.create
    private let scrollView = UIScrollView()
    private let masterStackView = UIStackView()
    private let scriptControl = UISegmentedControl(items: ["Segwit", "Taproot"])
    private let pathLabel = UILabel()
    private let pathButton = UIButton(type: .system)
    private let scriptHint = UILabel()
    private let cosignersCaption = UILabel()
    private let cosignerList = UIStackView()
    private let thresholdLabel = UILabel()
    private let thresholdHint = UILabel()
    private let minusButton = UIButton(type: .system)
    private let plusButton = UIButton(type: .system)
    private let createButton = UIButton(type: .system)

    var coinType: String {
        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        switch chain {
        case "main":
            return "0"
        default:
            return "1"
        }
    }

    private var defaultPath: String {
        "m/48h/\(coinType)h/0h/\(isTaproot ? "3" : isNested ? "1" : "2")h"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Create Multisig"
        if navigationController?.viewControllers.first == self {
            // Presented on its own (from a deep link): give it a way out.
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(doneAction))
        }
        WalletTheme.apply(to: self, tint: tint)
        derivationPath = defaultPath
        setupUI()

        if let cosigner = cosigner {
            isTaproot = cosigner.isP2TR
            derivationPath = cosigner.derivation
            addKeyStore(cosigner.fingerprint,
                        cosigner.accountXpub == "" ? cosigner.accountXprv : cosigner.accountXpub,
                        source: "This phone")
        }

        refresh()
    }

    // MARK: - Layout

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        masterStackView.axis = .vertical
        masterStackView.spacing = 12
        masterStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(masterStackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            masterStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            masterStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            masterStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            masterStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            masterStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        // 1. SCRIPT
        WalletTheme.style(scriptControl, tint: tint)
        scriptControl.addTarget(self, action: #selector(scriptChanged(_:)), for: .valueChanged)
        scriptControl.accessibilityIdentifier = "msig.script"
        pathLabel.font = WalletTheme.mono(12)
        pathLabel.textColor = WalletTheme.text
        pathButton.configuration = chip("Edit", systemImage: "pencil")
        pathButton.addTarget(self, action: #selector(editPath), for: .touchUpInside)
        pathButton.setContentHuggingPriority(.required, for: .horizontal)
        let pathRow = UIStackView(arrangedSubviews: [pathLabel, pathButton])
        pathRow.spacing = 8
        pathRow.alignment = .center
        prepareHint(scriptHint)
        masterStackView.addArrangedSubview(WalletTheme.cardView([
            WalletTheme.caption("> 1. SCRIPT", tint: tint),
            scriptControl,
            pathRow,
            scriptHint
        ], tint: tint, spacing: 8))

        // 2. COSIGNERS
        cosignersCaption.font = WalletTheme.mono(11, weight: .bold)
        cosignersCaption.textColor = tint.accent
        cosignerList.axis = .vertical
        cosignerList.spacing = 8
        let addRow1 = buttonRow([
            makeButton("This phone", systemImage: "iphone", id: "msig.addSigner", action: #selector(addFromSigner)),
            makeButton("New key", systemImage: "plus.circle", id: "msig.newKey", action: #selector(addNewKey))
        ])
        let addRow2 = buttonRow([
            makeButton("Scan", systemImage: "qrcode.viewfinder", id: "msig.scan", action: #selector(scanAction)),
            makeButton("Paste", systemImage: "doc.on.clipboard", id: "msig.paste", action: #selector(pasteAction)),
            makeButton("Type", systemImage: "keyboard", id: "msig.type", action: #selector(typeAction))
        ])
        masterStackView.addArrangedSubview(WalletTheme.cardView([
            cosignersCaption,
            cosignerList,
            hint("Add a key for every cosigner: a signer on this phone, a hardware wallet (scan or paste its multisig export), or another person's xpub."),
            addRow1,
            addRow2
        ], tint: tint, spacing: 8))

        // 3. SIGNATURES REQUIRED
        thresholdLabel.font = WalletTheme.mono(22, weight: .bold)
        thresholdLabel.textColor = WalletTheme.text
        thresholdLabel.textAlignment = .center
        thresholdLabel.accessibilityIdentifier = "msig.threshold"
        minusButton.configuration = chip("", systemImage: "minus")
        plusButton.configuration = chip("", systemImage: "plus")
        minusButton.accessibilityLabel = "Fewer signatures"
        plusButton.accessibilityLabel = "More signatures"
        minusButton.addTarget(self, action: #selector(lowerThreshold), for: .touchUpInside)
        plusButton.addTarget(self, action: #selector(raiseThreshold), for: .touchUpInside)
        for button in [minusButton, plusButton] {
            button.widthAnchor.constraint(equalToConstant: 48).isActive = true
        }
        let stepper = UIStackView(arrangedSubviews: [minusButton, thresholdLabel, plusButton])
        stepper.alignment = .center
        stepper.spacing = 8
        prepareHint(thresholdHint)
        masterStackView.addArrangedSubview(WalletTheme.cardView([
            WalletTheme.caption("> 3. SIGNATURES REQUIRED", tint: tint),
            stepper,
            thresholdHint
        ], tint: tint, spacing: 8))

        createButton.addTarget(self, action: #selector(createAction), for: .touchUpInside)
        createButton.accessibilityIdentifier = "msig.create"
        masterStackView.setCustomSpacing(20, after: masterStackView.arrangedSubviews.last ?? masterStackView)
        masterStackView.addArrangedSubview(createButton)
    }

    /// Redraws everything from the current state.
    private func refresh() {
        let n = cosigners.count
        let locked = n > 0

        scriptControl.selectedSegmentIndex = isTaproot ? 1 : 0
        scriptControl.isEnabled = !locked
        pathButton.isEnabled = !locked
        pathLabel.text = "Path  " + derivationPath
        if locked {
            scriptHint.text = "Remove all cosigners to change the script or path."
        } else if isTaproot {
            scriptHint.text = "Taproot (multi_a). Smaller, more private spends. Every cosigner's wallet must support Taproot multisig."
        } else {
            scriptHint.text = isNested
                ? "Nested Segwit (sh-wsh), for older wallets."
                : "Segwit (wsh sortedmulti). Works with almost every hardware wallet."
        }

        cosignersCaption.text = "> 2. COSIGNERS (\(n))"
        cosignerList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if n == 0 {
            let empty = UILabel()
            empty.text = "No cosigners yet."
            empty.font = WalletTheme.mono(13)
            empty.textColor = WalletTheme.dim
            cosignerList.addArrangedSubview(empty)
        } else {
            for (i, cosigner) in cosigners.enumerated() {
                cosignerList.addArrangedSubview(cosignerRow(cosigner, index: i))
            }
        }

        // A majority by default (2 of 3, 3 of 5), until the user picks.
        if !thresholdPicked { threshold = n / 2 + 1 }
        threshold = max(1, min(threshold, max(n, 1)))
        let ready = n > 1
        thresholdLabel.text = ready ? "\(threshold) of \(n)" : "– of \(n)"
        minusButton.isEnabled = ready && threshold > 1
        plusButton.isEnabled = ready && threshold < n
        if !ready {
            thresholdHint.text = "Add at least 2 cosigners."
            thresholdHint.textColor = WalletTheme.dim
        } else if threshold == n {
            thresholdHint.text = "Every key must sign. Lose any one key and the funds are stuck."
            thresholdHint.textColor = WalletTheme.pending
        } else if threshold == 1 {
            thresholdHint.text = "Any one key can spend on its own: a single stolen key is enough to take the funds."
            thresholdHint.textColor = WalletTheme.pending
        } else {
            thresholdHint.text = "Any \(threshold) of the \(n) keys can spend. You can lose \(n - threshold) and still recover."
            thresholdHint.textColor = WalletTheme.dim
        }

        WalletTheme.styleHero(createButton,
                              title: ready ? "Create \(threshold)-of-\(n) wallet" : "Create wallet",
                              systemImage: "checkmark",
                              tint: tint)
        createButton.isEnabled = ready
    }

    private func cosignerRow(_ cosigner: Cosigner, index: Int) -> UIView {
        let title = UILabel()
        title.text = "#\(index + 1)  \(cosigner.fingerprint)"
        title.font = WalletTheme.mono(13, weight: .bold)
        title.textColor = WalletTheme.text
        
        let source = UILabel()
        source.text = cosigner.source
        source.font = WalletTheme.mono(11)
        source.textColor = tint.accent
        
        let key = UILabel()
        key.text = cosigner.xpub
        key.font = WalletTheme.mono(11)
        key.textColor = WalletTheme.dim
        key.lineBreakMode = .byTruncatingMiddle
        
        let text = UIStackView(arrangedSubviews: [title, source, key])
        text.axis = .vertical
        text.spacing = 2
        
        let remove = WalletTheme.iconButton("xmark.circle", target: self, action: #selector(removeCosigner(_:)), tint: .danger)
        remove.tag = index
        remove.accessibilityLabel = "Remove cosigner \(index + 1)"
        
        let row = UIStackView(arrangedSubviews: [text, remove])
        row.spacing = 10
        row.alignment = .center
        return WalletTheme.cardView([row], tint: tint, spacing: 0, background: WalletTheme.bg)
    }
    
    private func prepareHint(_ label: UILabel) {
        label.font = WalletTheme.mono(11)
        label.textColor = WalletTheme.dim
        label.numberOfLines = 0
    }

    private func hint(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        prepareHint(label)
        return label
    }

    private func buttonRow(_ buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.spacing = 8
        row.distribution = .fillEqually
        return row
    }

    private func makeButton(_ title: String, systemImage: String, id: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = chip(title, systemImage: systemImage)
        button.accessibilityIdentifier = id
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func chip(_ title: String, systemImage: String) -> UIButton.Configuration {
        WalletTheme.chipConfiguration(title: title,
                                      systemImage: systemImage,
                                      tint: tint,
                                      fontSize: 12,
                                      imageSize: 11,
                                      imagePadding: 5,
                                      insets: NSDirectionalEdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8),
                                      clipsTitle: true)
    }

    // MARK: - Script and path

    @objc private func scriptChanged(_ sender: UISegmentedControl) {
        isTaproot = sender.selectedSegmentIndex == 1
        isNested = false
        derivationPath = defaultPath
        refresh()
    }

    @objc private func editPath() {
        let alert = UIAlertController(title: "Derivation path",
                                      message: "Every cosigner's key must come from this path. Keep the default unless your hardware wallets use another one.",
                                      preferredStyle: .alert)
        alert.addTextField { [weak self] field in
            field.text = self?.derivationPath
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.keyboardAppearance = .dark
        }
        alert.addAction(UIAlertAction(title: "Default", style: .default) { [weak self] _ in
            guard let self = self else { return }
            derivationPath = defaultPath
            refresh()
        })
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self = self else { return }
            let path = (alert?.textFields?.first?.text ?? "").replacingOccurrences(of: "’", with: "'")
                .trimmingCharacters(in: .whitespaces)
            guard Keys.validPath(path) else {
                showAlert(vc: self, title: "Invalid path", message: "Use a BIP32 path that starts with m/, e.g. \(defaultPath).")
                return
            }
            derivationPath = path
            refresh()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private var isStandardPath: Bool {
        let path = derivationPath.replacingOccurrences(of: "'", with: "h").replacingOccurrences(of: "’", with: "h")
        return path == "m/48h/\(coinType)h/0h/2h" || path == "m/48h/\(coinType)h/0h/3h"
    }

    // MARK: - Threshold

    @objc private func lowerThreshold() {
        thresholdPicked = true
        threshold -= 1
        refresh()
    }

    @objc private func raiseThreshold() {
        thresholdPicked = true
        threshold += 1
        refresh()
    }

    // MARK: - Adding cosigners

    @objc private func addFromSigner() {
        guard isStandardPath else {
            showAlert(vc: self, title: "Custom path", message: "Keys from this phone's signers use the standard path. Tap Edit → Default first.")
            return
        }
        showSignerPicker()
    }

    /// Makes a new 12 word signer on this phone and adds its cosigner key. The words are
    /// shown once, so the user can write them down.
    @objc private func addNewKey() {
        guard isStandardPath else {
            showAlert(vc: self, title: "Custom path", message: "New keys use the standard path. Tap Edit → Default first.")
            return
        }
        let alert = UIAlertController(title: "Create a new key on this phone?",
                                      message: "Fully Noded makes a new 12 word signer, saves it in Signers and adds its key here. You'll need to write the words down.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Create key", style: .default) { [weak self] _ in
            self?.createNewSigner()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func createNewSigner() {
        guard let words = Keys.seedWords(wordCount: 12),
              let encryptedWords = Crypto.encrypt(words.utf8),
              let mk = Keys.masterKey(words: words, coinType: coinType, passphrase: ""),
              let xfp = Keys.fingerprint(masterKey: mk),
              let xpub = Keys.xpub(path: derivationPath, masterKey: mk) else {
            showAlert(vc: self, title: "", message: "Unable to create a new key.")
            return
        }

        var dict = ["id": UUID(), "words": encryptedWords, "added": Date(), "label": "Multisig cosigner"] as [String: Any]
        if let encryptedXfp = Crypto.encrypt(xfp.utf8) {
            dict["xfp"] = encryptedXfp
        }

        CoreDataService.saveEntity(dict: dict, entityName: .signers) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard success else {
                    showAlert(vc: self, title: "", message: "Unable to save the new signer.")
                    return
                }
                self.addKeyStore(xfp, xpub, source: "This phone · new key")
                self.showWords(words)
            }
        }
    }

    private func showWords(_ words: String) {
        let numbered = words.split(separator: " ").enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        let alert = UIAlertController(title: "Write down these 12 words",
                                      message: "\n\(numbered)\n\nThey back up this cosigner. You can see them again in Signers.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "I wrote them down", style: .default))
        present(alert, animated: true)
    }

    @objc private func pasteAction() {
        pendingSource = "Pasted"
        if let data = UIPasteboard.general.data(forPasteboardType: "com.apple.traditional-mac-plain-text") {
            guard let string = String(bytes: data, encoding: .utf8) else {
                showAlert(vc: self, title: "", message: "Looks like you do not have valid text on your clipboard.")
                return
            }

            parseImportedString(string)
        } else if let string = UIPasteboard.general.string {
            parseImportedString(string)
        } else {
            showAlert(vc: self, title: "Nothing to paste", message: "Copy a cosigner's xpub, descriptor or multisig export first.")
        }
    }

    @objc private func scanAction() {
        pendingSource = "Scanned"
        showXpubScanner()
    }

    @objc private func typeAction() {
        pendingSource = "Typed"
        presentManualEntry(xpub: "")
    }

    /// Asks for a fingerprint and xpub (prefilled with `xpub` when one was pasted on its own).
    private func presentManualEntry(xpub: String) {
        let alert = UIAlertController(title: "Add a cosigner",
                                      message: "The key's master fingerprint and its xpub at \(derivationPath).",
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Fingerprint, e.g. 0a1b2c3d"
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.keyboardAppearance = .dark
            field.accessibilityIdentifier = "msig.fingerprintField"
        }
        alert.addTextField { field in
            field.placeholder = "xpub / tpub / Zpub / Vpub"
            field.text = xpub
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.keyboardAppearance = .dark
            field.accessibilityIdentifier = "msig.xpubField"
        }
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self, weak alert] _ in
            guard let self = self else { return }
            let xfp = (alert?.textFields?[0].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let key = (alert?.textFields?[1].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard xfp.count == 8, xfp.allSatisfy(\.isHexDigit) else {
                showAlert(vc: self, title: "Invalid fingerprint", message: "A fingerprint is 8 hex characters, e.g. 0a1b2c3d. Your hardware wallet shows it.")
                return
            }
            addKeyStore(xfp, key, source: pendingSource)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    /// Adds a key after checking it's a valid extended key and isn't already in the list.
    private func addKeyStore(_ xfp: String, _ key: String, source: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            var xpub = key
            let isPrivate = key.hasPrefix("xprv") || key.hasPrefix("tprv")
            if !isPrivate && !key.hasPrefix("xpub") && !key.hasPrefix("tpub") {
                xpub = XpubConverter.convert(extendedKey: key) ?? ""
            }
            guard isPrivate || XpubConverter.zpub(xpub: xpub) != nil else {
                showAlert(vc: self, title: "Invalid extended key", message: "That isn't a valid xpub.")
                return
            }
            guard !cosigners.contains(where: { $0.fingerprint.lowercased() == xfp.lowercased() || $0.xpub == xpub }) else {
                showAlert(vc: self, title: "Already added", message: "Cosigner \(xfp) is already in this wallet. Each cosigner needs its own key.")
                return
            }

            cosigners.append(Cosigner(fingerprint: xfp.lowercased(), xpub: xpub, source: source))
            refresh()
            SuccessView.toast("Cosigner #\(cosigners.count) added", in: self)
        }
    }

    @objc private func removeCosigner(_ sender: UIButton) {
        guard sender.tag < cosigners.count else { return }
        let removed = cosigners[sender.tag]
        let alert = UIAlertController(title: "Remove cosigner \(removed.fingerprint)?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            cosigners.removeAll { $0.fingerprint == removed.fingerprint }
            if cosigners.isEmpty { isNested = false }
            refresh()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Create

    @objc private func createAction() {
        guard cosigners.count > 1 else {
            showAlert(vc: self, title: "Add more cosigners", message: "A multisig needs at least 2 keys.")
            return
        }
        create(m: threshold)
    }

    private func create(m: Int) {
        guard Keys.validPath(derivationPath) else {
            showAlert(vc: self, title: "Invalid derivation", message: "Only valid derivation paths that start with m/ are allowed.")
            return
        }

        let path = derivationPath.replacingOccurrences(of: "m/", with: "")
        let descriptorKeys = cosigners.map { "[\($0.fingerprint)/\(path)]\($0.xpub)/0/*" }.joined(separator: ",")
        let n = cosigners.count

        var rawPrimDesc = "wsh(sortedmulti(\(m),\(descriptorKeys)))"

        if isNested {
            rawPrimDesc = "sh(wsh(sortedmulti(\(m),\(descriptorKeys))))"
        }

        if isTaproot {
            // create a dummy key for the internal key so its a true multisig.
            guard let dummyKey = WalletLogic.shared.dummyKey() else {
                showAlert(vc: self, title: "", message: "Unable to derive a dummy key for taproot multisig.")
                return
            }
            rawPrimDesc = "tr(\(dummyKey),multi_a(\(m),\(descriptorKeys)))"
        }

        let review = ImportReview(title: "Create \(m) of \(n) multisig", source: "Multisig creator · \(n) cosigners",
                                  receiveDescriptor: rawPrimDesc, label: "\(m) of \(n)", confirmTitle: "Create wallet")
        let blockheight = self.blockheight
        presentImportReview(review) { [weak self] label in
            self?.createNow(["descriptor": rawPrimDesc, "label": label, "blockheight": blockheight], mofn: "\(m) of \(n)")
        }
    }

    private func createNow(_ accountMap: [String: Any], mofn: String) {
        showActivity("creating multisig wallet...")
        ImportWallet.accountMap(accountMap) { [weak self] (success, errorDescription) in
            guard let self = self else { return }

            if success {
                self.showCreated(mofn: mofn)
            } else {
                self.hideActivity()
                showAlert(vc: self, title: "There was an error!", message: "Something went wrong during the wallet creation process: \(errorDescription ?? "unknown error")")
            }
        }
    }

    /// Replaces the form with the result: the wallet file and how to share it.
    private func showCreated(mofn: String) {
        isDone = true

        var format = "P2WSH"
        if isNested {
            format = "SHP2WSH"
        }
        if isTaproot {
            format = "TR"
        }

        walletText = """
        Name: Fully Noded
        Policy: \(mofn)
        Derivation: \(derivationPath)
        Format: \(format)

        \(cosigners.map { "\($0.fingerprint):\($0.xpub)" }.joined(separator: "\n\n"))
        """

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            hideActivity()
            NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
            navigationItem.hidesBackButton = true
            masterStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

            let title = UILabel()
            title.text = "\(mofn) wallet created ✓"
            title.font = WalletTheme.mono(17, weight: .bold)
            title.textColor = tint.accent
            title.numberOfLines = 0

            let file = UILabel()
            file.text = walletText
            file.font = WalletTheme.mono(11)
            file.textColor = WalletTheme.text
            file.numberOfLines = 0
            file.lineBreakMode = .byCharWrapping

            masterStackView.addArrangedSubview(WalletTheme.cardView([
                title,
                hint("It's now your active wallet. Give this wallet file to every cosigner (Passport, Sparrow, Coldcard, BlueWallet…) so they can check addresses and sign."),
            ], tint: tint, spacing: 8))

            masterStackView.addArrangedSubview(WalletTheme.cardView([
                WalletTheme.caption("> WALLET FILE", tint: tint),
                file,
                buttonRow([
                    makeButton("Export file", systemImage: "square.and.arrow.up", id: "msig.exportFile", action: #selector(exportFile)),
                    makeButton("Show QR", systemImage: "qrcode", id: "msig.exportQR", action: #selector(exportQR))
                ])
            ], tint: tint, spacing: 8))

            let done = UIButton(type: .system)
            WalletTheme.styleHero(done, title: "Done", systemImage: "checkmark", tint: tint)
            done.accessibilityIdentifier = "msig.done"
            done.addTarget(self, action: #selector(doneAction), for: .touchUpInside)
            masterStackView.setCustomSpacing(20, after: masterStackView.arrangedSubviews.last ?? masterStackView)
            masterStackView.addArrangedSubview(done)
            scrollView.setContentOffset(.zero, animated: false)
        }
    }

    @objc private func exportFile() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("Import.txt")
        try? walletText.dataUsingUTF8StringEncoding.write(to: fileURL)
        present(UIDocumentPickerViewController(forExporting: [fileURL]), animated: true)
    }

    @objc private func exportQR() {
        guard let ur = URHelper.dataToUrBytes(walletText.utf8) else {
            showAlert(vc: self, title: "Error", message: "Unable to convert the text into a UR.")
            return
        }
        qrToExport = ur.qrString
        showExport()
    }

    @objc private func doneAction() {
        if let navigationController = navigationController, navigationController.viewControllers.first != self {
            navigationController.popToRootViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }

    // MARK: - Parsing imports

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let signer = pendingSigner {
            pendingSigner = nil
            addKey(from: signer)
        }
    }

    private func addKey(from signer: SignerStruct) {
        guard let encryptedWords = signer.words, let words = Crypto.decrypt(encryptedWords)?.utf8String else {
            showAlert(vc: self, title: "Can't read this signer", message: "\(signer.label) has no seed words Fully Noded can decrypt on this phone.")
            return
        }
        var passphrase = ""
        if let encryptedPassphrase = signer.passphrase {
            guard let decrypted = Crypto.decrypt(encryptedPassphrase)?.utf8String else {
                showAlert(vc: self, title: "Can't read this signer", message: "Unable to decrypt the passphrase of \(signer.label).")
                return
            }
            passphrase = decrypted
        }
        convertWords(words, passphrase, label: signer.label)
    }

    private func convertWords(_ words: String, _ passphrase: String, label: String) {
        guard let mk = Keys.masterKey(words: words, coinType: coinType, passphrase: passphrase),
              let fingerprint = Keys.fingerprint(masterKey: mk),
              let xpub = Keys.xpub(path: derivationPath, masterKey: mk) else {
            showAlert(vc: self, title: "Unable to derive xpub", message: "The signer's words need to conform with BIP39.")
            return
        }

        addKeyStore(fingerprint, xpub, source: "This phone · \(label)")
    }

    private func showError() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            showAlert(vc: self, title: "", message: "Something went wrong, please let us know about it.")
        }
    }

    private func parseImportedString(_ item: String) {
        let item = TextFileImport.singleDescriptor(in: item) ?? item.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = item.lowercased()

        if item.hasPrefix("xpub") || item.hasPrefix("tpub") {
            // A bare xpub has no fingerprint: ask for it.
            presentManualEntry(xpub: item)

        } else if item.hasPrefix("Zpub") || item.hasPrefix("Vpub") || item.hasPrefix("Ypub") || item.hasPrefix("Upub") {
            guard let xpub = XpubConverter.convert(extendedKey: item) else {
                showError()
                return
            }
            if (item.hasPrefix("Ypub") || item.hasPrefix("Upub")) && cosigners.isEmpty && !isTaproot {
                isNested = true
                derivationPath = defaultPath
                refresh()
            }
            presentManualEntry(xpub: xpub)

        } else if item.hasPrefix("[") {
            parseDescriptor(Descriptor("wsh(\(item))"))

        } else if lowercased.hasPrefix("wsh(") || lowercased.hasPrefix("sh(wsh(") {
            addCosigners(from: [item])

        } else if lowercased.hasPrefix("wpkh(") || lowercased.hasPrefix("pkh(") || lowercased.hasPrefix("sh(wpkh(") || lowercased.hasPrefix("tr(") {
            addCosigners(from: [item])

        } else if lowercased.hasPrefix("ur:crypto-hdkey") || lowercased.hasPrefix("ur:crypto-account") || lowercased.hasPrefix("ur:crypto-seed") || lowercased.hasPrefix("ur:crypto-output") {
            let (descriptors, error) = URHelper.parseUr(urString: lowercased)
            guard error == nil, let descriptors = descriptors, descriptors.count > 0 else {
                showAlert(vc: self, title: "Error", message: error ?? "Unknown error decoding the QR code.")
                return
            }
            addCosigners(from: descriptors)

        } else if lowercased.hasPrefix("ur:bytes") {
            // A text file in a QR (wallet export JSON, a descriptor, a wallet file): handled
            // exactly as if it had been pasted.
            let (text, err) = URHelper.parseBlueWalletCoordinationSetup(lowercased)
            guard let textFile = text, !textFile.lowercased().hasPrefix("ur:") else {
                showAlert(vc: self, title: "Error", message: err ?? "Unknown error decoding the QR code.")
                return
            }
            parseImportedString(textFile)

        } else if let coldcardMultisigExport = try? jsonDecoder.decode(ColdcardMultiSigExport.self, from: item.utf8),
                  let deriv = coldcardMultisigExport.p2wsh_deriv,
                  let xfp = coldcardMultisigExport.xfp,
                  let p2wsh = coldcardMultisigExport.p2wsh {
            guard let xpub = XpubConverter.convert(extendedKey: p2wsh) else {
                showError()
                return
            }
            addKey(xfp, xpub, path: deriv)

        } else if let json = try? JSONSerialization.jsonObject(with: item.utf8, options: []) as? [String:Any] {
            if let xfp = json["xfp"] as? String,
               let xpub = json["xpub"] as? String,
               let path = json["path"] as? String {
                addKey(xfp, xpub, path: path)
            } else {
                let descriptors = WalletImport(json).descriptors
                guard !descriptors.isEmpty else {
                    showError()
                    return
                }
                addCosigners(from: descriptors)
            }

        } else if item.contains("Format: ") {
            let (accountMap, error) = TextFileImport.parse(item)
            guard let descriptor = accountMap?["descriptor"] as? String else {
                showAlert(vc: self, title: "Unsupported wallet file.", message: error ?? "Unknown error decoding the text file into a descriptor.")
                return
            }
            addCosigners(from: [descriptor])

        } else {
            showAlert(vc: self, title: "Unrecognized cosigner format.", message: item + " is not a recognized cosigner format. Please reach out to us so that we can add support for this.")
        }
    }

    /// Adds a key that comes with its own path. The first key sets the wallet's path; later
    /// ones must match it.
    private func addKey(_ xfp: String, _ xpub: String, path: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let normalized = { (p: String) in p.replacingOccurrences(of: "'", with: "h").replacingOccurrences(of: "’", with: "h") }
            if cosigners.isEmpty {
                derivationPath = path
            } else if normalized(path) != normalized(derivationPath) {
                showAlert(vc: self, title: "Different path", message: "This key is at \(path), but the wallet uses \(derivationPath). Every cosigner must use the same path.")
                return
            }
            addKeyStore(xfp, xpub, source: pendingSource)
        }
    }

    /// Adds cosigners from imported descriptors: every key of a multisig descriptor, or the
    /// first cosigner (bip48) key matching the derivation path. A single sig wallet isn't a
    /// cosigner, so it's refused with an explanation.
    private func addCosigners(from descriptors: [String]) {
        let parsed = descriptors.map { Descriptor($0) }

        if let multisig = parsed.first(where: { $0.isMulti && $0.keysWithPath.count > 1 }) {
            for key in multisig.keysWithPath {
                parseDescriptor(Descriptor("wsh(\(key))"))
            }
            return
        }

        let cosigners = parsed.filter { $0.isCosigner }
        guard !cosigners.isEmpty else {
            showAlert(vc: self, title: "Not a cosigner", message: "This is a single sig wallet, not a multisig cosigner. Export the cosigner (BIP48) key from your signer instead.")
            return
        }

        let derivation = derivationPath.replacingOccurrences(of: "h", with: "'")
        if let match = cosigners.first(where: { $0.derivation.replacingOccurrences(of: "h", with: "'") == derivation }) {
            parseDescriptor(match)
        } else {
            showAlert(vc: self, title: "There was an issue...", message: "It does not look like any of the supplied cosigners match the \(derivationPath) derivation path. For now the multisig creator only supports one derivation path per cosigner.")
        }
    }

    private func parseDescriptor(_ descriptor: Descriptor) {
        var key = descriptor.accountXpub
        let xprv = descriptor.accountXprv
        if xprv != "" {
            key = xprv
        }
        let fingerprint = descriptor.fingerprint

        guard key != "", fingerprint != "" else {
            showError()
            return
        }

        addKeyStore(fingerprint, key, source: pendingSource)
    }

    // MARK: - Navigation

    private func showXpubScanner() {
        let vc = QRScannerViewController()
        vc.isImporting = true
        vc.onDoneBlock = { [weak self] xpub in
            guard let self = self, let xpub = xpub else { return }

            self.parseImportedString(xpub)
        }
        present(vc, animated: true)
    }

    private func showSignerPicker() {
        let vc = SignersViewController()
        vc.isCreatingMsig = true
        vc.signerSelected = { [weak self] signer in
            self?.pendingSigner = signer
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showExport() {
        let vc = QRDisplayerViewController()
        vc.text = self.qrToExport
        vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
        vc.headerText = "Multisig Wallet UR Bytes"
        navigationController?.pushViewController(vc, animated: true)
    }

}
