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
    @IBOutlet weak var wordsTextView: UITextView!
    @IBOutlet weak var xpubField: UITextField!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var createOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createOutlet.clipsToBounds = true
        createOutlet.layer.cornerRadius = 8
        
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        
        wordsTextView.clipsToBounds = true
        wordsTextView.layer.cornerRadius = 8
        wordsTextView.layer.borderColor = UIColor.lightGray.cgColor
        wordsTextView.layer.borderWidth = 0.5
        
        wordsTextView.delegate = self
        xpubField.delegate = self
        
        spinner.addConnectingView(vc: self, description: "fetching chain type...")
        
        if ccXpub != "" && ccXfp != "" {
            derivationField.text = ccDeriv
            addKeyStore(ccXfp, ccXpub)
            showAlert(vc: self, title: "Coldcard xpub added ✅", message: "You can add more xpubs or tap the refresh button to get Fully Noded to create them for you. The seed words are *never* saved, make sure you write them down, they will be gone forever!")
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
        wordsTextView.resignFirstResponder()
        xpubField.resignFirstResponder()
        derivationField.resignFirstResponder()
    }
    
    @IBAction func refreshAction(_ sender: Any) {
        addSigner()
    }
    
    @IBAction func resetAction(_ sender: Any) {
        wordsTextView.text = ""
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
            self.wordsTextView.text = ""
            self.fingerprintField.text = ""
            self.xpubField.text = ""
            self.derivationField.isUserInteractionEnabled = false
        }
    }
    
    @IBAction func addAction(_ sender: Any) {
        guard let xpub = xpubField.text, xpub != "" else {
            showAlert(vc: self, title: "First you need to add an xpub", message: "Either paste an existing xpub or derive one by adding/creating bip39 seed words (signer) below 🔄.\n\nIf pasting your own xpub it is extremely important that is was derived from the specified derivation or you will not be able to spend from the wallet.")
            
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
    
    private func addSigner() {
        guard let words = Keys.seed() else {
            showAlert(vc: self, title: "Error", message: "We had a problem creating seed words...")
            
            return
        }
        
        convertWords(words: words)
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
            
            self.wordsTextView.text = ""
            self.fingerprintField.text = ""
            self.xpubField.text = ""
        }
    }
    
    private func convertWords(words: String) {
        guard let mk = Keys.masterKey(words: words, coinType: cointType, passphrase: ""),
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
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.xpubField.text = xpub
            self.fingerprintField.text = fingerprint
            self.wordsTextView.text = words
            let newPosition = self.xpubField.beginningOfDocument
            self.xpubField.selectedTextRange = self.xpubField.textRange(from: newPosition, to: newPosition)
        }
    }
    
    private func export(text: String) {
        if let url = exportMultisigWalletToURL(data: text.dataUsingUTF8StringEncoding) {
            DispatchQueue.main.async { [unowned vc = self] in
                let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    activityViewController.popoverPresentationController?.sourceView = self.view
                    activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
                }
                vc.present(activityViewController, animated: true) {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    }
                }
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == wordsTextView && wordsTextView.text != "" {
            convertWords(words: textView.text)
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == xpubField {
            let extendedKey = xpubField.text ?? ""
            if extendedKey != "" {
                if extendedKey.hasPrefix("xpub") || extendedKey.hasPrefix("tpub") {
                    if let _ = XpubConverter.zpub(xpub: extendedKey) {
                        
                    } else {
                        updateXpubField("")
                        showAlert(vc: self, title: "Error", message: "Invalid xpub")
                    }
                } else if extendedKey.hasPrefix("Zpub") || extendedKey.hasPrefix("Vpub") {
                    if let xpub = XpubConverter.convert(extendedKey: extendedKey) {
                        updateXpubField(xpub)
                        showAlert(vc: self, title: "Valid xpub ✅", message: "You added a Zpub or Vpub, which is fine but your node only understands xpubs, so we did you a favor and converted it for you.")
                    } else {
                        updateXpubField("")
                        showAlert(vc: self, title: "Error", message: "Invalid extended key. It must be either an xpub, tpub, Zpub or Vpub")
                    }
                }
            }
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView == wordsTextView {
            if let _ = Keys.masterKey(words: textView.text, coinType: cointType, passphrase: "") {
                convertWords(words: wordsTextView.text ?? "")
            }
        }
    }
    
    private func updateXpubField(_ xpub: String) {
        DispatchQueue.main.async { [weak self] in
            self?.xpubField.text = xpub
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
