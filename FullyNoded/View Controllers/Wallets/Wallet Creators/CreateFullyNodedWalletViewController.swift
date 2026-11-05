//
//  CreateFullyNodedWalletViewController.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

/// Create Wallet, built in code (teal WalletTheme, like Create Multisig).
class CreateFullyNodedWalletViewController: UIViewController, UINavigationControllerDelegate, UIDocumentPickerDelegate {
    // Pushed full height, without the tab bar.
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }

    var cosigner:Descriptor?
    /// Set only when the current recovery itself created the Core wallet (never for one that
    /// already existed), so a failed recovery can unload exactly what it made.
    private var walletCreatedByRecovery: String?
    var onDoneBlock:(((Bool)) -> Void)?
    var ccXfp = ""
    var xpub = ""
    var deriv = ""
    var descriptor: Descriptor?
    let jsonDecoder = JSONDecoder()
    var isSegwit = true
    var isTaproot = false
    /// Length of the seed the single sig creator generates (12 or 24 words).
    private var seedWordCount = 12

    private let tint = WalletTheme.Tint.create
    private let scriptControl = UISegmentedControl(items: ["Segwit", "Taproot"])
    private let wordsControl = UISegmentedControl(items: ["12 words", "24 words"])
    private let singleSigHint = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        navigationItem.title = "Create Wallet"
        
        // Cypherpunk teal look (see WalletTheme in ActiveWalletViewController.swift).
        WalletTheme.apply(to: self, tint: .create)
        setupUI()
        refreshSingleSig()
    }

    // MARK: - Layout

    private func setupUI() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        // SINGLE SIG: script and seed length picked here, then one button.
        WalletTheme.style(scriptControl, tint: tint)
        WalletTheme.style(wordsControl, tint: tint)
        scriptControl.selectedSegmentIndex = isTaproot ? 1 : 0
        wordsControl.selectedSegmentIndex = seedWordCount == 24 ? 1 : 0
        scriptControl.accessibilityIdentifier = "create.script"
        wordsControl.accessibilityIdentifier = "create.words"
        scriptControl.addTarget(self, action: #selector(singleSigOptionsChanged), for: .valueChanged)
        wordsControl.addTarget(self, action: #selector(singleSigOptionsChanged), for: .valueChanged)
        prepareHint(singleSigHint)
        let createSingleSig = UIButton(type: .system)
        WalletTheme.styleHero(createSingleSig, title: "Create single sig wallet", systemImage: "key", tint: tint)
        createSingleSig.accessibilityIdentifier = "create.singleSig"
        createSingleSig.accessibilityLabel = "Create single sig wallet"
        createSingleSig.addTarget(self, action: #selector(automaticAction), for: .touchUpInside)
        stack.addArrangedSubview(WalletTheme.cardView([
            WalletTheme.caption("> SINGLE SIG", tint: tint),
            title("One seed, kept encrypted on this phone. The simplest wallet to use and back up."),
            scriptControl,
            wordsControl,
            singleSigHint,
            createSingleSig
        ], tint: tint, spacing: 10))

        // MULTISIG
        let createMultisig = UIButton(type: .system)
        createMultisig.configuration = WalletTheme.buttonConfiguration(title: "Set up multisig", systemImage: "person.3", filled: false, tint: tint)
        createMultisig.accessibilityIdentifier = "create.multisig"
        createMultisig.addTarget(self, action: #selector(createMultiSigAction), for: .touchUpInside)
        stack.addArrangedSubview(WalletTheme.cardView([
            WalletTheme.caption("> MULTISIG", tint: tint),
            title("Several keys, any m of n can spend. For savings or funds shared with others."),
            hint("Keys can come from this phone, hardware wallets or other people."),
            createMultisig
        ], tint: tint, spacing: 10))

        // IMPORT OR RECOVER
        stack.setCustomSpacing(20, after: stack.arrangedSubviews.last ?? stack)
        stack.addArrangedSubview(WalletTheme.caption("> IMPORT OR RECOVER", tint: tint))
        stack.addArrangedSubview(optionRow(icon: "qrcode.viewfinder",
                                           title: "Scan a QR code",
                                           subtitle: "A wallet export or backup QR, including animated UR codes.",
                                           id: "create.scan",
                                           action: #selector(scanQrAction)))
        stack.addArrangedSubview(optionRow(icon: "doc.on.clipboard",
                                           title: "Paste text",
                                           subtitle: "Seed words, a descriptor, a Fully Noded backup or a wallet export.",
                                           id: "create.paste",
                                           action: #selector(pasteTextAction)))
        stack.addArrangedSubview(optionRow(icon: "folder",
                                           title: "Open a file",
                                           subtitle: "Fully Noded backups, Coldcard, Sparrow, Electrum and Unchained files.",
                                           id: "create.file",
                                           action: #selector(importFileAction)))
        stack.addArrangedSubview(optionRow(icon: "server.rack",
                                           title: "Bitcoin Core wallets",
                                           subtitle: "Use a wallet that's already on your node.",
                                           id: "create.core",
                                           action: #selector(syncCoreWalletAction)))

        let footer = hint("Private keys stay encrypted on this phone. Your node only gets public keys, so it can watch the wallet and build transactions.")
        footer.textAlignment = .center
        stack.setCustomSpacing(16, after: stack.arrangedSubviews.last ?? stack)
        stack.addArrangedSubview(footer)
    }

    @objc private func singleSigOptionsChanged() {
        isTaproot = scriptControl.selectedSegmentIndex == 1
        isSegwit = !isTaproot
        seedWordCount = wordsControl.selectedSegmentIndex == 1 ? 24 : 12
        refreshSingleSig()
    }

    private func refreshSingleSig() {
        let script = isTaproot
            ? "Taproot (BIP86, bc1p…): cheaper, more private spends. Some older wallets and services can't pay to it."
            : "Segwit (BIP84, bc1q…): works with every wallet and exchange."
        let words = seedWordCount == 24
            ? "24 words: more entropy."
            : "12 words: easier to write down. Just as secure in practice."
        singleSigHint.text = script + "\n" + words
    }

    /// Tappable card: bordered icon tile, title, one line on what it takes, chevron.
    private func optionRow(icon: String, title: String, subtitle: String, id: String, action: Selector) -> UIView {
        let control = UIControl()
        control.backgroundColor = WalletTheme.card
        control.layer.borderWidth = 1
        control.layer.borderColor = tint.line.cgColor
        control.addTarget(self, action: action, for: .touchUpInside)
        control.addTarget(self, action: #selector(rowTouchDown(_:)), for: [.touchDown, .touchDragEnter])
        control.addTarget(self, action: #selector(rowTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        control.isAccessibilityElement = true
        control.accessibilityLabel = title
        control.accessibilityHint = subtitle
        control.accessibilityTraits = .button
        control.accessibilityIdentifier = id

        let iconTile = UIView()
        iconTile.layer.borderWidth = 1
        iconTile.layer.borderColor = tint.line.cgColor
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        iconView.tintColor = tint.accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconTile.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = WalletTheme.mono(15, weight: .semibold)
        titleLabel.textColor = WalletTheme.text
        let subtitleLabel = hint(subtitle)

        let texts = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        texts.axis = .vertical
        texts.spacing = 3

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        chevron.tintColor = tint.dim
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [iconTile, texts, chevron])
        row.alignment = .center
        row.spacing = 12
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        control.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: control.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: control.bottomAnchor, constant: -12),
            iconTile.widthAnchor.constraint(equalToConstant: 36),
            iconTile.heightAnchor.constraint(equalToConstant: 36),
            iconView.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor)
        ])
        return control
    }

    @objc private func rowTouchDown(_ sender: UIControl) {
        sender.backgroundColor = tint.accent.withAlphaComponent(0.12)
    }

    @objc private func rowTouchUp(_ sender: UIControl) {
        UIView.animate(withDuration: 0.2) { sender.backgroundColor = WalletTheme.card }
    }

    private func title(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = WalletTheme.mono(13)
        label.textColor = WalletTheme.text
        label.numberOfLines = 0
        return label
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

    // MARK: - Actions
    
    @objc private func pasteTextAction() {
        if let data = UIPasteboard.general.data(forPasteboardType: "com.apple.traditional-mac-plain-text") {
            guard let string = String(bytes: data, encoding: .utf8) else {
                showAlert(vc: self, title: "", message: "Looks like you do not have valid text on your clipboard.")
                return
            }
            
            processPastedString(string)
        } else if let string = UIPasteboard.general.string {
           processPastedString(string)
        } else {
            showAlert(vc: self, title: "", message: "Not a supported import item. Please let us know about it so we can add it.")
        }
    }
    
    private func isExtendedKey(_ lowercased: String) -> Bool {
        if lowercased.hasPrefix("xprv") || lowercased.hasPrefix("tprv") || lowercased.hasPrefix("vprv") || lowercased.hasPrefix("yprv") || lowercased.hasPrefix("zprv") || lowercased.hasPrefix("uprv") || lowercased.hasPrefix("xpub") || lowercased.hasPrefix("tpub") || lowercased.hasPrefix("vpub") || lowercased.hasPrefix("ypub") || lowercased.hasPrefix("zpub") || lowercased.hasPrefix("upub") {
            return true
        } else {
            return false
        }
    }
    
    /// The descriptor import screen, which shows the descriptor and its addresses first.
    private func showDescriptorImport(_ descriptor: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.descriptor = Descriptor(descriptor)
            self.showDescriptorImporter()
        }
    }
    
    static func isDescriptor(_ lowercased: String) -> Bool {
        // With the "(": seed words can start with these letters too ("short …", "shift …"
        // would otherwise be read as an sh() descriptor and never offered as a seed).
        let functions = ["wsh(", "pkh(", "sh(", "combo(", "wpkh(", "addr(", "multi(", "sortedmulti(", "tr(", "rawtr("]
        return functions.contains { lowercased.hasPrefix($0) }
    }
    
    private func processPastedString(_ string: String) {
        processImportedString(string)
    }
    
    @objc private func syncCoreWalletAction() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
        
            let vc = CoreWalletsViewController()
            vc.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @objc private func importFileAction() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        present(documentPicker, animated: true, completion: nil)
    }
    
    @objc private func scanQrAction() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.showScanner()
        }
    }
    
    @objc private func automaticAction() {
        // Imports can change isTaproot: the seed screen gets what the card shows.
        singleSigOptionsChanged()
        segueToSingleSigCreator()
    }
    
    private func segueToSingleSigCreator() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.showSeedWords()
        }
    }
    
    @objc private func createMultiSigAction() {
        // A fresh multisig: no cosigner left over from an earlier import.
        cosigner = nil
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.showMultisigCreator()
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let data = try? Data(contentsOf: urls[0].absoluteURL) else {
            hideActivity()
            showAlert(vc: self, title: "", message: "That does not appear to be a recognized wallet backup/export/import file")
            return
        }
        
        guard let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
            
            guard let txt = String(bytes: data, encoding: .utf8) else {
                hideActivity()
                showAlert(vc: self, title: "", message: "That does not appear to be a recognized wallet backup/export/import file")
                return
            }
            
            self.processImportedString(txt)
            
            return
        }
        
        if let extendedPublicKeys = dict["extendedPublicKeys"] as? NSArray,
           let quorum = dict["quorum"] as? NSDictionary,
           let requiredSigners = quorum["requiredSigners"] as? Int {
            let name = dict["name"] as? String ?? "Unchained"
            var descriptor = "sh(sortedmulti(\(requiredSigners),"
            
            for (i, key) in extendedPublicKeys.enumerated() {
                if let keyDict = key as? NSDictionary {
                    if var keyPath = keyDict["bip32Path"] as? String,
                       let xfp = keyDict["xfp"] as? String,
                       let xpub = keyDict["xpub"] as? String {
                        
                        if keyPath != "Unknown" {
                            keyPath = "[\(keyPath.replacingOccurrences(of: "m", with: xfp))]\(xpub)/0/*"
                        } else {
                            keyPath = "[\(xfp)]\(xpub)/0/*"
                        }
                        
                        descriptor += keyPath
                        
                        if i + 1 == extendedPublicKeys.count {
                            descriptor += "))"
                            let accountMap = ["descriptor": descriptor, "blockheight": 0, "watching": [] as [String], "label": name] as [String : Any]
                            promptToImportUnchained(accountMap)
                        } else {
                            descriptor += ","
                        }
                    }
                }
            }
        }
        
        if let _ = dict["chain"] as? String {
            /// We think its a coldcard skeleton import
            promptToImportColdcardSingleSig(dict)
            
        } else if let deriv = dict["p2wsh_deriv"] as? String, let xfp = dict["xfp"] as? String, let p2wsh = dict["p2wsh"] as? String {
            /// It is most likely a multi-sig wallet export
            let origin = deriv.replacingOccurrences(of: "m", with: xfp)
            let descriptor = "wsh([\(origin)]\(p2wsh)/0/*)"
            promptToImportColdcardMsig(Descriptor(descriptor))

        } else if let _ = dict["wallet_type"] as? String {
            /// We think its an Electrum wallet
            promptToImportElectrumMsig(dict)
            
        } else if let _ = dict["descriptor"] as? String {
            promptToImportAccountMap(dict: dict)
            
        } else if let _ = dict["ExtPubKey"] as? String {
            promptToImportCoboSingleSig(dict)
        }
    }
    
    private func promptToImportUnchained(_ dict: [String:Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Import your Unchained Capital multi sig wallet?", message: "Looks like you selected a multi sig wallet. You can easily recreate the wallet as watchonly with Fully Noded, just tap \"import\".", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Import", style: .default, handler: { action in
                self.importAccountMap(dict)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToImportCoboSingleSig(_ dict: [String:Any]) {
        guard let extPubKey = dict["ExtPubKey"] as? String,
            let xfp = dict["MasterFingerprint"] as? String,
            let deriv = dict["AccountKeyPath"] as? String,
            let xpub = XpubConverter.convert(extendedKey: extPubKey) else {
            showAlert(vc: self, title: "Error converting that wallet import", message: "Please let us know about this issue so we can fix it.")
                
            return
        }
        
        var desc = ""
        
        if extPubKey.hasPrefix("xpub") || extPubKey.hasPrefix("tpub") {
            desc = "pkh([\(xfp)/\(deriv)]\(xpub)/0/*)"
            
        } else if extPubKey.hasPrefix("vpub") || extPubKey.hasPrefix("zpub") {
            desc = "wpkh([\(xfp)/\(deriv)]\(xpub)/0/*)"
            
        } else if extPubKey.hasPrefix("ypub") || extPubKey.hasPrefix("upub") {
            desc = "sh(wpkh([\(xfp)/\(deriv)]\(xpub)/0/*))"
            
        }
        
        let accountMap = ["descriptor": desc, "blockheight": 0, "watching": [] as [String], "label": "Wallet import"] as [String : Any]
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Import single sig?", message: "Looks like you selected a single sig wallet. You can easily recreate the wallet as watchonly with Fully Noded, just tap \"import\".", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Import", style: .default, handler: { action in
                self.importAccountMap(accountMap)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToImportElectrumMsig(_ dict: [String:Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Import your Electrum multisig wallet?", message: "Looks like you selected an Electrum wallet backup file. You can easily recreate the wallet as watchonly with Fully Noded, just tap \"import\".", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Import", style: .default, handler: { action in
                guard let accountMap = self.convertElectrumToAccountMap(dict) else {
                    showAlert(vc: self, title: "Uh oh", message: "We had an issue converting that backup file to a wallet... Please reach out on Telegram, Github or Twitter so we can fix it.")
                    return
                }
                
                self.importAccountMap(accountMap)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func convertElectrumToAccountMap(_ dict: [String:Any]) -> [String:Any]? {
        guard let descriptor = getDescriptorFromElectrumBackUp(dict) else { return nil }
        
        return ["descriptor": descriptor, "blockheight": 0, "watching": [] as [String], "label": "Electrum wallet"]
    }
    
    private func getDescriptorFromElectrumBackUp(_ dict: [String:Any]) -> String? {
        guard let walletType = dict["wallet_type"] as? String else { return nil }
        
        let processed = walletType.replacingOccurrences(of: "of", with: " ")
        let arr = processed.split(separator: " ")
        
        guard arr.count > 0 else { return nil }
        
        let m = "\(arr[0])"
        var keys = [[String:String]]()
        var derivationPathToUse = ""
        
        for (key, value) in dict {
            
            if key.hasPrefix("x") && key.hasSuffix("/") {
                
                guard let dict = value as? NSDictionary else { return nil }
                
                var keyToUse = [String:String]()
                
                if let derivation = dict["derivation"] as? String {
                    if derivation != "null" {
                        if derivation == "m/48'/0'/0'/2'" || derivation == "m/48'/1'/0'/2'" {
                            keyToUse["derivation"] = derivation
                            derivationPathToUse = derivation
                        }
                    }
                }
                
                if let root_fingerprint = dict["root_fingerprint"] as? String {
                    if root_fingerprint != "null" {
                        keyToUse["fingerprint"] = root_fingerprint
                    } else {
                        keyToUse["fingerprint"] = "00000000"
                    }
                } else {
                    keyToUse["fingerprint"] = "00000000"
                }
                
                guard let xpub = dict["xpub"] as? String, xpub.hasPrefix("Zpub") || xpub.hasPrefix("Vpub"), let convertedXpub = XpubConverter.convert(extendedKey: xpub) else {
                    showAlert(vc: self, title: "Unsupported script type", message: "Sorry but for now as this is a new feature we are only supporting the default script type p2wsh, if you would like the app to support other script types please make a request on Twitter, GitHub or Telegram.")
                    return nil
                }
                
                keyToUse["xpub"] = convertedXpub
                
                keys.append(keyToUse)
            }
        }
        
        guard derivationPathToUse == "m/48'/0'/0'/2'" || derivationPathToUse == "m/48'/1'/0'/2'" else {
            showAlert(vc: self, title: "Unsupported derivation", message: "Sorry, for now we only support m/48'/0'/0'/2' or m/48'/1'/0'/2'")
            return nil
        }
        
        for (i, key) in keys.enumerated() {
            if key["derivation"] == nil {
                keys[i]["derivation"] = derivationPathToUse
            }
        }
        
        var keysArray = [String]()
        
        for key in keys {
            guard let xpub = key["xpub"], var deriv = key["derivation"] else { return nil }
                        
            let xfp = key["fingerprint"] ?? "00000000"
            deriv = deriv.replacingOccurrences(of: "m/", with: "\(xfp)/")
            let str = "[\(deriv)]\(xpub)/0/*"
            keysArray.append(str)
        }
        
        var keysString = keysArray.description.replacingOccurrences(of: "[\"[", with: "[")
        keysString = keysString.replacingOccurrences(of: "*\"]", with: "*")
        keysString = keysString.replacingOccurrences(of: "\\", with: "")
        keysString = keysString.replacingOccurrences(of: "\"", with: "")
        keysString = keysString.replacingOccurrences(of: " ", with: "")
        
        return "wsh(sortedmulti(\(m),\(keysString)))"
    }
    
    private func promptToImportColdcardMsig(_ desc: Descriptor) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Create a multisig?", message: "You have uploaded a multisig file.", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.cosigner = desc
                    vc.showMultisigCreator()
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToImportColdcardSingleSig(_ coldcard: [String:Any]) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Create a single sig?", message: "You have uploaded a single sig file.", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { action in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .addColdCard, object: nil, userInfo: coldcard)
                    vc.navigationController?.popViewController(animated: true)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func importAccountMap(_ accountMap: [String:Any]) {
        showActivity("importing...")
        
        func importAccount() {
            if let _ = accountMap["descriptor"] as? String {
                if (accountMap["blockheight"] as? Int) != nil || (accountMap["blockheight"] as? Int64) != nil {
                    /// It is an Account Map.
                    ImportWallet.accountMap(accountMap) { (success, errorDescription) in
                        if success {
                            DispatchQueue.main.async {
                                self.hideActivity()
                                self.onDoneBlock!(true)
                                self.navigationController?.popViewController(animated: true)
                            }
                        } else {
                            self.hideActivity()
                            showAlert(vc: self, title: "Error", message: "There was an error importing your wallet: \(errorDescription ?? "unknown")")
                        }
                    }
                }
            } else if let _ = accountMap["ExtPubKey"] as? String {
                hideActivity()
                promptToImportCoboSingleSig(accountMap)
            }
        }
        
        if let url = accountMap["quickConnect"] as? String {
            QuickConnect.addNode(url: url) { (success, errorMessage) in
                guard success else {
                    self.hideActivity()
                    showAlert(vc: self, title: "Node connection issue:", message: errorMessage ?? "unknown error")
                    return
                }
                
                importAccount()
            }
        } else {
            importAccount()
        }
    }
    
    private func promptToImportAccountMap(dict: [String:Any]) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Import wallet?", message: "Looks like you have selected a valid wallet format ✓", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Import", style: .default, handler: { [unowned vc = self] action in
                vc.importAccountMap(dict)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func setPrimDesc(descriptors: [String], descriptorToUseIndex: Int) {
        var accountMap:[String:Any] = ["descriptor": "", "blockheight": 0, "watching": [] as [String], "label": "Wallet Import"]
        let primDesc = descriptors[descriptorToUseIndex]
        accountMap["descriptor"] = primDesc
        
        let desc = Descriptor("\(primDesc)")
        self.isTaproot = desc.isTaproot
        
        if desc.isCosigner {
            self.ccXfp = desc.fingerprint
            self.xpub = desc.accountXpub
            self.deriv = desc.derivation
            self.cosigner = desc
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.showMultisigCreator()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.descriptor = desc
                self.showDescriptorImporter()
            }
        }
    }
    
    private func prompToChoosePrimaryDesc(descriptors: [String]) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Choose an address format.", message: "", preferredStyle: .alert)
            
            for (i, descriptor) in descriptors.enumerated() {
                let descStr = Descriptor(descriptor)
                
                alert.addAction(UIAlertAction(title: descStr.scriptType, style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.setPrimDesc(descriptors: descriptors, descriptorToUseIndex: i)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func decodeWalletBackup(from hexString: String) -> WalletBackup? {
        WalletBackup.decode(hex: hexString)
    }
    
    private func promptToImport(backup: WalletBackup) {
        let date = backup.lastUpdate.formatted(date: .abbreviated, time: .shortened)
        let count = backup.descriptors.count
                
        let alert = UIAlertController(
            title: "Recover Wallet Backup?",
            message: """
            Backup details:
            • Last updated: \(date)
            • Descriptors: \(count)
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create Wallet", style: .default) { [weak self] _ in
            self?.performImport(backup: backup)
        })
        
        present(alert, animated: true)
    }

    // MARK: - Recovering a wallet backup
    //
    // 1. createwallet (watch-only, blank, descriptors) named after the receive descriptor, the
    //    same way a wallet created from a seed or descriptor is, so the recovery lands in the
    //    Core wallet it had before.
    // 2. Pruned node: move timestamps that predate the prune height up to it.
    // 3. importdescriptors for every descriptor the node's wallet doesn't already have.
    // 4. Save (or update) the Fully Noded wallet record with the backup attached.

    private func performImport(backup: WalletBackup) {
        guard let pair = backup.walletDescriptors() else {
            showAlert(title: "Can't recover this backup",
                      message: "It has no active HD (ranged) receive descriptor, so there's no wallet to recreate.")
            return
        }
        guard let backupData = try? backup.jsonData() else { return }
        showActivity("Recovering wallet...")

        let name = ImportWallet.walletName(receiveDescriptor: pair.receive)
        let fnWallet: [String: Any] = [
            "id": UUID(),
            "name": name,
            "label": "Recovered wallet",
            "receiveDescriptor": pair.receive,
            "changeDescriptor": pair.change,
            "walletBackup": backupData,
            "blockheight": Int64(backup.birthday.map { approximateHeight(for: Int64($0)) } ?? 0)
        ]

        let p = Create_Wallet_Param([
            "wallet_name": name,
            "disable_private_keys": true,
            "blank": true,
            "avoid_reuse": true,
            "descriptors": true,
            "load_on_startup": true
        ])
        OnchainUtils.createWallet(param: p) { [weak self] (created, message) in
            guard let self = self else { return }
            if created == nil, message?.contains("Database already exists") != true {
                self.failRecovery(message ?? "Unknown error creating wallet.")
                return
            }
            // The active wallet is NOT touched here. Every wallet RPC below is pinned to `name`,
            // so descriptors can't land in whatever wallet happens to be active, and a failed
            // recovery leaves the user's current active wallet as it was.
            self.walletCreatedByRecovery = created != nil ? name : nil
            self.importMissingDescriptors(backup: backup, fnWallet: fnWallet, walletName: name)
        }
    }

    private func importMissingDescriptors(backup: WalletBackup, fnWallet: [String: Any], walletName: String) {
        // What the node's wallet already has (empty for a freshly created one).
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listdescriptors, walletName: walletName) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            var existing: [String] = []
            if let response = response,
               let json = try? JSONSerialization.data(withJSONObject: response),
               let listed = try? JSONDecoder().decode(ListDescriptorsResponse.self, from: json) {
                // Belt and braces: the node must answer for exactly the wallet we're recovering.
                guard listed.walletName == walletName else {
                    self.failRecovery("The node answered for wallet \(listed.walletName) instead of \(walletName). Nothing was imported.")
                    return
                }
                existing = listed.descriptors.map { $0.desc }
            } else if response == nil {
                self.failRecovery("Couldn't read the wallet's descriptors: \(errorDesc ?? "unknown error")")
                return
            }

            let requests = backup.missingImportRequests(existing: existing)
            guard !requests.isEmpty else {
                // Same wallet as on the node: just make sure Fully Noded has it.
                self.saveRecoveredWallet(fnWallet, backup: backup, timestampsMoved: false)
                return
            }

            self.adjustForPruning(requests) { requests, moved in
                OnchainUtils.importDescriptors(Import_Descriptors(["requests": requests]), walletName: walletName) { (imported, message) in
                    guard imported else {
                        self.failRecovery(message ?? "importdescriptors failed.")
                        return
                    }
                    self.saveRecoveredWallet(fnWallet, backup: backup, timestampsMoved: moved)
                }
            }
        }
    }

    /// On a pruned node, rescanning from before the prune height fails, so any earlier
    /// timestamp is moved up to the time of the first block still on disk (its real time,
    /// from getblock; the 10-minute estimate is weeks off at today's heights).
    private func adjustForPruning(_ requests: [[String: Any]],
                                  completion: @escaping ([[String: Any]], Bool) -> Void) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getblockchaininfo) { response, _ in
            guard let info = (response as? [String: Any]).map(BlockchainInfo.init), info.pruned else {
                completion(requests, false)
                return
            }
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .getblockhash(.init(["height": info.pruneheight]))) { hashResponse, _ in
                let fallback = Int(self.approximateTimestamp(for: info.pruneheight))
                guard let hash = hashResponse as? String else {
                    completion(Self.moveTimestamps(requests, notBefore: fallback), true)
                    return
                }
                MakeRPCCall.sharedInstance.executeRPCCommand(method: .getblock(.init(["blockhash": hash]))) { blockResponse, _ in
                    let pruneTime = (blockResponse as? [String: Any])?["time"] as? Int ?? fallback
                    let moved = requests.contains { ($0["timestamp"] as? Int ?? 0) < pruneTime }
                    completion(Self.moveTimestamps(requests, notBefore: pruneTime), moved)
                }
            }
        }
    }

    private static func moveTimestamps(_ requests: [[String: Any]], notBefore time: Int) -> [[String: Any]] {
        requests.map { request in
            var request = request
            if (request["timestamp"] as? Int ?? 0) < time { request["timestamp"] = time }
            return request
        }
    }

    /// Adds the Fully Noded wallet record, or refreshes the backup on the one already there.
    private func saveRecoveredWallet(_ fnWallet: [String: Any], backup: WalletBackup, timestampsMoved: Bool) {
        let name = fnWallet["name"] as? String ?? ""
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self = self else { return }
            let finished: (Bool) -> Void = { [weak self] saved in
                guard let self = self else { return }
                guard saved else {
                    self.failRecovery("The wallet was imported on your node, but saving it in Fully Noded failed.")
                    return
                }
                // Only now, with everything imported and saved, does it become the active wallet.
                UserDefaults.standard.set(name, forKey: "walletName")
                self.walletCreatedByRecovery = nil
                self.showSuccess(showUpdatedTimestampAlert: timestampsMoved)
            }

            if let existing = (wallets ?? []).map(Wallet.init(dictionary:)).first(where: { $0.name == name }) {
                CoreDataService.update(id: existing.id, keyToUpdate: "walletBackup",
                                       newValue: fnWallet["walletBackup"] as Any, entity: .wallets, completion: finished)
            } else {
                CoreDataService.saveEntity(dict: fnWallet, entityName: .wallets, completion: finished)
            }
        }
    }

    private func failRecovery(_ message: String) {
        // A recovery that created the wallet but couldn't finish leaves an empty watch-only
        // wallet loaded on the node: unload it (the files stay; Core has no RPC to delete
        // them, and recovering the same backup again reuses them). Pinned by name, and only
        // ever for a wallet this recovery created.
        if let created = walletCreatedByRecovery {
            walletCreatedByRecovery = nil
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .unloadwallet(param: Unload_Wallet(["wallet_name": created]))) { _, _ in }
        }
        hideActivity {
            showAlert(title: "Recovery failed", message: message)
        }
    }
    
    private func approximateHeight(for timestamp: Int64) -> Int {
        let genesisTime: Int64 = 1_231_006_505      // block 0
        let elapsed = Double(timestamp - genesisTime)
        return max(0, Int((elapsed / 600.0).rounded()))
    }
    
    private func approximateTimestamp(for height: Int) -> Int64 {
        let genesisTime: Int64 = 1_231_006_505      // block 0
        return genesisTime + Int64((Double(height) * 600.0).rounded())
    }
    
    private func showSuccess(showUpdatedTimestampAlert: Bool) {
        hideActivity {
            if showUpdatedTimestampAlert {
                SuccessView.show(
                    in: self,
                    title: "Backup recovered",
                    subtitle: "⚠️ Pruned node: this wallet is older than your prune height (we updated the birthdate to match the prune height). If you don't see balances and a rescan does not show balances you will likely need to -reindex the blockchain."
                )
            } else {
                SuccessView.show(
                    in: self,
                    title: "Backup recovered",
                    subtitle: "Your wallet has been recovered."
                )
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .refreshWallet, object: nil)
            }
        }
    }
    
    private func processImportedString(_ item: String) {
        let item = TextFileImport.singleDescriptor(in: item) ?? item
        let lowercased = item.lowercased()
                
        // A Fully Noded wallet backup: hex-encoded JSON (whitespace / newlines from a
        // file or a paste are fine). Anything else falls through to the other formats.
        if let walletBackup = decodeWalletBackup(from: item) {
            promptToImport(backup: walletBackup)
            
        } else if self.isExtendedKey(lowercased) {
            
            showAlert(vc: self, title: "Not supported.", message: "Xpub importing is not supported, you need to import an output descriptor.")
            
        } else if Self.isDescriptor(lowercased) {
            showDescriptorImport(item)
            
        } else if lowercased.hasPrefix("ur:") {
            if lowercased.hasPrefix("ur:bytes") {
                // A text file in a QR (wallet export JSON, a descriptor, a multisig setup file):
                // handled exactly as if it had been pasted.
                let (text, err) = URHelper.parseBlueWalletCoordinationSetup(lowercased)
                guard let textFile = text, !textFile.lowercased().hasPrefix("ur:") else {
                    showAlert(vc: self, title: "Error", message: err ?? "Unknown error decoding the QR code.")
                    return
                }
                processImportedString(textFile)
                
            } else {
                let (descriptors, error) = URHelper.parseUr(urString: item)
                
                guard error == nil, let descriptors = descriptors else {
                    showAlert(vc: self, title: "Error", message: error ?? "Unknown error decoding the QR code.")
                    return
                }
                
                if descriptors.count > 1 {
                    self.prompToChoosePrimaryDesc(descriptors: descriptors)
                } else {
                    let desc = Descriptor("\(descriptors[0])")
                    if desc.isCosigner {
                        self.ccXfp = desc.fingerprint
                        self.xpub = desc.accountXpub
                        self.deriv = desc.derivation
                        self.cosigner = desc
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.showMultisigCreator()
                        }
                    } else {
                        // Same as a pasted descriptor: show it and its addresses before importing.
                        self.showDescriptorImport(descriptors[0])
                    }
                }
            }
            
        } else if Keys.validMnemonic(item) {
            let (bip84, bip86, segwitCosigner, taprootCosigner, message) = Keys.descriptorsFromSigner(signer: item, passphrase: nil)
            
            guard let encryptedSigner = Crypto.encrypt(item.utf8) else {
                showAlert(vc: self, title: "Unable to encrypt your signer.", message: "Please let us know about this bug.")
                return
            }
            
            var dict = ["id":UUID(), "words":encryptedSigner, "added": Date()] as [String:Any]
            if let mk = Keys.masterKey(words: item, coinType: "0", passphrase: ""),
               let xfp = Keys.fingerprint(masterKey: mk),
               let encryptedXfp = Crypto.encrypt(xfp.utf8) {
                dict["xfp"] = encryptedXfp
            }
            CoreDataService.saveEntity(dict: dict, entityName: .signers) { success in
                guard success else {
                    return
                }
                
                guard message == nil else {
                    showAlert(vc: self, title: "", message: message!)
                    return
                }
                
                self.prompToChoosePrimaryDesc(descriptors: [bip84!, bip86!, segwitCosigner!, taprootCosigner!])
            }
            
        } else if let coldcardSparrowExport = try? jsonDecoder.decode(ColdcardSparrowExport.self, from: item.utf8),
                  coldcardSparrowExport.chain != nil,
                  [coldcardSparrowExport.bip44?.standardDesc, coldcardSparrowExport.bip49?.standardDesc, coldcardSparrowExport.bip84?.standardDesc, coldcardSparrowExport.bip48_2?.standardDesc].contains(where: { $0 != nil }) {
            // Need to edit the desc slightly to work with Descriptor.swift
            // Sparrow is using the following format for cosigner
            //"wsh(sortedmulti(M,[0f056943/48h/1h/0h/2h]tpubDF2rnouQaaYrXF4noGTv6rQYmx87cQ4GrUdhpvXkhtChwQPbdGTi8GA88NUaSrwZBwNsTkC9bFkkC8vDyGBVVAQTZ2AS6gs68RQXtXcCvkP/0/*,...))"
            
            if let _ = coldcardSparrowExport.chain {
                var descriptors:[String] = []
                
                if let bip44 = coldcardSparrowExport.bip44, let desc = bip44.standardDesc {
                    descriptors.append(desc)
                }
                
                if let bip49 = coldcardSparrowExport.bip49, let desc = bip49.standardDesc {
                    descriptors.append(desc)
                }
                
                if let bip84 = coldcardSparrowExport.bip84, let desc = bip84.standardDesc {
                    descriptors.append(desc)
                }
                
                if let bip482 = coldcardSparrowExport.bip48_2, let desc = bip482.standardDesc {
                    descriptors.append(desc)
                }
                
                self.prompToChoosePrimaryDesc(descriptors: descriptors)
            }
            
        } else if let coldcardMultisigExport = try? jsonDecoder.decode(ColdcardMultiSigExport.self, from: item.utf8),
                  coldcardMultisigExport.p2wsh != nil {
            guard let deriv = coldcardMultisigExport.p2wsh_deriv else { return }
            guard let xfp = coldcardMultisigExport.xfp else { return }
            guard let p2wsh = coldcardMultisigExport.p2wsh else { return}
            guard let xpub = XpubConverter.convert(extendedKey: p2wsh) else { return }
            let origin = deriv.replacingOccurrences(of: "m", with: xfp)
            let descriptor = "wsh([\(origin)]\(xpub)/0/*)"
            promptToImportColdcardMsig(Descriptor(descriptor))

        } else if let dict = try? JSONSerialization.jsonObject(with: item.utf8, options: []) as? [String:Any],
                  dict["desc"] is String || !WalletImport(dict).descriptors.isEmpty {
            if dict["desc"] is String {
                self.importAccountMap(dict)
            } else {
                let descriptors = WalletImport(dict).descriptors
                if descriptors.count == 1 {
                    showDescriptorImport(descriptors[0])
                } else {
                    self.prompToChoosePrimaryDesc(descriptors: descriptors)
                }
            }

        } else if let accountMap = TextFileImport.parse(item).accountMap,
                  let descriptor = accountMap["descriptor"] as? String {
            showDescriptorImport(descriptor)
            
        } else if item.contains("Format: "), let error = TextFileImport.parse(item).errMessage {
            showAlert(vc: self, title: "Unsupported wallet file.", message: error)
            
        } else {
            showAlert(vc: self, title: "Unsupported import.", message: item + " is not a supported import option, please let us know about this so we can add support.")
        }
    }
    
    // MARK: - Navigation

    private func showSeedWords() {
        let vc = SeedDisplayerViewController()
        vc.isSegwit = isSegwit
        vc.isTaproot = isTaproot
        vc.wordCount = seedWordCount
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func showScanner() {
        let vc = QRScannerViewController()
        vc.isImporting = true
        vc.onDoneBlock = { [weak self] item in
            guard let self = self else { return }
            
            guard let item = item else {
                return
            }
            
            #if(DEBUG)
            print("item: \(item)")
            #endif
            
            self.processImportedString(item)
        }
        present(vc, animated: true)
    }
    
    private func showMultisigCreator() {
        let vc = CreateMultisigViewController()
        // The multisig creator picks its own script (or takes it from the cosigner), not
        // from the single sig card.
        vc.cosigner = cosigner
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func showDescriptorImporter() {
        let vc = ImportXpubViewController()
        vc.descriptor = descriptor
        navigationController?.pushViewController(vc, animated: true)
    }
}
