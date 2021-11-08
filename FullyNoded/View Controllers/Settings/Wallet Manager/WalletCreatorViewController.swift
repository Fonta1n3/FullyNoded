//
//  WalletCreatorViewController.swift
//  BitSense
//
//  Created by Peter on 06/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class WalletCreatorViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    let connectingView = ConnectingView()
    var alertStyle = UIAlertController.Style.actionSheet

    @IBOutlet var textField: UITextField!
    @IBOutlet var hotSwitchOutlet: UISwitch!
    @IBOutlet var coldSwitchOutlet: UISwitch!
    @IBOutlet var blankSwitchOutlet: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        textField.delegate = self
        textField.returnKeyType = .go
        coldSwitchOutlet.isOn = true
        hotSwitchOutlet.isOn = false
        blankSwitchOutlet.isOn = false
        
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        textField.becomeFirstResponder()
    }
    
    @IBAction func blankSwitchAction(_ sender: Any) {
        if blankSwitchOutlet.isOn {
            hotSwitchOutlet.isOn = false
            coldSwitchOutlet.isOn = false
        }
    }
    
    @IBAction func hotSwitchAction(_ sender: Any) {
        if hotSwitchOutlet.isOn {
            coldSwitchOutlet.isOn = false
            blankSwitchOutlet.isOn = false
        }
    }
    
    @IBAction func coldSwitchAction(_ sender: Any) {
        if coldSwitchOutlet.isOn {
            hotSwitchOutlet.isOn = false
            blankSwitchOutlet.isOn = false
        }
    }
    
    @IBAction func create(_ sender: Any) {
        guard textField.text != "" else {
            displayAlert(viewController: self, isError: true, message: "You need to name your wallet first")
            return
        }
        
        let walletName = textField.text!
        let nospaces = walletName.replacingOccurrences(of: " ", with: "_")
        connectingView.addConnectingView(vc: self, description: "Creating \(nospaces) Wallet")
        
        var param = ""
        
        if coldSwitchOutlet.isOn {
            param = "\"\(nospaces)\", true"
        }
        
        if hotSwitchOutlet.isOn {
            param = "\"\(nospaces)\""
        }
        
        if blankSwitchOutlet.isOn {
            param = "\"\(nospaces)\", false, true"
        }
        
        createWallet(param: param)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func createWallet(param: String) {
        OnchainUtils.createWallet(param: param) { [weak self] (name, message) in
            guard let self = self else { return }
            
            if let name = name {
                UserDefaults.standard.set(name, forKey: "walletName")
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    NotificationCenter.default.post(name: .refreshWallet, object: nil)
                    self.walletCreatedSuccess()
                }
            }
            
//            if let message = message {
//                showAlert(vc: self, title: "Warning", message: message)
//            }
        }
    }
    
    private func walletCreatedSuccess() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textField.text = ""
            self.connectingView.removeConnectingView()
            
            let alert = UIAlertController(title: "Wallet created successfully", message: "Your wallet is automatically activated, the Wallet tab is now refreshing, tap Done to go back", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.navigationController?.popToRootViewController(animated: true)
                }
            }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }

}
