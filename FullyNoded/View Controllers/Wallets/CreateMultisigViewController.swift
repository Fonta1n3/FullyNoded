//
//  CreateMultisigViewController.swift
//  FullyNoded
//
//  Created by Peter on 8/29/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class CreateMultisigViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate {
    
    var spinner = ConnectingView()
    private var isNested = false
    var blockheight = 0
    var m = Int()
    var n = Int()
    var keysString = ""
    var isDone = false
    var cosigner: Descriptor?
    var keys = [[String:String]]()
    var alertStyle = UIAlertController.Style.alert
    var multiSigAccountDesc = ""
    var qrToExport = ""
    var isBbqr = false
    let jsonDecoder = JSONDecoder()
    
    @IBOutlet weak var derivationField: UITextField!
    @IBOutlet weak var fingerprintField: UITextField!
    @IBOutlet weak var xpubField: UITextField!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var createOutlet: UIButton!
    @IBOutlet weak var addOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addOutlet.alpha = 0
        
        createOutlet.clipsToBounds = true
        createOutlet.layer.cornerRadius = 8
        
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        
        xpubField.delegate = self
        
        fingerprintField.text = ""
                
        if let cosigner = cosigner {
            derivationField.text = cosigner.derivation
            addKeyStore(cosigner.fingerprint, cosigner.accountXpub == "" ? cosigner.accountXprv : cosigner.accountXpub)
            showAlert(vc: self, title: "Cosigner added ✓", message: "Add more or select create wallet.")
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    override func viewDidAppear(_ animated: Bool) {}
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        fingerprintField.resignFirstResponder()
        textView.resignFirstResponder()
        xpubField.resignFirstResponder()
        derivationField.resignFirstResponder()
    }
    
    @IBAction func pasteAction(_ sender: Any) {
        if let data = UIPasteboard.general.data(forPasteboardType: "com.apple.traditional-mac-plain-text") {
            guard let string = String(bytes: data, encoding: .utf8) else {
                showAlert(vc: self, title: "", message: "Looks like you do not have valid text on your clipboard.")
                return
            }
            
            parseImportedString(string)
        } else if let string = UIPasteboard.general.string {
            parseImportedString(string)
        } else {
            showAlert(vc: self, title: "", message: "Not a supported import item. Please let us know about it so we can add it.")
        }
    }
    
    
    @IBAction func scanAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToScanXpubMsigCreator", sender: self)
        }
    }
    
    
    @IBAction func refreshAction(_ sender: Any) {
        guard self.derivationField.text == "m/48'/\(self.cointType)'/0'/2'" || self.derivationField.text == "m/48h/\(self.cointType)h/0h/2h" || self.derivationField.text == "m/48’/1’/0’/2’" else {
            showAlert(vc: self, title: "", message: "You can not use custom derivations when deriving a cosigner from an existing signer. Derivation must be set to m/48'/\(self.cointType)'/0'/2'")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToChooseSignerToDeriveXpub", sender: self)
        }
    }
    
    @IBAction func resetAction(_ sender: Any) {
        fingerprintField.text = ""
        xpubField.text = ""
        textView.text = ""
        keys.removeAll()
    }
    
    private func addKeyStore(_ xfp: String, _ xpub: String) {
            guard let rawDerivationPath = derivationProcessed() else { return }
            let prefix = rawDerivationPath.replacingOccurrences(of: "m/", with: "\(xfp)/")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.keys.append(["fingerprint":xfp,"xpub":xpub])
            self.textView.text += self.keystring(prefix: prefix, xpub: xpub)
            self.fingerprintField.text = ""
            self.xpubField.text = ""
        }
    }
    
    private func keystring(prefix: String, xpub: String) -> String {
        return "#\(self.keys.count):\n\n" + "Origin: [\(prefix)]\n\n" + "Key: " + xpub + "\n\n"
    }
    
    @IBAction func addAction(_ sender: Any) {
        guard let xpub = xpubField.text, xpub != "" else {
            showAlert(vc: self, title: "First you need to add an xpub", message: "")
            
            return
        }
        
        let fingerprint = fingerprintField.text ?? ""
        
        guard fingerprint != "" else {
            guard let fp = Keys.fingerprint(masterKey: xpub) else {
                showAlert(vc: self, title: "Unable to derive fingerprint", message: "We had an issue deriving the fingerprint from that xpub, please reset and try again.")
                
                return
            }
            
            addKeyStore(fp, xpub)
            
            return
        }
        
        addKeyStore(fingerprint, xpub)
    }
    
    @IBAction func createButton(_ sender: Any) {
        if !isDone {
            if keys.count > 1 {
                promptToCreate()
            } else {
                showAlert(vc: self, title: "Add more cosigners first.", message: "Creating a multi-sig wallet with one cosigner is pointless...")
            }
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                if self.navigationController != nil {
                    self.navigationController?.popToRootViewController(animated: true)
                } else {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
    
    var cointType: String {
        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        switch chain {
        case "main":
            return "0"
        default:
            return "1"
        }
    }
    
    private func promptToCreate() {
        guard keys.count > 0 else {
            let title = "You need to add cosigners first"
            let message = "Add an xpub or bip39 mnemonic from which a cosigner will be derived. Tap the refresh button to get Fully Noded to generate a new cosigner for you."
            
            showAlert(vc: self, title: title, message: message)
            
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "How many signatures are required to spend funds?", message: "", preferredStyle: self.alertStyle)
            
            for (i, _) in self.keys.enumerated() {
                alert.addAction(UIAlertAction(title: "\(i + 1)", style: .default, handler: { action in
                    self.create(m: i + 1)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func create(m: Int) {
        spinner.addConnectingView(vc: self, description: "creating multisig wallet...")
        
        var descriptorKeys = ""
        
        for (i, signer) in keys.enumerated() {
            guard let fingerprint = signer["fingerprint"], var xpub = signer["xpub"] else {
                self.spinner.removeConnectingView()
                
                showAlert(vc: self, title: "Something is missing", message: "Either the xpub or fingerprint was not added... Please tap the trashcan to reset everything and try again.")
                
                return
            }
            
            if !xpub.hasPrefix("xpub") && !xpub.hasPrefix("tpub") {
                guard let convertedXpub = XpubConverter.convert(extendedKey: xpub) else {
                    self.spinner.removeConnectingView()
                    
                    showAlert(vc: self, title: "Invalid extended key", message: "Only valid extended public keys are allowed. Please tap the trashcan to reset everything and try again.")
                    
                    return
                }
                
                xpub = convertedXpub
            }
            
            guard let derivationPathProcessed = derivationProcessed()?.replacingOccurrences(of: "m/", with: "") else {
                self.spinner.removeConnectingView()
                
                showAlert(vc: self, title: "Invalid derivation", message: "Only valid derivation paths that start with m/ are allowed. Please tap the trashcan to reset everything and try again.")
                
                return
            }
            
            descriptorKeys += "[\(fingerprint)/\(derivationPathProcessed)]\(xpub)/0/*"
            keysString += "\(fingerprint):\(xpub)\n\n"
            
            if i < keys.count - 1 {
                descriptorKeys += ","
            }
            
            if i + 1 == keys.count {
                var rawPrimDesc = "wsh(sortedmulti(\(m),\(descriptorKeys)))"
                
                if isNested {
                    rawPrimDesc = "sh(wsh(sortedmulti(\(m),\(descriptorKeys))))"
                }
                
                multiSigAccountDesc = rawPrimDesc
                
                let accountMap = ["descriptor": rawPrimDesc,"label": "\(m) of \(keys.count)", "blockheight": blockheight] as [String:Any]
                
                ImportWallet.accountMap(accountMap) { [weak self] (success, errorDescription) in
                    guard let self = self else { return }
                    
                    if success {
                        self.exportWallet(mofn: "\(m) of \(self.keys.count)")
                    } else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "There was an error!", message: "Something went wrong during the wallet creation process: \(errorDescription ?? "unknown error")")
                    }
                }
            }
        }
    }
    
    private func exportWallet(mofn: String) {
        isDone = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.createOutlet.setTitle("Done", for: .normal)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var message = "The wallet has been activated and the wallet view is refreshing, tap done to go back"
            var text = ""
            
                message = "Export the wallet as a text file (compatible with Coldcard) or QR code (compatible with Passport, Sparrow, Blue Wallet and more)."
                
                text = """
                Name: Fully Noded
                Policy: \(mofn)
                Derivation: \(self.derivationField.text ?? "error getting the derivation path, you should report this issue")
                Format: P2WSH
                
                \(self.keysString)
                """
                
                self.textView.text = text
            
            self.spinner.removeConnectingView()
            
            var alertStyle = UIAlertController.Style.actionSheet
            
            if (UIDevice.current.userInterfaceIdiom == .pad) {
                alertStyle = UIAlertController.Style.alert
            }
            
            let alert = UIAlertController(title: "\(mofn) successfully created ✓", message: message, preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Export Text File (Coldcard)", style: .default, handler: { action in
                self.export(text: text)
            }))
            
            alert.addAction(UIAlertAction(title: "Export UR QR Code", style: .default, handler: { action in
                guard let ur = URHelper.dataToUrBytes(text.utf8) else {
                    showAlert(vc: self, title: "Error", message: "Unable to convert the text into a UR.")
                    return
                }
                
                self.qrToExport = ur.qrString
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.performSegue(withIdentifier: "segueToExportMsig", sender: self)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Export BBQr", style: .default, handler: { action in
                self.qrToExport = text
                self.isBbqr = true
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.performSegue(withIdentifier: "segueToExportMsig", sender: self)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { action in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    if self.navigationController != nil {
                        self.navigationController?.popToRootViewController(animated: true)
                    } else {
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func derivationProcessed() -> String? {
        guard let text = derivationField.text?.replacingOccurrences(of: "’", with: "'"),
            Keys.validPath(text.replacingOccurrences(of: "’", with: "'")) else {
            return nil
        }
        
        return text
    }
    
    private func clear() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.fingerprintField.text = ""
            self.xpubField.text = ""
        }
    }
    
    private func convertWords(_ words: String, _ passphrase: String) {
        guard let mk = Keys.masterKey(words: words, coinType: cointType, passphrase: passphrase),
            let fingerprint = Keys.fingerprint(masterKey: mk) else {
                clear()
                showAlert(vc: self, title: "Invalid words", message: "The words need to conform with BIP39")
                return
        }
        
        guard let derivationPath = derivationProcessed() else {
            clear()
            showAlert(vc: self, title: "Invalid derivation", message: "You must input a valid bip32 derivation path, when in doubt stick with the default")
            return
        }
        
        guard let xpub = Keys.xpub(path: derivationPath, masterKey: mk),
            let _ = XpubConverter.zpub(xpub: xpub) else {
                clear()
                showAlert(vc: self, title: "Unable to derive xpub", message: "Looks like you added an invalid extended key")
                return
        }
        
        self.addKeyStore(fingerprint, xpub)
    }
    
    private func export(text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            let fileURL = fileManager.temporaryDirectory.appendingPathComponent("Coldcard-Import.txt")
            
            try? text.dataUsingUTF8StringEncoding.write(to: fileURL)
            
            if #available(iOS 14, *) {
                let controller = UIDocumentPickerViewController(forExporting: [fileURL]) // 5
                self.present(controller, animated: true) {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    }
                }
            } else {
                let controller = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
                self.present(controller, animated: true) {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    }
                }
            }
        }
    }
    
    private func showAddButton() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addOutlet.alpha = 1
            self.xpubField.resignFirstResponder()
        }
    }
    
    private func showError() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            showAlert(vc: self, title: "", message: "Something went wrong, please let us know about it.")
        }
    }
    
    private func parseImportedString(_ item: String) {
        if item.hasPrefix("xpub") || item.hasPrefix("tpub") {
            if let _ = XpubConverter.zpub(xpub: item) {
                showAddButton()
            } else {
                showError()
            }
        } else if item.hasPrefix("Zpub") || item.hasPrefix("Vpub") || item.hasPrefix("Ypub") || item.hasPrefix("Upub") {
            if let xpub = XpubConverter.convert(extendedKey: item) {
                updateXpubField(xpub)
                showAddButton()
                if item.hasPrefix("Ypub") || item.hasPrefix("Upub") {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.isNested = true
                        self.derivationField.text = self.derivationField.text!.replacingOccurrences(of: "/2'", with: "/1'")
                    }
                }
            } else {
                showError()
            }
        } else if item.hasPrefix("[") {
            parseDescriptor(Descriptor("wsh(\(item))"))
            
        } else if item.lowercased().hasPrefix("wsh(") || item.lowercased().hasPrefix("sh(wsh(") {
            parseDescriptor(Descriptor(item))
            
        } else if item.lowercased().hasPrefix("ur:crypto-hdkey") || item.lowercased().hasPrefix("ur:crypto-account") || item.lowercased().hasPrefix("ur:crypto-seed") {
            let (descriptors, error) = URHelper.parseUr(urString: item.lowercased())
            guard error == nil, let descriptors = descriptors, descriptors.count > 0 else {
                showAlert(vc: self, title: "Error", message: error ?? "Unknown error decoding the QR code.")
                return
            }
            
            for descriptor in descriptors {
                let str = Descriptor(descriptor)
                if str.isCosigner && str.derivation == self.derivationField.text?.replacingOccurrences(of: "h", with: "'") {
                    parseDescriptor(str)
                    break
                } else {
                    showAlert(vc: self, title: "There was an issue...", message: "It does not look like any of the supplied cosigners match the \(self.derivationField.text ?? "?") derivation path. For now the multisig creator only supports one derivation path per cosigner.")
                }
            }
            
        } else if item.lowercased().hasPrefix("ur:bytes") {
            let (text, err) = URHelper.parseBlueWalletCoordinationSetup(item.lowercased())
            if let textFile = text {
                if let dict = try? JSONSerialization.jsonObject(with: textFile.utf8, options: []) as? [String:Any] {
                    let importStruct = WalletImport(dict)
                    
                    if let bip48 = importStruct.bip48 {
                        parseDescriptor(Descriptor(bip48))
                    }
                    
                } else if let accountMap = TextFileImport.parse(textFile).accountMap {
                    let desc = accountMap["descriptor"] as? String ?? ""
                    let descriptorStr = Descriptor(desc)
                    
                    if descriptorStr.keysWithPath.count > 1 {
                        // add multiple keys at once
                        for msigKey in descriptorStr.keysWithPath {
                            let hack = "wsh(\(msigKey)"
                            let descHack = Descriptor(hack)
                            parseDescriptor(descHack)
                        }
                    } else {
                        parseDescriptor(Descriptor(desc))
                    }
                } else {
                    showAlert(vc: self, title: "Error", message: err ?? "Unknown error decoding the text file into a descriptor.")
                }
            } else {
                showAlert(vc: self, title: "Error", message: err ?? "Unknown error decoding the QR code.")
            }
            
        } else if let coldcardMultisigExport = try? jsonDecoder.decode(ColdcardMultiSigExport.self, from: item.utf8) {
            guard let deriv = coldcardMultisigExport.p2wsh_deriv else { return }
            guard let xfp = coldcardMultisigExport.xfp else { return }
            guard let p2wsh = coldcardMultisigExport.p2wsh else { return}
            guard let xpub = XpubConverter.convert(extendedKey: p2wsh) else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.derivationField.text = deriv
                self.addKeyStore(xfp, xpub)
            }
            
        } else if let data = item.data(using: .utf8) {
                guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any],
                    let xfp = json["xfp"] as? String,
                    let xpub = json["xpub"] as? String,
                    let path = json["path"] as? String else {
                    
                    showError()
                    
                    return
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.derivationField.text = path
                    self.addKeyStore(xfp, xpub)
                }
                
        } else {
            showAlert(vc: self, title: "Unrecognized cosigner format.", message: item + " is not a recognized cosigner format. Please reach out to us so that we can add support for this.")
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
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addKeyStore(fingerprint, key)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == xpubField {
            let extendedKey = xpubField.text ?? ""
            if extendedKey != "" && extendedKey.count > 20 {
                parseImportedString(extendedKey)
            }
        }
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        guard textField == xpubField, let xpub = textField.text, xpub.count > 20 else { return }
        
        parseImportedString(xpub)
    }
    
    private func updateXpubField(_ xpub: String) {
        DispatchQueue.main.async { [weak self] in
            self?.xpubField.text = xpub
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "segueToScanXpubMsigCreator":
            if #available(macCatalyst 14.0, *) {
                guard let vc = segue.destination as? QRScannerViewController else { fallthrough }
                vc.isImporting = true
                
                vc.onDoneBlock = { [weak self] xpub in
                    guard let self = self, let xpub = xpub else { return }
                                        
                    self.parseImportedString(xpub)
                }
            } else {
                // Fallback on earlier versions
            }            
            
        case "segueToChooseSignerToDeriveXpub":
            guard let vc = segue.destination as? SignersViewController else { fallthrough }
            
            vc.isCreatingMsig = true
            
            vc.signerSelected = { [weak self] signer in
                guard let self = self, let encryptedWords = signer.words, let words = Crypto.decrypt(encryptedWords) else { return }
                            
                guard let encryptedPassphrase = signer.passphrase else {
                    self.convertWords(words.utf8String ?? "", "")
                    return
                }
                
                guard let passphrase = Crypto.decrypt(encryptedPassphrase) else { return }
                
                self.convertWords(words.utf8String ?? "", passphrase.utf8String ?? "")
            }
            
        
        case "segueToExportMsig":
            guard let vc = segue.destination as? QRDisplayerViewController else { return }
            
            vc.text = self.qrToExport
            vc.isBbqr = self.isBbqr
            vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
            
            if isBbqr {
                vc.headerText = "Multisig Wallet BBQr"
            } else {
                vc.headerText = "Multisig Wallet UR Bytes"
            }
         
        default:
            break
        }
    }

}
