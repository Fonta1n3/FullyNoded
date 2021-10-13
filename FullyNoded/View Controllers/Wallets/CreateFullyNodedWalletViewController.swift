//
//  CreateFullyNodedWalletViewController.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit
import AVFoundation

class CreateFullyNodedWalletViewController: UIViewController, UINavigationControllerDelegate, UIDocumentPickerDelegate {
    
    @IBOutlet weak var multiSigOutlet: UIButton!
    @IBOutlet weak var singleSigOutlet: UIButton!
    
    var isDescriptor = false
    var onDoneBlock:(((Bool)) -> Void)?
    var spinner = ConnectingView()
    var ccXfp = ""
    var xpub = ""
    var deriv = ""
    var extendedKey = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        singleSigOutlet.layer.cornerRadius = 8
        multiSigOutlet.layer.cornerRadius = 8
    }
    
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
        let processed = string.condenseWhitespace()
        let lowercased = processed.lowercased()
        
        if isExtendedKey(lowercased) {
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.isDescriptor = false
                self.extendedKey = processed
                self.performSegue(withIdentifier: "segueToImportXpub", sender: self)
            }
            
        } else if lowercased.hasPrefix("ur:") {
            let (descriptors, error) = URHelper.parseUr(urString: lowercased)
            
            guard error == nil, let descriptors = descriptors else {
                showAlert(vc: self, title: "Error", message: error!)
                return
            }
            
            var accountMap:[String:Any] = ["descriptor": "", "blockheight": 0, "watching": [], "label": "Wallet Import"]
            
            if descriptors.count > 1 {
                self.prompToChoosePrimaryDesc(descriptors: descriptors)
            } else {
                accountMap["descriptor"] = descriptors[0]
                self.importAccountMap(accountMap)
            }
        } else if isDescriptor(lowercased) {
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.isDescriptor = true
                self.extendedKey = processed
                self.performSegue(withIdentifier: "segueToImportXpub", sender: self)
            }
            
        } else if let data = processed.data(using: .utf8) {
            if let accountMap = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] {
                promptToImportAccountMap(dict: accountMap)
            }
        }
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
        guard let _ = KeyChain.getData("UnlockPassword") else {
            showAlert(vc: self, title: "Security alert", message: "Single signature wallets store seed words on the app, you need to go to the home screen and tap the lock button to create a locking password before the app can hold seed words.")
            
            return
        }
        
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
    
    private func parseColdcardStyleTextFile(txt: String) -> [String:Any]? {
        let myStrings = txt.components(separatedBy: .newlines)
        var name = ""
        var sigsRequired = ""
        var deriv = ""
        var keys = [String]()
        var descriptor = ""
        
        for item in myStrings {
            if item.contains("Name: ") {
                name = item.replacingOccurrences(of: "Name: ", with: "")
            } else if item.contains("Policy: ") {
                let policy = item.replacingOccurrences(of: "Policy: ", with: "")
                let arr = policy.split(separator: " ")
                sigsRequired = "\(arr[0])"
            } else if item.contains("Format: ") {
                guard item.contains("P2WSH") else {
                    showAlert(vc: self, title: "Unsupported policy", message: "Currently we only support p2wsh multisig imports.")
                    return nil
                }
            } else if item.contains("Derivation: ") {
                deriv = item.replacingOccurrences(of: "Derivation: ", with: "")
            } else if item.hasPrefix("seed: ") && !item.hasPrefix("#") {
                keys.append(item)
            } else if !item.hasPrefix("#") {
                var processed = item.condenseWhitespace()
                processed = processed.replacingOccurrences(of: "\n", with: "")
                if processed != "" {
                    keys.append(processed.replacingOccurrences(of: " ", with: ""))
                }
            }
        }
        
        descriptor = "wsh(sortedmulti(\(sigsRequired),"
        
        for (i, key) in keys.enumerated() {
            
            func addKey(_ xpub: String, _ xfp: String) {
                if !xpub.hasPrefix("xpub") && !xpub.hasPrefix("tpub") {
                    guard let extKey = XpubConverter.convert(extendedKey: xpub) else {
                        showAlert(vc: self, title: "Error", message: "There was a problem converting your extended key to an xpub.")
                        return
                    }
                    
                    descriptor += "[\(xfp)/\(deriv.replacingOccurrences(of: "m/", with: ""))]\(extKey)/0/*"
                } else {
                    descriptor += "[\(xfp)/\(deriv.replacingOccurrences(of: "m/", with: ""))]\(xpub)/0/*"
                }
                
                if i < keys.count {
                    descriptor += ","
                } else {
                    descriptor += "))"
                }
            }
            
            if key.hasPrefix("seed: ") {
                let words = key.replacingOccurrences(of: "seed: ", with: "")
                
                guard let encryptedData = Crypto.encrypt(words.utf8) else {
                    showAlert(vc: self, title: "Unable to encrypt the seed words...", message: "Please let us know about this bug.")
                    return nil
                }
                
                saveSigner(encryptedSigner: encryptedData) { saved in
                    guard saved else {
                        showAlert(vc: self, title: "Unable to save the encrypted signer...", message: "Please let us know about this bug.")
                        return
                    }
                }
                
                var coinType = "0"
                
                let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
                
                if chain != "main" {
                    coinType = "1"
                }
                
                guard let mk = Keys.masterKey(words: words, coinType: coinType, passphrase: "") else {
                    showAlert(vc: self, title: "Unable to derive the master key from the seed words...", message: "Please let us know about this bug.")
                    return nil
                }
                
                guard let xfp = Keys.fingerprint(masterKey: mk) else {
                    showAlert(vc: self, title: "Unable to derive the fingerprint from the master key...", message: "Please let us know about this bug.")
                    return nil
                }
                
                guard let xpub = Keys.xpub(path: "m/48h/\(coinType)h/0h/2h", masterKey: mk) else {
                    showAlert(vc: self, title: "Unable to derive the bip48 xpub from the master key...", message: "Please let us know about this bug.")
                    return nil
                }
                
                addKey(xpub, xfp)
                
            } else {
                let arr = key.split(separator: ":")
                let xfp = "\(arr[0])"
                let xpub = "\(arr[1])"
                addKey(xpub, xfp)
            }
        }
        
        return ["descriptor": descriptor, "blockheight": 0, "watching": [], "label": name] as [String : Any]
    }
    
    private func saveSigner(encryptedSigner: Data, completion: @escaping ((Bool)) -> Void) {
        let dict = ["id":UUID(), "words":encryptedSigner] as [String:Any]
        CoreDataService.saveEntity(dict: dict, entityName: .signers) { success in
            completion(success)
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
            
            if let accountMap = parseColdcardStyleTextFile(txt: txt) {
                promptToImportCoboMultiSig(accountMap)
            }
            
            /*
             Name: CV_85C39000_2-3
             Policy: 2 of 3
             Derivation: m/48'/1'/0'/2'
             Format: P2WSH
             
             C2202A77: Vpub5nbpJQxCxQu9Nv5Effa1F8gdQsijrgk7KrMkioLs5DoRwb7MCjC3t1P2y9mXbnBgu29yL8EYexZqzniFdX7Xo3q8TuwkVAqbQpgxfAfrRiW
             5271C071: Vpub5mpRVCzdkDTtCwH9LrfiiPonePjP4CZSakA4wynC4zVBVAooaykiCzjUniYbLpWxoRotGiXwoKGcHC5kSxiJGX1Ybjf2ioNommVmCJg7AV2
             748CC6AA: Vpub5mcrJpVp9X8ZKsjyxwNu36SLRAWTMbqUtbmtcapahAtqVa66JtXhT4Uc9SVLN1nF782sPRRT2jbUbe7XzT8eue6vXsyDJKBvexGJHewyPxQ
             */
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
                            let accountMap = ["descriptor": descriptor, "blockheight": 0, "watching": [], "label": name] as [String : Any]
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
            promptToImportColdcardMsig(xfp, p2wsh, deriv)
            
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
    
    private func promptToImportCoboMultiSig(_ dict: [String:Any]) {
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
        
        let accountMap = ["descriptor": desc, "blockheight": 0, "watching": [], "label": "Wallet import"] as [String : Any]
        
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
            let alert = UIAlertController(title: "Create a multisig with your Coldcard?", message: "You have uploaded a Coldcard multisig file, this action allows you to easily create a wallet with your Coldcard and Fully Noded.", preferredStyle: .alert)
            
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
        var accountMap:[String:Any] = ["descriptor": "", "blockheight": 0, "watching": [], "label": "Wallet Import"]
        accountMap["descriptor"] = descriptors[descriptorToUseIndex]
        var arrayOfWatching:[String] = []
        
        for (i, desc) in descriptors.enumerated() {
            if i != descriptorToUseIndex {
                arrayOfWatching.append(desc)
            }
        }
        
        accountMap["watching"] = arrayOfWatching
        self.importAccountMap(accountMap)
    }
    
    func prompToChoosePrimaryDesc(descriptors: [String]) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Select primary address format.", message: "You are adding multiple descriptors which is great, but you need to choose one to be the primary descriptor we use to derive receive addresses.", preferredStyle: .alert)
            
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
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToScanner" {
            if #available(macCatalyst 14.0, *) {
                if let vc = segue.destination as? QRScannerViewController {
                    vc.isAccountMap = true
                    vc.onImportDoneBlock = { [unowned thisVc = self] accountMap in
                        if accountMap != nil {
                            thisVc.importAccountMap(accountMap!)
                        }
                    }
                    
                    vc.onAddressDoneBlock = { [weak self] item in
                        guard let self = self else { return }
                        
                        guard let item = item else {
                            return
                        }
                        
                        let lowercased = item.lowercased()
                        
                        if self.isExtendedKey(lowercased) {
                            
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                
                                self.isDescriptor = false
                                self.extendedKey = item
                                self.performSegue(withIdentifier: "segueToImportXpub", sender: self)
                            }
                            
                        } else if self.isDescriptor(lowercased) {
                            
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                
                                self.isDescriptor = true
                                self.extendedKey = item
                                self.performSegue(withIdentifier: "segueToImportXpub", sender: self)
                            }
                            
                        } else if lowercased.hasPrefix("ur:") {
                            if lowercased.hasPrefix("ur:bytes") {
                                let (text, err) = URHelper.parseBlueWalletCoordinationSetup(lowercased)
                                if let textFile = text {
                                     if let dict = try? JSONSerialization.jsonObject(with: textFile.utf8, options: []) as? [String:Any] {
                                        let sparrowStruct = SparrowWalletImport(dict)
                                        
                                        var descriptors:[String] = []
                                        
                                        if let bip44 = sparrowStruct.bip44 {
                                            descriptors.append(bip44)
                                        }
                                        if let bip49 = sparrowStruct.bip49 {
                                            descriptors.append(bip49)
                                        }
                                        if let bip84 = sparrowStruct.bip84 {
                                            descriptors.append(bip84)
                                        }
//                                        if let bip48 = sparrowStruct.bip48 {
//                                            descriptors.append(bip48)
//                                        }
                                        
                                        self.prompToChoosePrimaryDesc(descriptors: descriptors)
                                        
                                     } else if let accountMap = self.parseColdcardStyleTextFile(txt: textFile) {
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
                                
                                var accountMap:[String:Any] = ["descriptor": "", "blockheight": 0, "watching": [], "label": "Wallet Import"]
                                
                                if descriptors.count > 1 {
                                    self.prompToChoosePrimaryDesc(descriptors: descriptors)
                                } else {
                                    accountMap["descriptor"] = descriptors[0]
                                    self.importAccountMap(accountMap)
                                }
                            }
                        } else if let accountMap = self.parseColdcardStyleTextFile(txt: item) {
                            self.importAccountMap(accountMap)
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
        
        if segue.identifier == "segueToImportDescriptor" {
            if let vc = segue.destination as? ImportXpubViewController {
                vc.isDescriptor = true
            }
        }
        
        if segue.identifier == "segueToImportXpub" {
            if let vc = segue.destination as? ImportXpubViewController {
                vc.isDescriptor = self.isDescriptor
                vc.extKey = self.extendedKey
            }
        }
    }
}
