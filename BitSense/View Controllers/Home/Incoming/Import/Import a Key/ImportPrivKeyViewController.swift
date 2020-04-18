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
    @IBOutlet var qrView: UIImageView!
    let qrScanner = QRScanner()
    var isTorchOn = Bool()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
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
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        
        return UIInterfaceOrientationMask.portrait
        
    }
    
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
        
        qrScanner.textField.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        blurView.frame = CGRect(x: view.frame.minX + 10,
                                y: navigationController!.navigationBar.frame.maxY + 10,
                                width: view.frame.width - 20,
                                height: 50)
        
        blurView.layer.cornerRadius = 10
        blurView.clipsToBounds = true
        
        qrScanner.textFieldPlaceholder = "scan QR or type/paste here"
        qrScanner.keepRunning = false
        
        qrScanner.uploadButton.addTarget(self,
                                         action: #selector(self.chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.torchButton.addTarget(self,
                                        action: #selector(toggleTorch),
                                        for: .touchUpInside)
        
        isTorchOn = false
        addScanner()
        getValues()
        
    }
    
    func getValues() {
        
        //To do: create struct for import dict
        let str = ImportStruct(dictionary: dict)
        addToKeypool = str.addToKeyPool
        isInternal = str.isInternal
        timestamp = str.timeStamp
        label = str.label
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        qrScanner.chooseQRCodeFromLibrary()
        
    }
    
    func addShadow(view: UIView) {
        
        view.layer.shadowColor = UIColor.black.cgColor
        
        view.layer.shadowOffset = CGSize(width: 1.5,
                                         height: 1.5)
        
        view.layer.shadowRadius = 1.5
        view.layer.shadowOpacity = 0.5
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        if isTorchOn {
            
            toggleTorch()
            qrScanner.removeScanner()
            
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        qrScanner.textField.removeFromSuperview()
        blurView.removeFromSuperview()
        view.addSubview(blurView)
        blurView.contentView.addSubview(qrScanner.textField)
        
        addBlurView(frame: CGRect(x: view.frame.maxX - 80,
                                  y: qrView.frame.maxY - 80,
                                  width: 70,
                                  height: 70), button: qrScanner.uploadButton)
        
        addBlurView(frame: CGRect(x: 10,
                                  y: qrView.frame.maxY - 80,
                                  width: 70,
                                  height: 70), button: qrScanner.torchButton)
        
    }
    
    @objc func toggleTorch() {
        
        if isTorchOn {
            
            qrScanner.toggleTorch(on: false)
            isTorchOn = false
            
        } else {
            
            qrScanner.toggleTorch(on: true)
            isTorchOn = true
            
        }
        
    }
    
    func addScanner() {
        
        qrScanner.uploadButton.addTarget(self,
                                         action: #selector(chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.keepRunning = false
        qrView.frame = view.frame
        qrScanner.imageView = qrView
        qrScanner.vc = self
        qrScanner.scanQRCode()
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        
    }
    
    func importPublicKey(pubKey: String) {
        
        isAddress = false
        
        let reducer = Reducer()
        
        func getDescriptor() {
            
            let result = reducer.dictToReturn
            
            if reducer.errorBool {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: reducer.errorDescription)
                
            } else {
                
                let descriptor = "\"\(result["descriptor"] as! String)\""
                
                var params = "[{ \"desc\": \(descriptor), \"timestamp\": \(timestamp), \"watchonly\": true, \"label\": \"\(label)\", \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }]"
                
                if isInternal {
                    
                    params = "[{ \"desc\": \(descriptor), \"timestamp\": \(timestamp), \"watchonly\": true, \"keypool\": \(addToKeypool), \"internal\": true }]"
                    
                }
                
                self.executeNodeCommand(method: .importmulti,
                                        param: params)
                
            }
            
        }
        
        let param = "\"combo(\(pubKey))\""
        
        reducer.makeCommand(command: .getdescriptorinfo,
                            param: param,
                            completion: getDescriptor)
        
    }
    
    func parseKey(key: String) {
        
        importedKey = key
        
        qrScanner.textField.resignFirstResponder()
        
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
        
        connectingView.addConnectingView(vc: self,
                                         description: "analyzing descriptor")
        
        let reducer = Reducer()
        
        func getDescriptorInfo() {
            
            if !reducer.errorBool {
                
                let result = reducer.dictToReturn
                let hasprivatekeys = result["hasprivatekeys"] as! Bool
                let isrange = result["isrange"] as! Bool
                let descriptor = result["descriptor"] as! String
                
                if !hasprivatekeys {
                    
                    isWatchOnly = true
                    dict["descriptor"] = descriptor
                    
                } else {
                    
                    isWatchOnly = false
                    let checksum = result["checksum"] as! String
                    let hotDescriptor = desc + "#" + checksum
                    dict["descriptor"] = hotDescriptor
                    
                }
                
                dict["isWatchOnly"] = isWatchOnly
                
                if !isrange {
                    
                    importDescriptor(desc: (dict["descriptor"] as! String))
                    
                } else {
                    
                    displayDescriptorKeys(desc: "\"\(dict["descriptor"] as! String)\"")
                    
                }
                
            } else {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: reducer.errorDescription)
                
            }
            
        }
        
        let des = desc.replacingOccurrences(of: "'", with: "'\"'\"'")
        let param = "\"\(des)\""
        
        reducer.makeCommand(command: .getdescriptorinfo,
                            param: param,
                            completion: getDescriptorInfo)
        
        
    }
    
    func displayDescriptorKeys(desc: String) {
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                keyArray = reducer.arrayToReturn
                
                getKeyInfo(desc: desc,
                           address: keyArray[0] as! String)
                
                
            } else {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: reducer.errorDescription)
                
            }
            
        }
        
        let str = ImportStruct(dictionary: dict)
        let range = str.range
        let convertedRange = convertRange(range: range)
        let method = BTC_CLI_COMMAND.deriveaddresses
        let des = desc.replacingOccurrences(of: "'", with: "'\"'\"'")
        dict["descriptor"] = "\(des)"
        let param = "\(des), ''\(convertedRange)''"
        
        reducer.makeCommand(command: method,
                            param: param,
                            completion: getResult)
        
    }
    
    func getKeyInfo(desc: String, address: String) {
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                let result = reducer.dictToReturn
                isScript = result["isscript"] as! Bool
                
                DispatchQueue.main.async {
                    
                    self.performSegue(withIdentifier: "showDescriptorKeys",
                                      sender: self)
                    
                }
                
            } else {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: reducer.errorDescription)
                
            }
            
        }
        
        let param = "\"\(address)\""
        
        reducer.makeCommand(command: .getaddressinfo,
                            param: param,
                            completion: getResult)
        
    }
    
    func importDescriptor(desc: String) {
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                let result = reducer.arrayToReturn
                let success = (result[0] as! NSDictionary)["success"] as! Bool
                
                if success {
                    
                    connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: "Sucessfully imported the key!")
                    
                } else {
                    
                    let errorDict = (result[0] as! NSDictionary)["error"] as! NSDictionary
                    let error = errorDict["message"] as! String
                    connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: error)
                    
                }
                
                if let warnings = (result[0] as! NSDictionary)["warnings"] as? NSArray {
                    
                    if warnings.count > 0 {
                        
                        for warning in warnings {
                            
                            let warn = warning as! String
                            
                            DispatchQueue.main.async {
                                
                                let alert = UIAlertController(title: "Warning",
                                                              message: warn,
                                                              preferredStyle: UIAlertController.Style.alert)
                                
                                alert.addAction(UIAlertAction(title: "OK",
                                                              style: UIAlertAction.Style.default,
                                                              handler: nil))
                                
                                self.present(alert,
                                             animated: true,
                                             completion: nil)
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: reducer.errorDescription)
                
            }
            
        }
        
        let des = desc.replacingOccurrences(of: "'", with: "'\"'\"'")
        let str = ImportStruct(dictionary: dict)
        isWatchOnly = str.isWatchOnly
        let param = "[{ \"desc\": \"\(des)\", \"label\": \"\(label)\", \"timestamp\": \(timestamp), \"watchonly\": \(isWatchOnly), \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": true}''"
        
        reducer.makeCommand(command: .importmulti,
                            param: param,
                            completion: getResult)
        
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
    
    func getQRCode() {
        
        let stringURL = qrScanner.stringToReturn
        parseKey(key: stringURL)
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        if qrScanner.textField.text != "" {
            
            parseKey(key: qrScanner.textField.text!)
            
        }
        
        return true
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        qrScanner.textField.resignFirstResponder()
        
    }
    
    func didPickImage() {
        
        let qrString = qrScanner.qrString
        parseKey(key: qrString)
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                DispatchQueue.main.async {
                    
                    self.qrScanner.removeFromSuperview()
                    
                }
                
                switch method {
                    
                case .importprivkey:
                    
                    connectingView.removeConnectingView()
                    let result = reducer.stringToReturn
                    
                    if result == "Imported key success" {
                        
                        alertMessage = "Successfully imported private key"
                        
                    }
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "showKeyDetails", sender: self)
                        
                    }
                    
                case .importmulti:
                    
                    let result = reducer.arrayToReturn
                    let success = (result[0] as! NSDictionary)["success"] as! Bool
                    
                    if success {
                        
                        connectingView.removeConnectingView()
                        var messageString = "Sucessfully imported the address"
                        
                        if !isAddress {
                            
                            messageString = "Sucessfully imported the public key and its three address types"
                            
                        }
                        
                        alertMessage = messageString
                        
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "showKeyDetails", sender: self)
                            
                        }
                        
                    } else {
                        
                        let error = ((result[0] as! NSDictionary)["error"] as! NSDictionary)["message"] as! String
                        connectingView.removeConnectingView()
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: error)
                        
                    }
                    
                    if let warnings = (result[0] as! NSDictionary)["warnings"] as? NSArray {
                        
                        if warnings.count > 0 {
                            
                            for warning in warnings {
                                
                                let warn = warning as! String
                                
                                DispatchQueue.main.async {
                                    
                                    let alert = UIAlertController(title: "Warning", message: warn, preferredStyle: UIAlertController.Style.alert)
                                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                                    self.present(alert, animated: true, completion: nil)
                                    
                                }
                                
                            }
                            
                        }
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: reducer.errorDescription)
                    
                }
                
            }
            
        }
        
        reducer.makeCommand(command: method,
                            param: param,
                            completion: getResult)
        
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
        
    }
    
}
