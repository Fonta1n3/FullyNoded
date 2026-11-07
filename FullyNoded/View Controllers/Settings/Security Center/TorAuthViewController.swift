//
//  TorAuthViewController.swift
//  BitSense
//
//  Created by Peter on 13/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class TorAuthViewController: UIViewController, UITextFieldDelegate {
    // Pushed full height, without the tab bar.
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }

    let textField = UITextField()
    let publickKeyLabel = UILabel()
    var text = "Add"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Tor Auth"
        buildLayout()
        textField.delegate = self
        publickKeyLabel.text = ""
        // Cypherpunk look (WalletTheme in ActiveWalletViewController.swift).
        WalletTheme.apply(to: self, tint: .settings)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        CoreDataService.retrieveEntity(entityName: .authKeys) { [unowned vc = self] authKeys in
            if authKeys != nil {
                if authKeys!.count > 0 {
                    vc.text = "Refresh"
                    DispatchQueue.main.async { [unowned vc = self] in
                        let authkeys = AuthKeysStruct.init(dictionary: authKeys![0])
                        vc.publickKeyLabel.text = authkeys.publicKey
                        vc.textField.text = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                    }
                }
            }
        }
    }
    
    private func buildLayout() {
        let privateTitle = UILabel()
        privateTitle.text = "Private Key"
        let publicTitle = UILabel()
        publicTitle.text = "Public Key"

        textField.borderStyle = .roundedRect
        textField.font = .systemFont(ofSize: 14)
        textField.isSecureTextEntry = true
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no
        textField.returnKeyType = .next
        textField.keyboardAppearance = .dark

        publickKeyLabel.numberOfLines = 0
        publickKeyLabel.textColor = .secondaryLabel

        let note = UILabel()
        note.numberOfLines = 0
        note.font = .systemFont(ofSize: 12)
        note.textColor = .tertiaryLabel
        note.text = "You will need to add this public key in its current format to your tor \"authorized_clients\" directory and save it as a file with a \".auth\" extension. Once added to your node's machine make sure you restart Tor."

        let refresh = iconButton("arrow.clockwise", label: "Refresh auth keys", action: #selector(refreshAction(_:)))
        let copy = iconButton("doc.on.doc", label: "Copy public key", action: #selector(copyAction(_:)))
        let export = iconButton("square.and.arrow.up", label: "Export public key", action: #selector(exportAction(_:)))
        let publicButtons = UIStackView(arrangedSubviews: [copy, export])
        publicButtons.spacing = 13

        for subview in [privateTitle, refresh, textField, publicTitle, publicButtons, publickKeyLabel, note] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            privateTitle.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            privateTitle.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            refresh.centerYAnchor.constraint(equalTo: privateTitle.centerYAnchor),
            refresh.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            textField.topAnchor.constraint(equalTo: privateTitle.bottomAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            textField.heightAnchor.constraint(equalToConstant: 45),
            publicTitle.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 30),
            publicTitle.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            publicButtons.centerYAnchor.constraint(equalTo: publicTitle.centerYAnchor),
            publicButtons.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            publickKeyLabel.topAnchor.constraint(equalTo: publicTitle.bottomAnchor, constant: 8),
            publickKeyLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            publickKeyLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            note.topAnchor.constraint(equalTo: publickKeyLabel.bottomAnchor, constant: 8),
            note.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            note.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16)
        ])
    }

    private func iconButton(_ systemName: String, label: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.accessibilityLabel = label
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    @objc func copyAction(_ sender: Any) {
        guard let pubkey = publickKeyLabel.text else { return }
        
        UIPasteboard.general.string = pubkey
        SuccessView.toast("Pubkey copied", in: self)
    }

    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        textField.resignFirstResponder()
    }
    
    @objc func refreshAction(_ sender: Any) {
        promptToRefreshAuth()
    }
    
    @objc func exportAction(_ sender: Any) {
        if publickKeyLabel.text != "" {
            exportPublicKey()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.text != "" {
            promptToAddUserSuppliedAuth()
        }
        return true
    }
    
    private func addUserSuppliedPrivKey() {
        let data = (textField.text)!.dataUsingUTF8StringEncoding
        guard let encryptedKey = Crypto.encrypt(data) else { return }
        
        CoreDataService.retrieveEntity(entityName: .authKeys) { authKeys in
            guard let authKeys = authKeys, authKeys.count > 0 else {
                let dict = ["privateKey":encryptedKey, "publicKey":"user added public key", "id":UUID()] as [String : Any]
                CoreDataService.saveEntity(dict: dict, entityName: .authKeys) { [unowned vc = self] success in
                    if success {
                        showAlert(vc: vc, title: "", message: "Auth keys added.")
                    }
                }
                
                return
            }
            
            let authKeysStr = AuthKeysStruct.init(dictionary: authKeys[0])
            CoreDataService.update(id: authKeysStr.id, keyToUpdate: "privateKey", newValue: encryptedKey, entity: .authKeys) { [unowned vc = self] success in
                if success {
                    CoreDataService.update(id: authKeysStr.id, keyToUpdate: "publicKey", newValue: "user supplied keys", entity: .authKeys) { [unowned vc = self] success in
                        if success {
                            showAlert(vc: vc, title: "", message: "Updated autyh keys.")
                        } else {
                            showAlert(vc: vc, title: "Error", message: "Error saving user added public key")
                        }
                    }
                } else {
                    showAlert(vc: vc, title: "Error", message: "Error saving user added private key")
                }
            }
        }
    }
    
    private func generateNewKeyPair() {
        DispatchQueue.main.async {
            let keygen = KeyGen()
            keygen.generate { [unowned vc = self] (pubkey, privkey) in
                vc.publickKeyLabel.text = "descriptor:x25519:" + pubkey
                vc.textField.text = privkey
                let privKeyData = (vc.textField.text)!.dataUsingUTF8StringEncoding
                let pubKey = vc.publickKeyLabel.text!
                
                guard let encryptedPrivKey = vc.encryptedValue(privKeyData) else {
                    return
                }
                
                let dict = ["privateKey":encryptedPrivKey, "publicKey":pubKey, "id":UUID()] as [String : Any]
                CoreDataService.retrieveEntity(entityName: .authKeys) { authKeys in
                    if authKeys != nil {
                        if authKeys!.count > 0 {
                            let authKeysStruct = AuthKeysStruct.init(dictionary: authKeys![0])
                            CoreDataService.update(id: authKeysStruct.id, keyToUpdate: "privateKey", newValue: encryptedPrivKey, entity: .authKeys) { success in
                                if success {
                                    CoreDataService.update(id: authKeysStruct.id, keyToUpdate: "publicKey", newValue: pubKey, entity: .authKeys) { [unowned vc = self] success in
                                        if success {
                                            showAlert(vc: vc, title: "", message: "Auth kets updated.")
                                        } else {
                                            showAlert(vc: vc, title: "Error", message: "Error saving your public key.")
                                        }
                                    }
                                } else {
                                    showAlert(vc: vc, title: "Error", message: "Error saving your encrypted private key.")
                                }
                            }
                        } else {
                            CoreDataService.saveEntity(dict: dict, entityName: .authKeys) { success in
                                if success {
                                    showAlert(vc: vc, title: "", message: "Auth keys saved.")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func encryptedValue(_ decryptedValue: Data) -> Data? {
        return Crypto.encrypt(decryptedValue)
    }
    
    @objc func exportPublicKey() {
        DispatchQueue.main.async { [unowned vc = self] in
            let textToShare = [vc.publickKeyLabel.text!]
            let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = self.view
                activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
            vc.present(activityViewController, animated: true) {}
        }
    }
    
    private func promptToRefreshAuth() {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "\(vc.text) Tor v3 auth keys?", message: "For authentication to take effect you will need to add the public key to your node's Tor \"authorized_clients\" directory. If you do not have access to your node you may LOSE access by doing this!", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "\(vc.text)", style: .default, handler: { [unowned vc = self] action in
                vc.generateNewKeyPair()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToAddUserSuppliedAuth() {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Add user supplied Tor v3 auth keys?", message: "Make sure you know what you are doing! It needs to be base32, you can see our github for details. We do not derive the public key for you just yet... Consider donating to see more comprehensive features.", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [unowned vc = self] action in
                vc.addUserSuppliedPrivKey()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
}
