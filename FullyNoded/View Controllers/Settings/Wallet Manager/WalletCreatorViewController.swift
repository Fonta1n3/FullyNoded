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
    
    private func createWallet(param: String) {
        Reducer.makeCommand(command: .createwallet, param: param) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.connectingView.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                }
                return
            }
            
            self.handleWalletCreation(response: dict)
        }
    }
    
    func handleWalletCreation(response: NSDictionary) {
        let name = response["name"] as! String
        let ud = UserDefaults.standard
        ud.set(name, forKey: "walletName")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            NotificationCenter.default.post(name: .refreshWallet, object: nil)
            self.textField.text = ""
            self.walletCreatedSuccess()
        }
    }
    
    private func walletCreatedSuccess() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
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
