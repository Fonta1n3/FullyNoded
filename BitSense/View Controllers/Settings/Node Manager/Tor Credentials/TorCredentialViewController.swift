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
            keygen.generate()
            let pubkey = keygen.pubKey
            let privkey = keygen.privKey
            self.generateButtonOutlet.alpha = 0
            self.pubkeyTextView.text = "descriptor:x25519:" + pubkey
            self.authKeyField.text = privkey
            self.pubkeyDescription.alpha = 1
            self.pubkeyLabel.alpha = 1
            
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
        
        if createNew {
            
            if onionAddressField.text != "" {
                
                let id = randomString(length: 23)
                let enc = aes.encryptKey(keyToEncrypt: onionAddressField.text!)
                newNode["onionAddress"] = enc
                newNode["id"] = id
                
                if authKeyField.text != "" {
                    
                    let enc = aes.encryptKey(keyToEncrypt: authKeyField.text!)
                    newNode["authKey"] = enc
                    
                }
                
                if pubkeyTextView.text != "" {
                    
                    let enc = aes.encryptKey(keyToEncrypt: pubkeyTextView.text!)
                    newNode["authPubKey"] = enc
                    
                }
                
                cd.saveEntity(dict: newNode, entityName: .nodes) {
                    
                    if !self.cd.errorBool {
                        
                        let success = self.cd.boolToReturn
                        
                        if success {
                            
                            displayAlert(viewController: self,
                                         isError: false,
                                         message: "Tor node saved")
                            
                        } else {
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "Error saving tor node")
                            
                        }
                        
                    } else {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: self.cd.errorDescription)
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Add an onion address first")
            }
            
        } else {
            
            //updating
            if onionAddressField.text != "" && authKeyField.text != "" {
                
                let node = NodeStruct(dictionary: selectedNode)
                let enc = aes.encryptKey(keyToEncrypt: onionAddressField.text!)
                let privKey = (self.authKeyField.text!).replacingOccurrences(of: "====", with: "")
                let enc2 = self.aes.encryptKey(keyToEncrypt: privKey)
                let id = node.id
                let d1:[String:Any] = ["id":id,"newValue":enc,"keyToEdit":"onionAddress","entityName":ENTITY.nodes]
                let d2:[String:Any] = ["id":id,"newValue":enc2,"keyToEdit":"authKey","entityName":ENTITY.nodes]
                let dicts = [d1,d2]
                
                cd.updateEntity(dictsToUpdate: dicts) {
                    
                    if !self.cd.errorBool {
                        
                        let success = self.cd.boolToReturn
                        
                        if success {
                            
                            if self.pubkeyTextView.text != "" {
                                
                                let enc1 = self.aes.encryptKey(keyToEncrypt: self.pubkeyTextView.text!)
                                let d1:[String:Any] = ["id":id,"newValue":enc1,"keyToEdit":"authPubKey","entityName":ENTITY.nodes]
                                let dicts = [d1,d2]
                                self.cd.updateEntity(dictsToUpdate: dicts) {
                                    
                                    if !self.cd.errorBool {
                                        
                                        let success = self.cd.boolToReturn
                                        
                                        if success {
                                            
                                            print("pubkey updated successfully")
                                            
                                            displayAlert(viewController: self,
                                                         isError: false,
                                                         message: "Node updated")
                                            
                                        } else {
                                            
                                            print("error updating pubkey")
                                            
                                            displayAlert(viewController: self,
                                                         isError: true,
                                                         message: "Error updating node")
                                            
                                        }
                                        
                                    }
                                    
                                }
                                
                            }
                            
                        } else {
                           
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "Error updating tor node")
                            
                        }
                        
                    } else {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "Error updating tor node")
                        
                    }
                    
                }
                
            } else if onionAddressField.text != "" {
                
                let node = NodeStruct(dictionary: selectedNode)
                let id = node.id
                let enc = aes.encryptKey(keyToEncrypt: onionAddressField.text!)
                let d1:[String:Any] = ["id":id,"newValue":enc,"keyToEdit":"onionAddress","entityName":ENTITY.nodes]
                
                self.cd.updateEntity(dictsToUpdate: [d1]) {
                    
                    if !self.cd.errorBool {
                        
                        let success = self.cd.boolToReturn
                        
                        if success {
                            
                            print("onionaddress updated successfully")
                            
                            displayAlert(viewController: self,
                                         isError: false,
                                         message: "Tor node updated")
                            
                        } else {
                            
                            print("error updating onionaddress")
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "Error updating tor node")
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                //fields empty
                displayAlert(viewController: self,
                             isError: true,
                             message: "text fields are empty")
                
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
        
        pubkeyTextView.addGestureRecognizer(tapTextViewGesture)
        
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
    
    override func viewWillDisappear(_ animated: Bool) {
        
        onionAddressField.text = ""
        
    }
    
    func loadValues() {
        
        if !createNew {
            
            let node = NodeStruct(dictionary: selectedNode)
            let enc = node.onionAddress
            onionAddressField.text = aes.decryptKey(keyToDecrypt: enc)
            
            if node.authKey != "" {
                
                let enc = node.authKey
                
                DispatchQueue.main.async {
                    
                    self.authKeyField.text = self.aes.decryptKey(keyToDecrypt: enc)
                    
                }
                
                if node.authPubKey != "" {
                    
                    DispatchQueue.main.async {
                        
                        self.generateButtonOutlet.setTitle("refresh V3 auth key pair", for: .normal)
                        self.pubkeyTextView.text = self.aes.decryptKey(keyToDecrypt: node.authPubKey)
                        self.pubkeyDescription.alpha = 1
                        self.pubkeyLabel.alpha = 1
                        
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
