//
//  TorCredentialViewController.swift
//  BitSense
//
//  Created by Peter on 14/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class TorCredentialViewController: UIViewController, UINavigationControllerDelegate, UITextFieldDelegate, UITextViewDelegate {
    
    var tapTextViewGesture = UITapGestureRecognizer()
    var selectedNode = [String:Any]()
    var createNew = Bool()
    var newNode = [String:Any]()
    let aes = AESService()
    let cd = CoreDataService()
    let qrScanner = QRScanner()
    var isFirstTime = Bool()
    var isTorchOn = Bool()
    var scannerShowing = false
    let imageView = UIImageView()
    var scanningAuthKey = Bool()
    var scanningOnion = Bool()

    @IBOutlet var onionAddressField: UITextField!
    @IBOutlet var saveButton: UIButton!
    @IBOutlet var authKeyField: UITextField!
    @IBOutlet var pubkeyTextView: UITextView!
    @IBOutlet var pubkeyLabel: UILabel!
    @IBOutlet var pubkeyDescription: UILabel!
    @IBOutlet var generateButtonOutlet: UIButton!
    
    @IBAction func generateKeyPair(_ sender: Any) {
        
        DispatchQueue.main.async {
        
            let keygen = KeyGen()
            keygen.generate { [unowned vc = self] (pubkey, privkey) in
                
                vc.pubkeyTextView.addGestureRecognizer(vc.tapTextViewGesture)
                vc.generateButtonOutlet.alpha = 0
                vc.pubkeyTextView.text = "descriptor:x25519:" + pubkey
                vc.authKeyField.text = privkey
                vc.pubkeyDescription.alpha = 1
                vc.pubkeyLabel.alpha = 1
                
            }
            
        }
        
    }
    
    @IBAction func scanNow(_ sender: Any) {
        
        scanningOnion = true
        scanningAuthKey = false
        scanNow()
        
    }
    
    func scanNow() {
        
        onionAddressField.resignFirstResponder()
        authKeyField.resignFirstResponder()
        
        if isFirstTime {
            
            DispatchQueue.main.async {
                
                self.qrScanner.scanQRCode()
                self.addScannerButtons()
                self.imageView.addSubview(self.qrScanner.closeButton)
                self.isFirstTime = false
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                })
                
            }
            
        } else {
            
            self.qrScanner.startScanner()
            self.addScannerButtons()
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                })
                
            }
            
        }
        
    }
    
    @IBAction func scanAuthKey(_ sender: Any) {
        
        scanningAuthKey = true
        scanningOnion = false
        scanNow()
        
    }
    
    
    @IBAction func saveAction(_ sender: Any) {
        
        func encryptedValue(_ decryptedValue: Data) -> Data? {
            var encryptedValue:Data?
            Crypto.encryptData(dataToEncrypt: decryptedValue) { encryptedData in
                if encryptedData != nil {
                    encryptedValue = encryptedData!
                }
            }
            return encryptedValue
        }
        
        if createNew {
            
            if onionAddressField.text != "" {
                
                guard  let encryptedOnionAddress = encryptedValue((onionAddressField.text)!.dataUsingUTF8StringEncoding)  else { return }
                
                if authKeyField.text != "" {
                    guard let encryptedAuthKey = encryptedValue((authKeyField.text)!.dataUsingUTF8StringEncoding) else { return }
                    newNode["authKey"] = encryptedAuthKey
                }
                
                if pubkeyTextView.text != "" {
                    guard let encryptedAuthPubKey = encryptedValue((pubkeyTextView.text)!.dataUsingUTF8StringEncoding) else { return }
                    newNode["authPubKey"] = encryptedAuthPubKey
                }
                
                newNode["onionAddress"] = encryptedOnionAddress
                newNode["id"] = UUID()
                
                cd.saveEntity(dict: newNode, entityName: .newNodes) { [unowned vc = self] in
                    
                    if !vc.cd.errorBool {
                        
                        let success = vc.cd.boolToReturn
                        
                        if success {
                            
                            displayAlert(viewController: vc,
                                         isError: false,
                                         message: "Tor node saved")
                            
                        } else {
                            
                            displayAlert(viewController: vc,
                                         isError: true,
                                         message: "Error saving tor node")
                            
                        }
                        
                    } else {
                        
                        displayAlert(viewController: vc,
                                     isError: true,
                                     message: vc.cd.errorDescription)
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Add an onion address first")
            }
            
        } else {
            
            //updating
            let node = NodeStruct(dictionary: selectedNode)
            
            if onionAddressField.text != "" && authKeyField.text != "" && pubkeyTextView.text != "" {
                
                let privKeyData = (authKeyField.text)!.dataUsingUTF8StringEncoding
                let addressData = (onionAddressField.text)!.dataUsingUTF8StringEncoding
                let pubKeyData = (pubkeyTextView.text)!.dataUsingUTF8StringEncoding
                
                guard let encryptedPrivKey = encryptedValue(privKeyData) else {
                    return
                }
                guard let encryptedAddress = encryptedValue(addressData) else {
                    return
                }
                guard let encryptedPubKey = encryptedValue(pubKeyData) else {
                    return
                }
                
                cd.update(id: node.id!, keyToUpdate: "authKey", newValue: encryptedPrivKey, entity: .newNodes) { [unowned vc = self] success in
                    if success {
                        vc.cd.update(id: node.id!, keyToUpdate: "onionAddress", newValue: encryptedAddress, entity: .newNodes) { [unowned vc = self] success in
                            if success {
                                vc.cd.update(id: node.id!, keyToUpdate: "authPubKey", newValue: encryptedPubKey, entity: .newNodes) { [unowned vc = self] success in
                                    if success {
                                        displayAlert(viewController: vc, isError: false, message: "Node updated")
                                    } else {
                                        displayAlert(viewController: vc, isError: true, message: "Error updating node")
                                    }
                                }
                            } else {
                                displayAlert(viewController: self, isError: true, message: "Error updating node")
                            }
                        }
                    } else {
                        displayAlert(viewController: self, isError: true, message: "Error updating node")
                    }
                }
                
            } else if onionAddressField.text != "" {
                
                let decryptedAddress = (onionAddressField.text)!.dataUsingUTF8StringEncoding
                
                guard let encryptedOnionAddress = encryptedValue(decryptedAddress) else { return }
                cd.update(id: node.id!, keyToUpdate: "onionAddress", newValue: encryptedOnionAddress, entity: .newNodes) { [unowned vc = self] success in
                    if success {
                        displayAlert(viewController: self, isError: false, message: "Node updated!")
                    } else {
                        displayAlert(viewController: self, isError: true, message: "Error updating node!")
                    }
                }
                
            } else {
                //fields empty
                displayAlert(viewController: self, isError: true, message: "text fields are empty")
                
            }
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pubkeyLabel.alpha = 0
        pubkeyDescription.alpha = 0
        pubkeyTextView.isUserInteractionEnabled = true
        pubkeyTextView.isEditable = false
        pubkeyTextView.isSelectable = true
        
        tapTextViewGesture = UITapGestureRecognizer(target: self, action: #selector(shareRawText(_:)))
        imageView.alpha = 0
        imageView.backgroundColor = UIColor.black

        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        
        onionAddressField.delegate = self
        onionAddressField.isSecureTextEntry = true
        authKeyField.delegate = self
        authKeyField.isSecureTextEntry = true
        
        configureScanner()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        loadValues()
        
        if !createNew {
            
            saveButton.setTitle("Update", for: .normal)
            
        }
        
    }
    
    func loadValues() {
        
        if !createNew {
            
            func decryptedValue(_ encryptedValue: Data) -> String {
                var decryptedValue = ""
                Crypto.decryptData(dataToDecrypt: encryptedValue) { decryptedData in
                    if decryptedData != nil {
                        decryptedValue = decryptedData!.utf8
                    }
                }
                return decryptedValue
            }
            
            let node = NodeStruct(dictionary: selectedNode)
            if let enc = node.onionAddress {
                onionAddressField.text = decryptedValue(enc)
            }
            
            
            if node.authKey != nil {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.authKeyField.text = decryptedValue(node.authKey!)
                }
                if node.authPubKey != nil {
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.pubkeyTextView.addGestureRecognizer(vc.tapTextViewGesture)
                        vc.generateButtonOutlet.setTitle("refresh V3 auth key pair", for: .normal)
                        vc.pubkeyTextView.text = decryptedValue(node.authPubKey!)
                        vc.pubkeyDescription.alpha = 1
                        vc.pubkeyLabel.alpha = 1
                    }
                }
            }
            
        } else {
            
            onionAddressField.attributedPlaceholder = NSAttributedString(string: "hs7due39f4.onion:39876",
                                                                 attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
        }
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        self.view.endEditing(true)
        return true
        
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        
        onionAddressField.resignFirstResponder()
        authKeyField.resignFirstResponder()
        
    }
    
    func configureScanner() {
        
        isFirstTime = true
        
        imageView.frame = view.frame
        view.addSubview(imageView)
        imageView.alpha = 0
        imageView.isUserInteractionEnabled = true
        
        qrScanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.keepRunning = false
        qrScanner.vc = self
        qrScanner.imageView = imageView
        qrScanner.textField.alpha = 0
        
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        qrScanner.downSwipeAction = { self.back() }
        
        qrScanner.uploadButton.addTarget(self,
                                         action: #selector(self.chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.torchButton.addTarget(self,
                                        action: #selector(toggleTorch),
                                        for: .touchUpInside)
        
        isTorchOn = false
        
        
        qrScanner.closeButton.addTarget(self,
                                        action: #selector(back),
                                        for: .touchUpInside)
        
    }
    
    @objc func back() {
        print("back")
        
        DispatchQueue.main.async {
            
            self.imageView.alpha = 0
            self.scannerShowing = false
            
        }
        
    }
    
    func addScannerButtons() {
        
        self.addBlurView(frame: CGRect(x: self.imageView.frame.maxX - 80,
                                       y: self.imageView.frame.maxY - 150,
                                       width: 70,
                                       height: 70), button: self.qrScanner.uploadButton)
        
        self.addBlurView(frame: CGRect(x: 10,
                                       y: self.imageView.frame.maxY - 150,
                                       width: 70,
                                       height: 70), button: self.qrScanner.torchButton)
        
    }
    
    @objc func toggleTorch() {
        
        if isTorchOn {
            
            qrScanner.toggleTorch(on: false)
            isTorchOn = false
            
        } else {
            
            qrScanner.toggleTorch(on: true)
            isTorchOn = true
            
        }
        
    }
    
    func addBlurView(frame: CGRect, button: UIButton) {
        
        button.removeFromSuperview()
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        self.imageView.addSubview(blur)
        
    }
    
    func getQRCode() {
        print("getQRCode")
        
        let stringURL = qrScanner.stringToReturn
        imageView.alpha = 0
        
        if scanningOnion {
            
            onionAddressField.text = stringURL
            
        }
        
        if scanningAuthKey {
            
            authKeyField.text = stringURL
            
        }
        
    }
    
    func didPickImage() {
        
        let qrString = qrScanner.qrString
        imageView.alpha = 0
        
        if scanningOnion {
            
           onionAddressField.text = qrString
            
        }
        
        if scanningAuthKey {
            
            authKeyField.text = qrString
            
        }
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        qrScanner.chooseQRCodeFromLibrary()
        
    }
    
    //showPubKey
    
    @objc func shareRawText(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.pubkeyTextView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.pubkeyTextView.alpha = 1
                    
                })
                
            }
            
            self.performSegue(withIdentifier: "showPubKey", sender: self)
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "showPubKey":
            
            if let vc = segue.destination as? ShowV3PubKeyViewController {
                
                if self.pubkeyTextView.text != "" {
                    
                    vc.pubkey = self.pubkeyTextView.text!
                    
                }
                
            }
            
        default:
            
            break
            
        }
        
    }

}
