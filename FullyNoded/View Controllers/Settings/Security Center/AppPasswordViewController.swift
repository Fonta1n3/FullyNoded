//
//  AppPasswordViewController.swift
//  BitSense
//
//  Created by Peter on 13/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class AppPasswordViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var buttonOutlet: UIButton!
    var firstPassword = ""
    var isResetting = Bool()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.delegate = self
        textField.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        textField.removeGestureRecognizer(tapGesture)
        
        buttonOutlet.clipsToBounds = true
        buttonOutlet.layer.cornerRadius = 8
        buttonOutlet.showsTouchWhenHighlighted = true
        
        if KeyChain.getData("UnlockPassword") != nil {
            isResetting = true
            titleLabel.text = "Confirm existing password"
            buttonOutlet.setTitle("confirm", for: .normal)
        } else {
            isResetting = false
            titleLabel.text = "Create an unlock password"
            buttonOutlet.setTitle("save", for: .normal)
        }
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        textField.resignFirstResponder()
    }
    
    @IBAction func buttonAction(_ sender: Any) {
        textField.resignFirstResponder()
        if !isResetting {
            setNewPassword()
        } else {
            confirmExistsingMatches()
        }
    }
    
    private func updateViewToAddNewPassword() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textField.text = ""
            self.titleLabel.text = "Add new unlock password"
            self.buttonOutlet.setTitle("save", for: .normal)
            self.isResetting = false
            showAlert(vc: self, title: "Password confirmed ✓", message: "Correct password, now you may add a new one")
            self.textField.becomeFirstResponder()
        }
    }
    
    private func confirmExistsingMatches() {
        guard let text = textField.text, text != "", let existingHash = exisitingPassword() else { return }
                
        /// Include to guarantee backwards compatibility
        if text == existingHash.utf8String {
            updateViewToAddNewPassword()
            
        } else {
            guard let hash = hash(text) else { return }
            
            if hash == existingHash {
                updateViewToAddNewPassword()
                
            } else {
                showAlert(vc: self, title: "Error", message: "That password does not match your existing password!")
            }
        }
    }
    
    private func exisitingPassword() -> Data? {
        return KeyChain.getData("UnlockPassword")
    }
    
    private func hash(_ text: String) -> Data? {
        return Data(hexString: Crypto.sha256hash(text))
    }
    
    private func setNewPassword() {
        if firstPassword != "" {
            /// We know we are confirming.
            guard textField.text != "", let hex = hash(textField.text!)?.hexString, firstPassword == hex else {
                showAlert(vc: self, title: "Error", message: "Passwords did not match!")
                return
            }
                        
            setPassword(hex)
        } else {
            setLockPassword()
        }
    }
    
    private func setPassword(_ text: String) {
        guard let data = Data(hexString: text) else {
            showAlert(vc: self, title: "Invalid text", message: "")
            return
        }
        
        if KeyChain.set(data, forKey: "UnlockPassword") {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.textField.text = ""
            }
            
            passwordSet()
            
        } else {
            showAlert(vc: self, title: "Error", message: "We had an error saving your password.")
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
    
    private func setLockPassword() {
        guard let newPassword = textField.text, newPassword != "" else {
            shakeAlert(viewToShake: textField)
            return
        }
        
        guard newPassword.count > 7 else {
            showAlert(vc: self, title: "That is not secure!", message: "Your password needs to be at least 8 characters in length.")
            return
        }
        
        guard !newPassword.isNumber else {
            showAlert(vc: self, title: "That is not secure!", message: "Your password is a password, not a pin. Ideally, it should include numbers and letters. Numeric passwords are not allowed.")
            return
        }
        
        guard let data = hash(newPassword) else {
            shakeAlert(viewToShake: textField)
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.titleLabel.text = "Confirm the new password"
            self.firstPassword = data.hexString
            self.textField.text = ""
            self.buttonOutlet.setTitle("confirm", for: .normal)
            showAlert(vc: self, title: "Great, now enter it again", message: "This ensures you have not made any typos when creating a new password.")
            self.textField.becomeFirstResponder()
        }
        
    }
    
    private func passwordSet() {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: "Password set 🔐", message: "⚠️ Do not forget it! ⚠️\n\nForgetting this password will mean the app becomes completely bricked!\n\nIt is important to keep backups of all your wallets and signers incase you do", preferredStyle: UIAlertController.Style.alert)
            
            alert.addAction(UIAlertAction(title: "I understand", style: .destructive, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    self?.navigationController?.popToRootViewController(animated: true)
                }
            }))
            
            alert.popoverPresentationController?.sourceView = self?.view
            self?.present(alert, animated: true) {}
        }
    }

}

extension String  {
    var isNumber: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
}
