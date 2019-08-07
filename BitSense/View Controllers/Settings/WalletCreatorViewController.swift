//
//  WalletCreatorViewController.swift
//  BitSense
//
//  Created by Peter on 06/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class WalletCreatorViewController: UIViewController, UITextFieldDelegate {
    
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var isUsingSSH = IsUsingSSH.sharedInstance
    var torRPC:MakeRPCCall!
    var torClient:TorClient!
    
    let connectingView = ConnectingView()

    @IBOutlet var textField: UITextField!
    @IBOutlet var hotSwitchOutlet: UISwitch!
    @IBOutlet var coldSwitchOutlet: UISwitch!
    
    @IBAction func hotSwitchAction(_ sender: Any) {
        
        if hotSwitchOutlet.isOn {
            
            coldSwitchOutlet.isOn = false
            
        } else {
            
            coldSwitchOutlet.isOn = true
            
        }
        
    }
    
    @IBAction func coldSwitchAction(_ sender: Any) {
        
        if coldSwitchOutlet.isOn {
            
            hotSwitchOutlet.isOn = false
            
        } else {
            
            hotSwitchOutlet.isOn = true
            
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
            
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.createwallet,
                                       param: param)
            
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
        
        coldSwitchOutlet.isOn = true
        hotSwitchOutlet.isOn = false
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        isUsingSSH = IsUsingSSH.sharedInstance
        
        if isUsingSSH {
            
            ssh = SSHService.sharedInstance
            makeSSHCall = SSHelper.sharedInstance
            
        } else {
            
            torRPC = MakeRPCCall.sharedInstance
            torClient = TorClient.sharedInstance
            
        }
        
        textField.becomeFirstResponder()
        
    }
    
    @objc func dismissKeyboard() {
        
        view.endEditing(true)
        
    }
    
    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.createwallet:
                    
                    let response = makeSSHCall.dictToReturn
                    handleWalletCreation(response: response)
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: self.makeSSHCall.errorDescription)
                    
                }
                
            }
            
        }
        
        if self.ssh != nil {
            
            if self.ssh.session.isConnected {
                
                makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                              method: method,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Not connected")
                
            }
            
        } else {
            
            connectingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Not connected")
            
        }
        
    }
    
    func handleWalletCreation(response: NSDictionary) {
        
        let name = response["name"] as! String
        let warning = response["warning"] as! String
        
        UserDefaults.standard.set(name, forKey: "walletName")
        
        if warning == "" {
            
            self.connectingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: false,
                         message: "Succesfully created \"\(name)\"")
            
        } else {
            
            self.connectingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "\"\(name)\" created with warning: \(warning)")
            
        }
        
        DispatchQueue.main.async {
            
            self.textField.text = ""
            
        }
        
    }

}
