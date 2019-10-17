//
//  TransactionViewController.swift
//  BitSense
//
//  Created by Peter on 22/07/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class TransactionViewController: UIViewController {
    
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
                                       description: "bumping")
        
        executeNodeCommand(method: BTC_CLI_COMMAND.bumpfee,
                              param: "\"\(txid)\"")
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bumpButtonOutlet.alpha = 0

        creatingView.addConnectingView(vc: self,
                                       description: "getting transaction")
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        executeNodeCommand(method: BTC_CLI_COMMAND.gettransaction,
                              param: "\"\(txid)\", true")
        
    }
    
    func bumpFee(result: NSDictionary) {
        
        let originalFee = result["origfee"] as! Double
        let newFee = result["fee"] as! Double
        
        self.creatingView.removeConnectingView()
        
        displayAlert(viewController: self,
                     isError: false,
                     message: "fee bumped from \(originalFee.avoidNotation) to \(newFee.avoidNotation)")
        
    }
    

    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.bumpfee:
                    
                    let result = reducer.dictToReturn
                    bumpFee(result: result)
                    
                case BTC_CLI_COMMAND.gettransaction:
                    
                    let dict = reducer.dictToReturn
                    
                    DispatchQueue.main.async {
                        
                        self.textView.text = "\(reducer.dictToReturn)"
                        self.creatingView.removeConnectingView()
                        let replaceable = dict["bip125-replaceable"] as? String ?? ""
                        
                        if replaceable == "yes" {
                            
                            self.bumpButtonOutlet.alpha = 1
                            
                        }
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                creatingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: reducer.errorDescription)
                
            }
            
        }
        
        reducer.makeCommand(command: method,
                            param: param,
                            completion: getResult)
        
    }

}
