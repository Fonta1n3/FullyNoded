//
//  NodeDetailViewController.swift
//  BitSense
//
//  Created by Peter on 16/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import AVFoundation

class NodeDetailViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    let spinner = ConnectingView()
    var selectedNode:[String:Any]?
    let cd = CoreDataService()
    var createNew = Bool()
    var newNode = [String:Any]()
    var isInitialLoad = Bool()
    var isLightning = Bool()
    var isHost = Bool()
    var hostname: String?
    let imagePicker = UIImagePickerController()
    var scanNow = false
    var isNostr = false
    var isJoinMarket = false
    var isBitcoinCore = false
    var isLND = false
    var isCLN = false
    
    
    @IBOutlet weak var rpcAuthCopyButton: UIButton!
    @IBOutlet weak var rpcAuthLabel: UILabel!
    @IBOutlet weak var rpcAuthHeader: UILabel!
    @IBOutlet weak var masterStackView: UIStackView!
    @IBOutlet weak var seeEncryptionWordsButton: UIButton!
    @IBOutlet weak var nostrEncryptionWordsField: UITextField!
    @IBOutlet weak var nostrEncryptionWordsHeader: UILabel!
    @IBOutlet weak var scanNostrPubkeyQr: UIButton!
    @IBOutlet weak var showNostrPubkeyQr: UIButton!
    @IBOutlet weak var refreshNostrPrivkeyOutlet: UIButton!
    @IBOutlet weak var nostrRelayField: UITextField!
    @IBOutlet weak var nostrRelayHeader: UILabel!
    @IBOutlet weak var addressHeader: UILabel!
    @IBOutlet weak var nostrSubscriptionHeader: UILabel!
    @IBOutlet weak var nostrPrivkeyHeader: UILabel!
    @IBOutlet weak var nostrPubkeyHeader: UILabel!
    @IBOutlet weak var certHeader: UILabel!
    @IBOutlet weak var certField: UITextField!
    @IBOutlet weak var macaroonField: UITextField!
    @IBOutlet weak var passwordHeader: UILabel!
    @IBOutlet weak var usernameHeader: UILabel!
    @IBOutlet weak var scanQROutlet: UIBarButtonItem!
    @IBOutlet weak var header: UILabel!
    @IBOutlet var nodeLabel: UITextField!
    @IBOutlet var rpcUserField: UITextField!
    @IBOutlet var rpcPassword: UITextField!
    @IBOutlet var rpcLabel: UILabel!
    @IBOutlet var saveButton: UIButton!
    @IBOutlet weak var onionAddressField: UITextField!
    @IBOutlet weak var addressHeaderOutlet: UILabel!
    @IBOutlet weak var macaroonHeader: UILabel!
    @IBOutlet weak var nostrPubkeyField: UITextField!
    @IBOutlet weak var nostrPrivkeyField: UITextField!
    @IBOutlet weak var nostrToSubscribe: UITextField!
    @IBOutlet weak var networkControlOutlet: UISegmentedControl!
    @IBOutlet weak var exportNodeOutlet: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        masterStackView.alpha = 0
        networkControlOutlet.alpha = 0
        navigationController?.delegate = self
        configureTapGesture()
        nodeLabel.delegate = self
        rpcPassword.delegate = self
        rpcUserField.delegate = self
        onionAddressField.delegate = self
        nostrToSubscribe.delegate = self
        certField.delegate = self
        nostrEncryptionWordsField.delegate = self
        nostrRelayField.delegate = self
        macaroonField.delegate = self
        nostrPubkeyField.delegate = self
        nostrPrivkeyField.delegate = self
        rpcPassword.isSecureTextEntry = true
        onionAddressField.isSecureTextEntry = false
        nostrPrivkeyField.isSecureTextEntry = true
        saveButton.clipsToBounds = true
        saveButton.layer.cornerRadius = 8
        scanNostrPubkeyQr.setTitle("", for: .normal)
        showNostrPubkeyQr.setTitle("", for: .normal)
        seeEncryptionWordsButton.setTitle("", for: .normal)
        refreshNostrPrivkeyOutlet.setTitle("", for: .normal)
        header.text = "Node Credentials"
        navigationController?.delegate = self
        rpcPassword.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
        rpcUserField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
        
        rpcAuthLabel.numberOfLines = 0
        rpcAuthLabel.sizeToFit()
        rpcAuthLabel.translatesAutoresizingMaskIntoConstraints = false
        
        if isLightning {
            onionAddressField.placeholder = "localhost:9737"
        } else if isJoinMarket {
            onionAddressField.placeholder = "localhost:28183"
        }
        
        if isNostr {
            createNostrCreds()
        }
        
        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        switch chain {
        case "main":
            networkControlOutlet.selectedSegmentIndex = 0
        case "test":
            networkControlOutlet.selectedSegmentIndex = 1
        case "regtest":
            networkControlOutlet.selectedSegmentIndex = 2
        case "signet":
            networkControlOutlet.selectedSegmentIndex = 3
        default:
            break
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadValues()
        
        if scanNow {
            segueToScanNow()
        }
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        if rpcUserField.text != "" && rpcPassword.text != "" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                guard let auth = RPCAuth().generateCreds(username: rpcUserField.text!, password: rpcPassword.text!) else { return }
                
                rpcAuthLabel.text = auth.rpcAuth
            }
        }
    }
    
    @IBAction func switchNetworkAction(_ sender: Any) {
        switch networkControlOutlet.selectedSegmentIndex {
        case 0: updateChain("main")
        case 1: updateChain("test")
        case 2: updateChain("regtest")
        case 3: updateChain("signet")
        default:
            break
        }
    }
    
    private func updateChain(_ chain: String) {
        UserDefaults.standard.set(chain, forKey: "chain")
    }
    
    @IBAction func seeEncryptionWordsAction(_ sender: Any) {
        showAlert(vc: self, title: "", message: self.nostrEncryptionWordsField.text ?? "None exist yet.")
    }
    
    @IBAction func refreshNostrPrivkeyAction(_ sender: Any) {
        createNostrCreds()
    }
    
    @IBAction func showNostrPubkeyAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isNostr = true
            self.performSegue(withIdentifier: "segueToExportNode", sender: self)
                
        }
    }
    
    @IBAction func scanNostrPubkeyAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isNostr = true
            self.performSegue(withIdentifier: "segueToScanNodeCreds", sender: self)
        }
    }
    
    func removeNostrStuff() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.nostrRelayField != nil,
               self.nostrPubkeyField != nil,
               self.nostrRelayHeader != nil,
               self.nostrToSubscribe != nil,
               self.nostrPubkeyHeader != nil,
               self.nostrPrivkeyField != nil,
               self.nostrPrivkeyHeader != nil,
               self.nostrSubscriptionHeader != nil,
               self.scanNostrPubkeyQr != nil,
               self.showNostrPubkeyQr != nil,
               self.refreshNostrPrivkeyOutlet != nil,
               self.nostrEncryptionWordsField != nil,
               self.nostrEncryptionWordsField != nil,
               self.seeEncryptionWordsButton != nil {
                self.seeEncryptionWordsButton.removeFromSuperview()
                self.nostrEncryptionWordsField.removeFromSuperview()
                self.nostrEncryptionWordsHeader.removeFromSuperview()
                self.refreshNostrPrivkeyOutlet.removeFromSuperview()
                self.showNostrPubkeyQr.removeFromSuperview()
                self.scanNostrPubkeyQr.removeFromSuperview()
                self.nostrSubscriptionHeader.removeFromSuperview()
                self.nostrRelayField.removeFromSuperview()
                self.nostrRelayHeader.removeFromSuperview()
                self.nostrPubkeyField.removeFromSuperview()
                self.nostrPubkeyHeader.removeFromSuperview()
                self.nostrToSubscribe.removeFromSuperview()
                self.nostrPrivkeyField.removeFromSuperview()
                self.nostrPrivkeyHeader.removeFromSuperview()
            }
        }
    }
    
    func removeNonNostrStuff() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.rpcUserField != nil,
               self.rpcPassword != nil,
               self.passwordHeader != nil,
               self.usernameHeader != nil,
               self.usernameHeader != nil,
               self.macaroonField != nil,
               self.macaroonHeader != nil,
               self.certField != nil,
               self.certHeader != nil,
               self.addressHeader != nil,
               self.onionAddressField != nil,
               self.rpcAuthLabel != nil,
               self.rpcAuthHeader != nil,
               self.rpcAuthCopyButton != nil {
                self.rpcAuthCopyButton.removeFromSuperview()
                self.rpcAuthHeader.removeFromSuperview()
                self.rpcAuthLabel.removeFromSuperview()
                self.addressHeader.removeFromSuperview()
                self.rpcUserField.removeFromSuperview()
                self.rpcPassword.removeFromSuperview()
                self.passwordHeader.removeFromSuperview()
                self.usernameHeader.removeFromSuperview()
                self.macaroonField.removeFromSuperview()
                self.macaroonHeader.removeFromSuperview()
                self.certField.removeFromSuperview()
                self.certHeader.removeFromSuperview()
                self.onionAddressField.removeFromSuperview()
                self.scanQROutlet.tintColor = .clear
                self.exportNodeOutlet.tintColor = .clear
                self.networkControlOutlet.alpha = 1
            }
        }
    }
    
    func createNostrCreds() {
        let privkey = Crypto.privateKey()
        let pubkey = Keys.privKeyToPubKey(privkey)!
        guard let seed = Keys.seed() else { return }
        let arr = seed.split(separator: " ")
        var encryptionWords = ""
        for (i, word) in arr.enumerated() {
            if i < 5 {
                encryptionWords += word
                if i < 4 {
                    encryptionWords += " "
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.nostrPubkeyField.text = pubkey
            self.nostrPrivkeyField.text = privkey.hexString
            self.nostrRelayField.text = UserDefaults.standard.string(forKey: "nostrRelay") ?? "wss://nostr-relay.wlvs.space"
            self.nodeLabel.text = "Nostr Node"
            self.nostrEncryptionWordsField.isSecureTextEntry = true
            self.nostrEncryptionWordsField.text = encryptionWords
            self.removeNonNostrStuff()
            showAlert(vc: self, title: "", message: "Nostr node credentials created ✓")
        }
    }
    
    private func hash(_ text: String) -> Data? {
        return Data(hexString: Crypto.sha256hash(text))
    }
    
    @IBAction func showGuideAction(_ sender: Any) {
        guard let url = URL(string: "https://github.com/Fonta1n3/FullyNoded/blob/master/Docs/Bitcoin-Core/Connect.md") else {
            showAlert(vc: self, title: "", message: "The web page is not reachable.")
            
            return
        }
        
        UIApplication.shared.open(url)
    }
    
    
    @IBAction func copyRpcAuthAction(_ sender: Any) {
        guard let auth = rpcAuthLabel.text else { return }
        
        UIPasteboard.general.string = auth
        
        showAlert(vc: self, title: "", message: "Rpc auth copied ✓")
    }
    
    
//    @IBAction func showHostAction(_ sender: Any) {
//    #if targetEnvironment(macCatalyst)
//        // Code specific to Mac.
//        guard !isNostr, let _ = selectedNode, onionAddressField != nil, let hostAddress = onionAddressField.text, hostAddress != "" else {
//            showAlert(vc: self, title: "", message: "This feature only works once the node has been saved.")
//            return
//        }
//        let macName = UIDevice.current.name
//        if hostAddress.contains("127.0.0.1") || hostAddress.contains("localhost") || hostAddress.contains(macName) {
//            hostname = TorClient.sharedInstance.hostname()
//            if hostname != nil {
//                hostname = hostname?.replacingOccurrences(of: "\n", with: "")
//                isHost = true
//                DispatchQueue.main.async { [unowned vc = self] in
//                    vc.performSegue(withIdentifier: "segueToExportNode", sender: vc)
//                }
//            } else {
//                showAlert(vc: self, title: "", message: "There was an error getting your hostname for remote connection... Please make sure you are connected to the internet and that Tor successfully bootstrapped.")
//            }
//        } else {
//            showAlert(vc: self, title: "", message: "This feature can only be used with nodes which are running on the same computer as Fully Noded - Desktop.")
//        }
//    #else
//        // Code to exclude from Mac.
//        showAlert(vc: self, title: "", message: "This is a macOS feature only, when you use Fully Noded - Desktop, it has the ability to display a QR code you can scan with your iPhone or iPad to connect to your node remotely.")
//    #endif
//    }
    
    
    @IBAction func scanQuickConnect(_ sender: Any) {
        segueToScanNow()
    }
    
    private func segueToScanNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToScanNodeCreds", sender: self)
        }
    }
    
    @IBAction func goManageLightning(_ sender: Any) {
        if isLightning {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.performSegue(withIdentifier: "segueToLightningSettings", sender: vc)
            }
        }
    }
    
    @IBAction func exportNode(_ sender: Any) {
        if !isNostr {
            segueToExport()
        } else {
            showAlert(vc: self, title: "", message: "To export a nostr node just tap the QR on the public key.")
        }
    }
    
    private func segueToExport() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToExportNode", sender: vc)
        }
    }
    
    private func encryptCert(_ certText: String) -> Data? {
        print("cerText: \(certText)")
//         guard let certData = Data(base64Encoded: certText.condenseWhitespace(), options: []) else {
//             showAlert(vc: self, title: "Error", message: "Unable to convert the cert text to base64 data.")
//             return nil
//         }
        let certData = Data(certText.utf8)
         
         guard let encryptedCert = Crypto.encrypt(certData) else {
             showAlert(vc: self, title: "Error", message: "Unable to encrypt your cert data.")
             return nil
         }
        
        return encryptedCert
    }
    
    @IBAction func save(_ sender: Any) {
        
        func encryptedValue(_ decryptedValue: Data) -> Data? {
            return Crypto.encrypt(decryptedValue)
        }
        
        if createNew || selectedNode == nil {
            newNode["id"] = UUID()
            newNode["isLightning"] = isLightning
            newNode["isJoinMarket"] = isJoinMarket
            newNode["isNostr"] = isNostr
            
            if onionAddressField != nil,
                let onionAddressText = onionAddressField.text {
               guard let encryptedOnionAddress = encryptedValue(onionAddressText.utf8)  else {
                    showAlert(vc: self, title: "", message: "Error encrypting the address.")
                    return }
                newNode["onionAddress"] = encryptedOnionAddress
            }
            
            if nostrToSubscribe != nil,
                nostrToSubscribe.text != nil,
                nostrToSubscribe.text! != "",
                nostrToSubscribe.text!.isAlphanumeric,
                let data = Data(hexString: nostrToSubscribe.text!)  {
                newNode["subscribeTo"] = encryptedValue(data)
            }
            
            if nodeLabel.text != "" {
                newNode["label"] = nodeLabel.text!
            }
            
            if isBitcoinCore,
                rpcUserField != nil {
                if rpcUserField.text != "" {
                    guard let enc = encryptedValue((rpcUserField.text)!.dataUsingUTF8StringEncoding) else { return }
                    newNode["rpcuser"] = enc
                }
                
                if rpcPassword != nil {
                    if rpcPassword.text != "" {
                        guard let enc = encryptedValue((rpcPassword.text)!.dataUsingUTF8StringEncoding) else { return }
                        newNode["rpcpassword"] = enc
                    }
                }
            }
            
            if isLightning {
                if rpcPassword != nil {
                    if rpcPassword.text != "" {
                        guard let enc = encryptedValue((rpcPassword.text)!.dataUsingUTF8StringEncoding) else { return }
                        newNode["rpcpassword"] = enc
                    }
                }
            }
            
            if isLightning,
                macaroonField != nil,
                macaroonField.text != "" {
                var macaroonData:Data?
                if let macaroonDataCheck = try? Data.decodeUrlSafeBase64(macaroonField.text!) {
                    macaroonData = macaroonDataCheck
                } else if let macaroonDataCheck = Data(hexString: macaroonField.text!) {
                    macaroonData = macaroonDataCheck
                }
                guard let macaroonData = macaroonData else {
                    showAlert(vc: self, title: "", message: "Error decoding your macaroon. It can either be in hex or base64 format.")
                    return
                }
                guard let encryptedMacaroonHex = Crypto.encrypt(macaroonData.hexString.dataUsingUTF8StringEncoding) else { return }
                newNode["macaroon"] = encryptedMacaroonHex
            }
            
            if isLightning || isJoinMarket,
               certField != nil, certField.text != "" {
                guard let encryptedCert = encryptCert(certField.text!) else {
                    return
                }
                newNode["cert"] = encryptedCert
            }
            
            if isNostr, let encryptionWordsField = self.nostrEncryptionWordsField, let encryptionWords = encryptionWordsField.text {
                guard let encryptedWords = Crypto.encrypt(encryptionWords.utf8) else { return }
                
                newNode["nostrWords"] = encryptedWords
                
                if nostrRelayField != nil, nostrRelayField.text != nil {
                    UserDefaults.standard.setValue(nostrRelayField.text!, forKey: "nostrRelay")
                }
                
                if nostrPrivkeyField != nil, nostrPrivkeyField.text != "", nostrPrivkeyField.text!.isAlphanumeric {
                    if let privkey = Data(hexString: nostrPrivkeyField.text!) {
                        newNode["nostrPrivkey"] = encryptedValue(privkey)
                        guard let pubkey = Keys.privKeyToPubKey(privkey) else { return }
                        newNode["nostrPubkey"] = encryptedValue(Data(hexString: pubkey)!)
                    } else {
                        showAlert(vc: self, title: "", message: "Invalid nostr private key.")
                    }
                }
            }
            
            func save() {
                CoreDataService.retrieveEntity(entityName: .newNodes) { [unowned vc = self] nodes in
                    if nodes != nil {
                        if nodes!.count == 0 {
                            vc.newNode["isActive"] = true
                        } else {
                            if self.onionAddressField != nil, !self.onionAddressField.text!.hasSuffix(":28183") {
                                vc.newNode["isActive"] = false
                            }
                        }
                        
                        CoreDataService.saveEntity(dict: vc.newNode, entityName: .newNodes) { [unowned vc = self] success in
                            if success {
                                vc.nodeAddedSuccess()
                            } else {
                                displayAlert(viewController: vc, isError: true, message: "Error saving tor node")
                            }
                        }
                    }
                }
            }
            guard nodeLabel.text != "" else {
                displayAlert(viewController: self,
                             isError: true,
                             message: "Fill out all fields first")
                return
            }
            save()
        } else {
            //updating
            let id = selectedNode!["id"] as! UUID
            
            if nodeLabel.text != "" {
                CoreDataService.update(id: id, keyToUpdate: "label", newValue: nodeLabel.text!, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating label")
                    }
                }
            }
            
            if nostrPrivkeyField != nil, nostrPrivkeyField.text != "", nostrPrivkeyField.text!.isAlphanumeric {
                guard let data = Data(hexString: nostrPrivkeyField.text!), let enc = encryptedValue(data) else { return }
                CoreDataService.update(id: id, keyToUpdate: "nostrPrivkey", newValue: enc, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating nostr privkey")
                    }
                    
                    guard let pubkeydata = Data(hexString: self.nostrPrivkeyField.text!),
                            let newpubkey = Keys.privKeyToPubKey(pubkeydata),
                          let enc = encryptedValue(Data(hexString: newpubkey)!)else { return }
                                        
                    CoreDataService.update(id: id, keyToUpdate: "nostrPubkey", newValue: enc, entity: .newNodes) { [weak self] success in
                        guard let self = self else { return }
                        if !success {
                            displayAlert(viewController: self, isError: true, message: "error updating nostr pubkey")
                        }
                        
                        if self.nostrToSubscribe != nil, self.nostrToSubscribe.text != "", self.nostrToSubscribe.text!.isAlphanumeric, let data = Data(hexString: self.nostrToSubscribe.text!) {
                            guard let enc = encryptedValue(data) else { return }
                            CoreDataService.update(id: id, keyToUpdate: "subscribeTo", newValue: enc, entity: .newNodes) { success in
                                if !success {
                                    displayAlert(viewController: self, isError: true, message: "error updating subscribe to")
                                } else {
                                    if self.nostrRelayField != nil, let txt = self.nostrRelayField.text {
                                        
                                        if let encryptionWordsField = self.nostrEncryptionWordsField, let encryptionWords = encryptionWordsField.text {
                                            guard let encryptedWords = Crypto.encrypt(encryptionWords.utf8) else { return }
                                            
                                            CoreDataService.update(id: id, keyToUpdate: "nostrWords", newValue: encryptedWords, entity: .newNodes) { saved in
                                                if saved {
                                                    UserDefaults.standard.setValue(txt, forKey: "nostrRelay")
                                                    DispatchQueue.main.async {
                                                        NotificationCenter.default.post(name: .refreshNode, object: nil)
                                                    }
                                                } else {
                                                    showAlert(vc: self, title: "", message: "Error updating encryption words.")
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
            
            if rpcUserField != nil, rpcUserField.text != "" {
                guard let enc = encryptedValue((rpcUserField.text)!.dataUsingUTF8StringEncoding) else { return }
                CoreDataService.update(id: id, keyToUpdate: "rpcuser", newValue: enc, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating rpc username")
                    }
                }
            }
            
            if rpcPassword != nil, rpcPassword.text != "" {
                guard let enc = encryptedValue((rpcPassword.text)!.dataUsingUTF8StringEncoding) else { return }
                CoreDataService.update(id: id, keyToUpdate: "rpcpassword", newValue: enc, entity: .newNodes) { [weak self] success in
                    guard let self = self else { return }
                    
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating rpc password")
                    } else {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            guard let auth = RPCAuth().generateCreds(username: rpcUserField.text!, password: rpcPassword.text!) else { return }
                            
                            rpcAuthLabel.text = auth.rpcAuth
                        }
                    }
                }
            }
            
            if onionAddressField != nil, let addressText = onionAddressField.text {
                let decryptedAddress = addressText.dataUsingUTF8StringEncoding
                
                if onionAddressField.text!.hasSuffix(":8080") || onionAddressField.text!.hasSuffix(":10080") || onionAddressField.text!.hasSuffix(":9737") {
                    CoreDataService.update(id: id, keyToUpdate: "isLightning", newValue: true, entity: .newNodes) { success in
                        if !success {
                            displayAlert(viewController: self, isError: true, message: "error updating isLightning")
                        }
                    }
                }
                if onionAddressField.text!.hasSuffix(":28183") {
                    CoreDataService.update(id: id, keyToUpdate: "isJoinMarket", newValue: true, entity: .newNodes) { success in
                        if !success {
                            displayAlert(viewController: self, isError: true, message: "error updating isJoinMarket")
                        }
                    }
                }
                
                let arr = addressText.split(separator: ":")
                guard arr.count == 2 else {
                    showAlert(vc: self, title: "Not updated, port missing...", message: "Please make sure you add the port at the end of your onion hostname, such as xjshdu.onion:8332.\n\n8332 for mainnet, 8080 for LND or 28183 for Join Market.")
                    return
                }
                
                guard let encryptedOnionAddress = encryptedValue(decryptedAddress) else { return }
                
                CoreDataService.update(id: id, keyToUpdate: "onionAddress", newValue: encryptedOnionAddress, entity: .newNodes) { [unowned vc = self] success in
                    if success {
                        vc.nodeAddedSuccess()
                    } else {
                        displayAlert(viewController: vc, isError: true, message: "Error updating node!")
                    }
                }
            }
            
            if macaroonField != nil, macaroonField.text != "" {
                var macaroonData:Data?
                
                if let macaroonDataCheck = try? Data.decodeUrlSafeBase64(macaroonField.text!) {
                    macaroonData = macaroonDataCheck
                } else if let macaroonDataCheck = Data(hexString: macaroonField.text!) {
                    macaroonData = macaroonDataCheck
                }
                
                guard let macaroonData = macaroonData else {
                    showAlert(vc: self, title: "", message: "Error decoding your macaroon. It can either be in hex or base64 format.")
                    return
                }
                
                guard let encryptedMacaroonHex = Crypto.encrypt(macaroonData.hexString.dataUsingUTF8StringEncoding) else { return }
                                
                CoreDataService.update(id: id, keyToUpdate: "macaroon", newValue: encryptedMacaroonHex, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating macaroon")
                    }
                }
            }
            
            if certField != nil && certField.text != "" {
                guard let encryptedCert = encryptCert(certField.text!) else { return }
                
                CoreDataService.update(id: id, keyToUpdate: "cert", newValue: encryptedCert, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating cert")
                    }
                }
            }
            
            nodeAddedSuccess()
        }
    }
    
    func configureTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
    
    func loadValues() {
        
        func decryptedValue(_ encryptedValue: Data) -> String {
            guard let decrypted = Crypto.decrypt(encryptedValue) else { return "" }
            
            return decrypted.utf8String ?? ""
        }
        
        func decryptedNostr(_ encryptedValue: Data) -> String {
            guard let decrypted = Crypto.decrypt(encryptedValue) else { return "" }
            
            return decrypted.hexString
        }
        
        if selectedNode != nil {
            let node = NodeStruct(dictionary: selectedNode!)
            isNostr = node.isNostr
            if node.id != nil {
                if node.isNostr {
                    removeNonNostrStuff()
                    
                    if let encryptedWords = node.nostrWords {
                        guard let decryptedWords = Crypto.decrypt(encryptedWords) else { return }
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.nostrEncryptionWordsField.isSecureTextEntry = true
                            self.nostrEncryptionWordsField.text = decryptedWords.utf8String!
                        }
                    }
                    
                    if let encryptedPubkey = node.nostrPubkey {
                        let nostrPubkey = decryptedNostr(encryptedPubkey)
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.nostrPubkeyField.text = nostrPubkey
                        }
                    }
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.nostrRelayField.text = UserDefaults.standard.string(forKey: "nostrRelay") ?? "wss://nostr-relay.wlvs.space"
                    }
                                        
                    if let encryptedPrivkey = node.nostrPrivkey {
                        let nostrPrivkey = decryptedNostr(encryptedPrivkey)
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.nostrPrivkeyField.text = nostrPrivkey
                        }
                    }
                    
                    if let encryptedSubscribe = node.subscribeTo {
                        let nostrSubscribeTo = decryptedNostr(encryptedSubscribe)
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.nostrToSubscribe.text = nostrSubscribeTo
                        }
                    }
                } else {
                    removeNostrStuff()
                    if node.isLightning {
                        removeNonLightning()
                    } else {
                        if !node.isJoinMarket {
                            removeNonBitcoinCoreStuff()
                        }
                    }
                }
                
                if node.label != "" {
                    nodeLabel.text = node.label
                }
                
                if let user = node.rpcuser, let password = node.rpcpassword {
                    rpcUserField.text = decryptedValue(user)
                    rpcPassword.text = decryptedValue(node.rpcpassword!)
                    
                    if let auth = RPCAuth().generateCreds(username: rpcUserField.text!, password: rpcPassword.text!) {
                        rpcAuthLabel.text = auth.rpcAuth
                    }
                }
                                
                if let enc = node.onionAddress {
                    let decrypted = decryptedValue(enc)
                    if onionAddressField != nil {
                        onionAddressField.text = decrypted
                    }
                    
                    if decrypted.hasSuffix(":28183"),
                        rpcUserField != nil,
                        rpcPassword != nil,
                        passwordHeader != nil,
                        usernameHeader != nil,
                        usernameHeader != nil,
                        macaroonField != nil,
                        macaroonHeader != nil {
                        rpcAuthLabel.removeFromSuperview()
                        rpcAuthHeader.removeFromSuperview()
                        rpcAuthCopyButton.removeFromSuperview()
                        rpcUserField.removeFromSuperview()
                        rpcPassword.removeFromSuperview()
                        passwordHeader.removeFromSuperview()
                        usernameHeader.removeFromSuperview()
                        macaroonField.removeFromSuperview()
                        macaroonHeader.removeFromSuperview()
                        exportNodeOutlet.tintColor = .clear
                        scanQROutlet.tintColor = .clear
                        networkControlOutlet.alpha = 0
                    }
                }
                
                if node.cert != nil, certField != nil {
                    if let decryptedCert = Crypto.decrypt(node.cert!) {
                        certField.text = decryptedCert.utf8String ?? ""
                    }
                }
                
                if node.macaroon != nil, macaroonField != nil {
                    let hex = decryptedValue(node.macaroon!)
                    macaroonField.text = Data(hexString: hex)!.urlSafeB64String
                }
                
            }
        } else {
            if isNostr {
                removeNonNostrStuff()
            } else {
                removeNostrStuff()
            }
            
            if isLightning {
                removeNonLightning()
            }
            
            if isBitcoinCore {
                removeNonBitcoinCoreStuff()
                
                rpcUserField.text = "FullyNoded"
                rpcPassword.text = Crypto.privateKey().hex
                
                if let auth = RPCAuth().generateCreds(username: rpcUserField.text!, password: rpcPassword.text!) {
                    rpcAuthLabel.text = auth.rpcAuth
                }
                
                showAlert(vc: self, title: "RPC credentials created ✓", message: "Fully Noded creates an rpc password for you by default, export the rpc auth text to your bitcoin.conf, save it and restart your node to connect.")
            }
            
            if isJoinMarket {
                removeNonJm()
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.masterStackView.alpha = 1
        }
    }
    
    private func removeNonBitcoinCoreStuff() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.macaroonField != nil {
                self.macaroonField.removeFromSuperview()
            }
            if self.macaroonHeader != nil {
                self.macaroonHeader.removeFromSuperview()
            }
            if self.certField != nil {
                self.certField.removeFromSuperview()
            }
            if self.certHeader != nil {
                self.certHeader.removeFromSuperview()
            }
        }
    }
    
    private func removeNonJm() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.rpcAuthLabel.removeFromSuperview()
            self.rpcAuthHeader.removeFromSuperview()
            self.rpcAuthCopyButton.removeFromSuperview()
            self.rpcUserField.removeFromSuperview()
            self.exportNodeOutlet.tintColor = .clear
            self.scanQROutlet.tintColor = .clear
            self.rpcPassword.removeFromSuperview()
            self.passwordHeader.removeFromSuperview()
            self.usernameHeader.removeFromSuperview()
            self.macaroonField.removeFromSuperview()
            self.macaroonHeader.removeFromSuperview()
        }
    }
    
    private func removeNonLightning() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if rpcAuthLabel != nil, rpcAuthHeader != nil, rpcAuthCopyButton != nil {
                rpcAuthLabel.removeFromSuperview()
                rpcAuthHeader.removeFromSuperview()
                rpcAuthCopyButton.removeFromSuperview()
            }
            
            if self.isCLN {
                self.onionAddressField.placeholder = "localhost:9737"
                self.rpcPassword.placeholder = "Sparko key"
                self.passwordHeader.text = "Sparko key"
                self.usernameHeader.removeFromSuperview()
                self.certField.removeFromSuperview()
                self.certHeader.removeFromSuperview()
                self.macaroonField.removeFromSuperview()
                self.macaroonHeader.removeFromSuperview()
            } else if self.isLND {
                self.onionAddressField.placeholder = "localhost:8080"
                self.rpcPassword.removeFromSuperview()
                self.passwordHeader.removeFromSuperview()
            }
            self.usernameHeader.removeFromSuperview()
            self.rpcUserField.removeFromSuperview()
            self.exportNodeOutlet.tintColor = .clear
            self.scanQROutlet.tintColor = .clear
        }
    }
    
    private func removeLND() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.usernameHeader.removeFromSuperview()
            self.macaroonField.removeFromSuperview()
            self.macaroonHeader.removeFromSuperview()
            if self.certField != nil {
                self.certField.removeFromSuperview()
            }
            if self.certHeader != nil {
                self.certHeader.removeFromSuperview()
            }
        }
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.onionAddressField != nil {
                self.onionAddressField.resignFirstResponder()
            }
            if self.nodeLabel != nil {
                self.nodeLabel.resignFirstResponder()
            }
            if self.rpcUserField != nil {
                self.rpcUserField.resignFirstResponder()
            }
            if self.rpcPassword != nil {
                self.rpcPassword.resignFirstResponder()
            }
            if self.certField != nil {
                self.certField.resignFirstResponder()
            }
            if self.macaroonField != nil {
                self.macaroonField.resignFirstResponder()
            }
            if self.nostrPubkeyField != nil {
                self.nostrPubkeyField.resignFirstResponder()
            }
            if self.nostrPrivkeyField != nil {
                self.nostrPrivkeyField.resignFirstResponder()
            }
            if self.nostrToSubscribe != nil {
                self.nostrToSubscribe.resignFirstResponder()
            }
            if self.nostrEncryptionWordsField != nil {
                self.nostrEncryptionWordsField.resignFirstResponder()
            }
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == nostrEncryptionWordsField {
            nostrEncryptionWordsField.isSecureTextEntry = true
        }
    }
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }
    
    private func nodeAddedSuccess() {
        if selectedNode == nil || createNew {
            selectedNode = newNode
            createNew = false
            showAlert(vc: self, title: "Node saved ✓", message: "")
        } else {
            showAlert(vc: self, title: "Node updated ✓", message: "")
        }
        
    }
    
    func addBtcRpcQr(url: String) {
        QuickConnect.addNode(uncleJim: false, url: url) { [weak self] (success, errorMessage) in
            if success {
                if url.hasPrefix("clightning-rpc") {
                    self?.navigationController?.popViewController(animated: true)
                } else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.navigationController?.popViewController(animated: true)
                        NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                    }
                }
            } else {
                displayAlert(viewController: self, isError: true, message: "Error adding that node: \(errorMessage ?? "unknown")")
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToExportNode" {
            if let vc = segue.destination as? QRDisplayerViewController {
                
                if isNostr, let text = self.nostrPubkeyField.text, text != "" {
                    vc.text = self.nostrPubkeyField.text!
                    vc.headerText = "Nostr pubkey"
                    vc.descriptionText = "Share with your mac FN nostr node to connect over nostr."
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                    
                } else if onionAddressField.text!.hasSuffix(":28183") {
                    vc.text = "http://\(onionAddressField.text ?? "")?cert=\(certField.text ?? "")"
                    vc.headerText = "Join Market Connect"
                    vc.descriptionText = ""
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                    
                } else if isHost && !onionAddressField.text!.hasSuffix(":8080") && !onionAddressField.text!.hasSuffix(":10080") {
                    vc.text = "btcrpc://\(rpcUserField.text ?? ""):\(rpcPassword.text ?? "")@\(hostname!):11221/?label=\(nodeLabel.text?.replacingOccurrences(of: " ", with: "%20") ?? "")"
                    vc.headerText = "Quick Connect - Remote Control"
                    vc.descriptionText = "Fully Noded macOS hosts a secure hidden service for your node which can be used to remotely connect to it.\n\nSimply scan this QR with your iPhone or iPad using the Fully Noded iOS app and connect to your node remotely from anywhere in the world!"
                    isHost = false
                    vc.headerIcon = UIImage(systemName: "antenna.radiowaves.left.and.right")
                    
                } else if self.selectedNode?["macaroon"] == nil {
                    var prefix = "btcrpc"
                    if rpcUserField.text == "lightning" {
                        prefix = "clightning-rpc"
                    }
                    vc.text = "\(prefix)://\(rpcUserField.text ?? ""):\(rpcPassword.text ?? "")@\(onionAddressField.text ?? "")/?label=\(nodeLabel.text?.replacingOccurrences(of: " ", with: "%20") ?? "")"
                    vc.headerText = "QuickConnect QR"
                    vc.descriptionText = "You can share this QR with trusted others who you want to share your node with, they will have access to all wallets on your node!"
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                
                } else {
                    //its LND
                    vc.text = "lndconnect://\(onionAddressField.text ?? "")?cert=\(certField.text ?? "")&macaroon=\(macaroonField.text ?? "")"
                    vc.headerText = "LNDConnect QR"
                    vc.descriptionText = "You can share this QR with trusted others who you want to share your node with, they will have access to all wallets on your node!"
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                }
            }
        }
        
        if segue.identifier == "segueToScanNodeCreds" {
            if #available(macCatalyst 14.0, *) {
                if let vc = segue.destination as? QRScannerViewController {
                    vc.isQuickConnect = true
                    vc.onDoneBlock = { [unowned thisVc = self] url in
                        if url != nil {
                            if thisVc.isNostr {
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self else { return }
                                    
                                    self.nostrToSubscribe.text = url!
                                }
                            } else {
                                thisVc.addBtcRpcQr(url: url!)
                            }
                            
                        }
                    }
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
}
