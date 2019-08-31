//
//  TransactionViewController.swift
//  BitSense
//
//  Created by Peter on 22/07/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class TransactionViewController: UIViewController {
    
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var isUsingSSH = IsUsingSSH.sharedInstance
    var txid = ""
    let creatingView = ConnectingView()
    
    @IBOutlet var textView: UITextView!
    
    @IBOutlet var bumpButtonOutlet: UIButton!
    @IBAction func back(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    @IBAction func bumpFee(_ sender: Any) {
        
        creatingView.addConnectingView(vc: self,
                                       description: "Bumping")
        
        executeNodeCommandSsh(method: BTC_CLI_COMMAND.bumpfee,
                              param: "\"\(txid)\"")
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bumpButtonOutlet.alpha = 0

        creatingView.addConnectingView(vc: self,
                                       description: "Getting Transaction")
        
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
        
        executeNodeCommandSsh(method: BTC_CLI_COMMAND.gettransaction,
                              param: "\"\(txid)\", true")
        
    }
    
    func bumpFee(result: NSDictionary) {
        
        let originalFee = result["origfee"] as! Double
        let newFee = result["fee"] as! Double
        
        self.creatingView.removeConnectingView()
        
        displayAlert(viewController: self,
                     isError: false,
                     message: "Fee bumped from \(originalFee.avoidNotation) to \(newFee.avoidNotation)")
        
    }
    

    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.bumpfee:
                    
                    let result = makeSSHCall.dictToReturn
                    bumpFee(result: result)
                    
                case BTC_CLI_COMMAND.gettransaction:
                    
                    let dict = makeSSHCall.dictToReturn
                    
                    DispatchQueue.main.async {
                        
                        self.textView.text = "\(self.makeSSHCall.dictToReturn)"
                        self.creatingView.removeConnectingView()
                        
                        let replaceable = dict["bip125-replaceable"] as! String
                        
                        if replaceable == "yes" {
                            
                            self.bumpButtonOutlet.alpha = 1
                            
                        }
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                creatingView.removeConnectingView()
                
                displayAlert(viewController: self.navigationController!,
                             isError: true,
                             message: makeSSHCall.errorDescription)
                
            }
            
        }
        
        if ssh != nil {
            
            if ssh.session.isConnected {
                
                makeSSHCall.executeSSHCommand(ssh: ssh,
                                              method: method,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                creatingView.removeConnectingView()
                
                displayAlert(viewController: self.navigationController!,
                             isError: true,
                             message: "SSH not connected")
                
            }
            
        } else {
            
            creatingView.removeConnectingView()
            
            displayAlert(viewController: self.navigationController!,
                         isError: true,
                         message: "SSH not connected")
            
        }
        
    }

}
