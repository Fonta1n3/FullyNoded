//
//  DuressPinViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/15/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import UIKit

class DuressPinViewController: UIViewController, UITextFieldDelegate {
    // Pushed full height, without the tab bar.
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }

    private var pinHash = ""
    
    let duressPinTextField = UITextField()
    let saveButtonOutlet = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Duress PIN"
        buildLayout()
        duressPinTextField.delegate = self
        configureTapGesture()
        // Cypherpunk look (WalletTheme in ActiveWalletViewController.swift).
        WalletTheme.stylePrimary(saveButtonOutlet, tint: .settings)
        WalletTheme.apply(to: self, tint: .settings)
    }
    
    private func buildLayout() {
        let title = UILabel()
        title.text = "Duress PIN"
        title.font = .systemFont(ofSize: 25)

        duressPinTextField.borderStyle = .roundedRect
        duressPinTextField.placeholder = "duress PIN"
        duressPinTextField.font = .systemFont(ofSize: 14)
        duressPinTextField.isSecureTextEntry = true
        duressPinTextField.autocorrectionType = .no
        duressPinTextField.spellCheckingType = .no
        duressPinTextField.smartDashesType = .no
        duressPinTextField.smartQuotesType = .no
        duressPinTextField.smartInsertDeleteType = .no

        let warning = UILabel()
        warning.numberOfLines = 0
        warning.textColor = .secondaryLabel
        warning.text = "Setting a duress PIN means the app will PERMANENTLY DELETE ALL nodes, wallets and signers when this PIN is used to unlock the app."

        saveButtonOutlet.setTitle("Save Duress PIN", for: .normal)
        saveButtonOutlet.addTarget(self, action: #selector(saveDuressPinAction(_:)), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, duressPinTextField, warning, saveButtonOutlet])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])
    }
    
    @objc func saveDuressPinAction(_ sender: Any) {
        if pinHash == "" {
            guard let originalPIN = duressPinTextField.text else { return }
            
            pinHash = Crypto.sha256hash(originalPIN)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                duressPinTextField.text = ""
                saveButtonOutlet.setTitle("Confirm Duress PIN", for: .normal)
                showAlert(vc: self, title: "Confirm", message: "Confirm the PIN to save it.")
            }
        } else {
            guard let confirmedPIN = duressPinTextField.text else { return }
            
            let confirmedPINHash = Crypto.sha256hash(confirmedPIN)
            
            if confirmedPINHash == pinHash {
                UserDefaults.standard.set(pinHash, forKey: "DuressPIN")
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    saveButtonOutlet.setTitle("Save Duress PIN", for: .normal)
                    duressPinTextField.text = ""
                    pinHash = ""
                    SuccessView.show(in: self, title: "Duress PIN saved", subtitle: "Entering it at the lock screen wipes the app. Once used there is no going back.")
                }
            }
        }
    }
    
    private func configureTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        duressPinTextField.resignFirstResponder()
    }

}
