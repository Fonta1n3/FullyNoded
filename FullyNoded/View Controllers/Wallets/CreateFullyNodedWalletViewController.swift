//
//  CreateFullyNodedWalletViewController.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit


class CreateFullyNodedWalletViewController: UIViewController, UINavigationControllerDelegate, UIDocumentPickerDelegate {
    
    @IBOutlet weak var multiSigOutlet: UIButton!
    @IBOutlet weak var singleSigOutlet: UIButton!
    
    var cosigner:Descriptor?
    var onDoneBlock:(((Bool)) -> Void)?
    var spinner = ConnectingView()
    var ccXfp = ""
    var xpub = ""
    var deriv = ""
    var descriptor: Descriptor?
    var jmMessage = ""
    var isSegwit = false
    var isTaproot = false
    let jsonDecoder = JSONDecoder()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        singleSigOutlet.layer.cornerRadius = 8
        multiSigOutlet.layer.cornerRadius = 8
        
       
        
//        if #available(iOS 17.0, *) {
//            let reader = NFCReader()
//            print("reader: \(reader.canBeginSession)")
//            //let session = read
//            do {
//                try await reader.beginSession()
//                var tag
//                print("\(try await reader.readTag(<#T##tag: any NFCNDEFTag##any NFCNDEFTag#>))")
//            } catch {
//                print("begin session error: \(error.localizedDescription)")
//            }
//             
//        } else {
//            // Fallback on earlier versions
//        }
    }
    
//    override func viewDidAppear(_ animated: Bool) {
//        readNfc()
//    }
    
    
    
    @IBAction func pasteAction(_ sender: Any) {
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
    
    private func isDescriptor(_ lowercased: String) -> Bool {
        if lowercased.hasPrefix("wsh") || lowercased.hasPrefix("pkh") || lowercased.hasPrefix("sh") || lowercased.hasPrefix("combo") || lowercased.hasPrefix("wpkh") || lowercased.hasPrefix("addr") || lowercased.hasPrefix("multi") || lowercased.hasPrefix("sortedmulti") || lowercased.hasPrefix("tr(") {
            return true
        } else {
            return false
        }
    }
    
    private func processPastedString(_ string: String) {
        processImportedString(string)
    }
    
    @IBAction func fileAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Upload a file?", message: "Here you can upload files from your Hardware Wallets to easily create Fully Noded Wallet's", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Upload", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                var documentPicker:UIDocumentPickerViewController!
                
                if #available(iOS 14.0, *) {
                    documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
                } else {
                    documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
                }
                
                documentPicker.delegate = self
                documentPicker.modalPresentationStyle = .formSheet
                self.present(documentPicker, animated: true, completion: nil)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func scanQrAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToScanner", sender: self)
        }
    }
    
    @IBAction func automaticAction(_ sender: Any) {
        promptForSingleSigFormat()
    }
    
    private func promptForSingleSigFormat() {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Choose an address format.", message: "", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Segwit", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.isSegwit = true
                self.segueToSingleSigCreator()
            }))
            
            alert.addAction(UIAlertAction(title: "Taproot", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.isTaproot = true
                self.segueToSingleSigCreator()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func segueToSingleSigCreator() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToSeedWords", sender: self)
        }
    }
    
    @IBAction func manualAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "seguToManualCreation", sender: self)
        }
    }
    
    @IBAction func createMultiSigAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToCreateMultiSig", sender: self)
        }
    }
    
    @IBAction func createJmWalletAction(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "checking for existing jm wallets on your server...")
        JMUtils.wallets { [weak self] (jmWallets, message) in
            guard let self = self else { return }
            guard let jmWallets = jmWallets else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "JM Server issue", message: message ?? "unknown")
                return
            }
            
            if jmWallets.count > 0 {
                // select a wallet to use
                self.promptToChooseJmWallet(jmWallets: jmWallets)
            } else {
                DispatchQueue.main.async {
                    self.spinner.label.text = "creating new wallet (can take some time)..."
                }
                
                JMUtils.createWallet { (wallet, words, passphrase, message) in
                    self.spinner.removeConnectingView()
                    
                    guard let jmWallet = wallet, let words = words, let passphrase = passphrase else {
                        if let mess = message, mess.contains("Wallet already unlocked.") {
                            self.promptToLockWallets()
                        } else {
                            showAlert(vc: self, title: "There was an issue creating your JM wallet.", message: message ?? "Unknown.")
                        }
                        
                        return
                    }
                    UserDefaults.standard.setValue(jmWallet.name, forKey: "walletName")
                    var formattedWords = ""
                    for (i, word) in words.description.split(separator: " ").enumerated() {
                        formattedWords += "\(i + 1). \(word) "
                    }
                    self.jmMessage = """
                    In order to avoid lost funds back up the following information:
                    
                    Join Market Seed Words:
                    \(formattedWords)
                    
                    Join Market wallet encryption passphrase:
                    \(passphrase)
                    
                    Join Market wallet file:
                    \(jmWallet.jmWalletName)
                    """
                    self.segueToSingleSigCreator()
                }
            }
        }
    }
    
    private func promptToChooseJmWallet(jmWallets: [String]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spinner.removeConnectingView()
            
            let tit = "Join Market wallet"
            
            let mess = "Please select which wallet you'd like to use."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
            for jmWallet in jmWallets {
                alert.addAction(UIAlertAction(title: jmWallet, style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    self.recoverJm(jmWallet: jmWallet)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func recoverJm(jmWallet: String) {
        var walletToSave:[String:Any] = [
            "id": UUID(),
            "jmWalletName": jmWallet,
            "label": jmWallet,
            "type": "Single-Sig",
            "isJm": true,
            "maxIndex": 999,
            "index": Int64(0),
            "blockheight": 0
        ]
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Unlock \(jmWallet)"
            
            let alert = UIAlertController(title: title, message: "Input your JM wallet encryption passphrase to unlock the wallet.", preferredStyle: .alert)
            
            let recover = UIAlertAction(title: "Unlock", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                self.spinner.addConnectingView(vc: self, description: "attempting to unlock the jm wallet...")
                let jmWalletPassphrase = (alert.textFields![0] as UITextField).text
                let jmWalletPassphraseConfirm = (alert.textFields![1] as UITextField).text
                
                guard let jmWalletPassphrase = jmWalletPassphrase,
                      let jmWalletPassphraseConfirm = jmWalletPassphraseConfirm,
                      jmWalletPassphraseConfirm == jmWalletPassphrase else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "", message: "Passphrases do not match, try again.")
                    return
                }
                
                guard let encryptedPassword = Crypto.encrypt(jmWalletPassphrase.utf8) else { showAlert(vc: self, title: "", message: "error encrypting passphrase"); return }
                
                walletToSave["password"] = encryptedPassword
                var w:Wallet = .init(dictionary: walletToSave)
                
                JMUtils.unlockWallet(wallet: w) { [weak self] (unlockedWallet, message) in
                    guard let self = self else { return }
                    guard let unlockedWallet = unlockedWallet else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "", message: message ?? "unknown error when attempting to unlock \(w.name)")
                        return
                    }
                    
                    walletToSave["token"] = Crypto.encrypt(unlockedWallet.token.utf8)!
                    w = .init(dictionary: walletToSave)
                    
                    JMUtils.getDescriptors(wallet: w) { (descriptors, message) in
                        guard let descriptors = descriptors else {
                            showAlert(vc: self, title: "", message: "")
                            return
                        }
                        
                        walletToSave["watching"] = Array(descriptors[2...descriptors.count - 1])
                        walletToSave["receiveDescriptor"] = descriptors[0]
                        walletToSave["changeDescriptor"] = descriptors[1]
                        w = .init(dictionary: walletToSave)
                        
                        JMUtils.configGet(wallet: w, section: "BLOCKCHAIN", field: "rpc_wallet_file") { (jm_rpc_wallet, message) in
                            guard let jm_rpc_wallet = jm_rpc_wallet else {
                                self.spinner.removeConnectingView()
                                showAlert(vc: self, title: "", message: message ?? "error fetching Bitcoin Core rpc wallet name in jm config.")
                                return
                            }
                            walletToSave["name"] = jm_rpc_wallet
                            print("walletToSave: \(walletToSave)")
                            
                            CoreDataService.saveEntity(dict: walletToSave, entityName: .wallets) { saved in
                                self.spinner.removeConnectingView()
                                if saved {
                                    w = .init(dictionary: walletToSave)
                                    UserDefaults.standard.set(w.name, forKey: "walletName")
                                    self.spinner.removeConnectingView()
                                    showAlert(vc: self, title: "", message: "Join Market Wallet created, it should load automatically.")
                                    DispatchQueue.main.async { [weak self] in
                                        guard let self = self else { return }
                                        NotificationCenter.default.post(name: .refreshWallet, object: nil)
                                        self.navigationController?.popToRootViewController(animated: true)
                                    }
                                } else {
                                    showAlert(vc: self, title: "", message: message ?? "error saving wallet")
                                }
                            }
                        }
                    }
                }
            }
            
            alert.addTextField { jmWalletPassphrase in
                jmWalletPassphrase.placeholder = "join market wallet passphrase"
                jmWalletPassphrase.isSecureTextEntry = true
                jmWalletPassphrase.keyboardAppearance = .dark
            }
            
            alert.addTextField { jmWalletPassphraseConfirm in
                jmWalletPassphraseConfirm.placeholder = "confirm encryption passphrase"
                jmWalletPassphraseConfirm.keyboardAppearance = .dark
                jmWalletPassphraseConfirm.isSecureTextEntry = true
            }
            
            alert.addAction(recover)
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    private func promptToLockWallets() {
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let tit = "You have an existing Join Market wallet which is unlocked, you need to lock it before we can create a new one."
                
                let mess = ""
                
                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
                
                JMUtils.wallets { (server_wallets, message) in
                    guard let server_wallets = server_wallets else { return }
                    for server_wallet in server_wallets {
                        DispatchQueue.main.async {
                            alert.addAction(UIAlertAction(title: server_wallet, style: .default, handler: { [weak self] action in
                                guard let self = self else { return }
                                
                                self.spinner.addConnectingView(vc: self, description: "locking wallet...")
                                
                                for fnwallet in wallets {
                                    if fnwallet["id"] != nil {
                                        let str = Wallet(dictionary: fnwallet)
                                        if str.jmWalletName == server_wallet {
                                            JMUtils.lockWallet(wallet: str) { [weak self] (locked, message) in
                                                guard let self = self else { return }
                                                self.spinner.removeConnectingView()
                                                if locked {
                                                    showAlert(vc: self, title: "Wallet locked ✓", message: "Try joining the utxo again.")
                                                } else {
                                                    showAlert(vc: self, title: message ?? "Unknown issue locking that wallet...", message: "FN can only work with one JM wallet at a time, it looks like you need to restart your JM daemon in order to create a new wallet. Restart JM daemon and try again.")
                                                }
                                            }
                                        }
                                    }
                                }
                            }))
                        }
                    }
                }
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let data = try? Data(contentsOf: urls[0].absoluteURL) else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "", message: "That does not appear to be a recognized wallet backup/export/import file")
            return
        }
        
        guard let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
            
            guard let txt = String(bytes: data, encoding: .utf8) else {
                spinner.removeConnectingView()
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
    
    private func promptToImportMultiSig(_ dict: [String:Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Import your multi sig wallet?", message: "Looks like you selected a multi sig wallet. You can easily recreate the wallet as watchonly with Fully Noded, just tap \"import\".", preferredStyle: .alert)
            
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
            let alert = UIAlertController(title: "Create a multisig with your Coldcard?", message: "You have uploaded a Coldcard multisig file, this action allows you to easily create a wallet with your Coldcard and Fully Noded.", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.cosigner = desc
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
            let alert = UIAlertController(title: "Create a single sig with your Coldcard?", message: "You have uploaded a Coldcard single sig file, this action will recreate your Coldcard wallet on Fully Noded using its xpubs.", preferredStyle: .alert)
            
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
        spinner.addConnectingView(vc: self, description: "importing...")
        
        func importAccount() {
            if let _ = accountMap["descriptor"] as? String {
                if (accountMap["blockheight"] as? Int) != nil || (accountMap["blockheight"] as? Int64) != nil {
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
            } else if let _ = accountMap["ExtPubKey"] as? String {
                spinner.removeConnectingView()
                promptToImportCoboSingleSig(accountMap)
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
        
        if desc.isCosigner {
            self.ccXfp = desc.fingerprint
            self.xpub = desc.accountXpub
            self.deriv = desc.derivation
            self.cosigner = desc
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.performSegue(withIdentifier: "segueToCreateMultiSig", sender: self)
            }
        } else {
            //self.importAccountMap(accountMap)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.descriptor = desc
                self.performSegue(withIdentifier: "segueToImportDescriptor", sender: self)
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
    
    private func processImportedString(_ item: String) {
        let lowercased = item.lowercased()
        
        if self.isExtendedKey(lowercased) {
            
            showAlert(vc: self, title: "Not supported.", message: "Xpub importing is not supported, you need to import an output descriptor.")
            
        } else if self.isDescriptor(lowercased) {
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.descriptor = Descriptor(item)
                self.performSegue(withIdentifier: "segueToImportDescriptor", sender: self)
            }
            
        } else if lowercased.hasPrefix("ur:") {
            if lowercased.hasPrefix("ur:bytes") {
                let (text, err) = URHelper.parseBlueWalletCoordinationSetup(lowercased)
                if let textFile = text {
                     if let dict = try? JSONSerialization.jsonObject(with: textFile.utf8, options: []) as? [String:Any] {
                        let importStruct = WalletImport(dict)
                        
                        var descriptors:[String] = []
                        
                        if let bip44 = importStruct.bip44 {
                            descriptors.append(bip44)
                        }
                        if let bip49 = importStruct.bip49 {
                            descriptors.append(bip49)
                        }
                        if let bip84 = importStruct.bip84 {
                            descriptors.append(bip84)
                        }
                        if let bip48 = importStruct.bip48 {
                            descriptors.append(bip48)
                        }
                        
                        self.prompToChoosePrimaryDesc(descriptors: descriptors)
                        
                     } else if let accountMap = TextFileImport.parse(textFile).accountMap {
                        self.importAccountMap(accountMap)
                                                     
                    } else {
                        showAlert(vc: self, title: "Error", message: err ?? "Unknown error decoding the text file into a descriptor.")
                    }
                } else {
                    showAlert(vc: self, title: "Error", message: err ?? "Unknown error decoding the QR code.")
                }
                
            } else {
                let (descriptors, error) = URHelper.parseUr(urString: item)
                
                guard error == nil, let descriptors = descriptors else {
                    showAlert(vc: self, title: "Error", message: error ?? "Unknown error decoding the QR code.")
                    return
                }
                
                var accountMap:[String:Any] = ["descriptor": "", "blockheight": 0, "watching": [] as [String], "label": "Wallet Import"]
                
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
                            
                            self.performSegue(withIdentifier: "segueToCreateMultiSig", sender: self)
                        }
                    } else {
                        accountMap["descriptor"] = descriptors[0]
                        self.importAccountMap(accountMap)
                    }
                }
            }
            
        } else if Keys.validMnemonic(item) {
            let (descriptors, message) = Keys.descriptorsFromSigner(item)
            
            guard let encryptedSigner = Crypto.encrypt(item.utf8) else {
                showAlert(vc: self, title: "Unable to encrypt your signer.", message: "Please let us know about this bug.")
                return
            }
            
            let dict = ["id":UUID(), "words":encryptedSigner, "added": Date()] as [String:Any]
            CoreDataService.saveEntity(dict: dict, entityName: .signers) { success in
                guard success else {
                    return
                }
                
                guard let descriptors = descriptors else {
                    showAlert(vc: self, title: "Unable to derive descriptors...", message: "Please let us know about this issue. Error: \(message ?? "unknown.")")
                    return
                }
                
                self.prompToChoosePrimaryDesc(descriptors: descriptors)
            }
            
        } else if let coldcardSparrowExport = try? jsonDecoder.decode(ColdcardSparrowExport.self, from: item.utf8) {
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
                
                if let bip482 = coldcardSparrowExport.bip48_2, var desc = bip482.standardDesc {
                    descriptors.append(desc)
                }
                
                self.prompToChoosePrimaryDesc(descriptors: descriptors)
            }
            
        } else if let coldcardMultisigExport = try? jsonDecoder.decode(ColdcardMultiSigExport.self, from: item.utf8) {
            guard let deriv = coldcardMultisigExport.p2wsh_deriv else { return }
            guard let xfp = coldcardMultisigExport.xfp else { return }
            guard let p2wsh = coldcardMultisigExport.p2wsh else { return}
            guard let xpub = XpubConverter.convert(extendedKey: p2wsh) else { return }
            let origin = deriv.replacingOccurrences(of: "m", with: xfp)
            let descriptor = "wsh([\(origin)]\(xpub)/0/*)"
            promptToImportColdcardMsig(Descriptor(descriptor))
            
            
        } else if let dict = try? JSONSerialization.jsonObject(with: item.utf8, options: []) as? [String:Any] {
            if let _ = dict["desc"] as? String {
                self.importAccountMap(dict)
            }

        } else if let accountMap = TextFileImport.parse(item).accountMap {
            self.importAccountMap(accountMap)
            
        } else {
            showAlert(vc: self, title: "Unsupported import.", message: item + " is not a supported import option, please let us know about this so we can add support.")
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "segueToSeedWords":
            guard let vc = segue.destination as? SeedDisplayerViewController else { fallthrough }
            
            vc.isSegwit = isSegwit
            vc.isTaproot = isTaproot
            vc.jmMessage = jmMessage
            
        case "segueToScanner":
            if #available(macCatalyst 14.0, *) {
                guard let vc = segue.destination as? QRScannerViewController else { fallthrough }
                
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
            }
            
        case "segueToCreateMultiSig":
            guard let vc = segue.destination as? CreateMultisigViewController else { fallthrough }
            
            vc.cosigner = cosigner
            
        case "segueToImportDescriptor":
            guard let vc = segue.destination as? ImportXpubViewController else { fallthrough }
            
            vc.descriptor = descriptor
            
        default:
            break
        }
    }
}
