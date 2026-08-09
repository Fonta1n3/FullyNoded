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
            
    var selectedNode: NodeStruct?
    
    private let scrollView = UIScrollView()
    private let masterStackView = UIStackView()
    private let header = UILabel()
    private let nodeLabel = UITextField()
    private let addressHeader = UILabel()
    private let onionAddressField = UITextField()
    private let usernameHeader = UILabel()
    private let rpcUserField = UITextField()
    private let passwordHeader = UILabel()
    private let rpcPassword = UITextField()
    private let createPasswordButton = UIButton(type: .system)
    private let certHeader = UILabel()
    private let certField = UITextField()
    private let rpcAuthHeader = UILabel()
    private let rpcAuthLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        navigationController?.delegate = self
        
        setupUI()
        configureTapGesture()
        
        [nodeLabel, rpcPassword, rpcUserField, onionAddressField, certField].forEach {
            $0.delegate = self
            $0.textColor = .lightGray
        }
        
        rpcPassword.isSecureTextEntry = true
        onionAddressField.isSecureTextEntry = false
        
        rpcPassword.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        rpcUserField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        
        loadValues()
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        
        masterStackView.axis = .vertical
        masterStackView.spacing = 8
        masterStackView.alignment = .fill
        masterStackView.distribution = .fill
        masterStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(masterStackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            masterStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            masterStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            masterStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            masterStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),
            masterStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
                
        addSection(title: "Label", field: nodeLabel, placeholder: "My Node")
        
        addSection(title: "Address (host:port)", field: onionAddressField, placeholder: "xxxx.onion:8332")
        
        addSection(title: "RPC Username", field: rpcUserField, placeholder: "FullyNoded")
        
        passwordHeader.text = "RPC Password"
        passwordHeader.font = .preferredFont(forTextStyle: .headline)
        passwordHeader.textColor = .systemGreen
        masterStackView.addArrangedSubview(passwordHeader)
        
        let passwordRow = UIStackView(arrangedSubviews: [rpcPassword, createPasswordButton])
        passwordRow.axis = .vertical
        passwordRow.spacing = 8
        passwordRow.alignment = .center
        rpcPassword.placeholder = "Password"
        rpcPassword.borderStyle = .roundedRect
        createPasswordButton.setTitle("Generate secure password", for: .normal)
        createPasswordButton.addTarget(self, action: #selector(createRpcPass(_:)), for: .touchUpInside)
        masterStackView.addArrangedSubview(passwordRow)
        
        let copyRpcAuthButton =  makeButton(title: "Copy", action: #selector(copyRpcAuthAction(_:)))
        let exportRpcAuthButton = makeButton(title: "Export", action: #selector(exportRpcAuth(_:)))
        rpcAuthHeader.text = "RPC Auth (for bitcoin.conf)"
        rpcAuthHeader.font = .preferredFont(forTextStyle: .headline)
        rpcAuthHeader.textColor = .systemGreen
        masterStackView.addArrangedSubview(rpcAuthHeader)
        
        rpcAuthLabel.numberOfLines = 0
        rpcAuthLabel.font = .preferredFont(forTextStyle: .footnote)
        rpcAuthLabel.textColor = .label
        masterStackView.addArrangedSubview(rpcAuthLabel)
        
        let infoBtn = makeButton(title: "RPC Auth?", action: #selector(showRpcAuthInfoAction(_:)))
        let authButtons = UIStackView(arrangedSubviews: [copyRpcAuthButton, exportRpcAuthButton, infoBtn])
        authButtons.axis = .horizontal
        authButtons.spacing = 8
        authButtons.distribution = .fillEqually
        
        masterStackView.addArrangedSubview(authButtons)
        
        addSection(title: "SSL Certificate (Tor not used!)", field: certField, placeholder: "Paste or import .pem/.cer/text")
        
        let certButtons = UIStackView()
        certButtons.axis = .horizontal
        certButtons.spacing = 8
        certButtons.distribution = .fillEqually
        
        let pasteBtn = makeButton(title: "Paste", action: #selector(pasteCertAction(_:)))
        let deleteBtn = makeButton(title: "Delete", action: #selector(deleteCertAction(_:)))
        let fileBtn = makeButton(title: "Import File", action: #selector(showFilePickerAction(_:)))
        
        certButtons.addArrangedSubview(pasteBtn)
        certButtons.addArrangedSubview(deleteBtn)
        certButtons.addArrangedSubview(fileBtn)
        masterStackView.addArrangedSubview(certButtons)

        saveButton.setTitle("Save Node", for: .normal)
        saveButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        saveButton.configuration = .tinted()
        saveButton.setTitleColor(.tintColor, for: .normal)
        saveButton.layer.cornerRadius = 15
        saveButton.addTarget(self, action: #selector(save(_:)), for: .touchUpInside)
        masterStackView.addArrangedSubview(saveButton)
        
        masterStackView.addArrangedSubview(UIView())
    }
    
    private func addSection(title: String, field: UITextField, placeholder: String) {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .systemGreen
        masterStackView.addArrangedSubview(label)
        
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.clearButtonMode = .whileEditing
        masterStackView.addArrangedSubview(field)
    }
    
    private func makeButton(title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
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
        guard let node = selectedNode else { return }
        
        guard let id = node.id, let _ = node.cert else {
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
            
            showAlert(title: "", message: "A secure RPC password was created ✓")
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
        Task { @MainActor in
            // 1. Validate required fields
            guard let address = onionAddressField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty else {
                showAlert(vc: self, title: "", message: "You need to add an address first.")
                return
            }
            
            guard let user = rpcUserField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !user.isEmpty else {
                showAlert(vc: self, title: "", message: "You need to add a rpc user first.")
                return
            }
            
            guard let pass = rpcPassword.text, !pass.isEmpty else {
                showAlert(vc: self, title: "", message: "You need to add an rpc password first.")
                return
            }
            
            guard let label = nodeLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else {
                showAlert(vc: self, title: "", message: "You need to add a label first.")
                return
            }
            
            // 2. Validate host:port format
            let components = address.split(separator: ":")
            guard components.count == 2 else {
                showAlert(
                    vc: self,
                    title: "Not updated, port missing...",
                    message: "Please make sure you add the port at the end of your hostname, such as xxxx.onion:8332.\n\n8332 for mainnet, 18332 for testnet, 38332 for signet or 18443 for regtest."
                )
                return
            }
            
            // 3. Encrypt values
            guard let encAddress = Crypto.encrypt(Data(address.utf8)) else {
                showAlert(vc: self, title: "", message: "Error encrypting the address.")
                return
            }
            
            guard let encUser = Crypto.encrypt(Data(user.utf8)) else {
                showAlert(vc: self, title: "", message: "Error encrypting the rpc user.")
                return
            }
            
            guard let encPass = Crypto.encrypt(Data(pass.utf8)) else {
                showAlert(vc: self, title: "", message: "Error encrypting the rpc password.")
                return
            }
            
            // 4. Optional certificate
            var encryptedCert: Data?
            if let certText = certField.text?.condenseWhitespace(), !certText.isEmpty {
                encryptedCert = Crypto.encrypt(Data(certText.utf8))
            } else {
                let isLocalOrOnion = address.contains(".onion") ||
                address.hasPrefix("localhost:") ||
                address.hasPrefix("127.0.0.1:")
                
                if !isLocalOrOnion {
                    showAlert(
                        vc: self,
                        title: "Warning! ⚠️",
                        message: "You are not using an onion address or localhost. Your RPC credentials could be compromised! This is intended for LAN usage or testing purposes only! To be safer consider adding a SSL cert."
                    )
                }
            }
            
            // 5. Generate RPC auth string (already on MainActor)
            guard let auth = RPCAuth().generateCreds(username: user, password: pass) else {
                showAlert(vc: self, title: "Node not saved.", message: "Unable to create an rpc auth string. Please let us know about this!")
                return
            }
            rpcAuthLabel.text = auth.rpcAuth
            
            // 6. Create or update
            if let selectedNode, let id = selectedNode.id {
                // Update existing node
                await updateNodeValues(
                    id: id,
                    label: label,
                    encUser: encUser,
                    encPass: encPass,
                    encAddress: encAddress,
                    encCert: encryptedCert
                )
            } else if selectedNode == nil {
                // Create new node
                let nodeToSave: [String: Any] = [
                    "id": UUID(),
                    "label": label,
                    "onionAddress": encAddress,
                    "rpcuser": encUser,
                    "rpcpassword": encPass,
                    "cert": encryptedCert as Any
                ]
                saveNewNode(node: nodeToSave)
            } else {
                // selectedNode exists but has no id (legacy bug)
                showAlert(vc: self, title: "", message: "Selected node does not exist.")
            }
        }
    }
    
    @MainActor
    func updateNodeValues(id: UUID, label: String, encUser: Data, encPass: Data, encAddress: Data, encCert: Data?) async {
        do {
            try await updateNodeValue(id: id, keyToUpdate: "label", newValue: label)
            try await updateNodeValue(id: id, keyToUpdate: "rpcuser", newValue: encUser)
            try await updateNodeValue(id: id, keyToUpdate: "rpcpassword", newValue: encPass)
            try await updateNodeValue(id: id, keyToUpdate: "onionAddress", newValue: encAddress)
            
            if let encCert {
                try await updateNodeValue(id: id, keyToUpdate: "cert", newValue: encCert)
            }
            
            SuccessView.show(in: self, title: "Node updated")
        } catch {
            showAlert(vc: self, title: "", message: error.localizedDescription)
        }
    }

    func updateNodeValue(id: UUID, keyToUpdate: String, newValue: Any) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            CoreDataService.update(id: id, keyToUpdate: keyToUpdate, newValue: newValue, entity: .newNodes) { success in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "There was an error updating \(keyToUpdate). Please let us know about it!"]
                    ))
                }
            }
        }
    }
        
    func saveNewNode(node: [String: Any]) {
        var nodeToSave = node
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            
            guard let nodes = nodes else {
                showAlert(vc: self, title: "Not not saved.", message: "Unable to fetch Core Data.")
                return
            }
            
            nodeToSave["isActive"] = (nodes.count == 0)
            
            CoreDataService.saveEntity(dict: nodeToSave, entityName: .newNodes) { [weak self] success in
                guard let self = self else { return }
                
                if success {
                    selectedNode = NodeStruct(dictionary: nodeToSave)
                    SuccessView.show(in: self, title: "Node saved")
                } else {
                    showAlert(vc: self, title: "Node not saved!", message: "Unable to save node to Core Data, please let us know about this.")
                }
            }
        }
    }
    
    @IBAction func showHelpAction(_ sender: Any) {
        showAlert(vc: self,
                  title: "How to connect?",
                  message: "Step 1: Add an rpc user, password (tap the refresh button to create a secure rpc password).\n\nStep 2: Add the address for your node (xxxx.onion:8332 or localhost:8332), tap save.\n\nStep 3: Export the rpc auth text to your bitcoin.conf, save your bitcoin.conf.\n\nStep 4: Restart your node.\n\nStep 5: Ensure the node is activated by tapping it on the Node Manager view. Navigate back to the home screen and tap refresh to connect to your node.")
    }
    
    
    func configureTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
        
    func loadValues() {
        
        // Helper for decryption
        func decrypted(_ data: Data?) -> String {
            guard let data,
                  let decryptedData = Crypto.decrypt(data),
                  let string = decryptedData.utf8String else {
                return ""
            }
            return string
        }
        
        guard let node = selectedNode, node.id != nil else {
            // New node – generate default credentials
            rpcUserField.text = "FullyNoded"
            rpcPassword.text = Crypto.privateKey().hex
            
            if let auth = RPCAuth().generateCreds(username: "FullyNoded",
                                                  password: rpcPassword.text ?? "") {
                rpcAuthLabel.text = auth.rpcAuth
            }
            
            showAlert(vc: self,
                      title: "RPC credentials created ✓",
                      message: "Fully Noded creates an rpc password for you by default, export the rpc auth text to your bitcoin.conf, save it and restart your node to connect. To add your own, just edit the text field.")
            return
        }
        
        // Existing node
        nodeLabel.text = node.label.isEmpty ? nil : node.label
        
        // Credentials
        let user = decrypted(node.rpcuser)
        let password = decrypted(node.rpcpassword)
        
        rpcUserField.text = user
        rpcPassword.text = password
        
        if password == "xxx" {
            showAlert(vc: self,
                      title: "Quick Connect",
                      message: "Dummy rpc credentials detected:\n\nStep 1: Update the rpc user and password, tap save.\n\nStep 2: Export the rpc auth text to your bitcoin.conf, save your bitcoin.conf.\n\nStep 3: Restart your node.\n\nStep 4: Navigate back to the home screen and tap refresh to connect.")
        }
        
        if let auth = RPCAuth().generateCreds(username: user, password: password) {
            rpcAuthLabel.text = auth.rpcAuth
        }
        
        // Address
        let address = decrypted(node.onionAddress)
        onionAddressField.text = address
        
        let isLocalOrOnion = address.contains(".onion") ||
                             address.hasPrefix("localhost:") ||
                             address.hasPrefix("127.0.0.1:")
        
        if !isLocalOrOnion && node.cert == nil {
            showAlert(vc: self,
                      title: "Warning!",
                      message: "You are not using an onion address, your network traffic will not be routed over Tor! This is for connecting to nodes over localhost and LAN only, if using LAN https will be used and you must add the base64 SSL cert.")
        }
        
        // Certificate
        certField.text = decrypted(node.cert)
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
