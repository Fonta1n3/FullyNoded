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
        creatingView.addConnectingView(vc: self, description: "bumping")
        executeNodeCommand(method: .bumpfee, param: "\"\(txid)\"")
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bumpButtonOutlet.alpha = 0
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        creatingView.addConnectingView(vc: self, description: "getting transaction")
        
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
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                case .bumpfee:
                    if let result = response as? NSDictionary {
                        vc.bumpFee(result: result)
                    }
                case .gettransaction:
                    if let dict = response as? NSDictionary {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.textView.text = "\(dict)"
                            vc.creatingView.removeConnectingView()
                            let replaceable = dict["bip125-replaceable"] as? String ?? ""
                            if replaceable == "yes" {
                                vc.bumpButtonOutlet.alpha = 1
                            }
                        }
                    }
                default:
                    break
                }
            } else {
                vc.creatingView.removeConnectingView()
                displayAlert(viewController: vc, isError: true, message: errorMessage!)
            }
        }
    }
}
