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
        
        if KeyChain.getData("UnlockPassword") != nil {
            isResetting = true
            titleLabel.text = "Confirm existing password"
            let image = UIImage(systemName: "checkmark.circle")
            buttonOutlet.setImage(image, for: .normal)
        } else {
            isResetting = false
            titleLabel.text = "Add unlock password"
            let image = UIImage(systemName: "plus")
            buttonOutlet.setImage(image, for: .normal)
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
    
    private func confirmExistsingMatches() {
        if textField.text != "" && exisitingPassword() != "" {
            if textField.text! == exisitingPassword() {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.textField.text = ""
                    vc.titleLabel.text = "Add new unlock password"
                    let image = UIImage(systemName: "plus")
                    vc.buttonOutlet.setImage(image, for: .normal)
                    vc.isResetting = false
                    displayAlert(viewController: vc, isError: false, message: "Correct password, now add a new one")
                    vc.textField.becomeFirstResponder()
                }
            } else {
                showAlert(vc: self, title: "Error", message: "That password does not match your existing password!")
            }
        }
    }
    
    private func exisitingPassword() -> String {
        if KeyChain.getData("UnlockPassword") != nil {
            let passwordData = KeyChain.getData("UnlockPassword")
            return passwordData!.utf8
        } else {
            return ""
        }
    }
    
    private func setNewPassword() {
        if firstPassword != "" {
            /// We know we are confirming.
            if textField.text != "" {
                if firstPassword == textField.text {
                    setPassword(textField.text!)
                } else {
                    showAlert(vc: self, title: "Error", message: "Passwords did not match!")
                }
            }
        } else {
            setLockPassword()
        }
    }
    
    private func setPassword(_ text: String) {
        let data = text.dataUsingUTF8StringEncoding
        if KeyChain.set(data, forKey: "UnlockPassword") {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.textField.text = ""
            }
            displayAlert(viewController: self, isError: false, message: "password set, you may now go back")
        } else {
            showAlert(vc: self, title: "Error", message: "We had an error saving your password.")
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
    
    private func setLockPassword() {
        if textField.text != "" {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.titleLabel.text = "Confirm the new password"
                vc.firstPassword = vc.textField.text!
                vc.textField.text = ""
                let image = UIImage(systemName: "checkmark.circle")
                vc.buttonOutlet.setImage(image, for: .normal)
                displayAlert(viewController: vc, isError: false, message: "confirm the new password")
                vc.textField.becomeFirstResponder()
            }
        } else {
            shakeAlert(viewToShake: textField)
        }
    }

}
