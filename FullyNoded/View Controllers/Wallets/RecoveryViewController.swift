//
//  RecoveryViewController.swift
//  BitSense
//
//  Created by Peter on 29/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit
import LibWally

class RecoveryViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    var coinType = "0"
    var recoverSamourai = Bool()
    var descriptorsToImport = [String]()
    var accountNumber = "0"
    var primDesc = ""
    var changeDesc = ""
    var name = ""
    var spinner = ConnectingView()
    var addedWords = [String]()
    var justWords = [String]()
    var bip39Words = [String]()
    let label = UILabel()
    var autoCompleteCharacterCount = 0
    var timer = Timer()
    var blockheight:Int64!
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var wordView: UIView!
    @IBOutlet weak var recoverOutlet: UIButton!
    @IBOutlet weak var accountField: UITextField!
    @IBOutlet weak var passphraseField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        passphraseField.delegate = self
        accountField.delegate = self
        textField.delegate = self
        wordView.layer.cornerRadius = 8
        wordView.layer.borderColor = UIColor.lightGray.cgColor
        wordView.layer.borderWidth = 0.5
        recoverOutlet.clipsToBounds = true
        recoverOutlet.layer.cornerRadius = 8
        recoverOutlet.isEnabled = false
        bip39Words = Words.valid
        updatePlaceHolder(wordNumber: 1)
        accountField.text = "0"
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        setCoinType()
    }
    
    @IBAction func showHelp(_ sender: Any) {
        let message = "This tool allows you to import a BIP39 recovery phrase along with an optional passphrase and customizable account number. The recovery tool can take around 1 minute to complete. This is because it constructs most of the popular wallet derivation paths BIP44/49/84 and imports all address types for each derivation. It accounts for change and receive keys importing 2500 keys for each. Optionally you may opt to recover Samourai wallet derivations too (Ricochet, BadBank, Deposit, BIP47, PreMix, PostMix), this will add another minute or so. Once the recovery wallet is created it will rescan your blockchain. Your seed words are encrypted and saved locally, NOT on your node, your node will only hold the public keys"
        showAlert(vc: self, title: "Recovery", message: message)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        hideKeyboards()
    }
    
    private func hideKeyboards() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.accountField.resignFirstResponder()
            vc.textField.resignFirstResponder()
            vc.passphraseField.resignFirstResponder()
        }
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if passphraseField.isEditing {
            if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
                if self.view.frame.origin.y == 0 {
                    self.view.frame.origin.y -= keyboardSize.height
                }
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if passphraseField.isEditing {
            if self.view.frame.origin.y != 0 {
                self.view.frame.origin.y = 0
            }
        }
    }
    
    private func setCoinType() {
        spinner.addConnectingView(vc: self, description: "fetching chain type...")
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { [unowned vc = self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let chain = dict["chain"] as? String {
                    if chain == "test" {
                        vc.coinType = "1"
                    }
                    if let blocks = dict["blocks"] as? Int {
                        vc.blockheight = Int64(blocks)
                    }
                    vc.spinner.removeConnectingView()
                }
            } else {
                vc.showError(error: "Error getting blockchain info, please chack your connection to your node.")
                DispatchQueue.main.async {
                    vc.navigationController?.popToRootViewController(animated: true)
                }
            }
        }
    }
    
    private func promptRecoveryOptions() {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Would you like to include Samourai Wallet/Mixing derivation paths?", message: "Selecting yes will ensure all Samourai paths are recovered however will double the amount of time it takes to create the Recovery Wallet.", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Yes, include", style: .default, handler: { [unowned vc = self] action in
                vc.recoverSamourai = true
                vc.recoverNow()
            }))
            alert.addAction(UIAlertAction(title: "No, do not", style: .default, handler: { [unowned vc = self] action in
                vc.recoverSamourai = false
                vc.recoverNow()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func showError(error:String) {
        DispatchQueue.main.async { [unowned vc = self] in
            UserDefaults.standard.removeObject(forKey: "walletName")
            vc.spinner.removeConnectingView()
            showAlert(vc: vc, title: "Error", message: error)
        }
    }
    
    @objc func handleTap() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.textField.resignFirstResponder()
            vc.accountField.resignFirstResponder()
        }
    }
    
    private func updatePlaceHolder(wordNumber: Int) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.textField.attributedPlaceholder = NSAttributedString(string: "add word #\(wordNumber)", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        }
    }
    
    private func updateSpinnerText(text: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.spinner.label.text = text
        }
    }
    
    private func recoverNow() {
        spinner.addConnectingView(vc: self, description: "creating your recovery wallet...")
        
        accountNumber = accountField.text ?? "0"
        let passphrase = passphraseField.text ?? ""
        let seed = justWords.joined(separator: " ")
        
        if let mk = Keys.masterKey(words: seed, coinType: coinType, passphrase: passphrase) {
            createWallet(mk: mk) { [unowned vc = self] success in
                if success {
                    if vc.recoverSamourai {
                        vc.updateSpinnerText(text: "getting Samourai Bad Bank primary descriptor...")
                        vc.getDescriptorInfo(desc: vc.samouraiBadBankPrim(mk)) { [unowned vc = self] sam2DescPrim in
                            if sam2DescPrim != nil {
                                vc.descriptorsToImport.append(sam2DescPrim!)
                                vc.updateSpinnerText(text: "getting Samourai Bad Bank change descriptor...")
                                vc.getDescriptorInfo(desc: vc.samouraiBadBankChange(mk)) { [unowned vc = self] sam2DescChange in
                                    if sam2DescChange != nil {
                                        vc.descriptorsToImport.append(sam2DescChange!)
                                        vc.updateSpinnerText(text: "getting Samourai Pre Mix primary descriptor...")
                                        vc.getDescriptorInfo(desc: vc.samouraiPreMixPrim(mk)) { [unowned vc = self] samDesc3Prim in
                                            if samDesc3Prim != nil {
                                                vc.descriptorsToImport.append(samDesc3Prim!)
                                                vc.updateSpinnerText(text: "getting Samourai Pre Mix change descriptor...")
                                                vc.getDescriptorInfo(desc: vc.samouraiPreMixChange(mk)) { [unowned vc = self] samDesc3Change in
                                                    if samDesc3Change != nil {
                                                        vc.descriptorsToImport.append(samDesc3Change!)
                                                        vc.updateSpinnerText(text: "getting Samourai Post Mix primary descriptor...")
                                                        vc.getDescriptorInfo(desc: vc.samouraiPostMixPrim(mk)) { [unowned vc = self] samDesc4Prim in
                                                            if samDesc4Prim != nil {
                                                                vc.descriptorsToImport.append(samDesc4Prim!)
                                                                vc.updateSpinnerText(text: "getting Samourai Post Mix change descriptor...")
                                                                vc.getDescriptorInfo(desc: vc.samouraiPostMixChange(mk)) { [unowned vc = self] samDesc4Change in
                                                                    if samDesc4Change != nil {
                                                                        vc.descriptorsToImport.append(samDesc4Change!)
                                                                        vc.updateSpinnerText(text: "getting Samourai Ricochet 84 primary descriptor...")
                                                                        vc.getDescriptorInfo(desc: vc.samouraiRicochet84Prim(mk)) { [unowned vc = self] samDesc5Prim in
                                                                            if samDesc5Prim != nil {
                                                                                vc.descriptorsToImport.append(samDesc5Prim!)
                                                                                vc.updateSpinnerText(text: "getting Samourai Samourai Ricochet 84 change descriptor...")
                                                                                vc.getDescriptorInfo(desc: vc.samouraiRicochet84Change(mk)) { [unowned vc = self] samDesc5Change in
                                                                                    if samDesc5Change != nil {
                                                                                        vc.descriptorsToImport.append(samDesc5Change!)
                                                                                        vc.updateSpinnerText(text: "getting Samourai Ricochet 44 primary descriptor...")
                                                                                        vc.getDescriptorInfo(desc: vc.samouraiRicochet44Prim(mk)) { [unowned vc = self] samDesc6Prim in
                                                                                            if samDesc6Prim != nil {
                                                                                                vc.descriptorsToImport.append(samDesc6Prim!)
                                                                                                vc.updateSpinnerText(text: "getting Samourai Ricochet 44 change descriptor...")
                                                                                                vc.getDescriptorInfo(desc: vc.samouraiRicochet44Change(mk)) { [unowned vc = self] samDesc6Change in
                                                                                                    if samDesc6Change != nil {
                                                                                                        vc.descriptorsToImport.append(samDesc6Prim!)
                                                                                                        vc.updateSpinnerText(text: "getting Samourai Ricochet 49 primary descriptor...")
                                                                                                        vc.getDescriptorInfo(desc: vc.samouraiRicochet49Prim(mk)) { [unowned vc = self] samDesc7Prim in
                                                                                                            if samDesc7Prim != nil {
                                                                                                                vc.descriptorsToImport.append(samDesc7Prim!)
                                                                                                                vc.updateSpinnerText(text: "getting Samourai Ricochet 49 change descriptor...")
                                                                                                                vc.getDescriptorInfo(desc: vc.samouraiRicochet49Change(mk)) { samDesc7Change in
                                                                                                                    if samDesc7Change != nil {
                                                                                                                        vc.descriptorsToImport.append(samDesc7Change!)
                                                                                                                        vc.getNonSamouraiDescriptors(masterKey: mk)
                                                                                                                    }
                                                                                                                }
                                                                                                            }
                                                                                                        }
                                                                                                    }
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                    }
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        vc.getNonSamouraiDescriptors(masterKey: mk)
                    }
                }
            }
        } else {
            
        }
    }
    
    @IBAction func recoverAction(_ sender: Any) {
        promptRecoveryOptions()
    }
    
    private func getNonSamouraiDescriptors(masterKey: String) {
        updateSpinnerText(text: "getting BIP84 primary descriptor...")
        getDescriptorInfo(desc: bip84PrimDesc(masterKey)) { [unowned vc = self] bip84Prim in
            if bip84Prim != nil {
                vc.descriptorsToImport.append(bip84Prim!)
                vc.updateSpinnerText(text: "getting BIP84 change descriptor...")
                vc.getDescriptorInfo(desc: vc.bip84ChangeDesc(masterKey)) { [unowned vc = self] bip84Change in
                    if bip84Change != nil {
                        vc.descriptorsToImport.append(bip84Change!)
                        vc.updateSpinnerText(text: "getting BIP49 primary descriptor...")
                        vc.getDescriptorInfo(desc: vc.bip49PrimDesc(masterKey)) { [unowned vc = self] bip49Prim in
                            if bip49Prim != nil {
                                vc.descriptorsToImport.append(bip49Prim!)
                                vc.updateSpinnerText(text: "getting BIP49 change descriptor...")
                                vc.getDescriptorInfo(desc: vc.bip49ChangeDesc(masterKey)) { [unowned vc = self] bip49Change in
                                    if bip49Change != nil {
                                        vc.descriptorsToImport.append(bip49Change!)
                                        vc.updateSpinnerText(text: "getting BIP44 primary descriptor...")
                                        vc.getDescriptorInfo(desc: vc.bip44PrimDesc(masterKey)) { [unowned vc = self] bip44Prim in
                                            if bip44Prim != nil {
                                                vc.descriptorsToImport.append(bip44Prim!)
                                                vc.updateSpinnerText(text: "getting BIP44 change descriptor...")
                                                vc.getDescriptorInfo(desc: vc.bip44ChangeDesc(masterKey)) { [unowned vc = self] bip44Change in
                                                    if bip44Change != nil {
                                                        vc.descriptorsToImport.append(bip44Change!)
                                                        vc.updateSpinnerText(text: "getting BRD wallet primary descriptor...")
                                                        vc.getDescriptorInfo(desc: vc.brdPrimDesc(masterKey)) { [unowned vc = self] (bdrPrimDesd) in
                                                            if bdrPrimDesd != nil {
                                                                vc.descriptorsToImport.append(bdrPrimDesd!)
                                                                vc.updateSpinnerText(text: "getting BRD wallet change descriptor...")
                                                                vc.getDescriptorInfo(desc: vc.brdChangeDesc(masterKey)) { (brdChangeDesc) in
                                                                    if brdChangeDesc != nil {
                                                                        vc.descriptorsToImport.append(brdChangeDesc!)
                                                                        vc.importDescriptors(index: 0)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func importDescriptors(index: Int) {
        if index < descriptorsToImport.count {
            updateSpinnerText(text: "importing descriptor #\(index + 1) out of \(descriptorsToImport.count)...")
            let descriptor = descriptorsToImport[index]
            var params = "[{ \"desc\": \"\(descriptor)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"label\": \"Fully Noded Recovery\", \"keypool\": false, \"internal\": false }], {\"rescan\": false}"
            if descriptor.contains("84'/\(coinType)'/\(accountNumber)'") {
                if descriptor.contains("/0/*") {
                    params = "[{ \"desc\": \"\(descriptor)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"label\": \"Fully Noded Recovery\", \"keypool\": true, \"internal\": false }], {\"rescan\": false}"
                    primDesc = descriptor
                } else if descriptor.contains("/1/*") {
                    params = "[{ \"desc\": \"\(descriptor)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"keypool\": true, \"internal\": true }], {\"rescan\": false}"
                    changeDesc = descriptor
                }
            }
            importMulti(params: params) { [unowned vc = self] success in
                if success {
                    vc.importDescriptors(index: index + 1)
                } else {
                    vc.showError(error: "Error importing a recovery descriptor.")
                }
            }
        } else {
            updateSpinnerText(text: "starting a rescan...")
            Reducer.makeCommand(command: .getblockchaininfo, param: "") { [unowned vc = self] (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    if let pruned = dict["pruned"] as? Bool {
                        if pruned {
                            if let pruneHeight = dict["pruneheight"] as? Int {
                                Reducer.makeCommand(command: .rescanblockchain, param: "\(pruneHeight)") { [unowned vc = self] (response, errorMessage) in
                                    vc.saveLocally()
                                }
                            }
                        } else {
                            Reducer.makeCommand(command: .rescanblockchain, param: "") { [unowned vc = self] (response, errorMessage) in
                                vc.saveLocally()
                            }
                        }
                    }
                } else {
                    vc.showError(error: "Error starting a rescan, your wallet has not been saved. Please check your connection to your node and try again.")
                }
            }
        }
    }
    
   private func samouraiBadBankPrim(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/84h/\(coinType)h/2147483644h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/84h/\(coinType)h/2147483644h]\(xpub)/0/*)"
            }
        }
        return desc
    }
    
    private func samouraiBadBankChange(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/84h/\(coinType)h/2147483644h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/84h/\(coinType)h/2147483644h]\(xpub)/1/*)"
            }
        }
        return desc
    }
    
    private func samouraiPreMixPrim(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/84h/\(coinType)h/2147483645h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/84h/\(coinType)h/2147483645h]\(xpub)/0/*)"
            }
        }
        return desc
    }
    
    private func samouraiPreMixChange(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/84h/\(coinType)h/2147483645h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/84h/\(coinType)h/2147483645h]\(xpub)/1/*)"
            }
        }
        return desc
    }
    
    private func samouraiPostMixPrim(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/84h/\(coinType)h/2147483646h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/84h/\(coinType)h/2147483646h]\(xpub)/0/*)"
            }
        }
        return desc
    }
    
    private func samouraiPostMixChange(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/84h/\(coinType)h/2147483646h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/84h/\(coinType)h/2147483646h]\(xpub)/1/*)"
            }
        }
        return desc
    }
    
    private func samouraiRicochet84Prim(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/84h/\(coinType)h/2147483647h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/84h/\(coinType)h/2147483647h]\(xpub)/0/*)"
            }
        }
        return desc
    }
    
    private func samouraiRicochet84Change(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/84h/\(coinType)h/2147483647h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/84h/\(coinType)h/2147483647h]\(xpub)/1/*)"
            }
        }
        return desc
    }
    
    private func samouraiRicochet44Prim(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/44h/\(coinType)h/2147483647h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/44h/\(coinType)h/2147483647h]\(xpub)/0/*)"
            }
        }
        return desc
    }
    
    private func samouraiRicochet44Change(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/44h/\(coinType)h/2147483647h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/44h/\(coinType)h/2147483647h]\(xpub)/1/*)"
            }
        }
        return desc
    }
    
    private func samouraiRicochet49Prim(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/49h/\(coinType)h/2147483647h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/49h/\(coinType)h/2147483647h]\(xpub)/0/*)"
            }
        }
        return desc
    }
    
    private func samouraiRicochet49Change(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/49h/\(coinType)h/2147483647h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/49h/\(coinType)h/2147483647h]\(xpub)/1/*)"
            }
        }
        return desc
    }
    
    private func bip84PrimDesc(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/84h/\(coinType)h/\(accountNumber)h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/84h/\(coinType)h/\(accountNumber)h]\(xpub)/0/*)"
            }
        }
        return desc
    }
    
    private func bip84ChangeDesc(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/84h/\(coinType)h/\(accountNumber)h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/84h/\(coinType)h/\(accountNumber)h]\(xpub)/1/*)"
            }
        }
        return desc
    }
    
    private func bip44PrimDesc(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/44h/\(coinType)h/\(accountNumber)h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/44h/\(coinType)h/\(accountNumber)h]\(xpub)/0/*)"
            }
        }
        return desc
    }
    
    private func bip44ChangeDesc(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/44h/\(coinType)h/\(accountNumber)h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/44h/\(coinType)h/\(accountNumber)h]\(xpub)/1/*)"
            }
        }
        return desc
    }
    
    private func bip49PrimDesc(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/49h/\(coinType)h/\(accountNumber)h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/49h/\(coinType)h/\(accountNumber)h]\(xpub)/0/*)"
            }
        }
        return desc
    }
    
    private func bip49ChangeDesc(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/49h/\(coinType)h/\(accountNumber)h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/49h/\(coinType)h/\(accountNumber)h]\(xpub)/1/*)"
            }
        }
        return desc
    }
    
    private func brdPrimDesc(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/0h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/0h]\(xpub)/0/*)"
            }
        }
        return desc
    }
    
    private func brdChangeDesc(_ masterKey: String) -> String {
        var desc = ""
        if let xpub = Keys.xpub(path: "m/0h", masterKey: masterKey) {
            if let fingerprint = Keys.fingerprint(masterKey: masterKey) {
                desc = "combo([\(fingerprint)/0h]\(xpub)/1/*)"
            }
        }
        return desc
    }
    
    private func createWallet(mk: String, completion: @escaping ((Bool)) -> Void) {
        let walletName = "Recovery-\(Crypto.sha256hash(bip84PrimDesc(mk)))"
        let param = "\"\(walletName)\", true, true, \"\", true"
        Reducer.makeCommand(command: .createwallet, param: param) { [unowned vc = self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let name = dict["name"] as? String {
                    vc.name = name
                    UserDefaults.standard.set(name, forKey: "walletName")
                    completion(true)
                } else {
                    vc.showError(error: "Error creating wallet on your node")
                    completion(false)
                }
            } else {
                vc.showError(error: "Error creating wallet on your node: \(errorMessage ?? "unknown")")
                completion(false)
            }
        }
    }
    
    private func getDescriptorInfo(desc: String, completion: @escaping ((String?)) -> Void) {
        Reducer.makeCommand(command: .getdescriptorinfo, param: "\"\(desc)\"") { (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let updatedDescriptor = dict["descriptor"] as? String {
                    completion((updatedDescriptor))
                }
            }
        }
    }
    
    private func importMulti(params: String, completion: @escaping ((Bool)) -> Void) {
        Reducer.makeCommand(command: .importmulti, param: params) { (response, errorDescription) in
            if let result = response as? NSArray {
                if result.count > 0 {
                    if let dict = result[0] as? NSDictionary {
                        if let success = dict["success"] as? Bool {
                            completion((success))
                        } else {
                            completion((false))
                        }
                    }
                } else {
                    completion((false))
                }
            } else {
                completion((false))
            }
        }
    }
    
    private func saveLocally() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let data = self.justWords.joined(separator: " ").dataUsingUTF8StringEncoding
            let passphrase = self.passphraseField.text ?? ""
            
            guard let encryptedWords = Crypto.encrypt(data) else {
                self.showError(error: "error encrypting your seed")
                return
            }
            
            if passphrase != "" {
                guard let encryptedPassphrase = Crypto.encrypt(passphrase.dataUsingUTF8StringEncoding) else {
                    self.showError(error: "error encrypting your seed")
                    return
                }
                
                self.saveSignerAndPassphrase(encryptedSigner: encryptedWords, encryptedPassphrase: encryptedPassphrase)
            } else {
                
                self.saveSigner(encryptedSigner: encryptedWords)
            }
        }
    }
    
    private func saveSignerAndPassphrase(encryptedSigner: Data, encryptedPassphrase: Data) {
        let dict = ["id":UUID(), "words":encryptedSigner, "passphrase": encryptedPassphrase] as [String:Any]
        CoreDataService.saveEntity(dict: dict, entityName: .signers) { [unowned vc = self] success in
            if success {
                vc.saveWallet()
            } else {
                vc.showError(error: "error saving encrypted seed")
            }
        }
    }
    
    private func saveSigner(encryptedSigner: Data) {
        let dict = ["id":UUID(), "words":encryptedSigner] as [String:Any]
        CoreDataService.saveEntity(dict: dict, entityName: .signers) { [unowned vc = self] success in
            if success {
                vc.saveWallet()
            } else {
                vc.showError(error: "error saving encrypted seed")
            }
        }
    }
    
    private func saveWallet() {
        var dict = [String:Any]()
        dict["id"] = UUID()
        dict["label"] = "Recovery Wallet"
        dict["changeDescriptor"] = changeDesc
        dict["receiveDescriptor"] = primDesc
        dict["watching"] = descriptorsToImport
        dict["type"] = "Single-Sig"
        dict["name"] = name
        dict["maxIndex"] = Int64(2500)
        dict["index"] = Int64(0)
        dict["blockheight"] = Int64(blockheight)
        DispatchQueue.main.async { [unowned vc = self] in
            dict["account"] = vc.accountField.text ?? "0"
        }
        CoreDataService.saveEntity(dict: dict, entityName: .wallets) { [unowned vc = self] success in
            if success {
                NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                vc.label.text = ""
                vc.spinner.removeConnectingView()
                DispatchQueue.main.async {
                    vc.navigationController?.popToRootViewController(animated: true)
                }
                showAlert(vc: vc, title: "Successfully created a Fully Noded Recovery wallet ✅", message: "Your node is currently rescanning the blockchain, if your node is not pruned this can take up to an hour. Please check your balances again when the rescan completes. You can monitor rescan status in Tools > Get Wallet Info")
            }
        }
    }
    
    @IBAction func removeWordAction(_ sender: Any) {
        if self.justWords.count > 0 {
            
            DispatchQueue.main.async { [unowned vc = self] in
                
                vc.label.removeFromSuperview()
                vc.label.text = ""
                vc.addedWords.removeAll()
                vc.justWords.remove(at: vc.justWords.count - 1)
                
                for (i, word) in vc.justWords.enumerated() {
                    
                    vc.addedWords.append("\(i + 1). \(word)\n")
                    if i == 0 {
                        vc.updatePlaceHolder(wordNumber: i + 1)
                    } else {
                        vc.updatePlaceHolder(wordNumber: i + 2)
                    }
                }
                
                vc.label.textColor = .systemGreen
                vc.label.text = vc.addedWords.joined(separator: "")
                vc.label.frame = CGRect(x: 16, y: 0, width: vc.wordView.frame.width - 32, height: vc.wordView.frame.height - 10)
                vc.label.numberOfLines = 0
                vc.label.sizeToFit()
                vc.wordView.addSubview(vc.label)
                
                if let _ = BIP39Mnemonic(vc.justWords.joined(separator: " ")) {
                    
                    vc.validWordsAdded()
                    
                }
                
            }
            
        }
    }
    
    @IBAction func addWordAction(_ sender: Any) {
        processTextfieldInput()
    }
    
    private func processTextfieldInput() {
        print("processTextfieldInput")
        
        if textField.text != "" {
            
            //check if user pasted more then one word
            let processed = processedCharacters(textField.text!)
            let userAddedWords = processed.split(separator: " ")
            var multipleWords = [String]()
            
            if userAddedWords.count > 1 {
                
                //user add multiple words
                for (i, word) in userAddedWords.enumerated() {
                    
                    var isValid = false
                    
                    for bip39Word in bip39Words {
                        
                        if word == bip39Word {
                            isValid = true
                            multipleWords.append("\(word)")
                        }
                        
                    }
                    
                    if i + 1 == userAddedWords.count {
                        
                        // we finished our checks
                        if isValid {
                            
                            // they are valid bip39 words
                            addMultipleWords(words: multipleWords)
                            
                            textField.text = ""
                            
                        } else {
                            
                            //they are not all valid bip39 words
                            textField.text = ""
                            
                            showAlert(vc: self, title: "Error", message: "At least one of those words is not a valid BIP39 word. We suggest inputting them one at a time so you can utilize our autosuggest feature which will prevent typos.")
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                //its one word
                let processedWord = textField.text!.replacingOccurrences(of: " ", with: "")
                
                for word in bip39Words {
                    
                    if processedWord == word {
                        
                        addWord(word: processedWord)
                        textField.text = ""
                        
                    }
                    
                }
                
            }
            
        } else {
            
            shakeAlert(viewToShake: textField)
            
        }
        
    }
    
    private func formatSubstring(subString: String) -> String {
        
        let formatted = String(subString.dropLast(autoCompleteCharacterCount)).lowercased()
        return formatted
        
    }
    
    private func resetValues() {
        
        textField.textColor = .white
        autoCompleteCharacterCount = 0
        textField.text = ""
        
    }
    
    func searchAutocompleteEntriesWIthSubstring(substring: String) {
        
        let userQuery = substring
        let suggestions = getAutocompleteSuggestions(userText: substring)
        self.textField.textColor = .white
        
        if suggestions.count > 0 {
            
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { (timer) in
                
                let autocompleteResult = self.formatAutocompleteResult(substring: substring, possibleMatches: suggestions)
                self.putColorFormattedTextInTextField(autocompleteResult: autocompleteResult, userQuery : userQuery)
                self.moveCaretToEndOfUserQueryPosition(userQuery: userQuery)
                
            })
            
        } else {
            
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { [unowned vc = self] (timer) in //7
                
                vc.textField.text = substring
                
                if let _ = BIP39Mnemonic(vc.processedCharacters(vc.textField.text!)) {
                    
                    vc.processTextfieldInput()
                    vc.textField.textColor = .systemGreen
                    vc.validWordsAdded()
                    
                } else {
                    
                    vc.textField.textColor = .systemRed
                    
                }
                
                
            })
            
            autoCompleteCharacterCount = 0
            
        }
        
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        if textField != accountField && textField != passphraseField {
            var subString = (textField.text!.capitalized as NSString).replacingCharacters(in: range, with: string)
            subString = formatSubstring(subString: subString)
            
            if subString.count == 0 {
                
                resetValues()
                
            } else {
                
                searchAutocompleteEntriesWIthSubstring(substring: subString)
                
            }
        }
        
        return true
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField != accountField && textField != passphraseField {
            processTextfieldInput()
        } else if textField == accountField {
            accountField.endEditing(true)
        }
        return true
    }
    
    func getAutocompleteSuggestions(userText: String) -> [String]{
        
        var possibleMatches: [String] = []
        
        for item in bip39Words {
            
            let myString:NSString! = item as NSString
            let substringRange:NSRange! = myString.range(of: userText)
            
            if (substringRange.location == 0) {
                
                possibleMatches.append(item)
                
            }
            
        }
        
        return possibleMatches
        
    }
    
    func putColorFormattedTextInTextField(autocompleteResult: String, userQuery : String) {
        
        let coloredString: NSMutableAttributedString = NSMutableAttributedString(string: userQuery + autocompleteResult)
        
        coloredString.addAttribute(NSAttributedString.Key.foregroundColor,
                                   value: UIColor.systemGreen,
                                   range: NSRange(location: userQuery.count,length:autocompleteResult.count))
        
        self.textField.attributedText = coloredString
        
    }
    
    func moveCaretToEndOfUserQueryPosition(userQuery : String) {
        
        if let newPosition = self.textField.position(from: self.textField.beginningOfDocument, offset: userQuery.count) {
            
            self.textField.selectedTextRange = self.textField.textRange(from: newPosition, to: newPosition)
            
        }
        
        let selectedRange: UITextRange? = textField.selectedTextRange
        textField.offset(from: textField.beginningOfDocument, to: (selectedRange?.start)!)
        
    }
    
    func formatAutocompleteResult(substring: String, possibleMatches: [String]) -> String {
        
        var autoCompleteResult = possibleMatches[0]
        autoCompleteResult.removeSubrange(autoCompleteResult.startIndex..<autoCompleteResult.index(autoCompleteResult.startIndex, offsetBy: substring.count))
        autoCompleteCharacterCount = autoCompleteResult.count
        return autoCompleteResult
        
    }
    
    private func addMultipleWords(words: [String]) {
        
        DispatchQueue.main.async { [unowned vc = self] in
            
            vc.label.removeFromSuperview()
            vc.label.text = ""
            vc.addedWords.removeAll()
            vc.justWords = words
            
            for (i, word) in vc.justWords.enumerated() {
                vc.addedWords.append("\(i + 1). \(word)\n")
                vc.updatePlaceHolder(wordNumber: i + 2)
            }
            
            vc.label.textColor = .systemGreen
            vc.label.text = vc.addedWords.joined(separator: "")
            vc.label.frame = CGRect(x: 16, y: 0, width: vc.wordView.frame.width - 32, height: vc.wordView.frame.height - 10)
            vc.label.numberOfLines = 0
            vc.label.sizeToFit()
            vc.wordView.addSubview(vc.label)
            
            if let _ = BIP39Mnemonic(vc.justWords.joined(separator: " ")) {
                
                //vc.validWordsAdded()
                
            } else {
                                    
                showAlert(vc: vc, title: "Invalid", message: "Just so you know that is not a valid recovery phrase, if you are inputting a 24 word phrase ignore this message and keep adding your words.")
                
            }
            
        }
        
    }
    
    private func addWord(word: String) {
        
        DispatchQueue.main.async { [unowned vc = self] in
            
            vc.label.removeFromSuperview()
            vc.label.text = ""
            vc.addedWords.removeAll()
            vc.justWords.append(word)
            
            for (i, word) in vc.justWords.enumerated() {
                
                vc.addedWords.append("\(i + 1). \(word)\n")
                vc.updatePlaceHolder(wordNumber: i + 2)
                
            }
            
            vc.label.textColor = .systemGreen
            vc.label.text = vc.addedWords.joined(separator: "")
            vc.label.frame = CGRect(x: 16, y: 0, width: vc.wordView.frame.width - 32, height: vc.wordView.frame.height - 10)
            vc.label.numberOfLines = 0
            vc.label.sizeToFit()
            vc.wordView.addSubview(vc.label)
            
            if let _ = BIP39Mnemonic(vc.justWords.joined(separator: " ")) {
                vc.validWordsAdded()
            }
            vc.textField.becomeFirstResponder()
            
        }
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        print("didendediting")
        if textField == accountField {
            if accountField.text != "" {
                if let int = Int(accountField.text!) {
                    let text = accountField.text!
                    if int == 0 {
                        
                    } else if text.first == "0" {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.accountField.text = "0"
                            showAlert(vc: vc, title: "Error", message: "Input a valid number that does not start with 0")
                        }
                    }
                }
            }
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == accountField {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.accountField.text = ""
            }
        }
    }
    
    private func processedCharacters(_ string: String) -> String {
        var result = string.filter("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ ".contains)
        result = result.condenseWhitespace()
        return result
    }
    
    private func validWordsAdded() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.textField.resignFirstResponder()
            vc.recoverOutlet.isEnabled = true
        }
        showAlert(vc: self, title: "Valid Words ✓", message: "That is a valid recovery phrase, you may tap \"recover\" to recover this wallet.")
    }
    

}
