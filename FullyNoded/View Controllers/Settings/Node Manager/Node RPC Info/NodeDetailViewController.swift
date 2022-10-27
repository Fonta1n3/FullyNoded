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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        configureTapGesture()
        nodeLabel.delegate = self
        rpcPassword.delegate = self
        rpcUserField.delegate = self
        onionAddressField.delegate = self
        nostrToSubscribe.delegate = self
        certField.delegate = self
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
        refreshNostrPrivkeyOutlet.setTitle("", for: .normal)
        header.text = "Node Credentials"
        navigationController?.delegate = self
        
        if isLightning {
            addressHeaderOutlet.text = "Address: (xxx.onion:8080 or 127.0.0.1:8080)"
        } else {
            addressHeaderOutlet.text = "Address: (xxx.onion:8332 or 127.0.0.1:8332)"
        }
        
        if isNostr {
            createNostrCreds()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadValues()
        
        if scanNow {
            segueToScanNow()
        }
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
        if nostrRelayField != nil,
           nostrPubkeyField != nil,
           nostrRelayHeader != nil,
           nostrToSubscribe != nil,
           nostrPubkeyHeader != nil,
           nostrPrivkeyField != nil,
           nostrPrivkeyHeader != nil,
           nostrSubscriptionHeader != nil,
           scanNostrPubkeyQr != nil,
           showNostrPubkeyQr != nil,
           refreshNostrPrivkeyOutlet != nil {
            refreshNostrPrivkeyOutlet.removeFromSuperview()
            showNostrPubkeyQr.removeFromSuperview()
            scanNostrPubkeyQr.removeFromSuperview()
            nostrSubscriptionHeader.removeFromSuperview()
            nostrRelayField.removeFromSuperview()
            nostrRelayHeader.removeFromSuperview()
            nostrPubkeyField.removeFromSuperview()
            nostrPubkeyHeader.removeFromSuperview()
            nostrToSubscribe.removeFromSuperview()
            nostrPrivkeyField.removeFromSuperview()
            nostrPrivkeyHeader.removeFromSuperview()
        }
    }
    
    func removeNonNostrStuff() {
        func remove() {
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
               self.onionAddressField != nil {
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
            }
        }
        
        DispatchQueue.main.async {
            #if targetEnvironment(simulator)
                remove()
            #else
                let modelName = UIDevice.modelName
                if modelName != "arm64" && modelName != "x86_64" && modelName != "i386" {
                    remove()
                }
            #endif
        }
    }
    
    func createNostrCreds() {
        let privkey = Crypto.privateKey()
        let pubkey = Keys.privKeyToPubKey(privkey)!
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.nostrPubkeyField.text = pubkey
            self.nostrPrivkeyField.text = privkey.hexString
            self.nostrRelayField.text = UserDefaults.standard.string(forKey: "nostrRelay") ?? "wss://nostr-relay.wlvs.space"
            self.removeNonNostrStuff()
            showAlert(vc: self, title: "Nostr creds refreshed ✓", message: "Tap save to save the change.")
        }
    }
    
    @IBAction func recoverAction(_ sender: Any) {
        confirmiCloudRecovery()
    }
    
    private func confirmiCloudRecovery() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Recover iCloud backup?"
            let message = "You need to input the same encryption password that was used when you created the backup. If the incorrect password is entered your data will not be decrypted."
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let recover = UIAlertAction(title: "Recover", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                let text = (alert.textFields![0] as UITextField).text
                let confirm = (alert.textFields![0] as UITextField).text
                
                guard let text = text,
                      let confirm = confirm,
                      text == confirm,
                      let hash = self.hash(text) else {
                    showAlert(vc: self, title: "", message: "Passwords don't match!")
                    
                    return
                }
                
                self.spinner.addConnectingView(vc: self, description: "recovering...")
                
                BackupiCloud.recover(passwordHash: hash) { [weak self] (recovered, errorMess) in
                    guard let self = self else { return }
                    
                    let message = errorMess ?? ""
                    
                    if message.contains("No data exists in iCloud") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            BackupiCloud.recover(passwordHash: hash) { [weak self] (recovered, errorMess) in
                                guard let self = self else { return }
                                
                                self.spinner.removeConnectingView()
                                
                                if recovered {
                                    DispatchQueue.main.async { [weak self] in
                                        guard let self = self else { return }
                                        
                                        self.navigationController?.popViewController(animated: true)
                                        NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                                    }
                                } else {
                                    showAlert(vc: self, title: "", message: "Recovery failed... \(errorMess ?? "")")
                                }
                            }
                        }
                    } else {
                        self.spinner.removeConnectingView()
                        
                        if recovered {
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                
                                self.navigationController?.popViewController(animated: true)
                                NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                            }
                        } else {
                            showAlert(vc: self, title: "", message: "Recovery failed... \(errorMess ?? "")")
                        }
                    }
                }
            }
            
            alert.addTextField { textField in
                textField.placeholder = "encryption password"
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .dark
            }
            
            alert.addTextField { textField in
                textField.placeholder = "confirm password"
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .dark
            }
            
            alert.addAction(recover)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            
            self.present(alert, animated:true, completion: nil)
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
    
    
    @IBAction func showHostAction(_ sender: Any) {
        #if targetEnvironment(macCatalyst)
            // Code specific to Mac.
            let hostAddress = onionAddressField.text ?? ""
            let macName = UIDevice.current.name
            if hostAddress.contains("127.0.0.1") || hostAddress.contains("localhost") || hostAddress.contains(macName) {
                hostname = TorClient.sharedInstance.hostname()
                if hostname != nil {
                    hostname = hostname?.replacingOccurrences(of: "\n", with: "")
                    isHost = true
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.performSegue(withIdentifier: "segueToExportNode", sender: vc)
                    }
                } else {
                    showAlert(vc: self, title: "", message: "There was an error getting your hostname for remote connection... Please make sure you are connected to the internet and that Tor successfully bootstrapped.")
                }
            } else {
                showAlert(vc: self, title: "", message: "This feature can only be used with nodes which are running on the same computer as Fully Noded - Desktop.\n\nTo take advantage of this feature just download Bitcoin Core and run it.\n\nThen add your local node to Fully Noded - Desktop using 127.0.0.1:8332 as the address.\n\nYou can then tap this button to get a QR code which will allow you to connect your node via your iPhone or iPad on the mobile app.")
            }
        #else
            // Code to exclude from Mac.
            showAlert(vc: self, title: "", message: "This is a macOS feature only, when you use Fully Noded - Desktop, it has the ability to display a QR code you can scan with your iPhone or iPad to connect to your node remotely.")
        #endif
    }
    
    
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
        segueToExport()
    }
    
    private func segueToExport() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToExportNode", sender: vc)
        }
    }
    
    private func encryptCert(_ certText: String) -> Data? {
         guard let certData = Data(base64Encoded: certText.condenseWhitespace(), options: [.ignoreUnknownCharacters]) else {
             showAlert(vc: self, title: "Error", message: "Unable to convert the cert text to base64 data.")
             return nil
         }
         
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
            newNode["isLightning"] = false
            newNode["isJoinMarket"] = false
            newNode["isNostr"] = false
            
            var isLightning = false
            var isJoinMarket = false
            
            if onionAddressField != nil {
                if onionAddressField.text!.hasSuffix(":8080") || onionAddressField.text!.hasSuffix(":10080") {
                    isLightning = true
                }
                if onionAddressField.text!.hasSuffix(":28183") {
                    isJoinMarket = true
                }
                newNode["isLightning"] = isLightning
                newNode["isJoinMarket"] = isJoinMarket
                guard let encryptedOnionAddress = encryptedValue((onionAddressField.text)!.dataUsingUTF8StringEncoding)  else { return }
                newNode["onionAddress"] = encryptedOnionAddress
            }
            
            if nostrToSubscribe != nil, nostrToSubscribe.text != "", let data = Data(hexString: nostrToSubscribe.text!)  {
                newNode["subscribeTo"] = encryptedValue(data)
            }
            
            if nostrPrivkeyField != nil, nostrPrivkeyField.text != "" {
                let privkey = Data(hexString: nostrPrivkeyField.text!)!
                newNode["nostrPrivkey"] = encryptedValue(privkey)
                let pubkey = Keys.privKeyToPubKey(privkey)!
                newNode["nostrPubkey"] = encryptedValue(Data(hexString: pubkey)!)
                newNode["isNostr"] = true
            }
            
            if nostrRelayField != nil, nostrRelayField.text != nil {
                UserDefaults.standard.setValue(nostrRelayField.text!, forKey: "nostrRelay")
            }
            
            if nodeLabel.text != "" {
                newNode["label"] = nodeLabel.text!
            }
            
            if rpcUserField != nil {
                if rpcUserField.text != "" {
                    guard let enc = encryptedValue((rpcUserField.text)!.dataUsingUTF8StringEncoding) else { return }
                    newNode["rpcuser"] = enc
                }
            }
            
            if rpcPassword != nil {
                if rpcPassword.text != "" {
                    guard let enc = encryptedValue((rpcPassword.text)!.dataUsingUTF8StringEncoding) else { return }
                    newNode["rpcpassword"] = enc
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
                newNode["macaroon"] = encryptedMacaroonHex
            }
            
            if certField != nil {
                if certField.text != "" {
                    guard let encryptedCert = encryptCert(certField.text!) else {
                        return
                    }
                    newNode["cert"] = encryptedCert
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
            if rpcPassword != nil, rpcPassword.text != "" && rpcUserField != nil, rpcUserField.text != "" {
                save()
            } else if macaroonField != nil, macaroonField.text != "" || certField != nil, certField.text != "" {
                save()
            } else if nostrRelayField.text != "" && nostrPubkeyField.text != "" && nostrPrivkeyField.text != "" {
                save()
            } else {
                displayAlert(viewController: self,
                             isError: true,
                             message: "That combo wont work...")
            }
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
            
            if nostrPrivkeyField != nil, nostrPrivkeyField.text != "" {
                guard let data = Data(hexString: nostrPrivkeyField.text!), let enc = encryptedValue(data) else { return }
                CoreDataService.update(id: id, keyToUpdate: "nostrPrivkey", newValue: enc, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating nostr privkey")
                    }
                    
                    let newpubkey = Keys.privKeyToPubKey((Data(hexString: self.nostrPrivkeyField.text!)!))!
                    
                    guard let enc = encryptedValue(Data(hexString: newpubkey)!) else { return }
                    
                    CoreDataService.update(id: id, keyToUpdate: "nostrPubkey", newValue: enc, entity: .newNodes) { [weak self] success in
                        guard let self = self else { return }
                        if !success {
                            displayAlert(viewController: self, isError: true, message: "error updating nostr pubkey")
                        }
                        
                        if self.nostrToSubscribe != nil, self.nostrToSubscribe.text != "", let data = Data(hexString: self.nostrToSubscribe.text!) {
                            guard let enc = encryptedValue(data) else { return }
                            CoreDataService.update(id: id, keyToUpdate: "subscribeTo", newValue: enc, entity: .newNodes) { success in
                                if !success {
                                    displayAlert(viewController: self, isError: true, message: "error updating subscribe to")
                                }
                                
                                if self.nostrRelayField != nil, let txt = self.nostrRelayField.text {
                                    UserDefaults.standard.setValue(txt, forKey: "nostrRelay")
                                    MakeRPCCall.sharedInstance.connected = false
                                    MakeRPCCall.sharedInstance.connectToRelay { _ in }
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
                CoreDataService.update(id: id, keyToUpdate: "rpcpassword", newValue: enc, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating rpc password")
                    }
                }
            }
            
            if onionAddressField != nil {
                let decryptedAddress = (onionAddressField.text)!.dataUsingUTF8StringEncoding
                
                if onionAddressField.text!.hasSuffix(":8080") || onionAddressField.text!.hasSuffix(":10080") {
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
            
            showAlert(vc: self, title: "Credentials saved ✓", message: "")
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
            if node.id != nil {
                if node.isNostr {
                    removeNonNostrStuff()
                    
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
                }
                
                if node.label != "" {
                    nodeLabel.text = node.label
                }
                
                if node.rpcuser != nil {
                    rpcUserField.text = decryptedValue(node.rpcuser!)
                }
                
                if node.rpcpassword != nil {
                    rpcPassword.text = decryptedValue(node.rpcpassword!)
                    
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
                        rpcUserField.removeFromSuperview()
                        rpcPassword.removeFromSuperview()
                        passwordHeader.removeFromSuperview()
                        usernameHeader.removeFromSuperview()
                        macaroonField.removeFromSuperview()
                        macaroonHeader.removeFromSuperview()
                    }
                }
                
                if node.cert != nil, certField != nil {
                    if let decryptedCert = Crypto.decrypt(node.cert!) {
                        certField.text = decryptedCert.urlSafeB64String
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
        }
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        if onionAddressField != nil {
            onionAddressField.resignFirstResponder()
        }
        if nodeLabel != nil {
            nodeLabel.resignFirstResponder()
        }
        if rpcUserField != nil {
            rpcUserField.resignFirstResponder()
        }
        if rpcPassword != nil {
            rpcPassword.resignFirstResponder()
        }
        if certField != nil {
            certField.resignFirstResponder()
        }
        if macaroonField != nil {
            macaroonField.resignFirstResponder()
        }
        if nostrPubkeyField != nil {
            nostrPubkeyField.resignFirstResponder()
        }
        if nostrPrivkeyField != nil {
            nostrPrivkeyField.resignFirstResponder()
        }
        if nostrToSubscribe != nil {
            nostrToSubscribe.resignFirstResponder()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }
    
    private func nodeAddedSuccess() {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Saved ✓", message: ".", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true) {}
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
