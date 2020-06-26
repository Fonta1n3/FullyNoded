//
//  WalletCreatorViewController.swift
//  BitSense
//
//  Created by Peter on 06/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class WalletCreatorViewController: UIViewController, UITextFieldDelegate {
    
    let connectingView = ConnectingView()

    @IBOutlet var textField: UITextField!
    @IBOutlet var hotSwitchOutlet: UISwitch!
    @IBOutlet var coldSwitchOutlet: UISwitch!
    @IBOutlet var blankSwitchOutlet: UISwitch!
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self,
                                                                 action: #selector(dismissKeyboard))
        
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
        let warning = response["warning"] as! String
        let ud = UserDefaults.standard
        ud.set(name, forKey: "walletName")
        
        if warning == "" {
            
            self.connectingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: false,
                         message: "Succesfully created \"\(name)\", we are now refreshing your home screen.")
            
        } else {
            
            self.connectingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "\"\(name)\" created with warning: \(warning)")
            
        }
        
        NotificationCenter.default.post(name: .refreshWallet, object: nil)
        
        DispatchQueue.main.async {
            
            self.textField.text = ""
            
        }
        
    }

}
