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
    
    let textInput = UITextField()
    let nextButton = UIButton()
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
        
        textInput.delegate = self
        textInput.backgroundColor = UIColor.white
        textInput.keyboardType = UIKeyboardType.default
        textInput.layer.cornerRadius = 10
        textInput.textColor = UIColor.black
        textInput.textAlignment = .center
        textInput.keyboardAppearance = UIKeyboardAppearance.dark
        textInput.autocorrectionType = .no
        
        labelTitle.frame = CGRect(x: 10, y: self.view.frame.maxY / 8, width: self.view.frame.width - 20, height: 100)
        
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
                    
                DispatchQueue.main.async {
                        
                    UIView.animate(withDuration: 0.2, animations: {
                            
                        self.labelTitle.alpha = 0
                        self.nextButton.alpha = 0
                        self.textInput.alpha = 0
                            
                    }) { _ in
                            
                        self.nextButton.removeFromSuperview()
                        self.textInput.removeFromSuperview()
                        
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "goToMainMenu", sender: self)
                            
                        }
                            
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
            
            func randomString(length: Int) -> String {
                
                let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                return String((0...length-1).map{ _ in letters.randomElement()! })
                
            }
            
            let password = randomString(length: 32)
                
            let saveSuccessful:Bool = KeychainWrapper.standard.set(password, forKey: "AESPassword")
                
            if saveSuccessful {
                    
                print("Encryption key saved successfully: \(saveSuccessful)")
                    
            } else {
                    
                print("error saving encryption key")
                    
            }
                
            UserDefaults.standard.set(true, forKey: "firstTime")
            
        }
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextFieldDidEndEditingReason) {
        print("textFieldDidEndEditing")
        
        
    }

}
