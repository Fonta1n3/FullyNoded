//
//  SignRawViewController.swift
//  BitSense
//
//  Created by Peter on 05/05/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class SignRawViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
    
    let creatingView = ConnectingView()
    var scanUnsigned = Bool()
    var scanPrivateKey = Bool()
    var scanScript = Bool()
    var vout = Int()
    var scriptSigHex = ""
    var prevTxID = ""
    var isWitness = Bool()
    var amount = Double()
    var inputsIndex = 0
    var outputTotalValue = Double()
    var inputTotalValue = Double()
    var txn = ""
    var unsignedTxn = ""
    
    @IBOutlet var unsignedTextView: UITextView!
    @IBOutlet var privateKeyField: UITextField!
    @IBOutlet var unsignOutlet: UILabel!
    @IBOutlet var pkeyOutlet: UILabel!
    @IBOutlet var scanUnsignedOutlet: UIButton!
    @IBOutlet var scanPrivKeyOutlet: UIButton!
    @IBOutlet var scanRedeemScriptOutlet: UIButton!
    @IBOutlet var scriptLabel: UILabel!
    @IBOutlet var switchOutlet: UISwitch!
    @IBOutlet var muSigLabel: UILabel!
    @IBOutlet var scriptTextView: UITextView!
    
    @IBAction func switchAction(_ sender: Any) {
        if switchOutlet.isOn {
            creatingView.addConnectingView(vc: self, description: "fetching redeem script")
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.2) {
                    self.scanRedeemScriptOutlet.alpha = 1
                    self.scriptLabel.alpha = 1
                    self.scriptTextView.alpha = 1
                }
                self.executeNodeCommand(method: .decoderawtransaction, param: "\"\(self.unsignedTextView.text!)\"")
            }
            
        } else {
            UIView.animate(withDuration: 0.2) {
                self.scanRedeemScriptOutlet.alpha = 0
                self.scriptLabel.alpha = 0
                self.scriptTextView.alpha = 0
            }
        }
    }
    
    
    @IBAction func scanUnsigned(_ sender: Any) {
        scanUnsigned = true
        scanScript = false
        scanPrivateKey = false
        scan()
    }
    
    @IBAction func scanPrivKey(_ sender: Any) {
        scanUnsigned = false
        scanScript = false
        scanPrivateKey = true
        scan()
    }
    
    @IBAction func scanRedeemScript(_ sender: Any) {
        scanUnsigned = false
        scanScript = true
        scanPrivateKey = false
        scan()
    }
    
    @IBAction func signNow(_ sender: Any) {
        if !switchOutlet.isOn {
            
            if privateKeyField.text != "" && unsignedTextView.text != "" {
                creatingView.addConnectingView(vc: self, description: "signing")
                signWithKey(key: privateKeyField.text!, tx: unsignedTextView.text!)
                
            } else if privateKeyField.text == "" && unsignedTextView.text != "" {
                creatingView.addConnectingView(vc: self, description: "signing")
                executeNodeCommand(method: .signrawtransactionwithwallet, param: "\"\(unsignedTextView.text!)\"")
                
            } else if unsignedTextView.text == "" {
                shakeAlert(viewToShake: unsignedTextView)
                
            }
            
        } else {
            
            //sign multisig
            if privateKeyField.text != "" && unsignedTextView.text != "" && scriptTextView.text != "" {
                creatingView.addConnectingView(vc: self, description: "signing")
                let unsigned = unsignedTextView.text!
                let redeemScript = scriptTextView.text!
                var privateKeys = privateKeyField.text!
                if privateKeys.contains(", ") {
                    //there is more then one, process the array
                    privateKeys = privateKeys.replacingOccurrences(of: ", ", with: "\", \"")
                }
                
                var param = ""
                
                if !isWitness {
                    param = "\"\(unsigned)\", ''[\"\(privateKeys)\"]'', ''[{ \"txid\": \"\(self.prevTxID)\", \"vout\": \(vout), \"scriptPubKey\": \"\(scriptSigHex)\", \"redeemScript\": \"\(redeemScript)\", \"amount\": \(amount) }]''"
                    
                } else {
                    param = "\"\(unsigned)\", ''[\"\(privateKeys)\"]'', ''[{ \"txid\": \"\(self.prevTxID)\", \"vout\": \(vout), \"scriptPubKey\": \"\(scriptSigHex)\", \"witnessScript\": \"\(redeemScript)\", \"amount\": \(amount) }]''"
                    
                }
                self.executeNodeCommand(method: .signrawtransactionwithkey, param: param)
                
            } else if unsignedTextView.text != "" {
                creatingView.addConnectingView(vc: self, description: "signing")
                self.executeNodeCommand(method: .signrawtransactionwithwallet, param: "\"\(unsignedTextView.text!)\"")
                
            } else {
                displayAlert(viewController: self, isError: true, message: "you need to fill out all the info")
                
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scriptLabel.alpha = 0
        scanRedeemScriptOutlet.alpha = 0
        scriptTextView.alpha = 0
        switchOutlet.alpha = 0
        muSigLabel.alpha = 0
        scanPrivKeyOutlet.alpha = 0
        privateKeyField.alpha = 0
        pkeyOutlet.alpha = 0
        
        scriptTextView.delegate = self
        privateKeyField.delegate = self
        unsignedTextView.delegate = self
        
        unsignedTextView.clipsToBounds = true
        unsignedTextView.layer.cornerRadius = 8
        unsignedTextView.layer.borderWidth = 1.0
        unsignedTextView.layer.borderColor = UIColor.darkGray.cgColor
        
        scriptTextView.clipsToBounds = true
        scriptTextView.layer.cornerRadius = 8
        scriptTextView.layer.borderWidth = 1.0
        scriptTextView.layer.borderColor = UIColor.darkGray.cgColor
        
        switchOutlet.isOn = false
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let string = UIPasteboard.general.string {
            unsignedTextView.text = string
            showOptionals()
        }
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        unsignedTextView.resignFirstResponder()
        privateKeyField.resignFirstResponder()
        scriptTextView.resignFirstResponder()
    }
    
    func scan() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToScannerFromTxSigner", sender: vc)
        }
    }
    
    func signWithKey(key: String, tx: String) {
        let param = "\"\(tx)\", [\"\(key)\"]"
        executeNodeCommand(method: .signrawtransactionwithkey, param: param)
    }
    
    func parseText(text: String) {
        
        if scanPrivateKey {
            
            DispatchQueue.main.async {
                
                if self.privateKeyField.text != "" {
                    
                    self.privateKeyField.text! += ", \(text)"
                    
                } else {
                    
                    self.privateKeyField.text = text
                    
                }
                
            }
            
        } else if scanScript {
            
            DispatchQueue.main.async {
                
                self.scriptTextView.text = text
                
            }
            
            
        } else if scanUnsigned {
            
            DispatchQueue.main.async {
                
                self.unsignedTextView.text = text
                self.showOptionals()
                
            }
            
        }
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                    
                case .signrawtransactionwithwallet:
                    if let dict = response as? NSDictionary {
                        let complete = dict["complete"] as! Bool
                        if complete {
                            let hex = dict["hex"] as! String
                            vc.creatingView.removeConnectingView()
                            vc.txn = hex
                            self.showRaw()
                            
                        } else if !complete {
                            let hex = dict["hex"] as! String
                            vc.unsignedTxn = hex
                            self.showRaw()
                            vc.creatingView.removeConnectingView()
                            
                        } else if let errors = dict["errors"] as? NSArray {
                            vc.creatingView.removeConnectingView()
                            var errorStrings = [String]()
                            for error in errors {
                                let dic = error as! NSDictionary
                                let str = dic["error"] as! String
                                errorStrings.append(str)
                            }
                            var err = errorStrings.description.replacingOccurrences(of: "]", with: "")
                            err = err.description.replacingOccurrences(of: "[", with: "")
                            displayAlert(viewController: vc, isError: true, message: err)
                        }
                    }
                    
                case .decoderawtransaction:
                    if let txDict = response as? NSDictionary {
                        let vin = txDict["vin"] as! NSArray
                        let vinDict = vin[0] as! NSDictionary
                        vc.prevTxID = vinDict["txid"] as! String
                        vc.vout = vinDict["vout"] as! Int
                        vc.executeNodeCommand(method: .getrawtransaction, param: "\"\(vc.prevTxID)\", true")
                    }
                    
                case .getrawtransaction:
                    if let prevTxDict = response as? NSDictionary {
                        let outputs = prevTxDict["vout"] as! NSArray
                        for outputDict in outputs {
                            let output = outputDict as! NSDictionary
                            let index = output["n"] as! Int
                            if index == vc.vout {
                                let scriptPubKey = output["scriptPubKey"] as! NSDictionary
                                let addresses = scriptPubKey["addresses"] as! NSArray
                                let spendingFromAddress = addresses[0] as! String
                                vc.scriptSigHex = scriptPubKey["hex"] as! String
                                vc.amount = output["value"] as! Double
                                vc.executeNodeCommand(method: .getaddressinfo, param: "\"\(spendingFromAddress)\"")
                            }
                        }
                    }
                    
                case .getaddressinfo:
                    if let result = response as? NSDictionary {
                        if let script = result["hex"] as? String {
                            vc.isWitness = result["iswitness"] as! Bool
                            DispatchQueue.main.async {
                                self.scriptTextView.text = script
                                self.creatingView.removeConnectingView()
                            }
                        } else {
                            DispatchQueue.main.async { [unowned vc = self] in
                                displayAlert(viewController: vc, isError: true, message: "unable to fetch the redeem script")
                                vc.creatingView.removeConnectingView()
                            }
                        }
                    }
                    
                case .signrawtransactionwithkey:
                    if let dict = response as? NSDictionary {
                        let complete = dict["complete"] as! Bool
                        if complete {
                            let hex = dict["hex"] as! String
                            vc.txn = hex
                            vc.showRaw()
                            vc.creatingView.removeConnectingView()
                            
                        } else if let errors = dict["errors"] as? NSArray {
                                vc.creatingView.removeConnectingView()
                                var errorStrings = [String]()
                                for error in errors {
                                    let dic = error as! NSDictionary
                                    let str = dic["error"] as! String
                                    errorStrings.append(str)
                                }
                                var err = errorStrings.description.replacingOccurrences(of: "]", with: "")
                                err = err.description.replacingOccurrences(of: "[", with: "")
                                displayAlert(viewController: vc, isError: true, message: err)
                            
                        } else {
                            if let hex = dict["hex"] as? String {
                                vc.creatingView.removeConnectingView()
                                vc.unsignedTxn = hex
                                vc.showRaw()
                            }
                        }
                    }
                default:
                    break
                }
            } else {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.creatingView.removeConnectingView()
                    displayAlert(viewController: vc, isError: true, message: errorMessage ?? "")
                }
            }
        }
    }
    
    func showRaw() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToBroadcastFromTxSigner", sender: vc)
        }
    }
    
    func showOptionals() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.2) { [unowned vc = self] in
                vc.switchOutlet.alpha = 1
                vc.muSigLabel.alpha = 1
                vc.scanPrivKeyOutlet.alpha = 1
                vc.privateKeyField.alpha = 1
                vc.pkeyOutlet.alpha = 1
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        textField.endEditing(true)
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        if textField.text != "" {
            
            textField.becomeFirstResponder()
            
        } else {
            
            if let string = UIPasteboard.general.string {
                
                textField.resignFirstResponder()
                textField.text = string
                
            } else {
                
                textField.becomeFirstResponder()
                
            }
            
        }
        
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        if textView.text != "" {
            
            textView.becomeFirstResponder()
            
        } else {
            
            if let string = UIPasteboard.general.string {
                
                textView.resignFirstResponder()
                textView.text = string
                
                if textView == self.unsignedTextView {
                    
                    showOptionals()
                    
                }
                
            } else {
                
                textView.becomeFirstResponder()
                
            }
            
        }
        
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        
        if textView == self.unsignedTextView {
            
            showOptionals()
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToScannerFromTxSigner" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isScanningAddress = true
                vc.onAddressDoneBlock = { text in
                    if text != nil {
                        self.parseText(text: text!)
                    }
                }
            }
        } else if segue.identifier == "segueToBroadcastFromTxSigner" {
            if let vc = segue.destination as? SignerViewController {
                vc.txn = self.txn
                vc.txnUnsigned = self.unsignedTxn
            }
        }
    }
    
}
