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
    
    var helpTitle = ""
    var helpMessage = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        
        firstTimeHere()
        
        /*usernameInput.delegate = self
        nodePasswordInput.delegate = self
        ipAddressInput.delegate = self
        portInput.delegate = self*/
        
        textInput.delegate = self
        textInput.backgroundColor = UIColor.white
        textInput.keyboardType = UIKeyboardType.default
        textInput.layer.cornerRadius = 10
        textInput.textColor = UIColor.black
        textInput.textAlignment = .center
        textInput.keyboardAppearance = UIKeyboardAppearance.dark
        textInput.autocorrectionType = .no
        
        labelTitle.frame = CGRect(x: 10, y: self.view.frame.maxY / 8, width: self.view.frame.width - 20, height: 100)
        
        /*usernameInput.frame = CGRect(x: 50, y: self.labelTitle.frame.maxY + 10, width: self.view.frame.width - 100, height: 50)
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
        portInput.keyboardAppearance = UIKeyboardAppearance.dark*/
        
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
        
        if UserDefaults.standard.string(forKey: "UnlockPassword") != nil {
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "login", sender: self)
            }
        } else {
           addPassword()
        }
        
        infoButton.frame = CGRect(x: view.frame.maxX - 110, y: 20, width: 100, height: 35)
        infoButton.setTitle("Help?", for: .normal)
        infoButton.setTitleColor(UIColor.white, for: .normal)
        infoButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue", size: 20)
        infoButton.titleLabel?.textAlignment = .right
        infoButton.addTarget(self, action: #selector(showHelp), for: .touchUpInside)
        
   }
    
    @objc func showHelp() {
        
        displayAlert(viewController: self, title: self.helpTitle, message: self.helpMessage)
        
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
                
                UserDefaults.standard.set(self.secondPassword, forKey: "UnlockPassword")
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
                        
                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "goToMainMenu", sender: self)
                        }
                            
                            
                        /*if self.firstTime {
                                
                            DispatchQueue.main.async {
                                //self.performSegue(withIdentifier: "login", sender: self)
                                //self.getNodeUsername()
                            }
                                
                        } else {
                                
                            DispatchQueue.main.async {
                                self.performSegue(withIdentifier: "goToMainMenu", sender: self)
                            }
                                
                        }*/
                            
                    }
                        
                }
                
        } else {
            displayAlert(viewController: self, title: "Error", message: "Passwords did not match, try again.")
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
        print("firstTimeHere")
        
        if UserDefaults.standard.object(forKey: "firstTime") == nil {
            
            self.firstTime = true
            
            UserDefaults.standard.set("500", forKey: "miningFee")
            
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
                
                let saveSuccessful:Bool = KeychainWrapper.standard.set(password, forKey: "AESPassword")
                
                if saveSuccessful {
                    
                    print("Encryption key saved successfully: \(saveSuccessful)")
                    
                } else {
                    
                    print("error saving encryption key")
                    
                }
                
                
            } catch {
                
                print("error")
                
            }
            
            UserDefaults.standard.set(true, forKey: "firstTime")
            
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
        
        /*if textField == self.usernameInput {
            
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
        }*/
        
    }
    
    /*func savePassword(password: String) {
        
        let stringToSave = self.encryptKey(keyToEncrypt: password)
        UserDefaults.standard.set(stringToSave, forKey: "NodePassword")
        UIView.animate(withDuration: 0.2, animations: {
            
            self.nodePasswordInput.alpha = 0
            self.labelTitle.alpha = 0
            
        }, completion: { _ in
            
            self.nodePasswordInput.text = ""
            self.labelTitle.text = ""
            self.nodePasswordInput.removeFromSuperview()
            self.getIPAddress()
            
        })
        
    }
    
    func saveIPAdress(ipAddress: String) {
        
        let stringToSave = self.encryptKey(keyToEncrypt: ipAddress)
        UserDefaults.standard.set(stringToSave, forKey: "NodeIPAddress")
        UIView.animate(withDuration: 0.2, animations: {
            
            self.ipAddressInput.alpha = 0
            self.labelTitle.alpha = 0
            
        }, completion: { _ in
            
            self.ipAddressInput.text = ""
            self.labelTitle.text = ""
            self.ipAddressInput.removeFromSuperview()
            self.getPort()
            
        })
        
    }
    
    func savePort(port: String) {
        
        let stringToSave = self.encryptKey(keyToEncrypt: port)
        UserDefaults.standard.set(stringToSave, forKey: "NodePort")
        UIView.animate(withDuration: 0.2, animations: {
            
            self.portInput.alpha = 0
            self.labelTitle.alpha = 0
            
        }, completion: { _ in
            
            self.portInput.text = ""
            self.labelTitle.text = ""
            self.portInput.removeFromSuperview()
            self.performSegue(withIdentifier: "goToMainMenu", sender: self)
            
        })
    }
    
    func saveUsername(username: String) {
        
        let stringToSave = self.encryptKey(keyToEncrypt: username)
        UserDefaults.standard.set(stringToSave, forKey: "NodeUsername")
        UIView.animate(withDuration: 0.2, animations: {
            
            self.usernameInput.alpha = 0
            self.labelTitle.alpha = 0
            
        }, completion: { _ in
            
            self.usernameInput.text = ""
            self.labelTitle.text = ""
            self.usernameInput.removeFromSuperview()
            self.getNodePassword()
            
        })
        
    }
    
    func getPort() {
        print("getPort")
        
        view.addSubview(self.portInput)
        self.portInput.becomeFirstResponder()
        self.labelTitle.text = "Enter Your Nodes Port"
        self.labelTitle.adjustsFontSizeToFitWidth = true
        self.helpTitle = "Enter Your Nodes Port"
        self.helpMessage = "TL;DR: Mainnet = 8332, Testnet = 18332.\n\nThis is only required if you are filling out your RPC credentials to connect to your node. By default Bitcoin Core assigns 8332 for mainnet and 18332 for testnet for listening for RPC calls. If you are using SSH to log in to your node then you can put any number you like here as it will not be used."
        
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
        self.helpTitle = "Enter Your Nodes IP Address"
        self.helpMessage = "This is either your public or private IP address that your node is connected to. You must put rpcallowip=0.0.0.0/0 to allow any IP to connect to your node, if you only want to specify a certain IP then enter that IP Address.\n\nIf your are using SSH then input whatever IP address Bitcoin core is connected to."
        
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
        alertView.addSubview(infoButton)
        self.usernameInput.becomeFirstResponder()
        self.labelTitle.frame = CGRect(x: self.view.center.x - ((view.frame.width - 10) / 2), y: self.usernameInput.frame.minY - 50, width: view.frame.width - 10, height: 50)
        self.labelTitle.font = UIFont.init(name: "HelveticaNeue-Light", size: 18)
        self.labelTitle.textAlignment = .center
        self.labelTitle.text = "Enter Your Node Username"
        self.labelTitle.adjustsFontSizeToFitWidth = true
        self.helpTitle = "Enter Your Node Username"
        self.helpMessage = "If using RPC credentials you must input the rpcuser value that can be found in your bitcoin.conf file, if there isn't one you can add one, you will need to shut down Bitcoin Core and restart it.\n\nIf you are SSHing into the node then you can simply put the computers username e.g. \"root\", this is whatever username shows up when you open a terminal window."
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
        self.helpTitle = "Enter Your Node Password"
        self.helpMessage = "If using RPC credentials you must input the rpcpassword value that can be found in your bitcoin.conf file, if there isn't one you can add one make sure it is a strong password, you will need to shut down Bitcoin Core and restart it.\n\nIf you are SSHing into the node then you can simply input the SSH password, by default Fully Noded will try to RPC into your node and you may have to wait while the connection times out before an error message prompts you to try and SSH into the node. Select SSH when prompted, if it does not connect right away quit the app and reopen and it should connect quickly."
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.nodePasswordInput.alpha = 1
            self.labelTitle.alpha = 1
            
        }, completion: { _ in
            
            self.addNextButton(inputView: self.nodePasswordInput)
            
        })
    }*/

}
