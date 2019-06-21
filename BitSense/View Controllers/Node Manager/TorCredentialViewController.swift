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

    @IBOutlet var onionAddressField: UITextField!
    @IBOutlet var saveButton: UIButton!
    
    @IBAction func scanNow(_ sender: Any) {
        
        onionAddressField.resignFirstResponder()
        
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
    
    @IBAction func saveAction(_ sender: Any) {
        
        if createNew {
            
            if onionAddressField.text != "" {
                
                let id = randomString(length: 23)
                let enc = aes.encryptKey(keyToEncrypt: onionAddressField.text!)
                newNode["onionAddress"] = enc
                newNode["id"] = id
                
                let success = cd.saveCredentialsToCoreData(vc: navigationController!,
                                                           credentials: newNode)
                
                if success {
                    
                    displayAlert(viewController: navigationController!,
                                 isError: false,
                                 message: "Tor node saved")
                    
                    self.navigationController!.popToRootViewController(animated: true)
                    
                } else {
                    
                    displayAlert(viewController: navigationController!,
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
            if onionAddressField.text != "" {
                
                let id = selectedNode["id"] as! String
                let enc = aes.encryptKey(keyToEncrypt: onionAddressField.text!)
                
                let success = cd.updateNode(viewController: self,
                                            id: id,
                                            newValue: enc,
                                            keyToEdit: "onionAddress")
                
                if success {
                    
                    displayAlert(viewController: navigationController!,
                                 isError: false,
                                 message: "Tor node updated")
                    
                    self.navigationController!.popToRootViewController(animated: true)
                    
                } else {
                    
                    displayAlert(viewController: navigationController!,
                                 isError: true,
                                 message: "Error updating tor node")
                    
                }
                
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
        
        configureScanner()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        loadValues()
        
        if !createNew {
            
            saveButton.setTitle("Update", for: .normal)
            
        }
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        onionAddressField.text = ""
        
    }
    
    func loadValues() {
        
        if !createNew {
            
            let enc = selectedNode["onionAddress"] as! String
            onionAddressField.text = aes.decryptKey(keyToDecrypt: enc)
            
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
        onionAddressField.text = stringURL
        
    }
    
    func didPickImage() {
        
        let qrString = qrScanner.qrString
        imageView.alpha = 0
        onionAddressField.text = qrString
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        qrScanner.chooseQRCodeFromLibrary()
        
    }

}
