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
        
        if textField.text != "" {
            
            let walletName = textField.text!
            
            let nospaces = walletName.replacingOccurrences(of: " ", with: "_")
            
            connectingView.addConnectingView(vc: self,
                                             description: "Creating \(nospaces) Wallet")
            
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
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "You need to name your wallet first")
            
        }
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        textField.resignFirstResponder()
        return true
        
    }
    
    @objc func dismissKeyboard() {
        
        view.endEditing(true)
        
    }
    
    private func createWallet(param: String) {
        Reducer.makeCommand(command: .createwallet, param: param) { [unowned vc = self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                vc.handleWalletCreation(response: dict)
            } else {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.connectingView.removeConnectingView()
                    displayAlert(viewController: vc, isError: true, message: errorMessage ?? "")
                }
            }
        }
    }
    
    func handleWalletCreation(response: NSDictionary) {
        let name = response["name"] as! String
        let ud = UserDefaults.standard
        ud.set(name, forKey: "walletName")
        DispatchQueue.main.async { [unowned vc = self] in
            NotificationCenter.default.post(name: .refreshWallet, object: nil)
            vc.textField.text = ""
            vc.walletCreatedSuccess()
        }
    }
    
    private func walletCreatedSuccess() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.connectingView.removeConnectingView()
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Wallet created successfully", message: "Your wallet is automatically activated, the Wallet tab is now refreshing, tap Done to go back", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.navigationController?.popToRootViewController(animated: true)
                }
            }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true) {}
        }
    }

}
