//
//  TorCredentialViewController.swift
//  BitSense
//
//  Created by Peter on 14/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class TorCredentialViewController: UIViewController, UINavigationControllerDelegate, UITextFieldDelegate {
    
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
                
                let success = cd.saveEntity(vc: self,
                                            dict: newNode,
                                            entityName: .nodes)
                
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
                             message: "Add an onion address first")
            }
            
        } else {
            
            //updating
            if onionAddressField.text != "" && authKeyField.text != "" {
                
                let node = NodeStruct(dictionary: selectedNode)
                let id = node.id
                let enc = aes.encryptKey(keyToEncrypt: onionAddressField.text!)
                
                let success = cd.updateEntity(viewController: self,
                                              id: id,
                                              newValue: enc,
                                              keyToEdit: "onionAddress",
                                              entityName: .nodes)
                
                if success {
                    
                    let enc = aes.encryptKey(keyToEncrypt: authKeyField.text!)
                    
                    let success2 = cd.updateEntity(viewController: self,
                                            id: id,
                                            newValue: enc,
                                            keyToEdit: "authKey",
                                            entityName: .nodes)
                    
                    if success2 {
                        
                        displayAlert(viewController: self,
                                     isError: false,
                                     message: "Tor node updated")
                        
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
                
            } else if onionAddressField.text != "" {
             
                //only onion address updated
                let node = NodeStruct(dictionary: selectedNode)
                let id = node.id
                let enc = aes.encryptKey(keyToEncrypt: onionAddressField.text!)
                
                let success = cd.updateEntity(viewController: self,
                                              id: id,
                                              newValue: enc,
                                              keyToEdit: "onionAddress",
                                              entityName: .nodes)
                
                if success {
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: "Tor node updated")
                    
                } else {
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "Error updating tor node")
                    
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
                authKeyField.text = aes.decryptKey(keyToDecrypt: enc)
                
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
        
        imageView.frame = CGRect(x: 0, y: 60, width: view.frame.width, height: view.frame.height - 105)
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

}
