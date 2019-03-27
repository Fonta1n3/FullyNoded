//
//  CreateRawTxViewController.swift
//  BitSense
//
//  Created by Peter on 09/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftKeychainWrapper
import AES256CBC
import EFQRCode

class CreateRawTxViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {
    
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var qrCode = UIImage()
    var ssh:SSHService!
    var isUsingSSH = Bool()
    let pushButton = UIButton()
    let decodeButton = UIButton()
    var spendable = Double()
    var inputArray = [Any]()
    var changeAmount = Double()
    var rawTxUnsigned = String()
    var rawTxSigned = String()
    var amountAvailable = Double()
    var spendableUtxos = [NSDictionary]()
    var changeAddress = String()
    var utxoTxId = String()
    var utxoVout = Int()
    let addressInput = UITextField()
    let amountInput = UITextField()
    let qrImageView = UIImageView()
    let uploadButton = UIButton()
    let imageImportView = UIImageView()
    let avCaptureSession = AVCaptureSession()
    let imagePicker = UIImagePickerController()
    var stringURL = String()
    var address = String()
    let titleLabel = UILabel()
    let nextButton = UIButton()
    var amount = String()
    var inputs = ""
    let sweepButtonView = Bundle.main.loadNibNamed("KeyPadButtonView", owner: self, options: nil)?.first as! UIView?
    var sweep = Bool()
    @IBOutlet var displayQrView: UIImageView!
    @IBOutlet var textView: UITextView!
    
    @IBAction func backAction(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    /*enum BTC_CLI_COMMAND: String {
        case decoderawtransaction = "decoderawtransaction"
        case getnewaddress = "getnewaddress"
        case gettransaction = "gettransaction"
        case sendrawtransaction = "sendrawtransaction"
        case signrawtransaction = "signrawtransactionwithwallet"
        case createrawtransaction = "createrawtransaction"
        case getrawchangeaddress = "getrawchangeaddress"
        case getaccountaddress = "getaddressesbyaccount"
        case getwalletinfo = "getwalletinfo"
        case getblockchaininfo = "getblockchaininfo"
        case getbalance = "getbalance"
        case getunconfirmedbalance = "getunconfirmedbalance"
        case listaccounts = "listaccounts"
        case listreceivedbyaccount = "listreceivedbyaccount"
        case listreceivedbyaddress = "listreceivedbyaddress"
        case listtransactions = "listtransactions"
        case listunspent = "listunspent"
        case bumpfee = "bumpfee"
    }*/
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("CreateRawTxViewController")
        
        displayQrView.alpha = 0
        textView.alpha = 0
        
        textView.textColor = UIColor.white
        textView.textAlignment = .natural
        textView.font = UIFont.init(name: "HelveticaNeue-Light", size: 14)
        textView.adjustsFontForContentSizeCategory = true
        
        decodeButton.setTitle("Decode", for: .normal)
        decodeButton.setTitleColor(UIColor.white, for: .normal)
        decodeButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Bold", size: 20)
        decodeButton.titleLabel?.textAlignment = .right
        decodeButton.addTarget(self, action: #selector(decode), for: .touchUpInside)
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        addressInput.delegate = self
        amountInput.delegate = self
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        NotificationCenter.default.addObserver(self, selector: #selector(sweepButtonClicked), name: NSNotification.Name(rawValue: "buttonClickedNotification"), object: nil)
        getAddress()
    }
    
    @objc func sweepButtonClicked() {
        
        print("sweep button clicked")
        sweep = true
        self.view.endEditing(true)
        
    }
    
    func processBIP21(url: String) {
        print("processBIP21: \(url)")
        
        func getaddress(processedKey: String) {
            print("getaddress: \(processedKey)")
            
            //if processedKey.hasPrefix("1") || processedKey.hasPrefix("3") || processedKey.hasPrefix("bc") || processedKey.hasPrefix("2") || processedKey.hasPrefix("m") || processedKey.hasPrefix("tb") || processedKey.hasPrefix("2") {
                
                self.address = processedKey
                print("recipient address = \(self.address)")
                self.addressInput.removeFromSuperview()
                self.imageImportView.removeFromSuperview()
                self.qrImageView.removeFromSuperview()
                self.uploadButton.removeFromSuperview()
                
                if self.amount != "" {
                    DispatchQueue.main.async {
                        self.amountInput.text = self.amount
                    }
                }
                
                self.titleLabel.text = ""
                self.amountInput.placeholder = "Amount in BTC"
                self.amountInput.keyboardType = UIKeyboardType.decimalPad
                self.amountInput.frame = CGRect(x: self.view.frame.minX + 25, y: 150, width: self.view.frame.width - 50, height: 50)
                self.amountInput.textAlignment = .center
                self.amountInput.borderStyle = .roundedRect
                self.amountInput.autocorrectionType = .no
                self.amountInput.autocapitalizationType = .none
                self.amountInput.keyboardAppearance = UIKeyboardAppearance.dark
                self.amountInput.backgroundColor = UIColor.groupTableViewBackground
                self.amountInput.returnKeyType = UIReturnKeyType.go
                self.amountInput.becomeFirstResponder()
                self.amountInput.inputAccessoryView = sweepButtonView
                self.view.addSubview(self.amountInput)
                self.addNextButton(inputView: self.amountInput)
            /*} else {
                
                //displayAlert(viewController: self, title: "Error", message: "Thats not a valid Bitcoin Address")
                
            }*/

        }
        
        var address = url
        
        //format bip21
        if address.contains("bitcoin:") || address.contains("?") || address.contains("=") {
            
            if address.hasPrefix(" ") {
                
                address = address.replacingOccurrences(of: " ", with: "")
                //getaddress(processedKey: address)
            }
            
            if address.contains("?") {
                
                let formatArray = address.split(separator: "?")
                print("formatArray = \(formatArray)")
                self.address = formatArray[0].replacingOccurrences(of: "bitcoin:", with: "")
                
                
                if formatArray[1].contains("amount=") && formatArray[1].contains("&") {
                    
                    //get rid of other parameters but has amount
                    let array = formatArray[1].split(separator: "&")
                    self.amount = array[0].replacingOccurrences(of: "amount=", with: "")
                    
                    
                } else if formatArray[1].contains("amount=") {
                    
                    //just amount parameter present
                    self.amount = formatArray[1].replacingOccurrences(of: "amount=", with: "")
                    
                } else {
                    
                    //has no amount but does have other parameters
                    //getaddress(processedKey: address)
                }
                
                getaddress(processedKey: self.address)
                
            } else {
                
                //has no amount or other parameters
                getaddress(processedKey: address)
            }
            
        } else {
            //normal address
            getaddress(processedKey: address)
        }
        
    }
    
    /*func pushRawTx() {
        
        DispatchQueue.main.async {
            self.ssh.executeStringResponse(command: BTC_COMMAND.sendrawtransaction, params: "\"\(self.rawTxSigned)\"", response: { (result, error) in
                if error != nil {
                    print("error sendrawtransaction = \(String(describing: error))")
                } else {
                    print("result = \(String(describing: result))")
                    
                    if let txID = result as? String {
                        
                        DispatchQueue.main.async {
                            
                            UIPasteboard.general.string = txID
                            
                            self.sentAnimation()
                            
                            let alert = UIAlertController(title: NSLocalizedString("Success", comment: ""), message: "ID copied to clipboard", preferredStyle: UIAlertControllerStyle.actionSheet)
                            
                            alert.addAction(UIAlertAction(title: NSLocalizedString("Done", comment: ""), style: .cancel, handler: { (action) in
                                self.dismiss(animated: true, completion: nil)
                            }))
                            
                            alert.popoverPresentationController?.sourceView = self.view
                            
                            self.present(alert, animated: true) {
                            }
                        }
                        
                    } else {
                        displayAlert(viewController: self, title: "Error", message: "Unable to parse Transaction ID.")
                    }
                }
            })
        }
        
    }*/
    
    /*@objc func push() {
        
        if !self.isUsingSSH {
            self.executeNodeCommand(method: BTC_CLI_COMMAND.sendrawtransaction.rawValue, param: "\"\(self.rawTxSigned)\"")
        } else {
            pushRawTx()
        }
    }*/
    
    func decodeRawTransaction() {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            self.ssh.execute(command: BTC_CLI_COMMAND.decoderawtransaction, params: "\"\(self.rawTxSigned)\"", response: { (result, error) in
                if error != nil {
                    print("error decoderawtransaction = \(String(describing: error))")
                } else {
                    print("result = \(String(describing: result))")
                    
                    if let decodedTx = result as? NSDictionary {
                        DispatchQueue.main.async {
                            self.textView.text = "\(decodedTx)"
                            self.decodeButton.setTitle("Encode", for: .normal)
                            self.decodeButton.removeTarget(self, action: #selector(self.decode), for: .touchUpInside)
                            self.decodeButton.addTarget(self, action: #selector(self.encodeText), for: .touchUpInside)
                        }
                    }
                }
            })
        }
        
        
    }
    
    @objc func decode() {
        
        if !self.isUsingSSH {
            
            self.executeNodeCommand(method: BTC_CLI_COMMAND.decoderawtransaction.rawValue, param: "\"\(self.rawTxSigned)\"")
            
        } else {
            
            self.decodeRawTransaction()
        }
        
    }
    
    @objc func encodeText() {
        print("encodeText")
        
        DispatchQueue.main.async {
            
            self.textView.text = self.rawTxSigned
            self.decodeButton.setTitle("Decode", for: .normal)
            self.decodeButton.removeTarget(self, action: #selector(self.encodeText), for: .touchUpInside)
            self.decodeButton.addTarget(self, action: #selector(self.decode), for: .touchUpInside)
            
        }
        
    }
    
    func sentAnimation() {
        self.decodeButton.removeFromSuperview()
        //self.pushButton.removeFromSuperview()
        self.textView.removeFromSuperview()
        self.titleLabel.removeFromSuperview()
        let imageView = UIImageView()
        imageView.frame = CGRect(x: self.view.center.x - 95, y: (self.view.center.y - 95) - (self.view.frame.height / 5), width: 190, height: 190)
        imageView.image = UIImage(named: "whiteCheck")
        imageView.alpha = 0
        self.view.addSubview(imageView)
        
        imageView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        
        UIView.animate(withDuration: 2.0, delay: 0, usingSpringWithDamping: CGFloat(0.20), initialSpringVelocity: CGFloat(6.0), options: UIViewAnimationOptions.allowUserInteraction, animations: {
            
            imageView.alpha = 1
            imageView.transform = CGAffineTransform.identity
            
        })
    }
    
    override func viewDidLayoutSubviews() {
        
        titleLabel.frame = CGRect(x: view.center.x - ((view.frame.width - 50) / 2), y: 60, width: view.frame.width - 50, height: 55)
        //textView.frame = CGRect(x: 10, y: self.titleLabel.frame.maxY + 60, width: self.view.frame.width - 20, height: self.view.frame.maxY - (self.titleLabel.frame.maxY + 120))
        //pushButton.frame = CGRect(x: 10, y: view.frame.maxY - 55, width: 100, height: 50)
        decodeButton.frame = CGRect(x: self.view.frame.maxX - 105, y: view.frame.maxY - 55, width: 100, height: 50)
        
    }
    
    @objc func nextButtonAction() {
        
        self.view.endEditing(true)
        
    }
    
    func listUnspent() {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            self.ssh.execute(command: BTC_CLI_COMMAND.listunspent, params: "", response: { (result, error) in
                if error != nil {
                    print("error listunspent")
                } else {
                    print("result = \(String(describing: result))")
                    if let dict = result as? NSArray {
                        
                        if let miningFeeCheck = UserDefaults.standard.object(forKey: "miningFee") as? String {
                            
                            var txFee = Double()
                            var miningFeeString = ""
                            miningFeeString = miningFeeCheck
                            miningFeeString = miningFeeString.replacingOccurrences(of: ",", with: "")
                            let fee = (Double(miningFeeString)!) / 100000000
                            txFee = fee
                            
                            if !self.sweep {
                                
                                if self.spendable < Double(self.amount)! + txFee {
                                    
                                    DispatchQueue.main.async {
                                        displayAlert(viewController: self, title: "Error", message: "Insufficient funds.")
                                    }
                                    
                                } else {
                                    
                                    if let resultArray = dict as? NSArray {
                                        
                                        if resultArray.count > 0 {
                                            
                                            for utxo in resultArray {
                                                
                                                if let utxoDict = utxo as? NSDictionary {
                                                    
                                                    if let _ = utxoDict["txid"] as? String {
                                                        
                                                        if let spendableCheck = utxoDict["spendable"] as? Bool {
                                                            
                                                            if spendableCheck {
                                                                
                                                                if let _ = utxoDict["vout"] as? Int {
                                                                    
                                                                    if let _ = utxoDict["amount"] as? Double {
                                                                        
                                                                        self.spendableUtxos.append(utxoDict)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            var loop = true
                                            
                                            self.inputArray.removeAll()
                                            
                                            if self.spendableUtxos.count > 0 {
                                                
                                                var sumOfUtxo = 0.0
                                                
                                                for spendable in self.spendableUtxos {
                                                    
                                                    if loop {
                                                        
                                                        let amountAvailable = spendable["amount"] as! Double
                                                        sumOfUtxo = sumOfUtxo + amountAvailable
                                                        
                                                        if sumOfUtxo < (Double(self.amount)! + fee) {
                                                            
                                                            self.utxoTxId = spendable["txid"] as! String
                                                            self.utxoVout = spendable["vout"] as! Int
                                                            let input = "{\"txid\":\"\(self.utxoTxId)\",\"vout\": \(self.utxoVout),\"sequence\": 1}"
                                                            self.inputArray.append(input)
                                                            
                                                        } else {
                                                            
                                                            loop = false
                                                            self.utxoTxId = spendable["txid"] as! String
                                                            self.utxoVout = spendable["vout"] as! Int
                                                            let input = "{\"txid\":\"\(self.utxoTxId)\",\"vout\": \(self.utxoVout),\"sequence\": 1}"
                                                            self.inputArray.append(input)
                                                            self.changeAmount = sumOfUtxo - (Double(self.amount)! + fee)
                                                            self.changeAmount = Double(round(100000000*self.changeAmount)/100000000)
                                                            //self.executeNodeCommand(method: BTC_CLI_COMMAND.getrawchangeaddress.rawValue, param: "")
                                                            self.getRawChangeAddress()
                                                        }
                                                    }
                                                }
                                            }
                                            
                                        } else {
                                            displayAlert(viewController: self, title: "Error", message: "You have no available UTXO's to create a transaction with, try bumping the fee of pending transactions so they clear quicker or fund your wallet with more Bitcoin.")
                                        }
                                    }
                                }
                                
                            } else {
                                //sweeping
                                self.changeAmount = 0.00050000
                                
                                if let resultArray = dict as? NSArray {
                                    
                                    if resultArray.count > 0 {
                                        
                                        for utxo in resultArray {
                                            
                                            if let utxoDict = utxo as? NSDictionary {
                                                
                                                if let _ = utxoDict["txid"] as? String {
                                                    
                                                    if let spendableCheck = utxoDict["spendable"] as? Bool {
                                                        
                                                        if spendableCheck {
                                                            
                                                            if let _ = utxoDict["vout"] as? Int {
                                                                
                                                                if let _ = utxoDict["amount"] as? Double {
                                                                    
                                                                    self.spendableUtxos.append(utxoDict)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        
                                        self.inputArray.removeAll()
                                        
                                        if self.spendableUtxos.count > 0 {
                                            
                                            var sumOfUtxo = 0.0
                                            
                                            for spendable in self.spendableUtxos {
                                                
                                                let amountAvailable = spendable["amount"] as! Double
                                                sumOfUtxo = sumOfUtxo + amountAvailable
                                                self.utxoTxId = spendable["txid"] as! String
                                                self.utxoVout = spendable["vout"] as! Int
                                                let input = "{\"txid\":\"\(self.utxoTxId)\",\"vout\": \(self.utxoVout),\"sequence\": 1}"
                                                self.inputArray.append(input)
                                                
                                            }
                                            
                                            let array = String(sumOfUtxo).split(separator: ".")
                                            if array[1].count > 8 {
                                                
                                                sumOfUtxo = round(100000000*sumOfUtxo)/100000000
                                                print("sumofutxo = \(sumOfUtxo), txfee = \(txFee)")
                                            }
                                            self.amount = "\(sumOfUtxo - txFee - 0.00050000)"
                                            print("amount = sumofutxo = \(sumOfUtxo), txfee = \(txFee)")
                                            
                                            self.inputs = self.inputArray.description
                                            self.inputs = self.inputs.replacingOccurrences(of: "[\"", with: "[")
                                            self.inputs = self.inputs.replacingOccurrences(of: "\"]", with: "]")
                                            self.inputs = self.inputs.replacingOccurrences(of: "\"{", with: "{")
                                            self.inputs = self.inputs.replacingOccurrences(of: "}\"", with: "}")
                                            self.inputs = self.inputs.replacingOccurrences(of: "\\", with: "")
                                            self.getRawChangeAddress()
                                            
                                        }
                                        
                                    } else {
                                        displayAlert(viewController: self, title: "Error", message: "You have no available UTXO's to create a transaction with, try bumping the fee of pending transactions so they clear quicker or fund your wallet with more Bitcoin.")
                                    }
                                }
                            }
                            
                        } else {
                            displayAlert(viewController: self, title: "Error", message: "No mining fee set, please go to settings to set the mining fee.")
                        }
                        
                    }
                }
            })
        }
    }
    
    func getRawChangeAddress() {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            self.ssh.executeStringResponse(command: BTC_CLI_COMMAND.getrawchangeaddress, params: "", response: { (result, error) in
                if error != nil {
                    print("error getrawchangeaddress = \(String(describing: error))")
                } else {
                    print("result = \(String(describing: result))")
                    if let _ = result as? String {
                        
                        self.changeAddress = result!
                        
                        if self.sweep {
                            
                            //self.executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction.rawValue, param: "\(self.inputs), {\"\(self.address)\":\(self.amount),  \"\(self.changeAddress)\": \(self.changeAmount)}")
                            self.createRawTransaction()
                            self.sweep = false
                            
                        } else {
                            
                            self.inputs = self.inputArray.description
                            self.inputs = self.inputs.replacingOccurrences(of: "[\"", with: "[")
                            self.inputs = self.inputs.replacingOccurrences(of: "\"]", with: "]")
                            self.inputs = self.inputs.replacingOccurrences(of: "\"{", with: "{")
                            self.inputs = self.inputs.replacingOccurrences(of: "}\"", with: "}")
                            self.inputs = self.inputs.replacingOccurrences(of: "\\", with: "")
                            self.createRawTransaction()
                        }
                        
                        
                    }
                }
            })
        }
    }
    
    func createRawTransaction() {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            self.ssh.executeStringResponse(command: BTC_CLI_COMMAND.createrawtransaction, params: "\'\(self.inputs)\' \'{\"\(self.address)\":\(self.amount), \"\(self.changeAddress)\": \(self.changeAmount)}\'", response: { (result, error) in
                if error != nil {
                    print("error createrawtransaction = \(String(describing: error))")
                } else {
                    print("result = \(String(describing: result))")
                    if let rawTx = result as? String {
                        
                        self.rawTxUnsigned = rawTx
                        self.signRawTransaction()
                        
                    }
                    
                }
            })
        }
    }
    
    func signRawTransaction() {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            self.ssh.execute(command: BTC_CLI_COMMAND.signrawtransaction, params: "\'\(self.rawTxUnsigned)\'", response: { (result, error) in
                if error != nil {
                    print("error signrawtransaction = \(String(describing: error))")
                } else {
                    print("result = \(String(describing: result))")
                    
                    if let signedTransaction = result as? NSDictionary {
                        
                        self.rawTxSigned = signedTransaction["hex"] as! String
                        
                        DispatchQueue.main.async {
                            
                            self.nextButton.removeFromSuperview()
                            self.amountInput.removeFromSuperview()
                            self.textView.text = self.rawTxSigned
                            self.qrCode = self.generateQrCode(key: self.rawTxSigned)
                            self.displayQrView.image = self.qrCode
                            UIPasteboard.general.string = self.rawTxSigned
                            self.view.addSubview(self.decodeButton)
                            
                            UIView.animate(withDuration: 0.3, animations: {
                                self.displayQrView.alpha = 1
                                self.textView.alpha = 1
                            })
                            
                            self.tapTextViewGesture = UITapGestureRecognizer(target: self, action: #selector(self.shareRawText(_:)))
                            self.textView.addGestureRecognizer(self.tapTextViewGesture)
                            self.tapQRGesture = UITapGestureRecognizer(target: self, action: #selector(self.shareQRCode(_:)))
                            self.displayQrView.addGestureRecognizer(self.tapQRGesture)
                            
                            let alert = UIAlertController(title: NSLocalizedString("Copied to clipboard", comment: ""), message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
                            
                            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel, handler: { (action) in
                                //self.dismiss(animated: true, completion: nil)
                            }))
                            
                            alert.popoverPresentationController?.sourceView = self.view
                            
                            self.present(alert, animated: true) {
                            }
                            
                            
                        }
                    }
                }
            })
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        if sweep {
            
            if !self.isUsingSSH {
                
                self.executeNodeCommand(method: BTC_CLI_COMMAND.listunspent.rawValue, param: "")
                
            } else {
                
                self.listUnspent()
            }
           
            
        } else {
            
            if textField == self.amountInput && self.amountInput.text != "" {
                
                let dbl = self.amountInput.text?.toDouble()
                
                if dbl != nil && dbl! > 0.0 {
                    
                    print("amount = \(String(describing: self.amountInput.text))")
                    self.amount = self.amountInput.text!
                    if self.amount.hasPrefix(".") {
                        self.amount = "0" + self.amount
                        
                        if !self.isUsingSSH {
                            self.executeNodeCommand(method: BTC_CLI_COMMAND.listunspent.rawValue, param: "")
                        } else {
                            self.listUnspent()
                        }
                        
                    } else {
                        
                        if !self.isUsingSSH {
                            self.executeNodeCommand(method: BTC_CLI_COMMAND.listunspent.rawValue, param: "")
                        } else {
                            self.listUnspent()
                        }
                    }
                    
                } else {
                    displayAlert(viewController: self, title: "Error", message: "Only valid numbers allowed.")
                    DispatchQueue.main.async {
                        self.amountInput.text = ""
                    }
                }
            }
            
        }
        
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        print("shouldChangeCharactersInRange")
        
        if (textField.text?.contains("."))! {
            
           let decimalCount = (textField.text?.components(separatedBy: ".")[1])?.count
            
            if decimalCount! <= 7 {
                
                
            } else {
                DispatchQueue.main.async {
                    displayAlert(viewController: self, title: "", message: "Only 8 decimal places allowed, please reenter amount.")
                    self.amountInput.text = ""
                }
                
            }
            
        }
        
        
        
        return true
    }
    
    func addNextButton(inputView: UITextField) {
        
        DispatchQueue.main.async {
            self.nextButton.removeFromSuperview()
            self.nextButton.frame = CGRect(x: self.view.center.x - 40, y: inputView.frame.maxY + 10, width: 80, height: 55)
            self.nextButton.showsTouchWhenHighlighted = true
            self.nextButton.setTitle("Next", for: .normal)
            self.nextButton.setTitleColor(UIColor.white, for: .normal)
            self.nextButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Bold", size: 20)
            self.nextButton.addTarget(self, action: #selector(self.nextButtonAction), for: .touchUpInside)
            self.view.addSubview(self.nextButton)
        }
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        addressInput.resignFirstResponder()
    }

    @objc func goBack() {
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        if textField == self.addressInput && addressInput.text != "" {
            
            processKeys(key: addressInput.text!)
            self.addressInput.resignFirstResponder()
            
        } else if textField == self.amountInput && self.amountInput.text != "" {
            
            print("amount = \(String(describing: self.amountInput.text))")
            
        } else {
            
            self.addressInput.resignFirstResponder()
            self.amountInput.resignFirstResponder()
        }
        
        return true
    }
    
    func getAddress() {
        
        addressInput.frame = CGRect(x: self.view.frame.minX + 25, y: 150, width: self.view.frame.width - 50, height: 50)
        addressInput.textAlignment = .center
        addressInput.borderStyle = .roundedRect
        addressInput.autocorrectionType = .no
        addressInput.autocapitalizationType = .none
        addressInput.keyboardAppearance = UIKeyboardAppearance.dark
        addressInput.backgroundColor = UIColor.groupTableViewBackground
        addressInput.returnKeyType = UIReturnKeyType.go
        addressInput.placeholder = "Recipient Address"
        
        titleLabel.font = UIFont.init(name: "HelveticaNeue-Bold", size: 30)
        titleLabel.textColor = UIColor.white
        titleLabel.text = ""
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.textAlignment = .natural
        
        self.qrImageView.frame = CGRect(x: self.view.center.x - ((self.view.frame.width - 50)/2), y: self.addressInput.frame.maxY + 10, width: self.view.frame.width - 50, height: self.view.frame.width - 50)
        self.uploadButton.frame = CGRect(x: self.view.frame.maxX - 140, y: self.view.frame.maxY - 60, width: 130, height: 55)
        self.uploadButton.showsTouchWhenHighlighted = true
        self.uploadButton.setTitle("From Photos", for: .normal)
        self.uploadButton.setTitleColor(UIColor.white, for: .normal)
        self.uploadButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Bold", size: 20)
        self.uploadButton.addTarget(self, action: #selector(self.chooseQRCodeFromLibrary), for: .touchUpInside)
        
        func scanQRCode() {
            
            do {
                
                try scanQRNow()
                print("scanQRNow")
                
            } catch {
                
                print("Failed to scan QR Code")
            }
            
        }
        
        DispatchQueue.main.async {
            self.view.addSubview(self.imageImportView)
            self.view.addSubview(self.titleLabel)
            self.view.addSubview(self.addressInput)
            self.view.addSubview(self.qrImageView)
            self.view.addSubview(self.uploadButton)
            scanQRCode()
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            
            let detector:CIDetector=CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh])!
            let ciImage:CIImage = CIImage(image:pickedImage)!
            var qrCodeLink = ""
            let features = detector.features(in: ciImage)
            
            for feature in features as! [CIQRCodeFeature] {
                qrCodeLink += feature.messageString!
            }
            
            print(qrCodeLink)
            
            
            
            if qrCodeLink != "" {
                
                DispatchQueue.main.async {
                    
                    let bip21Check = qrCodeLink.replacingOccurrences(of: "bitcoin:", with: "")
                    self.processKeys(key: bip21Check)
                    
                }
                
            }
            
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    
    
    @objc func chooseQRCodeFromLibrary() {
        
        present(imagePicker, animated: true, completion: nil)
    }
    
    enum error: Error {
        
        case noCameraAvailable
        case videoInputInitFail
        
    }
    
    func scanQRNow() throws {
        
        guard let avCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            
            print("no camera")
            throw error.noCameraAvailable
            
        }
        
        guard let avCaptureInput = try? AVCaptureDeviceInput(device: avCaptureDevice) else {
            
            print("failed to int camera")
            throw error.videoInputInitFail
        }
        
        
        let avCaptureMetadataOutput = AVCaptureMetadataOutput()
        avCaptureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        
        if let inputs = self.avCaptureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                self.avCaptureSession.removeInput(input)
            }
        }
        
        if let outputs = self.avCaptureSession.outputs as? [AVCaptureMetadataOutput] {
            for output in outputs {
                self.avCaptureSession.removeOutput(output)
            }
        }
        
        self.avCaptureSession.addInput(avCaptureInput)
        self.avCaptureSession.addOutput(avCaptureMetadataOutput)
        avCaptureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        let avCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: avCaptureSession)
        avCaptureVideoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        avCaptureVideoPreviewLayer.frame = self.qrImageView.bounds
        self.qrImageView.layer.addSublayer(avCaptureVideoPreviewLayer)
        self.avCaptureSession.startRunning()
        
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if metadataObjects.count > 0 {
            print("metadataOutput")
            
            let machineReadableCode = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
            
            if machineReadableCode.type == AVMetadataObject.ObjectType.qr {
                
                stringURL = machineReadableCode.stringValue!
                processKeys(key: stringURL)
                self.avCaptureSession.stopRunning()
                self.avCaptureSession.startRunning()
                
            }
        }
    }
    
    func processKeys(key: String) {
        
        self.processBIP21(url: key)
        
   }
    
    func executeNodeCommand(method: String, param: Any) {
        
       func decrypt(item: String) -> String {
            
            var decrypted = ""
            if let password = KeychainWrapper.standard.string(forKey: "AESPassword") {
                if let decryptedCheck = AES256CBC.decryptString(item, password: password) {
                    decrypted = decryptedCheck
                }
            }
            return decrypted
        }
        
        let nodeUsername = decrypt(item: UserDefaults.standard.string(forKey: "NodeUsername")!)
        let nodePassword = decrypt(item: UserDefaults.standard.string(forKey: "NodePassword")!)
        let ip = decrypt(item: UserDefaults.standard.string(forKey: "NodeIPAddress")!)
        let port = decrypt(item: UserDefaults.standard.string(forKey: "NodePort")!)
        let url = URL(string: "http://\(nodeUsername):\(nodePassword)@\(ip):\(port)")
        var request = URLRequest(url: url!)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method)\",\"params\":[\(param)]}".data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) -> Void in
            
            do {
                
                if error != nil {
                    
                    displayAlert(viewController: self, title: "Error", message: "\(error.debugDescription)")
                    
                } else {
                    
                    if let urlContent = data {
                        
                        do {
                            
                            let jsonAddressResult = try JSONSerialization.jsonObject(with: urlContent, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                            
                            if let errorCheck = jsonAddressResult["error"] as? NSDictionary {
                                
                                if let error = errorCheck["message"] as? String {
                                    displayAlert(viewController: self, title: "Error", message: error)
                                }
                                
                            } else {
                                
                                if let resultCheck = jsonAddressResult["result"] as? Any {
                                    
                                    switch method {
                                        
                                    case BTC_CLI_COMMAND.decoderawtransaction.rawValue:
                                        
                                        if let decodedTx = resultCheck as? NSDictionary {
                                            DispatchQueue.main.async {
                                                self.textView.text = "\(decodedTx)"
                                                //self.view.addSubview(self.pushButton)
                                                self.decodeButton.setTitle("Encode", for: .normal)
                                                self.decodeButton.removeTarget(self, action: #selector(self.decode), for: .touchUpInside)
                                                self.decodeButton.addTarget(self, action: #selector(self.encodeText), for: .touchUpInside)
                                            }
                                        }
                                        
                                    case BTC_CLI_COMMAND.getbalance.rawValue:
                                        
                                        if let balanceCheck = resultCheck as? Double {
                                            self.spendable = balanceCheck
                                        }
                                        
                                    case BTC_CLI_COMMAND.getrawchangeaddress.rawValue:
                                        
                                            if let _ = resultCheck as? String {
                                                
                                                self.changeAddress = resultCheck as! String
                                                
                                                if self.sweep {
                                                    
                                                    self.executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction.rawValue, param: "\(self.inputs), {\"\(self.address)\":\(self.amount),  \"\(self.changeAddress)\": \(self.changeAmount)}")
                                                    self.sweep = false
                                                    
                                                } else {
                                                    
                                                    self.inputs = self.inputArray.description
                                                    self.inputs = self.inputs.replacingOccurrences(of: "[\"", with: "[")
                                                    self.inputs = self.inputs.replacingOccurrences(of: "\"]", with: "]")
                                                    self.inputs = self.inputs.replacingOccurrences(of: "\"{", with: "{")
                                                    self.inputs = self.inputs.replacingOccurrences(of: "}\"", with: "}")
                                                    self.inputs = self.inputs.replacingOccurrences(of: "\\", with: "")
                                                    self.executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction.rawValue, param: "\(self.inputs), {\"\(self.address)\":\(self.amount),  \"\(self.changeAddress)\": \(self.changeAmount)}")
                                                }
                                            }
                                            
                                        
                                    case BTC_CLI_COMMAND.listunspent.rawValue:
                                        
                                        if let miningFeeCheck = UserDefaults.standard.object(forKey: "miningFee") as? String {
                                            
                                            var txFee = Double()
                                            var miningFeeString = ""
                                            miningFeeString = miningFeeCheck
                                            miningFeeString = miningFeeString.replacingOccurrences(of: ",", with: "")
                                            let fee = (Double(miningFeeString)!) / 100000000
                                            txFee = fee
                                            
                                            if !self.sweep {
                                               
                                                if self.spendable < Double(self.amount)! + txFee {
                                                    
                                                    DispatchQueue.main.async {
                                                        displayAlert(viewController: self, title: "Error", message: "Insufficient funds.")
                                                    }
                                                    
                                                } else {
                                                    
                                                    if let resultArray = resultCheck as? NSArray {
                                                        
                                                        if resultArray.count > 0 {
                                                            
                                                            for utxo in resultArray {
                                                                
                                                                if let utxoDict = utxo as? NSDictionary {
                                                                    
                                                                    if let _ = utxoDict["txid"] as? String {
                                                                        
                                                                        if let spendableCheck = utxoDict["spendable"] as? Bool {
                                                                            
                                                                            if spendableCheck {
                                                                                
                                                                                if let _ = utxoDict["vout"] as? Int {
                                                                                    
                                                                                    if let _ = utxoDict["amount"] as? Double {
                                                                                        
                                                                                        self.spendableUtxos.append(utxoDict)
                                                                                    }
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                            
                                                            var loop = true
                                                            
                                                            self.inputArray.removeAll()
                                                            
                                                            if self.spendableUtxos.count > 0 {
                                                                
                                                                var sumOfUtxo = 0.0
                                                                
                                                                for spendable in self.spendableUtxos {
                                                                    
                                                                    if loop {
                                                                        
                                                                        let amountAvailable = spendable["amount"] as! Double
                                                                        sumOfUtxo = sumOfUtxo + amountAvailable
                                                                        
                                                                        if sumOfUtxo < (Double(self.amount)! + fee) {
                                                                            
                                                                            self.utxoTxId = spendable["txid"] as! String
                                                                            self.utxoVout = spendable["vout"] as! Int
                                                                            let input = "{\"txid\":\"\(self.utxoTxId)\",\"vout\": \(self.utxoVout),\"sequence\": 1}"
                                                                            self.inputArray.append(input)
                                                                            
                                                                        } else {
                                                                            
                                                                            loop = false
                                                                            self.utxoTxId = spendable["txid"] as! String
                                                                            self.utxoVout = spendable["vout"] as! Int
                                                                            let input = "{\"txid\":\"\(self.utxoTxId)\",\"vout\": \(self.utxoVout),\"sequence\": 1}"
                                                                            self.inputArray.append(input)
                                                                            self.changeAmount = sumOfUtxo - (Double(self.amount)! + fee)
                                                                            self.changeAmount = Double(round(100000000*self.changeAmount)/100000000)
                                                                            self.executeNodeCommand(method: BTC_CLI_COMMAND.getrawchangeaddress.rawValue, param: "")
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                            
                                                        } else {
                                                            displayAlert(viewController: self, title: "Error", message: "You have no available UTXO's to create a transaction with, try bumping the fee of pending transactions so they clear quicker or fund your wallet with more Bitcoin.")
                                                        }
                                                    }
                                                }
                                                
                                            } else {
                                                
                                                //sweeping
                                                self.changeAmount = 0.00050000
                                                
                                                if let resultArray = resultCheck as? NSArray {
                                                    
                                                    if resultArray.count > 0 {
                                                        
                                                        for utxo in resultArray {
                                                            
                                                            if let utxoDict = utxo as? NSDictionary {
                                                                
                                                                if let _ = utxoDict["txid"] as? String {
                                                                    
                                                                    if let spendableCheck = utxoDict["spendable"] as? Bool {
                                                                        
                                                                        if spendableCheck {
                                                                            
                                                                            if let _ = utxoDict["vout"] as? Int {
                                                                                
                                                                                if let _ = utxoDict["amount"] as? Double {
                                                                                    
                                                                                    self.spendableUtxos.append(utxoDict)
                                                                                    
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                        
                                                        self.inputArray.removeAll()
                                                        
                                                        if self.spendableUtxos.count > 0 {
                                                            
                                                            var sumOfUtxo = 0.0
                                                            
                                                            for spendable in self.spendableUtxos {
                                                                
                                                                let amountAvailable = spendable["amount"] as! Double
                                                                sumOfUtxo = sumOfUtxo + amountAvailable
                                                                self.utxoTxId = spendable["txid"] as! String
                                                                self.utxoVout = spendable["vout"] as! Int
                                                                let input = "{\"txid\":\"\(self.utxoTxId)\",\"vout\": \(self.utxoVout),\"sequence\": 1}"
                                                                self.inputArray.append(input)
                                                                
                                                            }
                                                            
                                                            let array = String(sumOfUtxo).split(separator: ".")
                                                            if array[1].count > 8 {
                                                                
                                                                sumOfUtxo = round(100000000*sumOfUtxo)/100000000
                                                                print("sumofutxo = \(sumOfUtxo), txfee = \(txFee.avoidNotation)")
                                                            }
                                                            
                                                            let total = sumOfUtxo - txFee - 0.00050000
                                                            let totalRounded = round(100000000*total)/100000000
                                                            self.amount = "\(totalRounded)"
                                                            print("amount = \(self.amount) sumofutxo = \(sumOfUtxo), txfee = \(txFee.avoidNotation)")
                                                            
                                                            self.inputs = self.inputArray.description
                                                            self.inputs = self.inputs.replacingOccurrences(of: "[\"", with: "[")
                                                            self.inputs = self.inputs.replacingOccurrences(of: "\"]", with: "]")
                                                            self.inputs = self.inputs.replacingOccurrences(of: "\"{", with: "{")
                                                            self.inputs = self.inputs.replacingOccurrences(of: "}\"", with: "}")
                                                            self.inputs = self.inputs.replacingOccurrences(of: "\\", with: "")
                                                            self.executeNodeCommand(method: BTC_CLI_COMMAND.getrawchangeaddress.rawValue, param: "")
                                                            
                                                       }
                                                        
                                                    } else {
                                                        displayAlert(viewController: self, title: "Error", message: "You have no available UTXO's to create a transaction with, try bumping the fee of pending transactions so they clear quicker or fund your wallet with more Bitcoin.")
                                                    }
                                                }
                                            }
                                            
                                        } else {
                                            displayAlert(viewController: self, title: "Error", message: "No mining fee set, please go to settings to set the mining fee.")
                                        }
                                        
                                    case BTC_CLI_COMMAND.createrawtransaction.rawValue:
                                        
                                        if let _ = resultCheck as? String {
                                            
                                            self.rawTxUnsigned = resultCheck as! String
                                            self.executeNodeCommand(method: BTC_CLI_COMMAND.signrawtransaction.rawValue, param: "\"\(self.rawTxUnsigned)\"")
                                            
                                        }
                                        
                                    case BTC_CLI_COMMAND.signrawtransaction.rawValue:
                                        
                                        if let signedTransaction = resultCheck as? NSDictionary {
                                            
                                            self.rawTxSigned = signedTransaction["hex"] as! String
                                            
                                            
                                            DispatchQueue.main.async {
                                                
                                                self.nextButton.removeFromSuperview()
                                                self.amountInput.removeFromSuperview()
                                                self.textView.text = self.rawTxSigned
                                                self.qrCode = self.generateQrCode(key: self.rawTxSigned)
                                                self.displayQrView.image = self.qrCode
                                                UIPasteboard.general.string = self.rawTxSigned
                                                self.view.addSubview(self.decodeButton)
                                                
                                                UIView.animate(withDuration: 0.3, animations: {
                                                    self.displayQrView.alpha = 1
                                                    self.textView.alpha = 1
                                                })
                                                
                                                self.tapTextViewGesture = UITapGestureRecognizer(target: self, action: #selector(self.shareRawText(_:)))
                                                self.textView.addGestureRecognizer(self.tapTextViewGesture)
                                                self.tapQRGesture = UITapGestureRecognizer(target: self, action: #selector(self.shareQRCode(_:)))
                                                self.displayQrView.addGestureRecognizer(self.tapQRGesture)
                                                
                                                let alert = UIAlertController(title: NSLocalizedString("Copied to clipboard", comment: ""), message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
                                                
                                                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel, handler: { (action) in
                                                    //self.dismiss(animated: true, completion: nil)
                                                }))
                                                
                                                alert.popoverPresentationController?.sourceView = self.view
                                                
                                                self.present(alert, animated: true) {
                                                }
                                                
                                                
                                            }
                                        }
                                        
                                    case BTC_CLI_COMMAND.sendrawtransaction.rawValue:
                                        
                                        if let txID = resultCheck as? String {
                                            
                                            DispatchQueue.main.async {
                                                
                                                UIPasteboard.general.string = txID
                                                
                                                self.sentAnimation()
                                                
                                                let alert = UIAlertController(title: NSLocalizedString("Success", comment: ""), message: "ID copied to clipboard", preferredStyle: UIAlertControllerStyle.actionSheet)
                                                
                                                alert.addAction(UIAlertAction(title: NSLocalizedString("Done", comment: ""), style: .cancel, handler: { (action) in
                                                    self.dismiss(animated: true, completion: nil)
                                                }))
                                                
                                                alert.popoverPresentationController?.sourceView = self.view
                                                
                                                self.present(alert, animated: true) {
                                                }
                                            }
                                            
                                        } else {
                                            displayAlert(viewController: self, title: "Error", message: "Unable to parse Transaction ID.")
                                        }
                                        
                                    default: break
                                        
                                    }
                                    
                                }
                                
                            }
                            
                        } catch {
                            
                            print("error processing json")
                            
                        }
                    }
                }
            }
        }
        
        task.resume()
        
    }
    
    func generateQrCode(key: String) -> UIImage {
        
        var imageToReturn = UIImage()
        
        if let cgImage = EFQRCode.generate(content: key,
                                        size: EFIntSize.init(width: 256, height: 256),
                                        backgroundColor: UIColor.clear.cgColor,
                                        foregroundColor: UIColor.white.cgColor,
                                        watermark: nil,
                                        watermarkMode: EFWatermarkMode.scaleAspectFit,
                                        inputCorrectionLevel: EFInputCorrectionLevel.h,
                                        icon: nil,
                                        iconSize: nil,
                                        allowTransparent: true,
                                        pointShape: EFPointShape.circle,
                                        mode: EFQRCodeMode.none,
                                        binarizationThreshold: 0,
                                        magnification: EFIntSize.init(width: 50, height: 50),
                                        foregroundPointOffset: 0) {
            
            imageToReturn = UIImage(cgImage: cgImage)
            
        } else {
            
            imageToReturn = UIImage(named: "clear.png")!
            
            let label = UILabel()
            label.text = "Data too large to create QR Code"
            label.frame = CGRect(x: 0, y: self.displayQrView.frame.minY + 20, width: self.displayQrView.frame.width, height: 40)
            label.textColor = UIColor.white
            label.textAlignment = .center
            
            self.displayQrView.addSubview(label)
            
        }
        
        return imageToReturn
        
    }
    
    @objc func shareRawText(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                self.textView.alpha = 0
            }) { _ in
                UIView.animate(withDuration: 0.2, animations: {
                    self.textView.alpha = 1
                })
            }
            
            let textToShare = [self.rawTxSigned]
            let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
            //self.present(activityViewController, animated: true, completion: nil)
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true) {}
        }
    }
    
    @objc func shareQRCode(_ sender: UITapGestureRecognizer) {
        print("shareQRCode")
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.displayQrView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.displayQrView.alpha = 1
                    
                })
                
            }
            
            if let cgImage = EFQRCode.generate(content: self.rawTxSigned,
                                            size: EFIntSize.init(width: 256, height: 256),
                                            backgroundColor: UIColor.white.cgColor,
                                            foregroundColor: UIColor.black.cgColor,
                                            watermark: nil,
                                            watermarkMode: EFWatermarkMode.scaleAspectFit,
                                            inputCorrectionLevel: EFInputCorrectionLevel.h,
                                            icon: nil,
                                            iconSize: nil,
                                            allowTransparent: true,
                                            pointShape: EFPointShape.circle,
                                            mode: EFQRCodeMode.none,
                                            binarizationThreshold: 0,
                                            magnification: EFIntSize.init(width: 50, height: 50),
                                            foregroundPointOffset: 0) {
                
                let qrImage = UIImage(cgImage: cgImage)
                
                
                let objectsToShare = [qrImage]
                
                DispatchQueue.main.async {
                    
                    let activityController = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
                    activityController.completionWithItemsHandler = { (type,completed,items,error) in
                        print("completed. type=\(String(describing: type)) completed=\(completed) items=\(String(describing: items)) error=\(String(describing: error))")
                    }
                    activityController.popoverPresentationController?.sourceView = self.view
                    self.present(activityController, animated: true) {}
                    
                }
                
            }
            
        }
        
    }
    
}

extension String {
    func toDouble() -> Double? {
        return NumberFormatter().number(from: self)?.doubleValue
    }
}



