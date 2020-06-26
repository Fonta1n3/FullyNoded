//
//  IdentityViewController.swift
//  BitSense
//
//  Created by Peter on 10/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class IdentityViewController: UIViewController, UITextViewDelegate {
    
    var sign = Bool()
    var verify = Bool()
    var scanKey = Bool()
    var scanMessage = Bool()
    var scanSig = Bool()
    var scannerShowing = Bool()
    var isFirstTime = Bool()
    var isTorchOn = Bool()
    var sigFieldEditing = Bool()
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var keyOutlet: UITextView!
    @IBOutlet var messageOutlet: UITextView!
    @IBOutlet var sigOutlet: UITextView!
    
    let qrScanner = QRScanner()
    let connectingView = ConnectingView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if verify {
            
            navigationItem.title = "Verify"
            sigOutlet.textColor = UIColor.white
            
        }
        
        if sign {
            
            sigOutlet.isEditable = false
            sigOutlet.isSelectable = true
            
        }
        
        configureScanner()
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        sigOutlet.delegate = self
        
    }
    
    @IBAction func actionButton(_ sender: Any) {
        
        if sign && keyOutlet.text != "" && messageOutlet.text != "" {
            
            connectingView.addConnectingView(vc: self,
                                             description: "signing")
            
            let key = keyOutlet.text!
            let message = messageOutlet.text!
            let param = "\"\(key)\", \"\(message)\""
            var method = BTC_CLI_COMMAND.signmessage
            
            if isPrivKey(key: key) {
                
                method = BTC_CLI_COMMAND.signmessagewithprivkey
                
            }
            
            executeNodeCommand(method: method,
                               param: param)
            
        }
        
        if verify && keyOutlet.text != "" && messageOutlet.text != "" && sigOutlet.text != "" {
            
            connectingView.addConnectingView(vc: self,
                                             description: "verifying")
            
            let key = keyOutlet.text!
            let message = messageOutlet.text!
            let sig = sigOutlet.text!
            let param = "\"\(key)\", \"\(sig)\", \"\(message)\""
            let method = BTC_CLI_COMMAND.verifymessage
            
            executeNodeCommand(method: method,
                               param: param)
            
        }
        
    }
    
    func isPrivKey(key: String) -> Bool {
        
        var boolToReturn = false
        
        switch key {
            
        case _ where key.hasPrefix("l"),
             _ where key.hasPrefix("5"),
             _ where key.hasPrefix("9"),
             _ where key.hasPrefix("c"),
             _ where key.hasPrefix("k"):
            
            boolToReturn = true
            
        default:
            
            break
            
        }
        
        return boolToReturn
        
    }
    
    @IBAction func scanKey(_ sender: Any) {
        
        scanKey = true
        scanSig = false
        scanMessage = false
        scanNow()
        
    }
    
    @IBAction func scanMessage(_ sender: Any) {
        
        scanMessage = true
        scanKey = false
        scanSig = false
        scanNow()
        
    }
    
    @IBAction func scanSignature(_ sender: Any) {
        
        scanSig = true
        scanMessage = false
        scanKey = false
        scanNow()
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                case .signmessagewithprivkey,
                     .signmessage:
                    if let sig = response as? String {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.sigOutlet.text = sig
                            vc.connectingView.removeConnectingView()
                        }
                    }
                case .verifymessage:
                    if let verified = response as? Double {
                        if verified == 1.0 {
                            vc.showAlert(verified: true)
                        } else {
                            vc.showAlert(verified: false)
                        }
                        vc.connectingView.removeConnectingView()
                    }
                default:
                    break
                }
            } else {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.connectingView.removeConnectingView()
                    displayAlert(viewController: vc, isError: true, message: errorMessage!)
                }
            }
        }
    }
    
    func showAlert(verified: Bool) {
        
        DispatchQueue.main.async {
            
            var tit = "Signature Verified"
            var mess = "This signature matches the signature for the signed message"
            
            if !verified {
                
                tit = "Invalid Signature!"
                mess = "This signature DOES NOT match the signature for the signed message"
                
            }
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in }))
            self.present(alert, animated: true, completion: nil)
            
        }
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        hideKeyboards()
        
    }
    
    func hideKeyboards() {
        
        DispatchQueue.main.async {
            
            self.sigOutlet.resignFirstResponder()
            self.keyOutlet.resignFirstResponder()
            self.messageOutlet.resignFirstResponder()
            
        }
        
    }
    
    func scanNow() {
        print("scanNow")
        
        scannerShowing = true
        hideKeyboards()
        
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
    
    @objc func chooseQRCodeFromLibrary() {
        
        qrScanner.chooseQRCodeFromLibrary()
        
    }
    
    func configureScanner() {
        
        isFirstTime = true
        
        imageView.alpha = 0
        imageView.frame = view.frame
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
    
    func addScannerButtons() {
        
        self.addBlurView(frame: CGRect(x: self.imageView.frame.maxX - 80,
                                       y: self.imageView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.qrScanner.uploadButton)
        
        self.addBlurView(frame: CGRect(x: 10,
                                       y: self.imageView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.qrScanner.torchButton)
        
    }
    
    @objc func back() {
        
        DispatchQueue.main.async {
            
            self.imageView.alpha = 0
            self.scannerShowing = false
            
        }
        
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
    
    func addText(text: String) {
        print("text = \(text)")
        
        print("scanSig = \(scanSig)")
        
        DispatchQueue.main.async {
            
            self.back()
            
            if self.scanKey {
                
                self.keyOutlet.text = text
                
            }
            
            if self.scanSig {
                
                self.sigOutlet.text = text
                
            }
            
            if self.scanMessage {
                
                self.messageOutlet.text = text
                
            }
            
        }
        
    }
    
    func getQRCode() {
        
        addText(text: qrScanner.stringToReturn)
        
    }
    
    func didPickImage() {
        
        addText(text: qrScanner.qrString)
        
    }
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        
        if textView == sigOutlet {
            
            sigFieldEditing = true
            
        }
        
        return true
        
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        
        if textView == sigOutlet {
            
            sigFieldEditing = false
            
        }
        
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        
        if sigFieldEditing {
            if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
                if self.view.frame.origin.y == 0 {
                    self.view.frame.origin.y -= keyboardSize.height
                }
            }
        }
        
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        
        if sigFieldEditing {
            if self.view.frame.origin.y != 0 {
                self.view.frame.origin.y = 0
            }
        }
        
    }
    
}
