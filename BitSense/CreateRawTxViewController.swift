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

class CreateRawTxViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {
    
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
    
    enum BTC_CLI_COMMAND: String {
        case decoderawtransaction = "decoderawtransaction"
        case getnewaddress = "getnewaddress"
        case gettransaction = "gettransaction"
        case sendrawtransaction = "sendrawtransaction"
        case signrawtransaction = "signrawtransaction"
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
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("CreateRawTxViewController")
        
        executeNodeCommand(method: BTC_CLI_COMMAND.getbalance.rawValue, param: "")
        
        let backButton = UIButton()
        let modelName = UIDevice.modelName
        if modelName == "iPhone X" {
            backButton.frame = CGRect(x: 15, y: 30, width: 25, height: 25)
        } else {
            backButton.frame = CGRect(x: 15, y: 20, width: 25, height: 25)
        }
        backButton.showsTouchWhenHighlighted = true
        backButton.setImage(#imageLiteral(resourceName: "back.png"), for: .normal)
        backButton.addTarget(self, action: #selector(self.goBack), for: .touchUpInside)
        self.view.addSubview(backButton)
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        addressInput.delegate = self
        amountInput.delegate = self
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        getAddress()
    }
    
    @objc func nextButtonAction() {
        
        self.view.endEditing(true)
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        if textField == self.amountInput && self.amountInput.text != "" {
            
            let dbl = self.amountInput.text?.toDouble()
            
            if dbl != nil && dbl! > 0.0 {
                
                print("amount = \(String(describing: self.amountInput.text))")
                self.amount = self.amountInput.text!
                if self.amount.hasPrefix(".") {
                    self.amount = "0" + self.amount
                    self.executeNodeCommand(method: BTC_CLI_COMMAND.listunspent.rawValue, param: "")
                } else {
                    self.executeNodeCommand(method: BTC_CLI_COMMAND.listunspent.rawValue, param: "")
                }
                
            } else {
                displayAlert(viewController: self, title: "Error", message: "Only valid numbers allowed.")
                DispatchQueue.main.async {
                    self.amountInput.text = ""
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
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
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
            
            //show confirmation screen
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
        addressInput.placeholder = "Scan or type an Address"
        
        titleLabel.frame = CGRect(x: view.center.x - ((view.frame.width - 50) / 2), y: addressInput.frame.minY - 65, width: view.frame.width - 50, height: 55)
        titleLabel.font = UIFont.init(name: "HelveticaNeue-Bold", size: 30)
        titleLabel.textColor = UIColor.white
        titleLabel.text = "Recipient Address"
        titleLabel.numberOfLines = 0
        //addShadow(view: title)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.textAlignment = .center
        
        self.qrImageView.frame = CGRect(x: self.view.center.x - ((self.view.frame.width - 50)/2), y: self.addressInput.frame.maxY + 10, width: self.view.frame.width - 50, height: self.view.frame.width - 50)
        //addShadow(view:self.qrImageView)
        
        self.uploadButton.frame = CGRect(x: self.view.frame.maxX - 140, y: self.view.frame.maxY - 60, width: 130, height: 55)
        self.uploadButton.showsTouchWhenHighlighted = true
        self.uploadButton.setTitle("From Photos", for: .normal)
        //addShadow(view: self.uploadButton)
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
    

    //get recipient address
    
    //get amount in btc
    
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
        
        if key.hasPrefix("1") || key.hasPrefix("3") || key.hasPrefix("bc") || key.hasPrefix("2") || key.hasPrefix("m") || key.hasPrefix("tb") || key.hasPrefix("2") {
            
            self.address = key
            print("recipient address = \(self.address)")
            self.addressInput.removeFromSuperview()
            self.imageImportView.removeFromSuperview()
            self.qrImageView.removeFromSuperview()
            self.uploadButton.removeFromSuperview()
            
            self.titleLabel.text = "Amount"
            
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
            self.view.addSubview(self.amountInput)
            self.addNextButton(inputView: self.amountInput)
            
        } else {
            
            displayAlert(viewController: self, title: "Error", message: "Thats not a valid Bitcoin Address")
            
        }
        
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
        
        let nodeUsername = decrypt(item: KeychainWrapper.standard.string(forKey: "NodeUsername")!)
        let nodePassword = decrypt(item: KeychainWrapper.standard.string(forKey: "NodePassword")!)
        let ip = decrypt(item: KeychainWrapper.standard.string(forKey: "NodeIPAddress")!)
        let port = decrypt(item: KeychainWrapper.standard.string(forKey: "NodePort")!)
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
                                        
                                    case BTC_CLI_COMMAND.getbalance.rawValue:
                                        
                                        if let balanceCheck = resultCheck as? Double {
                                            self.spendable = balanceCheck
                                        }
                                        
                                    case BTC_CLI_COMMAND.getrawchangeaddress.rawValue:
                                        
                                        if let _ = resultCheck as? String {
                                            self.changeAddress = resultCheck as! String
                                            self.inputs = self.inputArray.description
                                            self.inputs = self.inputs.replacingOccurrences(of: "[\"", with: "[")
                                            self.inputs = self.inputs.replacingOccurrences(of: "\"]", with: "]")
                                            self.inputs = self.inputs.replacingOccurrences(of: "\"{", with: "{")
                                            self.inputs = self.inputs.replacingOccurrences(of: "}\"", with: "}")
                                            self.inputs = self.inputs.replacingOccurrences(of: "\\", with: "")
                                            self.executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction.rawValue, param: "\(self.inputs), {\"\(self.address)\":\(self.amount),  \"\(self.changeAddress)\": \(self.changeAmount)}")
                                        }
                                        
                                    case BTC_CLI_COMMAND.listunspent.rawValue:
                                        
                                        if let miningFeeCheck = UserDefaults.standard.object(forKey: "miningFee") as? String {
                                            
                                            var txFee = Double()
                                            var miningFeeString = ""
                                            miningFeeString = miningFeeCheck
                                            miningFeeString = miningFeeString.replacingOccurrences(of: ",", with: "")
                                            let fee = (Double(miningFeeString)!) / 100000000
                                            txFee = fee
                                            
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
                                                self.titleLabel.text = "Raw:"
                                                self.nextButton.removeFromSuperview()
                                                self.amountInput.removeFromSuperview()
                                                let textView = UITextView()
                                                textView.frame = CGRect(x: 10, y: self.titleLabel.frame.maxY, width: self.view.frame.width - 20, height: self.view.frame.height - self.titleLabel.frame.maxY)
                                                textView.text = self.rawTxSigned
                                                textView.textColor = UIColor.white
                                                textView.textAlignment = .natural
                                                textView.font = UIFont.init(name: "HelveticaNeue", size: 18)
                                                textView.adjustsFontForContentSizeCategory = true
                                                textView.isSelectable = true
                                                textView.isEditable = false
                                                textView.backgroundColor = self.view.backgroundColor
                                                self.view.addSubview(textView)
                                            }
                                            
                                            DispatchQueue.main.async {
                                                let alert = UIAlertController(title: NSLocalizedString("Push?", comment: ""), message: "\(self.amount) BTC to \(self.address)", preferredStyle: UIAlertControllerStyle.actionSheet)
                                                
                                                alert.addAction(UIAlertAction(title: NSLocalizedString("Push", comment: ""), style: .default, handler: { (action) in
                                                    self.executeNodeCommand(method: BTC_CLI_COMMAND.sendrawtransaction.rawValue, param: "\"\(self.rawTxSigned)\"")
                                                }))
                                                
                                                alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in
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

}

extension String {
    func toDouble() -> Double? {
        return NumberFormatter().number(from: self)?.doubleValue
    }
}


