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
    @IBOutlet weak var coreWalletOutlet: UIButton!
    @IBOutlet weak var pasteOutlet: UIButton!
    @IBOutlet weak var importFileOutlet: UIButton!
    @IBOutlet weak var scanQrOutlet: UIButton!
    
    var cosigner:Descriptor?
    var onDoneBlock:(((Bool)) -> Void)?
    let spinner = ConnectingView.shared
    var ccXfp = ""
    var xpub = ""
    var deriv = ""
    var descriptor: Descriptor?
    let jsonDecoder = JSONDecoder()
    var isSegwit = false
    var isTaproot = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        coreWalletOutlet.clipsToBounds = true
        pasteOutlet.clipsToBounds = true
        importFileOutlet.clipsToBounds = true
        scanQrOutlet.clipsToBounds = true
        coreWalletOutlet.layer.cornerRadius = 8
        pasteOutlet.layer.cornerRadius = 8
        importFileOutlet.layer.cornerRadius = 8
        scanQrOutlet.layer.cornerRadius = 8
        singleSigOutlet.layer.cornerRadius = 8
        multiSigOutlet.layer.cornerRadius = 8
        
    }
    
    @IBAction func pasteTextAction(_ sender: Any) {
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
    
    private func promptForSingleSigFormat() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let alert = UIAlertController(title: "Choose a single sig wallet type.", message: "", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Segwit (BIP84)", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    isSegwit = true
                    segueToSingleSigCreator()
                }))
                
                alert.addAction(UIAlertAction(title: "Taproot (BIP86)", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    isTaproot = true
                    segueToSingleSigCreator()
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = view
                present(alert, animated: true, completion: nil)
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
    
    @IBAction func syncCoreWalletAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
        
            performSegue(withIdentifier: "segueToSyncCoreWallet", sender: self)
        }
    }
    
    
    @IBAction func importFileAction(_ sender: Any) {
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
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let data = try? Data(contentsOf: urls[0].absoluteURL) else {
            spinner.dismiss()
            showAlert(vc: self, title: "", message: "That does not appear to be a recognized wallet backup/export/import file")
            return
        }
        
        guard let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
            
            guard let txt = String(bytes: data, encoding: .utf8) else {
                spinner.dismiss()
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
            let alert = UIAlertController(title: "Create a multisig?", message: "You have uploaded a multisig file.", preferredStyle: .alert)
            
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
        spinner.show(vc: self, description: "importing...")
        
        func importAccount() {
            if let _ = accountMap["descriptor"] as? String {
                if (accountMap["blockheight"] as? Int) != nil || (accountMap["blockheight"] as? Int64) != nil {
                    /// It is an Account Map.
                    ImportWallet.accountMap(accountMap) { (success, errorDescription) in
                        if success {
                            DispatchQueue.main.async {
                                self.spinner.dismiss()
                                self.onDoneBlock!(true)
                                self.navigationController?.popViewController(animated: true)
                            }
                        } else {
                            self.spinner.dismiss()
                            showAlert(vc: self, title: "Error", message: "There was an error importing your wallet: \(errorDescription ?? "unknown")")
                        }
                    }
                }
            } else if let _ = accountMap["ExtPubKey"] as? String {
                spinner.dismiss()
                promptToImportCoboSingleSig(accountMap)
            }
        }
        
        if let url = accountMap["quickConnect"] as? String {
            QuickConnect.addNode(url: url) { (success, errorMessage) in
                guard success else {
                    self.spinner.dismiss()
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
    
    private func decodeWalletBackup(from hexString: String) -> WalletBackup? {
        
        guard let data = Data(hexString: hexString) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        
        do {
            let backup = try decoder.decode(WalletBackup.self, from: data)
            return backup
        } catch {
            showAlert(title: "Decode Failed", message: "Could not parse backup data.\n\nError: \(error.localizedDescription)")
            return nil
        }
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

    private func performImport(backup: WalletBackup) {
        guard let jsonData = try? backup.jsonData() else { return }
        spinner.show(vc: self, description: "Recovering wallet...")
        
        var fnWalletToCreateDict: [String: Any] = [
            "walletBackup": jsonData,
            "label": "Recovered wallet",
            "blockheight": UInt64(0),// fix this
            "id": UUID()
        ]
        
        var descriptorDicts: [[String: Any]] = []
        for (i, descriptor) in backup.descriptors.enumerated() {
            let fnDesc = Descriptor(descriptor.desc)            
            
            var descriptorDict: [String: Any] = [
                "internal": descriptor.internal ?? false,
                "active": descriptor.active,
                "desc": descriptor.desc
            ]
                        
            if let range = descriptor.range {
                if range.count == 2 {
                    descriptorDict["range"] = [range[0],range[1]]
                } else if range.count == 1 {
                    descriptorDict["range"] = [range[0]]
                } else if let _internal = descriptor.internal, !_internal {
                    descriptorDict["label"] = descriptor.label
                }
            } else if let _internal = descriptor.internal, !_internal  {
                descriptorDict["label"] = descriptor.label
            } else if descriptor.internal == nil {
                descriptorDict["label"] = descriptor.label
            }
            
            if let timestamp = descriptor.timestamp {
                descriptorDict["timestamp"] = timestamp
                fnWalletToCreateDict["blockheight"] = approximateHeight(for: Int64(timestamp))
            }
            
            if let nextIndex = descriptor.nextIndex {
                descriptorDict["next_index"] = nextIndex
            }
            
            descriptorDicts.append(descriptorDict)
            
            if fnDesc.isHD, descriptor.active {
                if !fnDesc.isInternal {
                    fnWalletToCreateDict["receiveDescriptor"] = descriptor.desc
                    fnWalletToCreateDict["name"] = "FullyNoded-" + Crypto.sha256hash("\(descriptor.desc.split(separator: "#")[0])")
                } else {
                    fnWalletToCreateDict["changeDescriptor"] = descriptor.desc
                }
            }
            
            if i + 1 == backup.descriptors.count {
                createWallet(fnWalletToCreateDict: fnWalletToCreateDict, backup: backup, descriptorDicts: descriptorDicts)
            }
        }
    }
    
    private func setActiveAndImport(name: String, exists: Bool, backup: WalletBackup, descriptorDicts: [[String: Any]], fnWalletToCreateDict: [String: Any]) {
        UserDefaults.standard.set(name, forKey: "walletName")
        var descriptorDicts_ = descriptorDicts
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getblockchaininfo) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            guard let response = response as? [String: Any] else { return }
            var pruneHeight: Int?
            let blockchainInfo = BlockchainInfo(response)
            if blockchainInfo.pruned {
                pruneHeight = blockchainInfo.pruneheight
            }
            
            var showUpdatedTimestampAlert: Bool = false
            
            for i in 0..<descriptorDicts_.count {
                var descriptorDict = descriptorDicts_[i]
                
                if let descriptorTimestamp = descriptorDict["timestamp"] as? Int,
                   let pruneHeight = pruneHeight {
                    
                    if !checkPruneHeightAndTimestamp(descriptorTimestamp: descriptorTimestamp, pruneHeight: pruneHeight) {
                        // Update timestamp to pruneHeight
                        let estimatedTimestamp = approximateTimestamp(for: pruneHeight)
                        descriptorDict["timestamp"] = estimatedTimestamp
                        showUpdatedTimestampAlert = true
                    }
                }
                
                descriptorDicts_[i] = descriptorDict
            }
            
            if exists {
                processWalletThatExistsOnNode(name: name, exists: exists, backup: backup, descriptorDicts: descriptorDicts_, fnWalletToCreateDict: fnWalletToCreateDict, pruneHeight: pruneHeight, showUpdatedTimestampAlert: showUpdatedTimestampAlert)
            } else {
                // save the local wallet and import the descriptors.
                CoreDataService.saveEntity(dict: fnWalletToCreateDict, entityName: .wallets) { [weak self] walletRecovered in
                    guard let self = self else { return }
                    guard walletRecovered else {
                        showAlert(title: "Wallet backuo not updated.", message: "Please contact as asap and let us know about this bug.")
                        return
                    }
                    importDescNow(descriptorDicts: descriptorDicts_, exists: false, fnWalletToCreateDict: fnWalletToCreateDict, name: name, backup: backup, showUpdatedTimestampAlert: showUpdatedTimestampAlert)
                }
            }
        }
    }
    
    func checkPruneHeightAndTimestamp(descriptorTimestamp: Int, pruneHeight: Int) -> Bool {
        let target = Int64(descriptorTimestamp - 7_200)
        let estimatedHeight = approximateHeight(for: target)
        if pruneHeight <= estimatedHeight {
            return true
        } else {
            return false
        }
    }

    private func approximateHeight(for timestamp: Int64) -> Int {
        // Genesis block time (block 0)
        let genesisTime: Int64 = 1_231_006_505
        
        // Average seconds per block (Bitcoin target)
        let secondsPerBlock: Double = 600.0
        
        let elapsed = Double(timestamp - genesisTime)
        let height = elapsed / secondsPerBlock
        
        return max(0, Int(height.rounded()))
    }
    
    private func approximateTimestamp(for height: Int) -> Int64 {
        // Genesis block time (block 0)
        let genesisTime: Int64 = 1_231_006_505
        
        // Average seconds per block (Bitcoin target)
        let secondsPerBlock: Double = 600.0
        
        let elapsed = Double(height) * secondsPerBlock
        return genesisTime + Int64(elapsed.rounded())
    }
    
    private func processWalletThatExistsOnNode(name: String, exists: Bool, backup: WalletBackup, descriptorDicts: [[String: Any]], fnWalletToCreateDict: [String: Any], pruneHeight: Int?, showUpdatedTimestampAlert: Bool) {
        UserDefaults.standard.set(name, forKey: "walletName")
        
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listdescriptors) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            guard let response = response else { return }
            
            var uniqueDesc: [[String: Any]] = []
            var descriptorAlreadyExists = false
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: response, options: [])
                let listDescriptorResponse = try JSONDecoder().decode(ListDescriptorsResponse.self, from: jsonData)
                
                guard listDescriptorResponse.descriptors.count > 0 else {
                    importDescNow(descriptorDicts: descriptorDicts, exists: true, fnWalletToCreateDict: fnWalletToCreateDict, name: name, backup: backup, showUpdatedTimestampAlert: showUpdatedTimestampAlert)
                    return
                }
                
                for (d, descriptor) in listDescriptorResponse.descriptors.enumerated() {
                    
                    for (b, backupDescriptorDict) in descriptorDicts.enumerated() {
                        if descriptor.desc == backupDescriptorDict["desc"] as? String {
                            descriptorAlreadyExists = true
                        }
                        
                        if b + 1 == descriptorDicts.count,  !descriptorAlreadyExists {
                            uniqueDesc.append(backupDescriptorDict)
                        }
                    }
                    
                    if d + 1 == listDescriptorResponse.descriptors.count {
                        if uniqueDesc.count > 0 {
                            importDescNow(descriptorDicts: uniqueDesc, exists: true, fnWalletToCreateDict: fnWalletToCreateDict, name: name, backup: backup, showUpdatedTimestampAlert: showUpdatedTimestampAlert)
                        } else {
                            // else its the same exact wallet.. just activate and check for FNWallet equivalent..
                            CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] existingLocalFnWallets in
                                guard let self = self else { return }
                                guard let existingLocalFnWallets = existingLocalFnWallets, existingLocalFnWallets.count > 0 else { return }
                                var existsLocally = false
                                for (i, w) in existingLocalFnWallets.enumerated() {
                                    let existingFnWallet = Wallet(dictionary: w)
                                    if existingFnWallet.name == name {
                                        existsLocally = true
                                        // update it
                                        do {
                                            let data = try backup.jsonData()
                                            CoreDataService.update(id: existingFnWallet.id, keyToUpdate: "walletBackup", newValue: data, entity: .wallets) { [weak self] backupUpdated in
                                                guard let self = self else { return }
                                                spinner.dismiss()
                                                guard backupUpdated else {
                                                    showAlert(title: "Updating backup failed.", message: "Please contact as asap and let us know about this bug.")
                                                    return
                                                }
                                                showSuccess(showUpdatedTimestampAlert: showUpdatedTimestampAlert)
                                            }
                                        } catch {
                                            spinner.dismiss()
                                            showAlert(title: "Can not convert backup to json data", message: "Please contact as asap and let us know about this bug.")
                                        }
                                    }
                                    
                                    if i + 1 == existingLocalFnWallets.count, !existsLocally {
                                        // save the local fnwallet which exists on node only.
                                        CoreDataService.saveEntity(dict: fnWalletToCreateDict, entityName: .wallets) { [weak self] walletRecovered in
                                            guard let self = self else { return }
                                            guard walletRecovered else {
                                                showAlert(title: "Wallet backuo not updated.", message: "Please contact as asap and let us know about this bug.")
                                                return
                                            }
                                            showSuccess(showUpdatedTimestampAlert: showUpdatedTimestampAlert)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                spinner.dismiss {
                    showAlert(title: "Error parsing JSON", message: error.localizedDescription)
                }
            }
        }

    }
    
    private func createWallet(fnWalletToCreateDict: [String : Any], backup: WalletBackup, descriptorDicts: [[String: Any]]) {
        let p = Create_Wallet_Param([
            "wallet_name": (fnWalletToCreateDict["name"] as! String),
            "disable_private_keys": true,
            "blank": true,
            "avoid_reuse": true,
            "descriptors": true,
            "load_on_startup": true
        ])
        
        OnchainUtils.createWallet(param: p) { [weak self] (name, message) in
            guard let self = self else { return }
            guard let name = name else {
                if let message = message, message.contains("Database already exists") {
                    setActiveAndImport(name: fnWalletToCreateDict["name"] as! String, exists: true, backup: backup, descriptorDicts: descriptorDicts, fnWalletToCreateDict: fnWalletToCreateDict)
                } else {
                    spinner.dismiss()
                    showAlert(title: "", message: message ?? "Unknown error creating wallet.")
                }
                return
            }
            setActiveAndImport(name: name, exists: false, backup: backup, descriptorDicts: descriptorDicts, fnWalletToCreateDict: fnWalletToCreateDict)
        }
    }
    
    private func showSuccess(showUpdatedTimestampAlert: Bool) {
        spinner.dismiss {
            if showUpdatedTimestampAlert {
                SuccessView.show(
                    in: self,
                    title: "Backup Recovered\n⚠️ Pruned funds!",
                    subtitle: "The birthday of this wallet precedes your prune height (we updated the birthdate to match the prune height). If you don't see balances and a rescan does not show balances you will likely need to -reindex the blockchain."
                )
            } else {
                SuccessView.show(
                    in: self,
                    title: "Backup Recovered",
                    subtitle: "Your wallet has been recovered."
                )
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .refreshWallet, object: nil)
            }
        }
    }
    
    private func importDescNow(descriptorDicts: [[String: Any]], exists: Bool, fnWalletToCreateDict: [String: Any], name: String, backup: WalletBackup, showUpdatedTimestampAlert: Bool) {
        let p = Import_Descriptors(["requests": descriptorDicts])
        
        OnchainUtils.importDescriptors(p) { [weak self] (imported, message) in
            guard let self = self else { return }
            guard imported else {
                spinner.dismiss()
                if let message = message {
                    guard message.contains("-rescan") else {
                        showAlert(title: "", message: message)
                        return
                    }
                    showAlert(title: "", message: message)
                }
                return
            }
            
            if !exists {
                showSuccess(showUpdatedTimestampAlert: showUpdatedTimestampAlert)
            }
        }
    }
    
    private func processImportedString(_ item: String) {
        let lowercased = item.lowercased()
                
        if item.isValidHex, let walletBackup = decodeWalletBackup(from: item) {
            promptToImport(backup: walletBackup)
            
        } else if self.isExtendedKey(lowercased) {
            
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
            let (bip84, bip86, segwitCosigner, taprootCosigner, message) = Keys.descriptorsFromSigner(signer: item, passphrase: nil)
            
            guard let encryptedSigner = Crypto.encrypt(item.utf8) else {
                showAlert(vc: self, title: "Unable to encrypt your signer.", message: "Please let us know about this bug.")
                return
            }
            
            let dict = ["id":UUID(), "words":encryptedSigner, "added": Date()] as [String:Any]
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
                
                if let bip482 = coldcardSparrowExport.bip48_2, let desc = bip482.standardDesc {
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
            vc.isTaproot = isTaproot
            
        case "segueToImportDescriptor":
            guard let vc = segue.destination as? ImportXpubViewController else { fallthrough }
            
            vc.descriptor = descriptor
            
        default:
            break
        }
    }
}
