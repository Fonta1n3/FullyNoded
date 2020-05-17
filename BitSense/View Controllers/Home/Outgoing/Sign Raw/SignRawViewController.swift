//
//  SignRawViewController.swift
//  BitSense
//
//  Created by Peter on 05/05/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class SignRawViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
    
    var isTorchOn = Bool()
    var rawTxSigned = ""
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var scannerShowing = false
    var isFirstTime = Bool()
    var blurArray = [UIVisualEffectView]()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let qrGenerator = QRGenerator()
    let scanner = QRScanner()
    let creatingView = ConnectingView()
    let rawDisplayer = RawDisplayer()
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
    
    @IBOutlet var imageView: UIImageView!
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
            
            creatingView.addConnectingView(vc: self,
                                           description: "fetching redeem script")
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.2) {
                    
                    self.scanRedeemScriptOutlet.alpha = 1
                    self.scriptLabel.alpha = 1
                    self.scriptTextView.alpha = 1
                    
                }
                
                self.executeNodeCommand(method: .decoderawtransaction,
                                        param: "\"\(self.unsignedTextView.text!)\"")
                
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
        
        print("signNow")
        
        if !switchOutlet.isOn {
            
            if privateKeyField.text != "" && unsignedTextView.text != "" {
                
                creatingView.addConnectingView(vc: self, description: "signing")
                
                signWithKey(key: privateKeyField.text!,
                            tx: unsignedTextView.text!)
                
            } else if privateKeyField.text == "" && unsignedTextView.text != "" {
                
                creatingView.addConnectingView(vc: self, description: "signing")
                
                executeNodeCommand(method: .signrawtransactionwithwallet,
                                   param: "\"\(unsignedTextView.text!)\"")
                
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
                
                
                
                self.executeNodeCommand(method: .signrawtransactionwithkey,
                                        param: param)
                
            } else if unsignedTextView.text != "" {
                
                creatingView.addConnectingView(vc: self, description: "signing")
                
                self.executeNodeCommand(method: .signrawtransactionwithwallet, param: "\"\(unsignedTextView.text!)\"")
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "you need to fill out all the info")
                
            }
            
        }
        
    }
    
    @IBAction func back(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
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
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        imageView.isUserInteractionEnabled = true
        imageView.alpha = 0
        
        configureScanner()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        if let string = UIPasteboard.general.string {
            
            unsignedTextView.text = string
            showOptionals()
            
        }
        
    }
    
    func configureScanner() {
        
        isFirstTime = true
        
        imageView.alpha = 0
        imageView.frame = view.frame
        imageView.isUserInteractionEnabled = true
        
        scanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary),
                                       for: .touchUpInside)
        
        scanner.keepRunning = true
        scanner.vc = self
        scanner.imageView = imageView
        scanner.textField.alpha = 0
        
        scanner.completion = { self.getQRCode() }
        scanner.didChooseImage = { self.didPickImage() }
        scanner.downSwipeAction = { self.closeScanner() }
        
        scanner.uploadButton.addTarget(self,
                                       action: #selector(self.chooseQRCodeFromLibrary),
                                       for: .touchUpInside)
        
        scanner.torchButton.addTarget(self,
                                      action: #selector(toggleTorch),
                                      for: .touchUpInside)
        
        isTorchOn = false
        
        scanner.closeButton.addTarget(self,
                                      action: #selector(closeScanner),
                                      for: .touchUpInside)
        
    }
    
    func addScannerButtons() {
        
        self.addBlurView(frame: CGRect(x: self.imageView.frame.maxX - 80,
                                       y: self.imageView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.scanner.uploadButton)
        
        self.addBlurView(frame: CGRect(x: 10,
                                       y: self.imageView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.scanner.torchButton)
        
    }
    
    @objc func closeScanner() {
        print("back")
        
        DispatchQueue.main.async {
            
            for blur in self.blurArray{
                
                blur.removeFromSuperview()
                
            }
            
            self.imageView.alpha = 0
            self.scannerShowing = false
            
        }
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        unsignedTextView.resignFirstResponder()
        privateKeyField.resignFirstResponder()
        scriptTextView.resignFirstResponder()
        
    }
    
    func scan() {
        
        scannerShowing = true
        privateKeyField.resignFirstResponder()
        unsignedTextView.resignFirstResponder()
        scriptTextView.resignFirstResponder()
        
        if isFirstTime {
            
            DispatchQueue.main.async {
                
                self.scanner.scanQRCode()
                self.addScannerButtons()
                self.imageView.addSubview(self.scanner.closeButton)
                self.isFirstTime = false
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                })
                
            }
            
        } else {
            
            self.scanner.startScanner()
            self.addScannerButtons()
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                })
                
            }
            
        }
        
    }
    
    func addBlurView(frame: CGRect, button: UIButton) {
        
        button.removeFromSuperview()
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        view.addSubview(blur)
        blurArray.append(blur)
        
    }
    
    func signWithKey(key: String, tx: String) {
        
        let param = "\"\(tx)\", [\"\(key)\"]"
        
        executeNodeCommand(method: .signrawtransactionwithkey,
                           param: param)
        
    }
    
    func getQRCode() {
        
        let stringURL = scanner.stringToReturn
        parseText(text: stringURL)
        closeScanner()
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        scanner.chooseQRCodeFromLibrary()
        
    }
    
    func didPickImage() {
        
        let qrString = scanner.qrString
        parseText(text: qrString)
        closeScanner()
        
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
    
    @objc func toggleTorch() {
        
        if isTorchOn {
            
            scanner.toggleTorch(on: false)
            isTorchOn = false
            
        } else {
            
            scanner.toggleTorch(on: true)
            isTorchOn = true
            
        }
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                switch method {
                    
                case .signrawtransactionwithwallet:
                    
                    let dict = reducer.dictToReturn
                    let complete = dict["complete"] as! Bool
                    
                    if complete {
                        
                        let hex = dict["hex"] as! String
                        creatingView.removeConnectingView()
                        self.showRaw(raw: hex)
                        
                    } else {
                        
                        creatingView.removeConnectingView()
                        let errors = dict["errors"] as! NSArray
                        var errorStrings = [String]()
                        
                        for error in errors {
                            
                            let dic = error as! NSDictionary
                            let str = dic["error"] as! String
                            errorStrings.append(str)
                            
                        }
                        
                        var err = errorStrings.description.replacingOccurrences(of: "]", with: "")
                        err = err.description.replacingOccurrences(of: "[", with: "")
                        
                        if let hex = dict["hex"] as? String {
                            
                            creatingView.removeConnectingView()
                            self.showRaw(raw: hex)
                            
                        }
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: err)
                        
                    }
                    
                case .decoderawtransaction:
                    
                    let txDict = reducer.dictToReturn
                    let vin = txDict["vin"] as! NSArray
                    let vinDict = vin[0] as! NSDictionary
                    self.prevTxID = vinDict["txid"] as! String
                    self.vout = vinDict["vout"] as! Int
                    
                    self.executeNodeCommand(method: .getrawtransaction,
                                            param: "\"\(prevTxID)\", true")
                    
                case .getrawtransaction:
                    
                    let prevTxDict = reducer.dictToReturn
                    let outputs = prevTxDict["vout"] as! NSArray
                    
                    for outputDict in outputs {
                        
                        let output = outputDict as! NSDictionary
                        let index = output["n"] as! Int
                        
                        if index == self.vout {
                            
                            let scriptPubKey = output["scriptPubKey"] as! NSDictionary
                            let addresses = scriptPubKey["addresses"] as! NSArray
                            let spendingFromAddress = addresses[0] as! String
                            scriptSigHex = scriptPubKey["hex"] as! String
                            amount = output["value"] as! Double
                            
                            self.executeNodeCommand(method: .getaddressinfo,
                                                    param: "\"\(spendingFromAddress)\"")
                            
                        }
                        
                    }
                    
                case .getaddressinfo:
                    
                    let result = reducer.dictToReturn
                    
                    if let script = result["hex"] as? String {
                        
                        isWitness = result["iswitness"] as! Bool
                        
                        DispatchQueue.main.async {
                            
                            self.scriptTextView.text = script
                            self.creatingView.removeConnectingView()
                            
                        }
                        
                    } else {
                        
                        DispatchQueue.main.async {
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "unable to fetch the redeem script")
                            
                            self.creatingView.removeConnectingView()
                            
                        }
                        
                    }
                    
                    
                case .signrawtransactionwithkey:
                    
                    let dict = reducer.dictToReturn
                    let complete = dict["complete"] as! Bool
                    
                    if complete {
                        
                        let hex = dict["hex"] as! String
                        self.showRaw(raw: hex)
                        
                        creatingView.removeConnectingView()
                        
                        displayAlert(viewController: self,
                                     isError: false,
                                     message: "Transaction Complete")
                        
                    } else {
                        
                        DispatchQueue.main.async {
                            
                            self.creatingView.removeConnectingView()
                            
                            let errors = dict["errors"] as! NSArray
                            var errorStrings = [String]()
                            
                            for error in errors {
                                
                                let dic = error as! NSDictionary
                                let str = dic["error"] as! String
                                errorStrings.append(str)
                                
                            }
                            
                            var err = errorStrings.description.replacingOccurrences(of: "]", with: "")
                            err = err.description.replacingOccurrences(of: "[", with: "")
                            
                            if self.switchOutlet.isOn {
                                
                                if let hex = dict["hex"] as? String {
                                    
                                    self.showRaw(raw: hex)
                                    
                                    displayAlert(viewController: self,
                                                 isError: true,
                                                 message: err)
                                    
                                } else {
                                    
                                    displayAlert(viewController: self,
                                                 isError: true,
                                                 message: err)
                                    
                                }
                                
                            } else {
                                
                                displayAlert(viewController: self,
                                             isError: true,
                                             message: err)
                                
                            }
                            
                        }
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.creatingView.removeConnectingView()
                    
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
    
    func removeViews() {
        
        DispatchQueue.main.async {
            
            self.unsignOutlet.removeFromSuperview()
            self.pkeyOutlet.removeFromSuperview()
            self.unsignedTextView.removeFromSuperview()
            self.privateKeyField.removeFromSuperview()
            self.scanUnsignedOutlet.removeFromSuperview()
            self.scanPrivKeyOutlet.removeFromSuperview()
            self.scanRedeemScriptOutlet.removeFromSuperview()
            self.scriptLabel.removeFromSuperview()
            self.switchOutlet.removeFromSuperview()
            self.muSigLabel.removeFromSuperview()
            self.scriptTextView.removeFromSuperview()
            
        }
        
    }
    
    func getSmartFee(raw: String) {
        
        let reducer = Reducer()
        
        var dictToReturn = NSDictionary()
        
        func getSmartFee(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !reducer.errorBool {
                    
                    switch method {
                        
                    case .decoderawtransaction:
                        
                        let dict = reducer.dictToReturn
                        let txSize = dict["vsize"] as! Int
                        let outputs = dict["vout"] as! NSArray
                        let inputs = dict["vin"] as! NSArray
                        let outputCount = outputs.count
                        
                        for (i, outputDict) in outputs.enumerated() {
                            
                            let output = outputDict as! NSDictionary
                            amount = output["value"] as! Double
                            self.outputTotalValue += amount
                            
                            if i == outputCount - 1 {
                                
                                self.getInputTotal(inputs: inputs, txSize: txSize)
                                
                            }
                            
                        }
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: reducer.errorDescription)
                    
                }
                
            }
            
            reducer.makeCommand(command: method,
                                param: param,
                                completion: getResult)
            
        }
        
        getSmartFee(method: .decoderawtransaction,
                    param: "\"\(raw)\"")
        
    }
    
    func getInputTotal(inputs: NSArray, txSize: Int) {
        
        let reducer = Reducer()
        
        let feeTarget = UserDefaults.standard.object(forKey: "feeTarget") as! Int
        var inputsCount = inputs.count
        
        func getSmartFee(method: BTC_CLI_COMMAND, param: String, vout: Int) {
            
            func getResult() {
                
                if !reducer.errorBool {
                    
                    switch method {
                        
                    case .estimatesmartfee:
                        
                        let dict = reducer.dictToReturn
                        
                        displayFeeAlert(dict: dict,
                                        vsize: txSize,
                                        feeTarget: feeTarget)
                        
                    case .getrawtransaction:
                        
                        let result = reducer.stringToReturn
                        
                        getSmartFee(method: .decoderawtransaction,
                                    param: "\"\(result)\"", vout: vout)
                        
                    case .decoderawtransaction:
                        
                        let dict = reducer.dictToReturn
                        let outputs = dict["vout"] as! NSArray
                        
                        for outputDict in outputs {
                            
                            let output = outputDict as! NSDictionary
                            let index = output["n"] as! Int
                            
                            if index == vout {
                                
                                self.inputTotalValue += output["value"] as! Double
                                
                                if inputsIndex < inputsCount - 1 {
                                    
                                    inputsIndex += 1
                                    getInputTotal(inputs: inputs, txSize: txSize)
                                    
                                } else if inputsIndex == inputsCount - 1 {
                                    
                                    //finished fetching all input values, can compare optimal fee to actual fee now
                                    getSmartFee(method: BTC_CLI_COMMAND.estimatesmartfee,
                                                param: "\(feeTarget)", vout: vout)
                                    
                                }
                                
                            }
                            
                        }
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: reducer.errorDescription)
                    
                }
                
            }
            
            reducer.makeCommand(command: method,
                                param: param,
                                completion: getResult)
            
        }
        
        let inputDict = inputs[inputsIndex] as! NSDictionary
        let prevTxID = inputDict["txid"] as! String
        let vout = inputDict["vout"] as! Int
        
        getSmartFee(method: BTC_CLI_COMMAND.getrawtransaction,
                    param: "\"\(prevTxID)\"", vout: vout)
        
    }
    
    func displayFeeAlert(dict: NSDictionary, vsize: Int, feeTarget: Int) {
        
        let feeInBTC = self.inputTotalValue - self.outputTotalValue
        let feeInSats = feeInBTC * 100000000
        let txSize = Double(vsize)
        var btcPerKbyte = Double()
        
        if let btcPerKbyteCheck = dict["feerate"] as? Double {
            
            btcPerKbyte = btcPerKbyteCheck
            
        } else {
            
            // node is in regtest, hard coding the feerate
            btcPerKbyte = 0.00000100
            
        }
        
        let btcPerByte = btcPerKbyte / 1000
        let satsPerByte = btcPerByte * 100000000
        let optimalFeeForSixBlocks = satsPerByte * txSize
        let diff = optimalFeeForSixBlocks - feeInSats
        
        if diff < 0 {
            
            //overpaying
            let percentageDifference = Int(((feeInSats / optimalFeeForSixBlocks) * 100) - 100).avoidNotation
            
            DispatchQueue.main.async {
                
                let alert = UIAlertController(title: NSLocalizedString("Fee Alert", comment: ""),
                                              message: "The optimal fee to get this tx included in the next \(feeTarget) blocks is \(Int(optimalFeeForSixBlocks)) satoshis.\n\nYou are currently paying a fee of \(Int(feeInSats)) satoshis which is \(percentageDifference)% higher then necessary.", preferredStyle: UIAlertController.Style.alert)
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""),
                                              style: .default,
                                              handler: { (action) in }))
                
                self.present(alert, animated: true)
                
            }
            
        } else {
            
            //underpaying
            let percentageDifference = Int((((optimalFeeForSixBlocks - feeInSats) / optimalFeeForSixBlocks) * 100)).avoidNotation
            
            DispatchQueue.main.async {
                
                let alert = UIAlertController(title: NSLocalizedString("Fee Alert", comment: ""),
                                              message: "The optimal fee to get this tx included in the next \(feeTarget) blocks is \(Int(optimalFeeForSixBlocks)) satoshis.\n\nYou are currently paying a fee of \(Int(feeInSats)) satoshis which is \(percentageDifference)% lower then necessary.", preferredStyle: UIAlertController.Style.alert)
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""),
                                              style: .default,
                                              handler: { (action) in }))
                
                self.present(alert, animated: true)
                
            }
            
        }
        
    }
    
    func showRaw(raw: String) {
        
        DispatchQueue.main.async {
            
            self.removeViews()
            self.rawDisplayer.rawString = raw
            self.rawTxSigned = raw
            self.rawDisplayer.vc = self
            
            self.tapQRGesture = UITapGestureRecognizer(target: self,
                                                       action: #selector(self.shareQRCode(_:)))
            
            self.rawDisplayer.qrView.addGestureRecognizer(self.tapQRGesture)
            
            self.tapTextViewGesture = UITapGestureRecognizer(target: self,
                                                             action: #selector(self.shareRawText(_:)))
            
            self.rawDisplayer.textView.addGestureRecognizer(self.tapTextViewGesture)
            
            let newView = UIView()
            newView.backgroundColor = self.view.backgroundColor
            newView.frame = self.view.frame
            self.view.addSubview(newView)
            self.scanner.removeFromSuperview()
            self.creatingView.removeConnectingView()
            self.rawDisplayer.addRawDisplay()
            self.getSmartFee(raw: raw)
            
        }
        
    }
    
    @objc func shareQRCode(_ sender: UITapGestureRecognizer) {
        print("shareQRCode")
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.rawDisplayer.qrView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.rawDisplayer.qrView.alpha = 1
                    
                })
                
            }
            
            self.qrGenerator.textInput = self.rawDisplayer.rawString
            let qrImage = self.qrGenerator.getQRCode()
            let objectsToShare = [qrImage]
            
            let activityController = UIActivityViewController(activityItems: objectsToShare,
                                                              applicationActivities: nil)
            
            activityController.popoverPresentationController?.sourceView = self.view
            self.present(activityController, animated: true) {}
            
        }
        
    }
    
    @objc func shareRawText(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.rawDisplayer.textView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.rawDisplayer.textView.alpha = 1
                    
                })
                
            }
            
            let textToShare = [self.rawDisplayer.rawString]
            
            let activityViewController = UIActivityViewController(activityItems: textToShare,
                                                                  applicationActivities: nil)
            
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true) {}
            
        }
        
    }
    
    func showOptionals() {
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2) {
                
                self.switchOutlet.alpha = 1
                self.muSigLabel.alpha = 1
                self.scanPrivKeyOutlet.alpha = 1
                self.privateKeyField.alpha = 1
                self.pkeyOutlet.alpha = 1
                
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
    
}
