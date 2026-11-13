//
//  AppPasswordViewController.swift
//  BitSense
//
//  Created by Peter on 13/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class AppPasswordViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    // Pushed full height, without the tab bar.
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }

    let titleLabel = UILabel()
    let textField = UITextField()
    let buttonOutlet = UIButton(type: .custom)
    var firstPassword = ""
    var isResetting = Bool()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "App Password"
        buildLayout()
        
        navigationController?.delegate = self
        textField.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        buttonOutlet.clipsToBounds = true
        buttonOutlet.layer.cornerRadius = 8
        buttonOutlet.showsTouchWhenHighlighted = true
        
        if AppAuthentication.hasAppPassword {
            isResetting = true
            titleLabel.text = "Confirm existing password"
            buttonOutlet.setTitle("confirm", for: .normal)
        } else {
            isResetting = false
            titleLabel.text = "Create an unlock password"
            buttonOutlet.setTitle("save", for: .normal)
        }
        
        // Cypherpunk look (WalletTheme in ActiveWalletViewController.swift).
        WalletTheme.stylePrimary(buttonOutlet, tint: .settings)
        WalletTheme.apply(to: self, tint: .settings)
    }
    
    private func buildLayout() {
        titleLabel.text = "Add unlock password"
        textField.borderStyle = .roundedRect
        textField.font = .systemFont(ofSize: 14)
        textField.isSecureTextEntry = true
        textField.textContentType = .newPassword
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no
        textField.returnKeyType = .next
        textField.keyboardAppearance = .dark
        buttonOutlet.setTitle("Save", for: .normal)
        buttonOutlet.addTarget(self, action: #selector(buttonAction(_:)), for: .touchUpInside)

        let info = UITextView()
        info.isEditable = false
        info.isSelectable = false
        info.isScrollEnabled = false
        info.backgroundColor = .clear
        info.font = .systemFont(ofSize: 14)
        info.textColor = .secondaryLabel
        info.text = "This password is never saved to the device. Only the hash of the password is saved. That way even if your device is hacked the thief would not be able to extract a password from it."

        for subview in [titleLabel, textField, buttonOutlet, info] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -16),
            textField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            buttonOutlet.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 8),
            buttonOutlet.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonOutlet.widthAnchor.constraint(equalToConstant: 95),
            buttonOutlet.heightAnchor.constraint(equalToConstant: 34),
            info.topAnchor.constraint(equalTo: buttonOutlet.bottomAnchor, constant: 32),
            info.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            info.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            info.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor, constant: -20)
        ])
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        textField.resignFirstResponder()
    }

    /// Taps on the text field must not trigger the dismiss gesture, otherwise the field
    /// resigns first responder as soon as it gains it and typing goes nowhere.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touched = touch.view else { return true }
        return !touched.isDescendant(of: textField)
    }
    
    @objc func buttonAction(_ sender: Any) {
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
            SuccessView.toast("Password confirmed. Now enter a new one", in: self)
            self.textField.becomeFirstResponder()
        }
    }
    
    private func confirmExistsingMatches() {
        guard let text = textField.text, text != "" else { return }

        if AppAuthentication.verifyAppPassword(text) {
            updateViewToAddNewPassword()
        } else {
            showAlert(vc: self, title: "Error", message: "That password does not match your existing password!")
        }
    }
    
    private func setNewPassword() {
        if firstPassword != "" {
            /// We know we are confirming.
            guard let text = textField.text, text != "",
                  AppAuthentication.passwordHash(text).hexString == firstPassword else {
                showAlert(vc: self, title: "Error", message: "Passwords did not match!")
                return
            }
                        
            setPassword(text)
        } else {
            setLockPassword()
        }
    }
    
    private func setPassword(_ password: String) {
        if AppAuthentication.setAppPassword(password) {
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
        
        let data = AppAuthentication.passwordHash(newPassword)
        
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
