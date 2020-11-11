//
//  CreateFullyNodedWalletViewController.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit
import AVFoundation

class CreateFullyNodedWalletViewController: UIViewController, UINavigationControllerDelegate, UIDocumentPickerDelegate, UIImagePickerControllerDelegate {
    
    @IBOutlet weak var uploadOutlet: UIButton!
    @IBOutlet weak var multiSigOutlet: UIButton!
    @IBOutlet weak var singleSigOutlet: UIButton!
    @IBOutlet weak var recoveryOutlet: UIButton!
    @IBOutlet weak var importOutlet: UIButton!
    @IBOutlet weak var importXpubOutlet: UIButton!
    
    let imagePicker = UIImagePickerController()
    var onDoneBlock:(((Bool)) -> Void)?
    var spinner = ConnectingView()
    var alertStyle = UIAlertController.Style.actionSheet
    var ccXfp = ""
    var xpub = ""
    var deriv = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        singleSigOutlet.layer.cornerRadius = 8
        recoveryOutlet.layer.cornerRadius = 8
        importOutlet.layer.cornerRadius = 8
        multiSigOutlet.layer.cornerRadius = 8
        uploadOutlet.layer.cornerRadius = 8
        importXpubOutlet.layer.cornerRadius = 8
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
        checkPasteboard()
    }
    
    private func configureImagePicker() {
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
    }
    
    @IBAction func importXpubAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToImportXpub", sender: self)
        }
    }
    
    
    @IBAction func uploadFileAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Upload a file?", message: "Here you can upload files from your Hardware Wallets to easily create Fully Noded Wallet's", preferredStyle: vc.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Upload", style: .default, handler: { [unowned vc = self] action in
                let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)//public.item in iOS and .import
                documentPicker.delegate = vc
                documentPicker.modalPresentationStyle = .formSheet
                vc.present(documentPicker, animated: true, completion: nil)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    
    @IBAction func automaticAction(_ sender: Any) {
        guard let _ = KeyChain.getData("UnlockPassword") else {
            showAlert(vc: self, title: "Whoa, you are not using the app securely", message: "Single signature wallets store seed words on the app, you need to go to the home screen and tap the lock button to create a locking password before the app can hold seed words.")
            
            return
        }
        
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToSeedWords", sender: vc)
        }
    }
    
    @IBAction func manualAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "seguToManualCreation", sender: vc)
        }
    }
    
    @IBAction func createMultiSigAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToCreateMultiSig", sender: vc)
        }
    }
    
    @IBAction func howHelp(_ sender: Any) {
        let message = "You have the option to either create a Fully Noded Wallet or a Recovery Wallet, to read more about recovery tap it and then tap the help button in the recovery view. Fully Noded single sig wallets are BIP84 but watch for and can sign for all address types, you may create invoices in any address format and still spend your funds. You will get a 12 word BIP39 recovery phrase to backup, these seed words are encrypted and stored using your devices secure enclave (no passphrase). Your node ONLY holds public keys. Your device will be able to sign for any derivation path and the encrypted seed is stored independently of your wallet. With Fully Noded your node will build an unsigned psbt then the device will sign it locally, acting like a hardware wallet, we then pass it back to your node as a fully signed raw transaction for broadcasting."
        showAlert(vc: self, title: "Fully Noded Wallet", message: message)
    }
    
    @IBAction func importAction(_ sender: Any) {
        #if targetEnvironment(macCatalyst)
            configureImagePicker()
            chooseQRCodeFromLibrary()
        #else
            DispatchQueue.main.async { [unowned vc = self] in
                vc.performSegue(withIdentifier: "segueToScanner", sender: vc)
            }
        #endif
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if controller.documentPickerMode == .import {
            
            guard let data = try? Data(contentsOf: urls[0].absoluteURL), let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
                spinner.removeConnectingView()
                showAlert(vc: self, title: "Ooops", message: "That does not appear to be a recognized wallet backup/export/import file")
                return
            }
            
            if let _ = dict["chain"] as? String {
                /// We think its a coldcard skeleton import
                promptToImportColdcardSingleSig(dict)
                
            } else if let deriv = dict["p2wsh_deriv"] as? String, let xfp = dict["xfp"] as? String, let p2wsh = dict["p2wsh"] as? String {
                /// It is most likely a multi-sig wallet export
                promptToImportColdcardMsig(xfp, p2wsh, deriv)
                
            } else if let _ = dict["wallet_type"] as? String {
                /// We think its an Electrum wallet
                promptToImportElectrumMsig(dict)
                
            } else if let _ = dict["descriptor"] as? String {
                promptToImportAccountMap(dict: dict)
                
            } else {
                
            }
        }
    }
    
    private func promptToImportElectrumMsig(_ dict: [String:Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Import your Electrum multisig wallet?", message: "Looks like you selected an Electrum wallet backup file. You can easily recreate the wallet as watchonly with Fully Noded, just tap \"import\".", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "import", style: .default, handler: { action in
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
        
        return ["descriptor": descriptor, "blockheight": 0, "watching": [], "label": "Electrum wallet"]
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
    
    private func promptToImportColdcardMsig(_ xfp: String, _ xpub: String, _ deriv: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Create a multisig with your Coldcard?", message: "You have uploaded a Coldcard multisig file, this action allows you to easily create a wallet with your Coldcard and Fully Noded.", preferredStyle: vc.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.ccXfp = xfp
                    vc.xpub = xpub
                    vc.deriv = deriv
                    vc.performSegue(withIdentifier: "segueToCreateMultiSig", sender: vc)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToImportColdcardSingleSig(_ coldcard: [String:Any]) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Create a single sig with your Coldcard?", message: "You have uploaded a Coldcard single sig file, this action will recreate your Coldcard wallet on Fully Noded using its xpubs.", preferredStyle: vc.alertStyle)
            
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
    
    private func checkPasteboard() {
        let pastboard = UIPasteboard.general
        if let text = pastboard.string {
            if let data = text.data(using: .utf8) {
                do {
                    let accountMap = try JSONSerialization.jsonObject(with: data, options: []) as! [String:Any]
                    promptToImportAccountMap(dict: accountMap)
                } catch {
                    
                }
            }
        }
    }
    
    private func importAccountMap(_ accountMap: [String:Any]) {
        spinner.addConnectingView(vc: self, description: "importing...")
        
        func importAccount() {
            if let _ = accountMap["descriptor"] as? String {
                if let _ = accountMap["blockheight"] as? Int {
                    /// It is an Account Map.
                    ImportWallet.accountMap(accountMap) { (success, errorDescription) in
                        if success {
                            DispatchQueue.main.async {
                                self.spinner.removeConnectingView()
                                self.onDoneBlock!(true)
                                self.navigationController?.popViewController(animated: true)
                            }
                        } else {
                            self.spinner.removeConnectingView()
                            showAlert(vc: self, title: "Error", message: "There was an error importing your wallet: \(errorDescription ?? "unknown")")
                        }
                    }
                }
            }
        }
        
        if let url = accountMap["quickConnect"] as? String {
            QuickConnect.addNode(uncleJim: true, url: url) { (success, errorMessage) in
                guard success else {
                    self.spinner.removeConnectingView()
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
            let alert = UIAlertController(title: "Import wallet?", message: "Looks like you have selected a valid wallet format ✅", preferredStyle: vc.alertStyle)
            alert.addAction(UIAlertAction(title: "Import", style: .default, handler: { [unowned vc = self] action in
                vc.importAccountMap(dict)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func chooseQRCodeFromLibrary() {
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // Local variable inserted by Swift 4.2 migrator.
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        if let pickedImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage {
            let detector:CIDetector=CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh])!
            let ciImage:CIImage = CIImage(image:pickedImage)!
            var qrCodeLink = ""
            let features = detector.features(in: ciImage)
            for feature in features as! [CIQRCodeFeature] {
                qrCodeLink += feature.messageString!
            }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            picker.dismiss(animated: true, completion: { [weak self] in
                if let dict = try? JSONSerialization.jsonObject(with: qrCodeLink.dataUsingUTF8StringEncoding, options: []) as? [String:Any] {
                    self?.promptToImportAccountMap(dict: dict)
                }
            })
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToScanner" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isAccountMap = true
                
                vc.onImportDoneBlock = { [unowned thisVc = self] accountMap in
                    if accountMap != nil {
                        thisVc.importAccountMap(accountMap!)
                    }
                }
                
                vc.onQuickConnectDoneBlock = { [weak self] url in
                    guard let url = url else { return }
                    
                    QuickConnect.addNode(uncleJim: false, url: url) { (success, errorMessage) in
                        guard success else {
                            showAlert(vc: self, title: "There was an issue", message: errorMessage ?? "error adding that wallet")
                            return
                        }
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.spinner.removeConnectingView()
                            self.onDoneBlock!(true)
                            self.navigationController?.popViewController(animated: true)
                        }
                    }
                }
            }
        }
        if segue.identifier == "segueToCreateMultiSig" {
            if let vc = segue.destination as? CreateMultisigViewController {
                vc.ccXfp = ccXfp
                vc.ccXpub = xpub
                vc.ccDeriv = deriv
            }
        }
    }
}

fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
    return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
    return input.rawValue
}
