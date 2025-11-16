//
//  NodeDetailViewController.swift
//  BitSense
//
//  Created by Peter on 16/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

class NodeDetailViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    let spinner = ConnectingView()
    var selectedNode:[String:Any]?
    var createNew = Bool()
    var newNode = [String:Any]()
    var isInitialLoad = Bool()
    var scanNow = false
    
    @IBOutlet weak var rpcAuthCopyButton: UIButton!
    @IBOutlet weak var createPasswordButton: UIButton!
    @IBOutlet weak var rpcAuthExportButton: UIButton!
    @IBOutlet weak var rpcAuthLabel: UILabel!
    @IBOutlet weak var rpcAuthHeader: UILabel!
    @IBOutlet weak var masterStackView: UIStackView!
    @IBOutlet weak var addressHeader: UILabel!
    @IBOutlet weak var certHeader: UILabel!
    @IBOutlet weak var certField: UITextField!
    @IBOutlet weak var passwordHeader: UILabel!
    @IBOutlet weak var usernameHeader: UILabel!
    @IBOutlet weak var scanQROutlet: UIBarButtonItem!
    @IBOutlet weak var header: UILabel!
    @IBOutlet weak var nodeLabel: UITextField!
    @IBOutlet weak var rpcUserField: UITextField!
    @IBOutlet weak var rpcPassword: UITextField!
    @IBOutlet weak var rpcLabel: UILabel!
    @IBOutlet weak var saveButton: UIButton!
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
               
        rpcPassword.isSecureTextEntry = true
        onionAddressField.isSecureTextEntry = false
        saveButton.clipsToBounds = true
        saveButton.layer.cornerRadius = 8
     
        navigationController?.delegate = self
        rpcPassword.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
        rpcUserField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
        
        rpcAuthLabel.numberOfLines = 0
        rpcAuthLabel.sizeToFit()
        rpcAuthLabel.translatesAutoresizingMaskIntoConstraints = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadValues()
        
        if scanNow {
            segueToScanNow()
        }
    }
    
    @IBAction func showRpcAuthInfoAction(_ sender: Any) {
        showAlert(vc: self, title: "RPC Auth", message: "RPC Authentication is much more secure then storing your rpc password in your bitcoin.conf. An attacker can not access your node or derive your rpc password from this text. The rpcauth text displayed in Fully Noded is dynamic, you may see it change and that is OK. If you edit your rpcuser or rpcpassword you will need to export the rpcauth to your bitcoin.conf and restart your node to connect.")
    }
    
    @IBAction func createRpcPass(_ sender: Any) {
        guard let data = Crypto.secret() else { return }
        rpcPassword.text = data.hex
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let auth = RPCAuth().generateCreds(username: rpcUserField.text ?? "FullyNoded-OG", password: data.hex) else { return }
            
            rpcAuthLabel.text = auth.rpcAuth
        }
    }
    
    @IBAction func exportRpcAuth(_ sender: Any) {
        guard let rpcAuthText = rpcAuthLabel.text, rpcAuthText != "" else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let activityViewController = UIActivityViewController(activityItems: [rpcAuthText], applicationActivities: nil)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = self.view
                activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
            
            self.present(activityViewController, animated: true) {}
        }
    }
    
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        if textField == rpcUserField || textField == rpcPassword {
            if rpcUserField.text != "" && rpcPassword.text != "" {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    guard let auth = RPCAuth().generateCreds(username: rpcUserField.text!, password: rpcPassword.text!) else { return }
                    
                    rpcAuthLabel.text = auth.rpcAuth
                }
            }
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
    
    @IBAction func scanQuickConnect(_ sender: Any) {
        segueToScanNow()
    }
    
    private func segueToScanNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToScanNodeCreds", sender: self)
        }
    }
    
    private func encryptCert(_ certText: String) -> Data? {
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
            newNode["isLightning"] = false
            
            if let onionAddressText = onionAddressField.text {
                guard let encryptedOnionAddress = encryptedValue(onionAddressText.utf8)  else {
                    showAlert(vc: self, title: "", message: "Error encrypting the address.")
                    return
                }
                newNode["onionAddress"] = encryptedOnionAddress
            }
            
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
            
            if let cert = certField.text {
                guard let encryptedCert = encryptCert(cert) else {
                    return
                }
                newNode["cert"] = encryptedCert
            }
            
            
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
                                displayAlert(viewController: vc, isError: true, message: "Error saving node.")
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
            
            guard let address = onionAddressField.text, address != "" else {
                showAlert(vc: self, title: "", message: "You need to enter an address.")
                return
            }
            
            if !address.contains(".onion") && certField.text == nil || certField.text == "" {
                showAlert(vc: self, title: "Warning!", message: "You are not using an onion address, your network traffic will not be routed over Tor! This is for connecting to nodes over localhost and LAN only, if using LAN https will be used and you must add the base64 SSL cert.")
            } else {
                save()
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
            
            if let addressText = onionAddressField.text {
                let decryptedAddress = addressText.dataUsingUTF8StringEncoding
                
                let arr = addressText.split(separator: ":")
                guard arr.count == 2 else {
                    showAlert(vc: self, title: "Not updated, port missing...", message: "Please make sure you add the port at the end of your onion hostname, such as xjshdu.onion:8332.\n\n8332 for mainnet.")
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
                        
            if certField.text != nil, certField.text != "" {
                let cert = certField.text!.condenseWhitespace()
                guard let encryptedCert = encryptCert(cert) else { return }
                
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
        
        if selectedNode != nil {
            let node = NodeStruct(dictionary: selectedNode!)
            if node.id != nil {
                
                if node.label != "" {
                    nodeLabel.text = node.label
                }
                
                if let user = node.rpcuser, let password = node.rpcpassword {
                    rpcUserField.text = decryptedValue(user)
                    rpcPassword.text = decryptedValue(password)
                    
                    if let auth = RPCAuth().generateCreds(username: rpcUserField.text!, password: rpcPassword.text!) {
                        rpcAuthLabel.text = auth.rpcAuth
                    }
                }
                                
                if let enc = node.onionAddress {
                    let decrypted = decryptedValue(enc)
                    if onionAddressField != nil {
                        onionAddressField.text = decrypted
                    }
                    
                    if !decrypted.contains(".onion") && node.cert == nil && !decrypted.hasPrefix("localhost:") && !decrypted.hasPrefix("127.0.0.1:") {
                        showAlert(vc: self, title: "Warning!", message: "You are not using an onion address, your network traffic will not be routed over Tor! This is for connecting to nodes over localhost and LAN only, if using LAN https will be used and you must add the base64 SSL cert.")
                    }
                }
                
                if node.cert != nil {
                    if let decryptedCert = Crypto.decrypt(node.cert!) {
                        certField.text = decryptedCert.utf8String ?? ""
                    }
                }
            }
        } else {
            rpcUserField.text = "FullyNoded"
            rpcPassword.text = Crypto.privateKey().hex
            
            if let auth = RPCAuth().generateCreds(username: rpcUserField.text!, password: rpcPassword.text!) {
                rpcAuthLabel.text = auth.rpcAuth
            }
            
            showAlert(vc: self, title: "RPC credentials created ✓", message: "Fully Noded creates an rpc password for you by default, export the rpc auth text to your bitcoin.conf, save it and restart your node to connect.")
        }
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.onionAddressField.resignFirstResponder()
            self.nodeLabel.resignFirstResponder()
            self.rpcUserField.resignFirstResponder()
            self.rpcPassword.resignFirstResponder()
            self.certField.resignFirstResponder()
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
        QuickConnect.addNode(url: url) { [weak self] (success, errorMessage) in
            if success {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.navigationController?.popViewController(animated: true)
                    NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                }
            } else {
                displayAlert(viewController: self, isError: true, message: "Error adding that node: \(errorMessage ?? "unknown")")
            }
        }
    }
    
    func showCertificatePicker() {
        // Use broad types: certificates + generic data (covers .pem, .cer, .crt, .der)
        let supportedTypes: [UTType] = [
            .x509Certificate,  // .cer, .crt (PEM/DER)
            .data              // fallback for .pem, .der, unknown binaries
        ]
        
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: supportedTypes,
            asCopy: true  // Copies file into app sandbox (secure)
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        
        present(picker, animated: true)
    }
    
    @IBAction func showFilePickerAction(_ sender: Any) {
        showCertificatePicker()
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "segueToScanNodeCreds" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isQuickConnect = true
                vc.onDoneBlock = { [weak self] url in
                    guard let self = self else { return }
                    guard let url = url else { return }
                    addBtcRpcQr(url: url)
                }
            }
        }
    }
}

extension NodeDetailViewController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        let fileExtension = url.pathExtension.lowercased()
        
        let securedURL = copyToAppContainer(url: url)
        
        guard let base64Cert = CertificateManager.shared.certFileToBase64(fileURL: securedURL) else {
            showAlert(vc: self, title: "Error", message: "Unable to convert the cert file to base64 text. Ensure you are trying to upload a .pem, .cer, .crt or .der file.")
            return
        }
        
        DispatchQueue.main.async { [ weak self] in
            guard let self = self else { return }
            
            certField.text = base64Cert
        }
    }
    
    private func copyToAppContainer(url: URL) -> URL {
        let fm = FileManager.default
        let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docsDir.appendingPathComponent(url.lastPathComponent)
        
        try? fm.removeItem(at: dest)
        try? fm.copyItem(at: url, to: dest)
        
        return dest
    }
}
