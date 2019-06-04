//
//  CreateRawTxViewController.swift
//  BitSense
//
//  Created by Peter on 09/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit

class CreateRawTxViewController: UIViewController, UITextFieldDelegate {
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark))
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var qrCode = UIImage()
    var ssh:SSHService!
    let pushButton = UIButton()
    var spendable = Double()
    var changeAmount = Double()
    var rawTxUnsigned = String()
    var rawTxSigned = String()
    var amountAvailable = Double()
    var changeAddress = String()
    let amountInput = UITextField()
    let qrImageView = UIImageView()
    var stringURL = String()
    var address = String()
    let nextButton = UIButton()
    var amount = String()
    var blurArray = [UIVisualEffectView]()
    let rawDisplayer = RawDisplayer()
    
    let sweepButtonView = Bundle.main.loadNibNamed("KeyPadButtonView",
                                                   owner: self,
                                                   options: nil)?.first as! UIView?
    var sweep = Bool()
    var makeSSHCall:SSHelper!
    var creatingView = ConnectingView()
    let qrScanner = QRScanner()
    @IBOutlet var scannerView: UIImageView!
    var isTorchOn = Bool()
    let qrGenerator = QRGenerator()
    @IBOutlet var backImage: UIImageView!
    var miningFee = Double()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("CreateRawTxViewController")
        
        qrScanner.textField.delegate = self
        amountInput.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sweepButtonClicked),
                                               name: NSNotification.Name(rawValue: "buttonClickedNotification"),
                                               object: nil)
        
        addShadow(view: backImage)
        
        getAddress()
        
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
            
            self.rawDisplayer.closeButton.addTarget(self, action: #selector(self.close), for: .touchUpInside)
            
            self.rawDisplayer.decodeButton.addTarget(self, action: #selector(self.decode),
                                                for: .touchUpInside)
            
            self.tapQRGesture = UITapGestureRecognizer(target: self,
                                                  action: #selector(self.shareQRCode(_:)))
            
            self.rawDisplayer.qrView.addGestureRecognizer(self.tapQRGesture)
            
            self.tapTextViewGesture = UITapGestureRecognizer(target: self,
                                                        action: #selector(self.shareRawText(_:)))
            
            self.rawDisplayer.textView.addGestureRecognizer(self.tapTextViewGesture)
            
            self.nextButton.alpha = 0
            self.backImage.alpha = 0
            self.amountInput.removeFromSuperview()
            self.scannerView.removeFromSuperview()
            self.creatingView.removeConnectingView()
            self.rawDisplayer.addRawDisplay()
            
        }
        
    }
    
    @objc func tryRawNow() {
        
        func getChangeAddress() {
            
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.getrawchangeaddress,
                                       param: "")
            
        }
     
        if sweep {
            
            getChangeAddress()
            
        } else {
            
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
        
        qrScanner.textField.resignFirstResponder()
        
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
        print("sweep button clicked")
        
        self.amountInput.resignFirstResponder()
        sweep = true
        tryRawNow()
        
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
    
    func addNextButton(inputView: UITextField) {
        
        DispatchQueue.main.async {
            
            self.nextButton.removeFromSuperview()
            
            self.nextButton.frame = CGRect(x: self.view.center.x - 40,
                                           y: inputView.frame.maxY + 10,
                                           width: 80,
                                           height: 55)
            
            self.nextButton.showsTouchWhenHighlighted = true
            self.nextButton.setTitle("Next", for: .normal)
            self.nextButton.setTitleColor(UIColor.white, for: .normal)
            
            self.nextButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Bold",
                                                           size: 20)
            
            self.nextButton.addTarget(self, action: #selector(self.tryRawNow),
                                      for: .touchUpInside)
            
            self.view.addSubview(self.nextButton)
            
        }
        
    }
    
    func getAddress() {
        
        blurView.frame = CGRect(x: view.frame.minX + 10,
                                y: 80,
                                width: view.frame.width - 20,
                                height: 50)
        
        blurView.layer.cornerRadius = 10
        blurView.clipsToBounds = true
        
        qrScanner.textFieldPlaceholder = "scan address or type/paste here"
        
        qrScanner.uploadButton.addTarget(self,
                                         action: #selector(self.chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.torchButton.addTarget(self,
                                        action: #selector(toggleTorch),
                                        for: .touchUpInside)
        
        isTorchOn = false
        
        qrScanner.vc = self
        scannerView.frame = view.frame
        qrScanner.imageView = scannerView
        qrScanner.scanQRCode()
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        
        DispatchQueue.main.async {
            
            self.view.addSubview(self.blurView)
            self.blurView.contentView.addSubview(self.qrScanner.textField)
            
            self.addBlurView(frame: CGRect(x: self.view.frame.maxX - 80,
                                      y: self.view.frame.maxY - 80,
                                      width: 70,
                                      height: 70), button: self.qrScanner.uploadButton)
            
            self.addBlurView(frame: CGRect(x: 10,
                                      y: self.view.frame.maxY - 80,
                                      width: 70,
                                      height: 70), button: self.qrScanner.torchButton)
            
        }
        
    }
    
    func addBlurView(frame: CGRect, button: UIButton) {
        
        button.removeFromSuperview()
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark))
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
        
        if textField == qrScanner.textField && qrScanner.textField.text != "" {
            
            processKeys(key: qrScanner.textField.text!)
            
        } else if textField == self.amountInput && self.amountInput.text != "" {
            
            self.amountInput.resignFirstResponder()
            
        } else if textField == self.qrScanner.textField && self.qrScanner.textField.text == "" {
            
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
                
                self.qrScanner.textField.resignFirstResponder()
                self.amountInput.alpha = 0
                
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
                    
                    self.configureAmountInput()
                    self.view.addSubview(self.amountInput)
                    self.addNextButton(inputView: self.amountInput)
                    
                    DispatchQueue.main.async {
                        
                        UIView.animate(withDuration: 0.2, animations: {
                            
                            self.amountInput.alpha = 1
                            
                        }) { _ in
                            
                            DispatchQueue.main.async {
                                
                                if self.amount != "" && self.amount != "0.0" {
                                    
                                    self.amountInput.text = self.amount
                                    
                                }
                                
                                let impact = UIImpactFeedbackGenerator()
                                impact.impactOccurred()
                                
                            }
                            
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
    
    func configureAmountInput() {
        
        amountInput.placeholder = "Amount in BTC"
        amountInput.keyboardType = UIKeyboardType.decimalPad
        amountInput.textColor = UIColor.white
        
        amountInput.frame = CGRect(x: view.frame.minX + 25,
                                        y: 150,
                                        width: view.frame.width - 50,
                                        height: 50)
        
        amountInput.textAlignment = .center
        amountInput.borderStyle = .roundedRect
        amountInput.autocorrectionType = .no
        amountInput.autocapitalizationType = .none
        amountInput.keyboardAppearance = UIKeyboardAppearance.dark
        amountInput.backgroundColor = UIColor.darkGray
        amountInput.returnKeyType = UIReturnKeyType.go
        amountInput.becomeFirstResponder()
        amountInput.inputAccessoryView = sweepButtonView
        
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
        rawTransaction.sweep = self.sweep
        
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
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.decoderawtransaction:
                    
                    let decodedTx = makeSSHCall.dictToReturn
                    parseDecodedTx(decodedTx: decodedTx)
                    
                case BTC_CLI_COMMAND.getbalance:
                    
                    let balanceCheck = makeSSHCall.doubleToReturn
                    self.spendable = balanceCheck
                    
                case BTC_CLI_COMMAND.getrawchangeaddress:
                    
                    let changeAddress = makeSSHCall.stringToReturn
                    self.getRawTx(changeAddress: changeAddress)
                    
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

extension String {
    func toDouble() -> Double? {
        return NumberFormatter().number(from: self)?.doubleValue
    }
}



