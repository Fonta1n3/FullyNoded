//
//  ImportPrivKeyViewController.swift
//  BitSense
//
//  Created by Peter on 23/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ImportPrivKeyViewController: UIViewController, UITextFieldDelegate {
    
    var isPruned = Bool()
    let connectingView = ConnectingView()
    var isAddress = false
    var importedKey = ""
    var label = ""
    var dict = [String:Any]()
    var alertMessage = ""
    var isWatchOnly = Bool()
    @IBOutlet weak var nextButtonOutlet: UIButton!
    @IBOutlet weak var textField: UITextField!
    
   func addBlurView(frame: CGRect, button: UIButton) {
        
        button.removeFromSuperview()
        let blur = UIVisualEffectView()
        blur.effect = UIBlurEffect(style: UIBlurEffect.Style.dark)
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        view.addSubview(blur)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textField.delegate = self
        nextButtonOutlet.layer.cornerRadius = 8
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        getValues()
    }
    
    
    @IBAction func scanQrAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToScanPrivKey", sender: self)
        }
    }
    
    @IBAction func nextAction(_ sender: Any) {
        guard let key = textField.text, key != "" else { return }
        
        parseKey(key: key)
    }
    
    @objc func dismissKeyboard(_ sender: Any) {
        textField.resignFirstResponder()
    }
    
    func getValues() {
        //To do: create struct for import dict
        let str = ImportStruct(dictionary: dict)
        label = str.label
    }
    
    func parseKey(key: String) {
        
        importedKey = key
        
        func showError() {
            DispatchQueue.main.async {
                self.connectingView.removeConnectingView()
                displayAlert(viewController: self,
                             isError: true,
                             message: "Invalid key!")
            }
        }
        
        if key != "" {
            var prefix = key.lowercased()
            
            prefix = prefix.replacingOccurrences(of: "bitcoin:", with: "")
            
            switch prefix {
            case _ where prefix.hasPrefix("l"),
                 _ where prefix.hasPrefix("5"),
                 _ where prefix.hasPrefix("9"),
                 _ where prefix.hasPrefix("c"),
                 _ where prefix.hasPrefix("k"):
                
                DispatchQueue.main.async {
                    self.connectingView.addConnectingView(vc: self, description: "Importing Private Key")
                }
                
                let param = "\"\(key)\", \"\(label)\", false"
                
                self.executeNodeCommand(method: .importprivkey, param: param)
                
            case _ where prefix.hasPrefix("1"),
                 _ where prefix.hasPrefix("3"),
                 _ where prefix.hasPrefix("tb1"),
                 _ where prefix.hasPrefix("bc1"),
                 _ where prefix.hasPrefix("2"),
                 _ where prefix.hasPrefix("n"),
                 _ where prefix.hasPrefix("bcr"),
                 _ where prefix.hasPrefix("m"):
                
                DispatchQueue.main.async {
                    self.connectingView.addConnectingView(vc: self, description: "Importing Address")
                }
                
                let param = "[{ \"scriptPubKey\": { \"address\": \"\(key)\" }, \"label\": \"\(label)\", \"timestamp\": \"\now\", \"watchonly\": true, \"keypool\": false, \"internal\": false }], ''{\"rescan\": false}''"
                
                isAddress = true
                
                self.executeNodeCommand(method: .importmulti, param: param)
                
            default:
                showError()
            }
            
        } else {
            showError()
        }
    }
    
    
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                case .importprivkey:
                    vc.connectingView.removeConnectingView()
                    Reducer.makeCommand(command: .rescanblockchain, param: "") { (_, _) in }
                    DispatchQueue.main.async {
                        self.navigationController?.popToRootViewController(animated: true)
                    }
                    showAlert(vc: self, title: "Private key swept!", message: "Your node is rescanning the blockchain to detect historic transactions, your balance will not show until this process completes. It can take up to an hour for a non pruned node.")
                case .importmulti:
                    if let result = response as? NSArray {
                        let success = (result[0] as! NSDictionary)["success"] as! Bool
                        if success {
                            vc.connectingView.removeConnectingView()
                            var messageString = "Sucessfully imported the address"
                            if !vc.isAddress {
                                messageString = "Sucessfully imported the public key and its three address types"
                            }
                            vc.alertMessage = messageString
                            DispatchQueue.main.async { [unowned vc = self] in
                                vc.performSegue(withIdentifier: "showKeyDetails", sender: vc)
                            }
                        } else {
                            let error = ((result[0] as! NSDictionary)["error"] as! NSDictionary)["message"] as! String
                            vc.connectingView.removeConnectingView()
                            displayAlert(viewController: self, isError: true, message: error)
                        }
                        
                        if let warnings = (result[0] as! NSDictionary)["warnings"] as? NSArray {
                            if warnings.count > 0 {
                                for warning in warnings {
                                    let warn = warning as! String
                                    DispatchQueue.main.async { [unowned vc = self] in
                                        let alert = UIAlertController(title: "Warning", message: warn, preferredStyle: .alert)
                                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                        vc.present(alert, animated: true, completion: nil)
                                    }
                                }
                            }
                        }
                    }
                default:
                    break
                }
            } else {
                DispatchQueue.main.async {
                    vc.connectingView.removeConnectingView()
                    
                    guard var errorMess = errorMessage else { return }
                    
                    if errorMess.contains("private keys disabled") {
                        errorMess = "You are better of using your nodes default wallet for sweeping private keys:\n\nadvanced > bitcoin core wallets > toggle on the default wallet and try again\n\nIt is recommended to send all funds from swept private keys to a FN wallet"
                        self.navigationController?.popToRootViewController(animated: true)
                    }
                    
                    showAlert(vc: self, title: "", message: errorMess)
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToScanPrivKey" {
            guard let vc = segue.destination as? QRScannerViewController else { return }
            
            vc.isScanningAddress = true
            vc.onAddressDoneBlock = { [weak self] key in
                guard let self = self, let key = key else { return }
                
                self.parseKey(key: key)
            }
        }
    }
}
