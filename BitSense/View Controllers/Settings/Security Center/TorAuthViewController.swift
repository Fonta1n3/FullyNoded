//
//  TorAuthViewController.swift
//  BitSense
//
//  Created by Peter on 13/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class TorAuthViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var publickKeyLabel: UILabel!
    let qrScanner = QRScanner()
    var scannerShowing = false
    let imageView = UIImageView()
    var isFirstTime = Bool()
    var text = "Add"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textField.delegate = self
        publickKeyLabel.text = ""
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        let cd = CoreDataService()
        cd.retrieveEntity(entityName: .authKeys) { [unowned vc = self] in
            if cd.entities.count > 0 {
                vc.text = "Refresh"
                DispatchQueue.main.async { [unowned vc = self] in
                    let authkeys = AuthKeysStruct.init(dictionary: cd.entities[0])
                    vc.publickKeyLabel.text = authkeys.publicKey
                    vc.textField.text = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                }
            }
        }
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        textField.resignFirstResponder()
    }
    
    @IBAction func refreshAction(_ sender: Any) {
        promptToRefreshAuth()
    }
    
    @IBAction func exportAction(_ sender: Any) {
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
        Crypto.encryptData(dataToEncrypt: data) { encryptedKey in
            if encryptedKey != nil {
                let cd = CoreDataService()
                cd.retrieveEntity(entityName: .authKeys) {
                    if cd.entities.count > 0 {
                        let authKeysStr = AuthKeysStruct.init(dictionary: cd.entities[0])
                        cd.update(id: authKeysStr.id, keyToUpdate: "privateKey", newValue: encryptedKey!, entity: .authKeys) { [unowned vc = self] success in
                            if success {
                                cd.update(id: authKeysStr.id, keyToUpdate: "publicKey", newValue: "user supplied keys", entity: .authKeys) { [unowned vc = self] success in
                                    if success {
                                        displayAlert(viewController: vc, isError: false, message: "Updated auth keys")
                                    } else {
                                        showAlert(vc: vc, title: "Error", message: "Error saving user added public key")
                                    }
                                }
                            } else {
                                showAlert(vc: vc, title: "Error", message: "Error saving user added private key")
                            }
                        }
                    } else {
                        let dict = ["privateKey":encryptedKey!, "publicKey":"user added public key", "id":UUID()] as [String : Any]
                        cd.saveEntity(dict: dict, entityName: .authKeys) { [unowned vc = self] in
                            if !cd.errorBool {
                                displayAlert(viewController: vc, isError: false, message: "Auth keys added")
                            }
                        }
                    }
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
                let cd = CoreDataService()
                cd.retrieveEntity(entityName: .authKeys) {
                    if cd.entities.count > 0 {
                        let authKeysStruct = AuthKeysStruct.init(dictionary: cd.entities[0])
                        cd.update(id: authKeysStruct.id, keyToUpdate: "privateKey", newValue: encryptedPrivKey, entity: .authKeys) { success in
                            if success {
                                cd.update(id: authKeysStruct.id, keyToUpdate: "publicKey", newValue: pubKey, entity: .authKeys) { [unowned vc = self] success in
                                    if success {
                                        displayAlert(viewController: vc, isError: false, message: "auth keys updated!")
                                    } else {
                                        showAlert(vc: vc, title: "Error", message: "Error saving your public key")
                                    }
                                }
                            } else {
                                showAlert(vc: vc, title: "Error", message: "Error saving your encrypted private key")
                            }
                        }
                    } else {
                        cd.saveEntity(dict: dict, entityName: .authKeys) {
                            if !cd.errorBool {
                                displayAlert(viewController: vc, isError: false, message: "Auth keys saved!")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func encryptedValue(_ decryptedValue: Data) -> Data? {
        var encryptedValue:Data?
        Crypto.encryptData(dataToEncrypt: decryptedValue) { encryptedData in
            if encryptedData != nil {
                encryptedValue = encryptedData!
            }
        }
        return encryptedValue
    }
    
    @objc func exportPublicKey() {
        DispatchQueue.main.async { [unowned vc = self] in
            let textToShare = [vc.publickKeyLabel.text!]
            let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = vc.view
            vc.present(activityViewController, animated: true) {}
        }
    }
    
    private func promptToRefreshAuth() {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "\(vc.text) Tor v3 auth keys?", message: "For authentication to take effect you will need to add the public key to your node's Tor \"authorized_clients\" directory. If you do not have access to your node you may LOSE access by doing this!", preferredStyle: .actionSheet)
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
            let alert = UIAlertController(title: "Add user supplied Tor v3 auth keys?", message: "Make sure you know what you are doing! It needs to be base32, you can see our github for details. We do not derive the public key for you just yet... Consider donating to see more comprehensive features.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [unowned vc = self] action in
                vc.addUserSuppliedPrivKey()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
}
