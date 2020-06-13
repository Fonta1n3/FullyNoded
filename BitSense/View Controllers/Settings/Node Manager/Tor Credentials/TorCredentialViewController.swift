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

    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet var onionAddressField: UITextField!
    @IBOutlet var saveButton: UIButton!
    
    @IBAction func scanNow(_ sender: Any) {
        scanNow()
    }
    
    func scanNow() {
        
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
    
    @IBAction func scanAuthKey(_ sender: Any) {
        scanNow()
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
    
    @IBAction func saveAction(_ sender: Any) {
        
        if createNew {
            
            if onionAddressField.text != "" {
                
                guard  let encryptedOnionAddress = encryptedValue((onionAddressField.text)!.dataUsingUTF8StringEncoding)  else { return }
                
                newNode["onionAddress"] = encryptedOnionAddress
                newNode["id"] = UUID()
                var refresh = false
                cd.retrieveEntity(entityName: .newNodes) { [unowned vc = self] in
                    if vc.cd.entities.count == 0 {
                        vc.newNode["isActive"] = true
                        refresh = true
                    } else {
                        vc.newNode["isActive"] = false
                    }
                    vc.cd.saveEntity(dict: vc.newNode, entityName: .newNodes) { [unowned vc = self] in
                        
                        if !vc.cd.errorBool {
                            
                            let success = vc.cd.boolToReturn
                            
                            if success {
                                
                                if refresh {
                                    NotificationCenter.default.post(name: .refreshNode, object: nil)
                                    displayAlert(viewController: vc, isError: false, message: "Tor node saved, we are now refreshing the home screen automatically.")
                                } else {
                                    displayAlert(viewController: vc, isError: false, message: "Tor node saved")
                                }
                                
                            } else {
                                
                                displayAlert(viewController: vc, isError: true, message: "Error saving tor node")
                                
                            }
                            
                        } else {
                            
                            displayAlert(viewController: vc, isError: true, message: vc.cd.errorDescription)
                        }
                        
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
            
            if onionAddressField.text != "" {
                let decryptedAddress = (onionAddressField.text)!.dataUsingUTF8StringEncoding
                guard let encryptedOnionAddress = encryptedValue(decryptedAddress) else { return }
                cd.update(id: node.id!, keyToUpdate: "onionAddress", newValue: encryptedOnionAddress, entity: .newNodes) { [unowned vc = self] success in
                    if success {
                        displayAlert(viewController: vc, isError: false, message: "Node updated!")
                    } else {
                        displayAlert(viewController: vc, isError: true, message: "Error updating node!")
                    }
                }
            } else {
                displayAlert(viewController: self, isError: true, message: "text fields are empty")
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.alpha = 0
        imageView.backgroundColor = UIColor.black
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        onionAddressField.delegate = self
        onionAddressField.isSecureTextEntry = true
        headerLabel.adjustsFontSizeToFitWidth = true
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
