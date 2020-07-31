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
    var sigFieldEditing = Bool()
    
    @IBOutlet var keyOutlet: UITextView!
    @IBOutlet var messageOutlet: UITextView!
    @IBOutlet var sigOutlet: UITextView!
    
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
                
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
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
        
        
        
    }
    
    func addText(text: String) {
        DispatchQueue.main.async {
            
            
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
    
//    func getQRCode() {
//
//        addText(text: qrScanner.stringToReturn)
//
//    }
//
//    func didPickImage() {
//
//        addText(text: qrScanner.qrString)
//
//    }
    
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
