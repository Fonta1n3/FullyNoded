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
    
    var selectedNode: [String:Any]?
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
        
        loadValues()
    }
    
    @IBAction func pasteCertAction(_ sender: Any) {
        if let pasted = UIPasteboard.general.string {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                certField.text = pasted
            }
        }
    }
    
    @IBAction func deleteCertAction(_ sender: Any) {
        let n = NodeStruct(dictionary: selectedNode ?? newNode)
        guard let id = n.id, let _ = n.cert else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                certField.text = ""
            }
            return
        }
        promptToDeleteCert { [weak self] delete in
            guard let self = self else { return }
            
            guard delete else { return }
            
            CoreDataService.deleteValue(id: id, keyToDelete: "cert", entity: .newNodes) { [weak self] deleted in
                guard let self else { return }
                
                guard deleted else {
                    showAlert(vc: self, title: "", message: "Unable to delete.")
                    return
                }
                
                showAlert(vc: self, title: "", message: "Cert deleted.")
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    certField.text = ""
                }
            }
        }
    }
    
    func promptToDeleteCert(completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "Delete SSL Cert?",
            message: "",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            completion(true)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(false)
        })
        
        self.present(alert, animated: true)
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
    
    private func encryptCert(_ certText: String) -> Data? {
        let certData = Data(certText.utf8)
         
         guard let encryptedCert = Crypto.encrypt(certData) else {
             showAlert(vc: self, title: "Error", message: "Unable to encrypt your cert data.")
             return nil
         }
        
        return encryptedCert
    }
    
    @IBAction func save(_ sender: Any) {
        var encryptedCert: Data?
        
        guard let address = onionAddressField.text, address != "" else {
            showAlert(vc: self, title: "", message: "You need to add an address first.")
            return
        }
        
        guard let user = rpcUserField.text, user != "" else {
            showAlert(vc: self, title: "", message: "You need to add a rpc user first.")
            return
        }
        
        guard let pass = rpcPassword.text, pass != "" else {
            showAlert(vc: self, title: "", message: "You need to add an rpc password first.")
            return
        }
        
        guard let label = nodeLabel.text, label != "" else {
            showAlert(vc: self, title: "", message: "You need to add a label first.")
            return
        }
        
        let arr = address.split(separator: ":")
        let addressData = address.utf8
    
        guard arr.count == 2 else {
            showAlert(vc: self, title: "Not updated, port missing...", message: "Please make sure you add the port at the end of your hostname, such as xxxx.onion:8332.\n\n8332 for mainnet, 18332 for testnet, 38332 for signet or 18443 for regtest.")
            return
        }
            
        if let cert = certField.text, cert != "" {
            if let encCert = encryptedValue(certField.text!.condenseWhitespace().utf8) {
                encryptedCert = encCert
            }
        } else {
            let isLocalOrOnion = address.contains(".onion") || address.hasPrefix("localhost:") || address.hasPrefix("127.0.0.1:")
            if !isLocalOrOnion {
                showAlert(vc: self, title: "Warning! ⚠️", message: "You are not using an onion address or localhost. Your RPC credentials could be compromised! This is intended for LAN usage or testing purposes only! To be safer consider adding a SSL cert.")
            }
        }
            
        func encryptedValue(_ decryptedValue: Data) -> Data? {
            return Crypto.encrypt(decryptedValue)
        }
        
        guard let encAddress = encryptedValue(addressData)  else {
            showAlert(vc: self, title: "", message: "Error encrypting the address.")
            return
        }
        
        guard let encUser = encryptedValue(user.utf8) else {
            showAlert(vc: self, title: "", message: "Error encrypting the rpc user.")
            return
        }
        
        guard let encPass = encryptedValue(pass.utf8) else {
            showAlert(vc: self, title: "", message: "Error encrypting the rpc password.")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let auth = RPCAuth().generateCreds(username: user, password: pass) else {
                showAlert(vc: self, title: "Node not saved.", message: "Unable to create an rpc auth string. Please let us know about this!")
                return
            }
            
            rpcAuthLabel.text = auth.rpcAuth
        }
        
        if selectedNode == nil {
            newNode["id"] = UUID()
            newNode["isLightning"] = false
            newNode["label"] = label
            newNode["onionAddress"] = encAddress
            newNode["rpcuser"] = encUser
            newNode["rpcpassword"] = encPass
            newNode["cert"] = encryptedCert
            saveNewNode()
            
        } else {
            //updating
            guard let selectedNode = selectedNode else {
                showAlert(vc: self, title: "", message: "Selected node does not exist.")
                return
            }
            
            // This check is for backwards compatibility where there was a bug from long ago where an ID did not exist.
            guard let id = selectedNode["id"] as? UUID else {
                return
            }
            
            updateNodeValues(id: id, label: label, encUser: encUser, encPass: encPass, encAddress: encAddress, encCert: encryptedCert)
        }
    }
    
    func updateNodeValues(id: UUID, label: String, encUser: Data, encPass: Data, encAddress: Data, encCert: Data?) {
        
        updateNodeValue(id: id, keyToUpdate: "label", newValue: label) { [weak self] (updated, errorMessage) in
            guard let self = self else { return }
            
            guard updated else {
                showAlert(vc: self, title: "", message: errorMessage!)
                return
            }
            
            updateNodeValue(id: id, keyToUpdate: "rpcuser", newValue: encUser) { [weak self] (rpcUserUpdated, errorMessage) in
                guard let self = self else { return }
                
                guard rpcUserUpdated else {
                    showAlert(vc: self, title: "", message: errorMessage!)
                    return
                }
                
                updateNodeValue(id: id, keyToUpdate: "rpcpassword", newValue: encPass) { [weak self] (rpcPassUpdated, errorMessage) in
                    guard let self = self else { return }
                    
                    guard rpcPassUpdated else {
                        showAlert(vc: self, title: "", message: errorMessage!)
                        return
                    }
                    
                    updateNodeValue(id: id, keyToUpdate: "onionAddress", newValue: encAddress) { [weak self] (addressUpdated, errorMessage) in
                        guard let self = self else { return }
                        
                        guard addressUpdated else {
                            showAlert(vc: self, title: "", message: errorMessage!)
                            return
                        }
                        
                        guard let encCert = encCert else {
                            showAlert(vc: self, title: "", message: "Node updated ✓")
                            return
                        }
                        
                        updateNodeValue(id: id, keyToUpdate: "cert", newValue: encCert) { [weak self] (certUpdated, errorMessage) in
                            guard let self = self else { return }
                            
                            guard updated else {
                                showAlert(vc: self, title: "", message: errorMessage!)
                                return
                            }
                            
                            showAlert(vc: self, title: "", message: "Node updated ✓")
                        }
                    }
                }
            }
        }
    }
    
    func updateNodeValue(id: UUID, keyToUpdate: String, newValue: Any, completion: @escaping ((updated: Bool, errorMessage: String?)) -> Void) {
        CoreDataService.update(id: id, keyToUpdate: keyToUpdate, newValue: newValue, entity: .newNodes) { success in
            guard success else {
                completion((false, "There was an error updating \(keyToUpdate). Please let us know about it!"))
                return
            }
            completion((success, nil))
        }
    }
        
    func saveNewNode() {
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            
            guard let nodes = nodes else {
                showAlert(vc: self, title: "Not not saved.", message: "Unable to fetch Core Data.")
                return
            }
            
            newNode["isActive"] = (nodes.count == 0)
            
            CoreDataService.saveEntity(dict: newNode, entityName: .newNodes) { [weak self] success in
                guard let self = self else { return }
                
                if success {
                    selectedNode = newNode
                    newNode.removeAll()
                    showAlert(vc: self, title: "", message: "Node saved ✓")
                } else {
                    showAlert(vc: self, title: "Node not saved!", message: "Unable to save node to Core Data, please let us know about this.")
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
}

extension NodeDetailViewController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        let securedURL = copyToAppContainer(url: url)
        
        guard let base64Cert = CertificateManager.shared.certFileToBase64(fileURL: securedURL) else {
            showAlert(vc: self, title: "Error", message: "Unable to convert the cert file to base64 text. Ensure you are trying to upload a .pem, .cer, .crt or .der file.")
            return
        }
        
        DispatchQueue.main.async { [ weak self] in
            guard let self = self else { return }
            
            certField.text = base64Cert.condenseWhitespace()
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
