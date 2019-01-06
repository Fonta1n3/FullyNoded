//
//  CreateAccountViewController.swift
//  BitSense
//
//  Created by Peter on 08/08/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import SwiftKeychainWrapper
import AES256CBC
import Parse

class CreateAccountViewController: UIViewController, UITextFieldDelegate {
    
    let usernameInput = UITextField()
    let nodePasswordInput = UITextField()
    let ipAddressInput = UITextField()
    let portInput = UITextField()
    let segwit = SegwitAddrCoder()
    
    let textInput = UITextField()
    let nextButton = UIButton()
    let infoButton = UIButton()
    let buyNodeButton = UIButton()
    let alertView = UIView()
    let labelTitle = UILabel()
    var firstPassword = String()
    var secondPassword = String()
    var firstTime = Bool()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        //KeychainWrapper.standard.removeAllKeys()
        
        if KeychainWrapper.standard.object(forKey: "sshPassword") == nil {
            
            KeychainWrapper.standard.set("", forKey: "sshPassword")
        }
        
        firstTimeHere()
        
        if UserDefaults.standard.string(forKey: "userID") == nil {
            
            let newId = self.createUserKey()
            self.addUserToParse(userID: newId)
            
        }
        
        usernameInput.delegate = self
        nodePasswordInput.delegate = self
        ipAddressInput.delegate = self
        portInput.delegate = self
        
        textInput.delegate = self
        textInput.backgroundColor = UIColor.white
        textInput.keyboardType = UIKeyboardType.default
        textInput.layer.cornerRadius = 10
        textInput.textColor = UIColor.black
        textInput.textAlignment = .center
        textInput.keyboardAppearance = UIKeyboardAppearance.dark
        textInput.autocorrectionType = .no
        
        labelTitle.frame = CGRect(x: 10, y: self.view.frame.maxY / 8, width: self.view.frame.width - 20, height: 100)
        
        usernameInput.frame = CGRect(x: 50, y: self.labelTitle.frame.maxY + 10, width: self.view.frame.width - 100, height: 50)
        usernameInput.keyboardType = UIKeyboardType.default
        usernameInput.autocapitalizationType = .none
        usernameInput.autocorrectionType = .no
        usernameInput.layer.cornerRadius = 10
        usernameInput.backgroundColor = UIColor.white
        usernameInput.alpha = 0
        usernameInput.textColor = UIColor.black
        usernameInput.placeholder = "Node Username"
        usernameInput.returnKeyType = UIReturnKeyType.go
        usernameInput.textAlignment = .center
        usernameInput.keyboardAppearance = UIKeyboardAppearance.dark
        
        nodePasswordInput.frame = CGRect(x: 50, y: self.labelTitle.frame.maxY + 10, width: self.view.frame.width - 100, height: 50)
        nodePasswordInput.keyboardType = UIKeyboardType.default
        nodePasswordInput.autocapitalizationType = .none
        nodePasswordInput.autocorrectionType = .no
        nodePasswordInput.layer.cornerRadius = 10
        nodePasswordInput.backgroundColor = UIColor.white
        nodePasswordInput.alpha = 0
        nodePasswordInput.isSecureTextEntry = true
        nodePasswordInput.textColor = UIColor.black
        nodePasswordInput.placeholder = "Node Password"
        nodePasswordInput.returnKeyType = UIReturnKeyType.go
        nodePasswordInput.textAlignment = .center
        nodePasswordInput.keyboardAppearance = UIKeyboardAppearance.dark
        
        ipAddressInput.frame = CGRect(x: 50, y: self.labelTitle.frame.maxY + 10, width: self.view.frame.width - 100, height: 50)
        ipAddressInput.keyboardType = UIKeyboardType.decimalPad
        ipAddressInput.autocapitalizationType = .none
        ipAddressInput.autocorrectionType = .no
        ipAddressInput.layer.cornerRadius = 10
        ipAddressInput.backgroundColor = UIColor.white
        ipAddressInput.alpha = 0
        ipAddressInput.isSecureTextEntry = false
        ipAddressInput.textColor = UIColor.black
        ipAddressInput.placeholder = "IP Address"
        ipAddressInput.returnKeyType = UIReturnKeyType.go
        ipAddressInput.textAlignment = .center
        ipAddressInput.keyboardAppearance = UIKeyboardAppearance.dark
        
        portInput.frame = CGRect(x: 50, y: self.labelTitle.frame.maxY + 10, width: self.view.frame.width - 100, height: 50)
        portInput.keyboardType = UIKeyboardType.numberPad
        portInput.autocapitalizationType = .none
        portInput.autocorrectionType = .no
        portInput.layer.cornerRadius = 10
        portInput.backgroundColor = UIColor.white
        portInput.alpha = 0
        portInput.isSecureTextEntry = false
        portInput.textColor = UIColor.black
        portInput.placeholder = "Port Number"
        portInput.returnKeyType = UIReturnKeyType.go
        portInput.textAlignment = .center
        portInput.keyboardAppearance = UIKeyboardAppearance.dark
        
        labelTitle.font = UIFont.init(name: "HelveticaNeue-Light", size: 18)
        labelTitle.textColor = UIColor.white
        labelTitle.numberOfLines = 0
        
        alertView.frame = view.frame
        alertView.backgroundColor = UIColor.black
        
        nextButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Bold", size: 20)
        nextButton.titleLabel?.textAlignment = .right
        nextButton.backgroundColor = UIColor.clear
        nextButton.showsTouchWhenHighlighted = true
        nextButton.setTitleColor(UIColor.white, for: .normal)
        
        view.addSubview(alertView)
        
        if KeychainWrapper.standard.string(forKey: "UnlockPassword") != nil {
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "login", sender: self)
            }
        } else {
           addPassword()
        }
   }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        self.view.endEditing(true)
        return false
        
    }
    
    
    
    @objc func nextButtonAction() {
        
        self.view.endEditing(true)
        
    }
    
    func addNextButton(inputView: UITextField) {
        print("addNextButton")
        DispatchQueue.main.async {
            self.nextButton.removeFromSuperview()
            self.nextButton.frame = CGRect(x: self.view.center.x - 40, y: inputView.frame.maxY + 10, width: 80, height: 55)
            self.nextButton.showsTouchWhenHighlighted = true
            self.nextButton.setTitle("Next", for: .normal)
            self.nextButton.setTitleColor(UIColor.white, for: .normal)
            self.nextButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Bold", size: 20)
            self.nextButton.addTarget(self, action: #selector(self.nextButtonAction), for: .touchUpInside)
            self.alertView.addSubview(self.nextButton)
            self.addBuyNodeButton(buttonView: self.nextButton)
        }
        
    }
    
    func addBuyNodeButton(buttonView: UIButton) {
        print("addBuyNodeButton")
        DispatchQueue.main.async {
            self.buyNodeButton.removeFromSuperview()
            self.buyNodeButton.frame = CGRect(x: self.view.center.x - (self.view.frame.width / 2), y: buttonView.frame.maxY + 10, width: self.view.frame.width, height: 55)
            self.buyNodeButton.showsTouchWhenHighlighted = true
            self.buyNodeButton.setTitle("I don't have a node", for: .normal)
            self.buyNodeButton.setTitleColor(UIColor.white, for: .normal)
            self.buyNodeButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Light", size: 18)
            self.buyNodeButton.addTarget(self, action: #selector(self.buyNode), for: .touchUpInside)
            self.alertView.addSubview(self.buyNodeButton)
        }
    }
    
    @objc func buyNode() {
        DispatchQueue.main.async {
            //self.performSegue(withIdentifier: "buyNode", sender: self)
            self.performSegue(withIdentifier: "purchase", sender: self)
        }
    }
    
    func addPassword() {
        
        DispatchQueue.main.async {
            self.labelTitle.text = "First things first, please set a password that you will use to unlock the app."
            self.labelTitle.textAlignment = .natural
            self.textInput.placeholder = "Password"
            self.textInput.isSecureTextEntry = true
            self.nextButton.setTitle("Next", for: .normal)
            self.nextButton.addTarget(self, action: #selector(self.setLockPassword), for: .touchUpInside)
            self.textInput.frame = CGRect(x: 50, y: self.labelTitle.frame.maxY + 10, width: self.view.frame.width - 100, height: 50)
            self.nextButton.frame = CGRect(x: self.view.center.x - 40, y: self.textInput.frame.maxY + 10, width: 80, height: 50)
            self.view.addSubview(self.alertView)
            self.alertView.addSubview(self.labelTitle)
            self.alertView.addSubview(self.textInput)
            self.alertView.addSubview(self.nextButton)
            
        }
    }
    
    @objc func setLockPassword() {
        
        if self.textInput.text != "" {
            
            DispatchQueue.main.async {
                self.labelTitle.text = "Please confirm the Password to ensure there were no typos."
                self.firstPassword = self.textInput.text!
                self.textInput.text = ""
                self.nextButton.setTitle("Confirm", for: .normal)
                self.nextButton.removeTarget(self, action: #selector(self.setLockPassword), for: .touchUpInside)
                self.nextButton.addTarget(self, action: #selector(self.confirmLockPassword), for: .touchUpInside)
            }
        } else {
            shakeAlert(viewToShake: self.textInput)
        }
        
    }
    
    @objc func confirmLockPassword() {
        
        if self.textInput.text != "" {
            
            self.secondPassword = self.textInput.text!
            
            if self.firstPassword == self.secondPassword {
                
                let saveSuccessful:Bool = KeychainWrapper.standard.set(self.secondPassword, forKey: "UnlockPassword")
                
                if saveSuccessful {
                    
                    self.nextButton.removeTarget(self, action: #selector(self.confirmLockPassword), for: .touchUpInside)
                    self.textInput.text = ""
                    self.textInput.resignFirstResponder()
                    self.infoButton.removeFromSuperview()
                    
                    DispatchQueue.main.async {
                        
                        UIView.animate(withDuration: 0.2, animations: {
                            
                            self.labelTitle.alpha = 0
                            self.nextButton.alpha = 0
                            self.textInput.alpha = 0
                            
                        }) { _ in
                            
                            //self.labelTitle.removeFromSuperview()
                            self.nextButton.removeFromSuperview()
                            self.textInput.removeFromSuperview()
                            
                            
                            if self.firstTime {
                                
                                DispatchQueue.main.async {
                                    //self.performSegue(withIdentifier: "login", sender: self)
                                    self.getNodeUsername()
                                }
                                
                            } else {
                                
                                DispatchQueue.main.async {
                                    self.performSegue(withIdentifier: "goToMainMenu", sender: self)
                                }
                                
                            }
                            
                        }
                        
                    }
                    
                } else {
                    
                    //displayAlert(viewController: self, title: "Error", message: "Unable to save the password! Please try again.")
                    
                }
            } else {
                //displayAlert(viewController: self, title: "Error", message: "Passwords did not match, try again.")
            }
        } else {
            shakeAlert(viewToShake: self.textInput)
        }
    }
    
    func encryptKey(keyToEncrypt: String) -> String {
        
        let password = KeychainWrapper.standard.string(forKey: "AESPassword")!
        let encryptedkey = AES256CBC.encryptString(keyToEncrypt, password: password)!
        return encryptedkey
    }
    
    func firstTimeHere() {
        
        if KeychainWrapper.standard.object(forKey: "firstTime") == nil {
            
            self.firstTime = true
            
            UserDefaults.standard.set("20,000", forKey: "miningFee")
            
            let key = BTCKey.init()
            var password = ""
            let compressedPKData = BTCRIPEMD160(BTCSHA256(key?.compressedPublicKey as Data!) as Data!) as Data!
            
            do {
                
                password = try segwit.encode(hrp: "bc", version: 0, program: compressedPKData!)
                
                for _ in password {
                    
                    if password.count > 32 {
                        
                        password.removeFirst()
                        
                    }
                    
                }
                
                let newId = self.createUserKey()
                self.addUserToParse(userID: newId)
                
                let saveSuccessful:Bool = KeychainWrapper.standard.set(password, forKey: "AESPassword")
                
                if saveSuccessful {
                    
                    print("Encryption key saved successfully: \(saveSuccessful)")
                    
                } else {
                    
                    print("error saving encryption key")
                    
                }
                
                
            } catch {
                
                print("error")
                
            }
            
            KeychainWrapper.standard.set(true, forKey: "firstTime")
            
        }
    }
    
    func addUserToParse(userID: String) {
        
        let addUser = PFObject(className:"Users")
        addUser["userID"] = userID
        addUser["didPurchaseNode"] = false
        addUser.saveInBackground { (success: Bool, error: Error?) in
            if (success) {
                print("saved userid to parse success")
                UserDefaults.standard.set(userID, forKey: "userID")
            } else {
                // There was a problem, check error.description
                print(error.debugDescription)
            }
        }
    }
    
    func createUserKey() -> String {
        
        let key = BTCKey.init()
        var password = ""
        let compressedPKData = BTCRIPEMD160(BTCSHA256(key?.compressedPublicKey as Data!) as Data!) as Data!
        var id = ""
        
        do {
            
            password = try segwit.encode(hrp: "bc", version: 0, program: compressedPKData!)
            
            for _ in password {
                
                if password.count > 32 {
                    
                    password.removeFirst()
                    
                }
                
            }
            
            id = password
            
        } catch {
            
            print("error")
            
        }
        
        return id
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextFieldDidEndEditingReason) {
        print("textFieldDidEndEditing")
        
        if textField == self.usernameInput {
            
            if self.usernameInput.text != "" {
                
                self.saveUsername(username: self.usernameInput.text!)
                
            } else {
                
                shakeAlert(viewToShake: self.usernameInput)
            }
            
        } else if textField == self.nodePasswordInput {
            
            if self.nodePasswordInput.text != "" {
                
                self.savePassword(password: self.nodePasswordInput.text!)
                
            } else {
                
                shakeAlert(viewToShake: self.nodePasswordInput)
                
            }
            
        } else if textField == self.ipAddressInput {
            
            if self.ipAddressInput.text != "" {
                
                self.saveIPAdress(ipAddress: self.ipAddressInput.text!)
                
            } else {
                
                shakeAlert(viewToShake: self.ipAddressInput)
                
            }
            
        } else if textField == self.portInput {
            
            if self.portInput.text != "" {
                
                self.savePort(port: self.portInput.text!)
                
            } else {
                
                shakeAlert(viewToShake: self.portInput)
                
            }
        }
        
    }
    
    func savePassword(password: String) {
        
        let stringToSave = self.encryptKey(keyToEncrypt: password)
        let saveSuccessful:Bool = KeychainWrapper.standard.set(stringToSave, forKey: "NodePassword")
        
        if saveSuccessful {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.nodePasswordInput.alpha = 0
                self.labelTitle.alpha = 0
                
            }, completion: { _ in
                
                self.nodePasswordInput.text = ""
                self.labelTitle.text = ""
                self.nodePasswordInput.removeFromSuperview()
                self.getIPAddress()
                
            })
            
        } else {
            
            print("error saving string")
        }
        
    }
    
    func saveIPAdress(ipAddress: String) {
        
        let stringToSave = self.encryptKey(keyToEncrypt: ipAddress)
        let saveSuccessful:Bool = KeychainWrapper.standard.set(stringToSave, forKey: "NodeIPAddress")
        
        if saveSuccessful {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.ipAddressInput.alpha = 0
                self.labelTitle.alpha = 0
                
            }, completion: { _ in
                
                self.ipAddressInput.text = ""
                self.labelTitle.text = ""
                self.ipAddressInput.removeFromSuperview()
                self.getPort()
                
            })
            
        } else {
            
            print("error saving string")
        }
        
    }
    
    func savePort(port: String) {
        
        let stringToSave = self.encryptKey(keyToEncrypt: port)
        let saveSuccessful:Bool = KeychainWrapper.standard.set(stringToSave, forKey: "NodePort")
        
        if saveSuccessful {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.portInput.alpha = 0
                self.labelTitle.alpha = 0
                
            }, completion: { _ in
                
                self.portInput.text = ""
                self.labelTitle.text = ""
                self.portInput.removeFromSuperview()
                self.performSegue(withIdentifier: "goToMainMenu", sender: self)
                
            })
            
        } else {
            
            print("error saving string")
        }
    }
    
    func saveUsername(username: String) {
        
        let stringToSave = self.encryptKey(keyToEncrypt: username)
        let saveSuccessful:Bool = KeychainWrapper.standard.set(stringToSave, forKey: "NodeUsername")
        
        if saveSuccessful {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.usernameInput.alpha = 0
                self.labelTitle.alpha = 0
                
            }, completion: { _ in
                
                self.usernameInput.text = ""
                self.labelTitle.text = ""
                self.usernameInput.removeFromSuperview()
                self.getNodePassword()
                
            })
            
        } else {
            
            print("error saving string")
        }
        
    }
    
    func getPort() {
        print("getPort")
        
        view.addSubview(self.portInput)
        self.portInput.becomeFirstResponder()
        self.labelTitle.text = "Enter Your Nodes Port"
        self.labelTitle.adjustsFontSizeToFitWidth = true
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.portInput.alpha = 1
            self.labelTitle.alpha = 1
            
        }, completion: { _ in
            
            self.addNextButton(inputView: self.portInput)
            
        })
        
    }
    
    func getIPAddress() {
        print("getIPAddress")
        
        view.addSubview(self.ipAddressInput)
        self.ipAddressInput.becomeFirstResponder()
        self.labelTitle.text = "Enter Your Nodes IP Address"
        self.labelTitle.adjustsFontSizeToFitWidth = true
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.ipAddressInput.alpha = 1
            self.labelTitle.alpha = 1
            
        }, completion: { _ in
            
            self.addNextButton(inputView: self.ipAddressInput)
            
        })
        
    }
    
    func getNodeUsername() {
        print("getNodeUsername")
        
        view.addSubview(self.usernameInput)
        self.usernameInput.becomeFirstResponder()
        self.labelTitle.frame = CGRect(x: self.view.center.x - ((view.frame.width - 10) / 2), y: self.usernameInput.frame.minY - 50, width: view.frame.width - 10, height: 50)
        self.labelTitle.font = UIFont.init(name: "HelveticaNeue-Light", size: 18)
        self.labelTitle.textAlignment = .center
        self.labelTitle.text = "Enter Your Node Username"
        self.labelTitle.adjustsFontSizeToFitWidth = true
        self.addNextButton(inputView: self.usernameInput)
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.usernameInput.alpha = 1
            self.labelTitle.alpha = 1
            self.nextButton.alpha = 1
            
        })
    }
    
    func getNodePassword() {
        
        view.addSubview(self.nodePasswordInput)
        self.nodePasswordInput.becomeFirstResponder()
        self.labelTitle.text = "Enter Node Password"
        self.labelTitle.adjustsFontSizeToFitWidth = true
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.nodePasswordInput.alpha = 1
            self.labelTitle.alpha = 1
            
        }, completion: { _ in
            
            self.addNextButton(inputView: self.nodePasswordInput)
            
        })
    }

}
