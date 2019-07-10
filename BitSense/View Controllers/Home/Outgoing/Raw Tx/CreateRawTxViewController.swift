//
//  CreateRawTxViewController.swift
//  BitSense
//
//  Created by Peter on 09/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit

class CreateRawTxViewController: UIViewController, UITextFieldDelegate {
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var qrCode = UIImage()
    var ssh:SSHService!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var spendable = Double()
    var changeAmount = Double()
    var rawTxUnsigned = String()
    var rawTxSigned = String()
    var amountAvailable = Double()
    var changeAddress = String()
    let qrImageView = UIImageView()
    var stringURL = String()
    var address = String()
    let nextButton = UIButton()
    var amount = String()
    var blurArray = [UIVisualEffectView]()
    let rawDisplayer = RawDisplayer()
    var isUsingSSH = Bool()
    var scannerShowing = false
    var isFirstTime = Bool()
    
    @IBOutlet var amountInput: UITextField!
    @IBOutlet var addressInput: UITextField!
    
    
    let sweepButtonView = Bundle.main.loadNibNamed("KeyPadButtonView",
                                                   owner: self,
                                                   options: nil)?.first as! UIView?
    var makeSSHCall:SSHelper!
    var creatingView = ConnectingView()
    let qrScanner = QRScanner()
    var isTorchOn = Bool()
    let qrGenerator = QRGenerator()
    var miningFee = Double()
    var spendableBalance = Double()
    
    @IBOutlet var scannerView: UIImageView!
    
    @IBAction func back(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    @IBAction func sweepAction(_ sender: Any) {
        
        executeNodeCommandSsh(method: BTC_CLI_COMMAND.listunspent,
                              param: "")
        
        //self.amountInput.text = String(self.spendable - miningFee - 0.00050000)
        
    }
    
    func parseUnpsent(utxos: NSArray) {
        
        for utxo in utxos {
            
            let dict = utxo as! NSDictionary
            let spendable = dict["spendable"] as! Bool
            let amount = dict["amount"] as! Double
            
            if spendable {
                
                self.spendableBalance += amount
                
            }
            
        }
        
        DispatchQueue.main.async {
            
            self.amountInput.text = String(self.spendableBalance - self.miningFee - 0.00050000)
            
        }
        
    }
    
    
    func configureScanner() {
        
        isFirstTime = true
        
        scannerView.alpha = 0
        scannerView.frame = view.frame
        scannerView.isUserInteractionEnabled = true
        
        qrScanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.keepRunning = false
        qrScanner.vc = self
        qrScanner.imageView = scannerView
        qrScanner.textField.alpha = 0
        
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        
        qrScanner.uploadButton.addTarget(self,
                                         action: #selector(self.chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.torchButton.addTarget(self,
                                        action: #selector(toggleTorch),
                                        for: .touchUpInside)
        
        isTorchOn = false
        
        
        qrScanner.closeButton.addTarget(self,
                                        action: #selector(closeScanner),
                                        for: .touchUpInside)
        
    }
    
    func addScannerButtons() {
        
        self.addBlurView(frame: CGRect(x: self.scannerView.frame.maxX - 80,
                                       y: self.scannerView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.qrScanner.uploadButton)
        
        self.addBlurView(frame: CGRect(x: 10,
                                       y: self.scannerView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.qrScanner.torchButton)
        
    }
    
    @IBAction func scanNow(_ sender: Any) {
        
        print("scanNow")
        
        scannerShowing = true
        addressInput.resignFirstResponder()
        amountInput.resignFirstResponder()
        
        if isFirstTime {
            
            DispatchQueue.main.async {
                
                self.qrScanner.scanQRCode()
                self.addScannerButtons()
                self.scannerView.addSubview(self.qrScanner.closeButton)
                self.isFirstTime = false
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.scannerView.alpha = 1
                    
                })
                
            }
            
        } else {
            
            self.qrScanner.startScanner()
            self.addScannerButtons()
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.scannerView.alpha = 1
                    
                })
                
            }
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("CreateRawTxViewController")
        
        amountInput.delegate = self
        addressInput.delegate = self
        
        amountInput.inputAccessoryView = sweepButtonView
        
        configureScanner()
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sweepButtonClicked),
                                               name: NSNotification.Name(rawValue: "buttonClickedNotification"),
                                               object: nil)
        
        getMiningFee()
        
    }
    
    func getMiningFee() {
        
        let miningFeeCheck = UserDefaults.standard.object(forKey: "miningFee") as! String
        var miningFeeString = ""
        miningFeeString = miningFeeCheck
        miningFeeString = miningFeeString.replacingOccurrences(of: ",", with: "")
        let fee = (Double(miningFeeString)!) / 100000000
        miningFee = fee
        
    }
    
    func getQRCode() {
        
        let stringURL = qrScanner.stringToReturn
        processKeys(key: stringURL)
        
    }
    
    // MARK: User Actions
    
    @objc func close() {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    func showRaw(raw: String) {
        
        DispatchQueue.main.async {
            
            self.rawDisplayer.rawString = raw
            self.rawDisplayer.vc = self
            
            self.rawDisplayer.closeButton.addTarget(self, action: #selector(self.close),
                                                    for: .touchUpInside)
            
            self.rawDisplayer.decodeButton.addTarget(self, action: #selector(self.decode),
                                                for: .touchUpInside)
            
            self.tapQRGesture = UITapGestureRecognizer(target: self,
                                                  action: #selector(self.shareQRCode(_:)))
            
            self.rawDisplayer.qrView.addGestureRecognizer(self.tapQRGesture)
            
            self.tapTextViewGesture = UITapGestureRecognizer(target: self,
                                                        action: #selector(self.shareRawText(_:)))
            
            self.rawDisplayer.textView.addGestureRecognizer(self.tapTextViewGesture)
            
            self.amountInput.removeFromSuperview()
            self.scannerView.removeFromSuperview()
            self.creatingView.removeConnectingView()
            let background = UIView()
            background.frame = self.view.frame
            background.backgroundColor = self.view.backgroundColor
            self.view.addSubview(background)
            self.rawDisplayer.addRawDisplay()
            
        }
        
    }
    @IBAction func tryRawNow(_ sender: Any) {
        
        tryRaw()
        
    }
    
    @objc func tryRaw() {
        
        //if (self.amountInput.text?.toDouble())! <= self.spendable {
            
            func getChangeAddress() {
                
                self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.getrawchangeaddress,
                                           param: "")
                
            }
            
            /*if sweep {
                
                getChangeAddress()
                
            } else {*/
                
                if self.amountInput.text != "" {
                    
                    let dbl = self.amountInput.text?.toDouble()
                    
                    if dbl != nil && dbl! > 0.0 {
                        
                        self.amount = self.amountInput.text!
                        
                        if self.amount.hasPrefix(".") {
                            
                            self.amount = "0" + self.amount
                            
                        }
                        
                        DispatchQueue.main.async {
                            
                            self.amountInput.resignFirstResponder()
                            
                            self.creatingView.addConnectingView(vc: self,
                                                                description: "Creating Raw")
                            
                        }
                        
                        getChangeAddress()
                        
                    } else {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "Only valid numbers allowed.")
                        
                        DispatchQueue.main.async {
                            
                            self.creatingView.removeConnectingView()
                            
                            self.amountInput.text = ""
                            
                        }
                        
                    }
                    
                } else {
                    
                    shakeAlert(viewToShake: amountInput)
                    
                }
                
            //}
            
        /*} else {
            
            self.amountInput.text = ""
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Not enough funds")
            
        }*/
        
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
            self.qrGenerator.backColor = UIColor.white
            self.qrGenerator.foreColor = UIColor.black
            let qrImage = self.qrGenerator.getQRCode()
            let objectsToShare = [qrImage]
                
            let activityController = UIActivityViewController(activityItems: objectsToShare,
                                                              applicationActivities: nil)
            
            activityController.completionWithItemsHandler = { (type,completed,items,error) in }
            activityController.popoverPresentationController?.sourceView = self.view
            self.present(activityController, animated: true) {}
            
        }
        
    }
    
    func didPickImage() {
        
        let qrString = qrScanner.qrString
        processKeys(key: qrString)
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        qrScanner.chooseQRCodeFromLibrary()
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        amountInput.resignFirstResponder()
        addressInput.resignFirstResponder()
        
    }
    
    @objc func nextButtonAction() {
        
        self.view.endEditing(true)
        
    }
    
    @IBAction func backAction(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    @objc func sweepButtonClicked() {
        
        self.amountInput.resignFirstResponder()
        
        executeNodeCommandSsh(method: BTC_CLI_COMMAND.listunspent,
                              param: "")
        
    }
    
    @objc func decode() {
        
        print("decode")
        
        self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.decoderawtransaction,
                                   param: "\"\(self.rawTxSigned)\"")
        
    }
    
    @objc func encodeText() {
        print("encodeText")
        
        DispatchQueue.main.async {
            
            self.rawDisplayer.textView.text = self.rawTxSigned
            self.rawDisplayer.decodeButton.setTitle("Decode", for: .normal)
            
            self.rawDisplayer.decodeButton.removeTarget(self, action: #selector(self.encodeText),
                                           for: .touchUpInside)
            
            self.rawDisplayer.decodeButton.addTarget(self, action: #selector(self.decode),
                                        for: .touchUpInside)
            
        }
        
    }
    
    //MARK: User Interface
    
    func addShadow(view: UIView) {
        
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 1.5, height: 1.5)
        view.layer.shadowRadius = 1.5
        view.layer.shadowOpacity = 0.5
        
    }
    
    func generateQrCode(key: String) -> UIImage {
        
        self.qrGenerator.textInput = key
        self.qrGenerator.backColor = UIColor.clear
        self.qrGenerator.foreColor = UIColor.white
        let imageToReturn = self.qrGenerator.getQRCode()
        
        return imageToReturn
        
    }
    
    @objc func closeScanner() {
        print("back")
        
        DispatchQueue.main.async {
            
            self.scannerView.alpha = 0
            self.scannerShowing = false
            
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
    
    @objc func toggleTorch() {
        
        if isTorchOn {
            
            qrScanner.toggleTorch(on: false)
            isTorchOn = false
            
        } else {
            
            qrScanner.toggleTorch(on: true)
            isTorchOn = true
            
        }
        
    }
    
    //MARK: Textfield methods
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        print("shouldChangeCharactersInRange")
        
        if (textField.text?.contains("."))! {
            
           let decimalCount = (textField.text?.components(separatedBy: ".")[1])?.count
            
            if decimalCount! <= 7 {
                
                
            } else {
                
                DispatchQueue.main.async {
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "Only 8 decimal places allowed")
                    
                    self.amountInput.text = ""
                    
                }
                
            }
            
        }
        
        return true
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        if textField == addressInput && addressInput.text != "" {
            
            processKeys(key: addressInput.text!)
            
        } else if textField == self.amountInput && self.amountInput.text != "" {
            
            self.amountInput.resignFirstResponder()
            
        } else if textField == addressInput && addressInput.text == "" {
            
            shakeAlert(viewToShake: self.qrScanner.textField)
            
        }
        
        return true
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        if isTorchOn {
            
            toggleTorch()
            
        }
        
    }
    
    //MARK: Helpers
    
    func processBIP21(url: String) {
        
        let addressParser = AddressParser()
        let errorBool = addressParser.parseAddress(url: url).errorBool
        let errorDescription = addressParser.parseAddress(url: url).errorDescription
        
        if !errorBool {
            
            self.address = addressParser.parseAddress(url: url).address
            self.amount = "\(addressParser.parseAddress(url: url).amount)"
            
            DispatchQueue.main.async {
                
                self.addressInput.resignFirstResponder()
                self.amountInput.resignFirstResponder()
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    for blur in self.blurArray {
                        
                        blur.alpha = 0
                        
                    }
                    
                    self.blurView.alpha = 0
                    self.qrImageView.alpha = 0
                    self.qrScanner.alpha = 0
                
                }, completion: { _ in
                    
                    for blur in self.blurArray{
                        
                        blur.removeFromSuperview()
                        
                    }
                    
                    self.blurView.removeFromSuperview()
                    self.qrScanner.removeScanner()
                    
                    if self.isTorchOn {
                        
                        self.toggleTorch()
                        
                    }
                    
                    DispatchQueue.main.async {
                        
                        if self.amount != "" && self.amount != "0.0" {
                            
                            self.amountInput.text = self.amount
                            
                        }
                        
                        self.addressInput.text = self.address
                        
                        if self.amountInput.text != "" {
                            
                            self.tryRaw()
                            
                        }
                        
                    }
                    
                })
                
            }
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: errorDescription)
            
        }
        
    }
    
    enum error: Error {
        
        case noCameraAvailable
        case videoInputInitFail
        
    }
    
    func processKeys(key: String) {
        
        self.processBIP21(url: key)
        
    }
    
    func convertMiningFeeToDouble(miningFeeCheck: String) -> Double {
        
        let miningFeeString = miningFeeCheck.replacingOccurrences(of: ",",
                                                                  with: "")
        
        return (Double(miningFeeString)!) / 100000000
        
    }
    
    //MARK: Result Parsers
    
    func getSmartFee() {
        
        let getSmartFee = GetSmartFee()
        getSmartFee.rawSigned = rawTxSigned
        getSmartFee.ssh = ssh
        getSmartFee.makeSSHCall = makeSSHCall
        getSmartFee.vc = self
        getSmartFee.getSmartFee()
        
    }
    
    func getRawTx(changeAddress: String) {
        print("getRawTx")
        
        let rawTransaction = RawTransaction()
        rawTransaction.addressToPay = self.address
        rawTransaction.changeAddress = changeAddress
        rawTransaction.miningFee = self.miningFee
        rawTransaction.amount = Double(self.amount)!
        rawTransaction.ssh = self.ssh
        rawTransaction.torClient = self.torClient
        rawTransaction.torRPC = self.torRPC
        rawTransaction.isUsingSSH = self.isUsingSSH
        
        func getResult() {
            
            if !rawTransaction.errorBool {
                
                rawTxSigned = rawTransaction.signedRawTx
                showRaw(raw: rawTxSigned)
                getSmartFee()
                
            } else {
                
                creatingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: rawTransaction.errorDescription)
                
            }
            
        }
        
        rawTransaction.createRawTransaction(completion: getResult)
        
    }
    
    func parseDecodedTx(decodedTx: NSDictionary) {
        
        DispatchQueue.main.async {
            
            self.rawDisplayer.textView.text = "\(decodedTx)"
            self.rawDisplayer.decodeButton.setTitle("Encode", for: .normal)
            
            self.rawDisplayer.decodeButton.removeTarget(self, action: #selector(self.decode),
                                           for: .touchUpInside)
            
            self.rawDisplayer.decodeButton.addTarget(self, action: #selector(self.encodeText),
                                        for: .touchUpInside)
            
        }
        
    }
    
    //MARK: SSH Commands
    
    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        if !isUsingSSH {
            
            executeNodeCommandTor(method: method,
                                  param: param)
            
        } else {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.decoderawtransaction:
                        
                        let decodedTx = makeSSHCall.dictToReturn
                        parseDecodedTx(decodedTx: decodedTx)
                        
                    case BTC_CLI_COMMAND.getrawchangeaddress:
                        
                        let changeAddress = makeSSHCall.stringToReturn
                        self.getRawTx(changeAddress: changeAddress)
                        
                    case BTC_CLI_COMMAND.listunspent:
                        
                        self.spendableBalance = 0.0
                        let utxos = makeSSHCall.arrayToReturn
                        self.parseUnpsent(utxos: utxos)
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    DispatchQueue.main.async {
                        
                        self.creatingView.removeConnectingView()
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: self.makeSSHCall.errorDescription)
                        
                    }
                    
                }
                
            }
            
            if self.ssh.session.isConnected {
                
                makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                              method: method,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                creatingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Not connected")
                
            }
            
        }
        
    }
    
    // MARK: Tor RPC Commands
    
    func executeNodeCommandTor(method: BTC_CLI_COMMAND, param: Any) {
        
        func getResult() {
            
            if !torRPC.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.decoderawtransaction:
                    
                    let decodedTx = torRPC.dictToReturn
                    parseDecodedTx(decodedTx: decodedTx)
                    
                case BTC_CLI_COMMAND.getrawchangeaddress:
                    
                    let changeAddress = torRPC.stringToReturn
                    self.getRawTx(changeAddress: changeAddress)
                    
                case BTC_CLI_COMMAND.listunspent:
                    
                    self.spendableBalance = 0.0
                    let utxos = makeSSHCall.arrayToReturn
                    self.parseUnpsent(utxos: utxos)
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.creatingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: self.makeSSHCall.errorDescription)
                    
                }
                
            }
            
        }
        
        if self.torClient.isOperational {
            
            self.torRPC.executeRPCCommand(method: method,
                                          param: param,
                                          completion: getResult)
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Tor not connected")
            
        }
        
    }
    
}

extension String {
    func toDouble() -> Double? {
        return NumberFormatter().number(from: self)?.doubleValue
    }
}



