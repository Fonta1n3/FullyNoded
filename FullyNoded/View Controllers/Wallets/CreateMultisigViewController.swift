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
    var cointType = "0"
    var blockheight = 0
    var m = Int()
    var n = Int()
    var keysString = ""
    var isDone = Bool()
    var ccXfp = ""
    var ccXpub = ""
    var ccDeriv = ""
    var keys = [[String:String]]()
    var alertStyle = UIAlertController.Style.actionSheet
    
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
        
        spinner.addConnectingView(vc: self, description: "fetching chain type...")
        
        if ccXpub != "" && ccXfp != "" {
            derivationField.text = ccDeriv
            addKeyStore(ccXfp, ccXpub)
            showAlert(vc: self, title: "Coldcard keystore added ✅", message: "")
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        if (UIDevice.current.userInterfaceIdiom == .pad) {
            alertStyle = UIAlertController.Style.alert
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        getChain()
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        fingerprintField.resignFirstResponder()
        textView.resignFirstResponder()
        xpubField.resignFirstResponder()
        derivationField.resignFirstResponder()
    }
    
    @IBAction func scanAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToScanXpubMsigCreator", sender: self)
        }
    }
    
    
    @IBAction func refreshAction(_ sender: Any) {
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
        guard let rawDerivationPath = derivationProcessed() else {
            return
        }
        
        let prefix = rawDerivationPath.replacingOccurrences(of: "m/", with: "\(xfp)/")
        
        keys.append(["fingerprint":xfp,"xpub":xpub])
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textView.text += "#\(self.keys.count):\n\n" + "Origin: [\(prefix)]\n\n" + "Key: " + xpub + "\n\n"
            self.fingerprintField.text = ""
            self.xpubField.text = ""
            self.derivationField.isUserInteractionEnabled = false
        }
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
        promptToCreate()
    }
    
    private func getChain() {
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary, let blocks = dict["blocks"] as? Int, let chain = dict["chain"] as? String else {
                self.spinner.removeConnectingView()
                
                guard let errorMessage = errorMessage else {
                    showAlert(vc: self, title: "Error", message: "error fetching chain type")
                    
                    return
                }
                
                showAlert(vc: self, title: "Error fetching chain type", message: errorMessage)
                
                return
            }
            
            self.blockheight = blocks
            
            if chain != "main" {
                self.cointType = "1"
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.derivationField.text = "m/48'/\(self.cointType)'/0'/2'"
                self.spinner.removeConnectingView()
            }
        }
    }
    
    private func promptToCreate() {
        guard keys.count > 0 else {
            let title = "You need to add keystores first"
            let message = "You can either add an xpub, or bip39 mnemonic to get Fully Noded to derive the correct keystore for you. Alternatively you may tap the refresh button to get Fully Noded to generate the seed words and derive the correct keystore for you."
            
            showAlert(vc: self, title: title, message: message)
            
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "How many signers are required to spend funds?", message: "", preferredStyle: self.alertStyle)
            
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
                let rawPrimDesc = "wsh(sortedmulti(\(m),\(descriptorKeys)))"
                let accountMap = ["descriptor":rawPrimDesc,"label":"\(m) of \(keys.count)", "blockheight": blockheight] as [String:Any]
                
                ImportWallet.accountMap(accountMap) { [weak self] (success, errorDescription) in
                    guard let self = self else { return }
                    
                    if success {
                        self.walletSuccessfullyCreated(mofn: "\(m) of \(self.keys.count)")
                    } else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "There was an error!", message: "Something went wrong during the wallet creation process: \(errorDescription ?? "unknown error")")
                    }
                }
            }
        }
    }
    
    private func walletSuccessfullyCreated(mofn: String) {
        isDone = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var message = "The wallet has been activated and the wallet view is refreshing, tap done to go back"
            var text = ""
            
            if self.ccXpub != "" {
                message = "It is important you export this text to your Coldcard as a .txt file otherwise your Coldcard will not be able to sign for this wallet. Tap \"export\" to save the file that can be uploaded to your Coldcard via the SD card."
                
                text = """
                Name: Fully Noded
                Policy: \(mofn)
                Derivation: \(self.derivationField.text ?? "error getting the derivation path, you should report this issue")
                Format: P2WSH
                
                \(self.keysString)
                """
                
                self.textView.text = text
            }
            
            self.spinner.removeConnectingView()
                    
            var alertStyle = UIAlertController.Style.actionSheet
            
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            
            let alert = UIAlertController(title: "\(mofn) successfully created ✓", message: message, preferredStyle: alertStyle)
            
            if self.ccXpub != "" {
                alert.addAction(UIAlertAction(title: "Export", style: .default, handler: { action in
                    self.export(text: text)
                }))
            } else {
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
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                }
            }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func derivationProcessed() -> String? {
        guard let text = derivationField.text?.replacingOccurrences(of: "’", with: "'"),
            Keys.vaildPath(text.replacingOccurrences(of: "’", with: "'")) else {
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
            
            let controller = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
            self.present(controller, animated: true) {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
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
    
    private func parseExtendedKey(_ extendedKey: String) {
        if extendedKey.hasPrefix("xpub") || extendedKey.hasPrefix("tpub") {
            if let _ = XpubConverter.zpub(xpub: extendedKey) {
                showAddButton()
            }
        } else if extendedKey.hasPrefix("Zpub") || extendedKey.hasPrefix("Vpub") {
            if let xpub = XpubConverter.convert(extendedKey: extendedKey) {
                updateXpubField(xpub)
                showAddButton()
            }
        } else if extendedKey.hasPrefix("[") {
            let p = DescriptorParser()
            let hack = "wpkh(\(extendedKey))"
            let descriptor = p.descriptor(hack)
            let key = descriptor.accountXpub
            let fingerprint = descriptor.fingerprint
            
            guard key != "", fingerprint != "" else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.addKeyStore(fingerprint, key)
            }
        } else if let data = extendedKey.data(using: .utf8) {
            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any],
                let xfp = json["xfp"] as? String,
                let xpub = json["xpub"] as? String,
                let path = json["path"] as? String else {
                    return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.derivationField.text = path
                self.addKeyStore(xfp, xpub)
            }
            
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
                parseExtendedKey(extendedKey)
            }
        }
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        guard textField == xpubField, let xpub = textField.text, xpub.count > 20 else { return }
        
        parseExtendedKey(xpub)
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
            guard let vc = segue.destination as? QRScannerViewController else { fallthrough }
            
            vc.isScanningAddress = true
            
            vc.onAddressDoneBlock = { [weak self] xpub in
                guard let self = self, let xpub = xpub else { return }
                
                self.parseExtendedKey(xpub)
            }
            
        case "segueToChooseSignerToDeriveXpub":
            guard let vc = segue.destination as? SignersViewController else { fallthrough }
            
            vc.isCreatingMsig = true
            
            vc.signerSelected = { [weak self] signer in
                guard let self = self, let words = Crypto.decrypt(signer.words) else { return }
                            
                guard let encryptedPassphrase = signer.passphrase else {
                    self.convertWords(words.utf8, "")
                    return
                }
                
                guard let passphrase = Crypto.decrypt(encryptedPassphrase) else { return }
                
                self.convertWords(words.utf8, passphrase.utf8)
            }
        default:
            break
        }
    }

}
