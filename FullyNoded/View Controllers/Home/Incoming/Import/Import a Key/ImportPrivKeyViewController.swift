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
    var isDescriptor = Bool()
    var addToKeypool = Bool()
    var isInternal = Bool()
    var reScan = Bool()
    var importedKey = ""
    var label = ""
    var timestamp = Int()
    var dict = [String:Any]()
    var alertMessage = ""
    var isWatchOnly = Bool()
    var keyArray = NSArray()
    var isScript = Bool()
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
        addToKeypool = str.addToKeyPool
        isInternal = str.isInternal
        timestamp = str.timeStamp
        label = str.label
        
    }
    
    func importPublicKey(pubKey: String) {
        isAddress = false
        let param = "\"combo(\(pubKey))\""
        Reducer.makeCommand(command: .getdescriptorinfo, param: param) { [unowned vc = self] (response, errorMessage) in
            if let result = response as? NSDictionary {
                let descriptor = "\"\(result["descriptor"] as! String)\""
                var params = "[{ \"desc\": \(descriptor), \"timestamp\": \(vc.timestamp), \"watchonly\": true, \"label\": \"\(vc.label)\", \"keypool\": \(vc.addToKeypool), \"internal\": \(vc.isInternal) }]"
                if vc.isInternal {
                    params = "[{ \"desc\": \(descriptor), \"timestamp\": \(vc.timestamp), \"watchonly\": true, \"keypool\": \(vc.addToKeypool), \"internal\": true }]"
                }
                vc.executeNodeCommand(method: .importmulti, param: params)
            } else {
                vc.connectingView.removeConnectingView()
                displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
            }
        }
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
        
        if isDescriptor {
            
            analyzeDescriptor(desc: key)
            
        } else {
            
            if key != "" {
                
                var prefix = key.lowercased()
                
                prefix = prefix.replacingOccurrences(of: "bitcoin:",
                                                     with: "")
                
                switch prefix {
                    
                case _ where prefix.hasPrefix("l"),
                     _ where prefix.hasPrefix("5"),
                     _ where prefix.hasPrefix("9"),
                     _ where prefix.hasPrefix("c"),
                     _ where prefix.hasPrefix("k"):
                    
                    DispatchQueue.main.async {
                        
                        self.connectingView.addConnectingView(vc: self,
                                                              description: "Importing Private Key")
                        
                    }
                    
                    let param = "\"\(key)\", \"\(label)\", false"
                    
                    self.executeNodeCommand(method: .importprivkey,
                                            param: param)
                    
                case _ where prefix.hasPrefix("1"),
                     _ where prefix.hasPrefix("3"),
                     _ where prefix.hasPrefix("tb1"),
                     _ where prefix.hasPrefix("bc1"),
                     _ where prefix.hasPrefix("2"),
                     _ where prefix.hasPrefix("n"),
                     _ where prefix.hasPrefix("bcr"),
                     _ where prefix.hasPrefix("m"):
                    
                    DispatchQueue.main.async {
                        
                        self.connectingView.addConnectingView(vc: self,
                                                              description: "Importing Address")
                        
                    }
                    
                    var param = "[{ \"scriptPubKey\": { \"address\": \"\(key)\" }, \"label\": \"\(label)\", \"timestamp\": \(timestamp), \"watchonly\": true, \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": true}''"
                    
                    if isInternal {
                        
                        param = "[{ \"scriptPubKey\": { \"address\": \"\(key)\" }, \"timestamp\": \(timestamp), \"watchonly\": true, \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": true}''"
                        
                    }
                                        
                    isAddress = true
                    
                    self.executeNodeCommand(method: .importmulti,
                                            param: param)
                    
                case _ where prefix.hasPrefix("0"):
                    
                    DispatchQueue.main.async {
                        
                        self.connectingView.addConnectingView(vc: self,
                                                              description: "Importing Public Key")
                        
                    }
                    
                    importPublicKey(pubKey: prefix)
                    
                default:
                    
                    showError()
                    
                }
                
            } else {
                
                showError()
                
            }
            
        }
        
    }
    
    func analyzeDescriptor(desc: String) {
        connectingView.addConnectingView(vc: self, description: "analyzing descriptor")
        let des = desc.replacingOccurrences(of: "'", with: "'\"'\"'")
        let param = "\"\(des)\""
        Reducer.makeCommand(command: .getdescriptorinfo, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                if let result = response as? NSDictionary {
                    let hasprivatekeys = result["hasprivatekeys"] as! Bool
                    let isrange = result["isrange"] as! Bool
                    let descriptor = result["descriptor"] as! String
                    if !hasprivatekeys {
                        vc.isWatchOnly = true
                        vc.dict["descriptor"] = descriptor
                    } else {
                        vc.isWatchOnly = false
                        let checksum = result["checksum"] as! String
                        let hotDescriptor = desc + "#" + checksum
                        vc.dict["descriptor"] = hotDescriptor
                    }
                    vc.dict["isWatchOnly"] = vc.isWatchOnly
                    if !isrange {
                        vc.importDescriptor(desc: (vc.dict["descriptor"] as! String))
                    } else {
                        vc.displayDescriptorKeys(desc: "\"\(vc.dict["descriptor"] as! String)\"")
                    }
                }
            } else {
                vc.connectingView.removeConnectingView()
                displayAlert(viewController: self, isError: true, message: errorMessage!)
            }
        }
    }
    
    func displayDescriptorKeys(desc: String) {
        let str = ImportStruct(dictionary: dict)
        let range = str.range
        let convertedRange = convertRange(range: range)
        let des = desc.replacingOccurrences(of: "'", with: "'\"'\"'")
        dict["descriptor"] = "\(des)"
        let param = "\(des), ''\(convertedRange)''"
        Reducer.makeCommand(command: .deriveaddresses, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                if let result = response as? NSArray {
                    vc.keyArray = result
                    vc.getKeyInfo(desc: desc, address: vc.keyArray[0] as! String)
                }
            } else {
                vc.connectingView.removeConnectingView()
                displayAlert(viewController: vc, isError: true, message: errorMessage!)
            }
        }
    }
    
    func getKeyInfo(desc: String, address: String) {
        let param = "\"\(address)\""
        Reducer.makeCommand(command: .getaddressinfo, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                if let result = response as? NSDictionary {
                    vc.isScript = result["isscript"] as! Bool
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.performSegue(withIdentifier: "showDescriptorKeys",sender: vc)
                    }
                }
            } else {
                vc.connectingView.removeConnectingView()
                displayAlert(viewController: vc, isError: true, message: errorMessage!)
            }
        }
    }
    
    func importDescriptor(desc: String) {
        let des = desc.replacingOccurrences(of: "'", with: "'\"'\"'")
        let str = ImportStruct(dictionary: dict)
        isWatchOnly = str.isWatchOnly
        let param = "[{ \"desc\": \"\(des)\", \"label\": \"\(label)\", \"timestamp\": \(timestamp), \"watchonly\": \(isWatchOnly), \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": true}''"
        Reducer.makeCommand(command: .importmulti, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                if let result = response as? NSArray {
                    let success = (result[0] as! NSDictionary)["success"] as! Bool
                    if success {
                        vc.connectingView.removeConnectingView()
                        displayAlert(viewController: self, isError: false, message: "Sucessfully imported the key!")
                    } else {
                        let errorDict = (result[0] as! NSDictionary)["error"] as! NSDictionary
                        let error = errorDict["message"] as! String
                        vc.connectingView.removeConnectingView()
                        displayAlert(viewController: vc, isError: true, message: error)
                    }
                    if let warnings = (result[0] as! NSDictionary)["warnings"] as? NSArray {
                        if warnings.count > 0 {
                            for warning in warnings {
                                let warn = warning as! String
                                DispatchQueue.main.async { [unowned vc = self] in
                                    let alert = UIAlertController(title: "Warning",message: warn, preferredStyle: .alert)
                                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                    vc.present(alert, animated: true, completion: nil)
                                }
                            }
                        }
                    }
                }
            } else {
                vc.connectingView.removeConnectingView()
                displayAlert(viewController: vc, isError: true, message: errorMessage!)
            }
        }
    }
    
    func convertRange(range: String) -> [Int] {
        
        var arrayToReturn = [Int]()
        let newrange = range.replacingOccurrences(of: " ", with: "")
        let rangeArray = newrange.components(separatedBy: "to")
        let zero = Int(rangeArray[0])!
        let one = Int(rangeArray[1])!
        arrayToReturn = [zero,one]
        dict["convertedRange"] = arrayToReturn
        return arrayToReturn
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                case .importprivkey:
                    vc.connectingView.removeConnectingView()
                    if let result = response as? String {
                        if result == "Imported key success" {
                            vc.alertMessage = "Successfully imported private key"
                        }
                        DispatchQueue.main.async {
                            vc.performSegue(withIdentifier: "showKeyDetails", sender: vc)
                        }
                    }
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
                    displayAlert(viewController: vc, isError: true, message: errorMessage!)
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showKeyDetails" {
            
            if let vc = segue.destination as? GetInfoViewController {
                
                vc.labelToSearch = label
                vc.getaddressesbylabel = true
                vc.alertMessage = alertMessage
                
            }
            
        }
        
        if segue.identifier == "showDescriptorKeys" {
            
            if let vc = segue.destination as? ImportExtendedKeysViewController {
                
                vc.dict = dict
                vc.keyArray = keyArray
                vc.isHDMusig = isScript
                
            }
            
        }
        
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
