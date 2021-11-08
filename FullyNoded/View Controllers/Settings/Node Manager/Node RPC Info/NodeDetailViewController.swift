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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        configureTapGesture()
        nodeLabel.delegate = self
        rpcPassword.delegate = self
        rpcUserField.delegate = self
        onionAddressField.delegate = self
        certField.delegate = self
        macaroonField.delegate = self
        rpcPassword.isSecureTextEntry = true
        onionAddressField.isSecureTextEntry = false
        saveButton.clipsToBounds = true
        saveButton.layer.cornerRadius = 8
        header.text = "Node Credentials"
        navigationController?.delegate = self
        
        if isLightning {
            addressHeaderOutlet.text = "Address: (xxx.onion:8080 or 127.0.0.1:8080)"
        } else {
            addressHeaderOutlet.text = "Address: (xxx.onion:8332 or 127.0.0.1:8332)"
            
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadValues()
        
        if scanNow {
            segueToScanNow()
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
        if onionAddressField.text != "" && rpcPassword.text != "" && rpcUserField.text != "" {
            segueToExport()
        } else if onionAddressField.text != "" && macaroonField.text != "" {
            segueToExport()
        } else {
            showAlert(vc: self, title: "Incomplete node creds.", message: "This button is for sharing your nodes quick connect or lndconnect QR code so trusted others can use your node.")
        }
    }
    
    private func segueToExport() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToExportNode", sender: vc)
        }
    }
    
    @IBAction func save(_ sender: Any) {
        
        func encryptedValue(_ decryptedValue: Data) -> Data? {
            return Crypto.encrypt(decryptedValue)
        }
        
        if createNew || selectedNode == nil {
            
            newNode["id"] = UUID()
            
            var isLightning = false
            
            if onionAddressField.text!.hasSuffix(":8080") {
                isLightning = true
            }
            
            newNode["isLightning"] = isLightning
            
            if nodeLabel.text != "" {
                newNode["label"] = nodeLabel.text!
            }
            
            if rpcUserField.text != "" {
                guard let enc = encryptedValue((rpcUserField.text)!.dataUsingUTF8StringEncoding) else { return }
                newNode["rpcuser"] = enc
            }
            
            if rpcPassword.text != "" {
                guard let enc = encryptedValue((rpcPassword.text)!.dataUsingUTF8StringEncoding) else { return }
                newNode["rpcpassword"] = enc
            }
            
            if macaroonField.text != "" {
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
            
            if certField.text != "" {
                guard let certData = try? Data.decodeUrlSafeBase64(certField.text!) else { return }
                
                guard let encryptedCert = Crypto.encrypt(certData) else { return }
                
                newNode["cert"] = encryptedCert
            }
            
            guard let encryptedOnionAddress = encryptedValue((onionAddressField.text)!.dataUsingUTF8StringEncoding)  else { return }
            newNode["onionAddress"] = encryptedOnionAddress
            
            func save() {
                CoreDataService.retrieveEntity(entityName: .newNodes) { [unowned vc = self] nodes in
                    if nodes != nil {
                        if nodes!.count == 0 {
                            vc.newNode["isActive"] = true
                        } else {
                            vc.newNode["isActive"] = false
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
            
            if nodeLabel.text != "" && rpcPassword.text != "" && rpcUserField.text != "" && onionAddressField.text != "" {
                save()
            } else if nodeLabel.text != "" && onionAddressField.text != "" && macaroonField.text != "" {
                save()
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Fill out all fields first")
                
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
            
            if rpcUserField.text != "" {
                guard let enc = encryptedValue((rpcUserField.text)!.dataUsingUTF8StringEncoding) else { return }
                CoreDataService.update(id: id, keyToUpdate: "rpcuser", newValue: enc, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating rpc username")
                    }
                }
            }
            
            if rpcPassword.text != "" {
                guard let enc = encryptedValue((rpcPassword.text)!.dataUsingUTF8StringEncoding) else { return }
                CoreDataService.update(id: id, keyToUpdate: "rpcpassword", newValue: enc, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating rpc password")
                    }
                }
            }
            
            let decryptedAddress = (onionAddressField.text)!.dataUsingUTF8StringEncoding
            
            if onionAddressField.text!.hasSuffix(":8080") {
                CoreDataService.update(id: id, keyToUpdate: "isLightning", newValue: true, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating isLightning")
                    }
                }
            }
            
            if macaroonField.text != "" {
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
            
            if certField.text != "" {
                guard let certData = try? Data.decodeUrlSafeBase64(certField.text!) else { return }
                
                guard let encryptedCert = Crypto.encrypt(certData) else { return }
                
                CoreDataService.update(id: id, keyToUpdate: "cert", newValue: encryptedCert, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating cert")
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
    }
    
    func configureTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
    
    func loadValues() {
        
        func decryptedValue(_ encryptedValue: Data) -> String {
            guard let decrypted = Crypto.decrypt(encryptedValue) else { return "" }
            
            return decrypted.utf8 ?? ""
        }
        
        if selectedNode != nil {
            let node = NodeStruct(dictionary: selectedNode!)
            //hideValues(node: node)
            
            if node.id != nil {
                
                if node.label != "" {
                    nodeLabel.text = node.label
                } else {
                    nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                         attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                }
                
                if node.rpcuser != nil {
                    rpcUserField.text = decryptedValue(node.rpcuser!)
                } else {
                    rpcUserField.attributedPlaceholder = NSAttributedString(string: "rpcuser",
                                                                            attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                }
                
                if node.rpcpassword != nil {
                    rpcPassword.text = decryptedValue(node.rpcpassword!)
                    
                } else {
                    rpcPassword.attributedPlaceholder = NSAttributedString(string: "rpcpassword",
                                                                           attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                }
                
                if let enc = node.onionAddress {
                    onionAddressField.text = decryptedValue(enc)
                } else {
                    var placeHolder = "127.0.0.1:8332"
                    
                    if isLightning {
                        placeHolder = "127.0.0.1:8080"
                    }
                    
                    onionAddressField.attributedPlaceholder = NSAttributedString(string: placeHolder,
                                                                                 attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                }
                
                if node.cert != nil {
                    if let decryptedCert = Crypto.decrypt(node.cert!) {
                        certField.text = decryptedCert.urlSafeB64String
                    }
                }
                
                if node.macaroon != nil {
                    let hex = decryptedValue(node.macaroon!)
                    macaroonField.text = Data(hexString: hex)!.urlSafeB64String
                }
                
            } else {
                rpcPassword.attributedPlaceholder = NSAttributedString(string: "rpcpassword",
                                                                       attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
                rpcUserField.attributedPlaceholder = NSAttributedString(string: "rpcuser",
                                                                        attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
                nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                     attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
                var placeHolder = "127.0.0.1:8332"
                
                if isLightning {
                    placeHolder = "127.0.0.1:8080"
                }
                
                onionAddressField.attributedPlaceholder = NSAttributedString(string: placeHolder,
                                                                             attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            }
        } else {
            rpcPassword.attributedPlaceholder = NSAttributedString(string: "rpcpassword",
                                                                   attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
            rpcUserField.attributedPlaceholder = NSAttributedString(string: "rpcuser",
                                                                    attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
            nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                 attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
            var placeHolder = "127.0.0.1:8332"
            
            if isLightning {
                placeHolder = "127.0.0.1:8080"
                nodeLabel.text = "Lightning Node"
            } else {
                nodeLabel.text = "Bitcoin Core"
            }
            
            onionAddressField.attributedPlaceholder = NSAttributedString(string: "127.0.0.1:8332",
                                                                         attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                        
            #if targetEnvironment(macCatalyst)
                onionAddressField.text = placeHolder
            #endif
        }
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        onionAddressField.resignFirstResponder()
        nodeLabel.resignFirstResponder()
        rpcUserField.resignFirstResponder()
        rpcPassword.resignFirstResponder()
        certField.resignFirstResponder()
        macaroonField.resignFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }
    
    private func nodeAddedSuccess() {
        CoreDataService.retrieveEntity(entityName: .newNodes) { [unowned vc = self] nodes in
            if nodes != nil {
                if !vc.isLightning {
                    if nodes!.count > 1 {
                        vc.deActivateNodes(nodes: nodes!) {
                            DispatchQueue.main.async { [unowned vc = self] in
                                let alert = UIAlertController(title: "Node added successfully ✓", message: "Your node has been saved and activated, tap Done to go back. Sometimes its necessary to force quit and reopen FullyNoded to refresh the Tor connection to your new node.", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                                    DispatchQueue.main.async { [unowned vc = self] in
                                        NotificationCenter.default.post(name: .refreshNode, object: nil)
                                        vc.navigationController?.popToRootViewController(animated: true)
                                    }
                                }))
                                alert.popoverPresentationController?.sourceView = vc.view
                                vc.present(alert, animated: true) {}
                            }
                        }
                    } else {
                        if !vc.createNew {
                            DispatchQueue.main.async { [unowned vc = self] in
                                let alert = UIAlertController(title: "Node updated successfully", message: "Your node has been updated, tap Done to go back. Sometimes its necessary to force quit and reopen FullyNoded to refresh the Tor connection using your updated node credentials.", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                                    DispatchQueue.main.async { [unowned vc = self] in
                                        NotificationCenter.default.post(name: .refreshNode, object: nil)
                                        vc.navigationController?.popToRootViewController(animated: true)
                                    }
                                }))
                                alert.popoverPresentationController?.sourceView = vc.view
                                vc.present(alert, animated: true) {}
                            }
                        } else {
                           DispatchQueue.main.async { [unowned vc = self] in
                            let alert = UIAlertController(title: "Node added successfully ✓", message: "Your node has been added and activated. The home screen is automatically refreshing. Tap Done to go back.", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                                    DispatchQueue.main.async { [unowned vc = self] in
                                        NotificationCenter.default.post(name: .refreshNode, object: nil)
                                        vc.navigationController?.popToRootViewController(animated: true)
                                    }
                                }))
                                alert.popoverPresentationController?.sourceView = vc.view
                                vc.present(alert, animated: true) {}
                            }
                        }
                    }
                } else {
                    if !vc.createNew {
                        DispatchQueue.main.async { [unowned vc = self] in
                            let alert = UIAlertController(title: "Node updated successfully", message: "Your node has been updated, tap Done to go back. Sometimes its necessary to force quit and reopen FullyNoded to refresh the Tor connection using your updated node credentials.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                                DispatchQueue.main.async { [unowned vc = self] in
                                    vc.navigationController?.popViewController(animated: true)
                                }
                            }))
                            alert.popoverPresentationController?.sourceView = vc.view
                            vc.present(alert, animated: true) {}
                        }
                    } else {
                       DispatchQueue.main.async { [unowned vc = self] in
                        let alert = UIAlertController(title: "Node added successfully ✓", message: "Your node has been added and activated. The home screen is automatically refreshing. Tap Done to go back.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                                DispatchQueue.main.async { [unowned vc = self] in
                                    vc.navigationController?.popViewController(animated: true)
                                }
                            }))
                            alert.popoverPresentationController?.sourceView = vc.view
                            vc.present(alert, animated: true) {}
                        }
                    }
                }
            }
        }
    }
    
    private func deActivateNodes(nodes: [[String:Any]], completion: @escaping () -> Void) {
        for (i, node) in nodes.enumerated() {
            let str = NodeStruct(dictionary: node)
            let isActive = str.isActive
            
            if createNew {
                let newNodeStr = NodeStruct(dictionary: self.newNode)
                if isActive && newNodeStr.isLightning && str.isLightning {
                    CoreDataService.update(id: str.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                }
                
                if isActive && !newNodeStr.isLightning && !str.isLightning {
                    CoreDataService.update(id: str.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                }
                
            } else {
                if selectedNode != nil {
                    let selectedNodeStr = NodeStruct(dictionary: selectedNode!)
                    
                    if isActive && selectedNodeStr.isLightning && str.isLightning {
                        CoreDataService.update(id: str.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                    }
                    
                    if isActive && !selectedNodeStr.isLightning && !str.isLightning {
                        CoreDataService.update(id: str.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                    }
                }
            }
            
            if i + 1 == nodes.count {
                if createNew {
                    let id = newNode["id"] as! UUID
                    CoreDataService.update(id: id, keyToUpdate: "isActive", newValue: true, entity: .newNodes) { success in
                        completion()
                    }
                } else {
                    if selectedNode != nil {
                        let selectedNodeStr = NodeStruct(dictionary: selectedNode!)
                        
                        if let id = selectedNodeStr.id {
                            CoreDataService.update(id: id, keyToUpdate: "isActive", newValue: true, entity: .newNodes) { success in
                                completion()
                            }
                        }
                    }
                }
            }
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
                var prefix = "btcrpc"
                
                if onionAddressField.text!.hasSuffix(":8080") {
                    prefix = "clightning-rpc"
                    
                    if macaroonField.text != "" {
                        prefix = "lndconnect"
                    }
                }
                
                if isHost && !onionAddressField.text!.hasSuffix(":8080") {
                    vc.text = "\(prefix)://\(rpcUserField.text ?? ""):\(rpcPassword.text ?? "")@\(hostname!):11221/?label=\(nodeLabel.text?.replacingOccurrences(of: " ", with: "%20") ?? "")"
                    vc.headerText = "Quick Connect - Remote Control"
                    vc.descriptionText = "Fully Noded macOS hosts a secure hidden service for your node which can be used to remotely connect to it.\n\nSimply scan this QR with your iPhone or iPad using the Fully Noded iOS app and connect to your node remotely from anywhere in the world!"
                    isHost = false
                    vc.headerIcon = UIImage(systemName: "antenna.radiowaves.left.and.right")
                    
                } else if self.selectedNode?["macaroon"] == nil {
                    vc.text = "\(prefix)://\(rpcUserField.text ?? ""):\(rpcPassword.text ?? "")@\(onionAddressField.text ?? "")/?label=\(nodeLabel.text?.replacingOccurrences(of: " ", with: "%20") ?? "")"
                    vc.headerText = "QuickConnect QR"
                    vc.descriptionText = "You can share this QR with trusted others who you want to share your node with, they will have access to all wallets on your node!"
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                } else {
                    //its LND
                    vc.text = "\(prefix)://\(onionAddressField.text ?? "")?cert=\(certField.text ?? "")&macaroon=\(macaroonField.text ?? "")"
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
                    vc.onQuickConnectDoneBlock = { [unowned thisVc = self] url in
                        if url != nil {
                            thisVc.addBtcRpcQr(url: url!)
                        }
                    }
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
}
