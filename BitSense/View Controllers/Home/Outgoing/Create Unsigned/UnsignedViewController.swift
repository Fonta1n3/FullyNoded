//
//  UnsignedViewController.swift
//  BitSense
//
//  Created by Peter on 30/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class UnsignedViewController: UIViewController, UITextFieldDelegate {
    
    let addressParser = AddressParser()
    let qrScanner = QRScanner()
    let qrGenerator = QRGenerator()
    let rawDisplayer = RawDisplayer()
    let creatingView = ConnectingView()
    let createUnsigned = CreateUnsigned()
    
    var torRPC:MakeRPCCall!
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var torClient:TorClient!
    var isUsingSSH = IsUsingSSH.sharedInstance
    
    var isFirstTime = Bool()
    var isTorchOn = Bool()
    var blurArray = [UIVisualEffectView]()
    
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var scannerShowing = false
    var unsignedTx = ""
    var amount = Double()
    var isSpendingFrom = Bool()
    var isReceiving = Bool()
    var isChange = Bool()
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))

    @IBOutlet var changeField: UITextField!
    @IBOutlet var amountField: UITextField!
    @IBOutlet var spendingField: UITextField!
    @IBOutlet var receivingField: UITextField!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var navBar: UINavigationBar!
    @IBOutlet var amountOutlet: UILabel!
    @IBOutlet var recOutlet: UILabel!
    @IBOutlet var recButtonOutlet: UIButton!
    @IBOutlet var addressOutlet: UILabel!
    @IBOutlet var addressButtOutlet: UIButton!
    @IBOutlet var changeOutlet: UILabel!
    @IBOutlet var changeButtOutlet: UIButton!
    
    @IBAction func scanChange(_ sender: Any) {
        
        print("scanChange")
        isSpendingFrom = false
        isReceiving = false
        isChange = true
        scanNow()
        
    }
    
    @IBAction func scanSpendingFrom(_ sender: Any) {
        
        print("scanSpendingFrom")
        isSpendingFrom = true
        isReceiving = false
        isChange = false
        scanNow()
        
    }
    
    @IBAction func scanReceiving(_ sender: Any) {
        
        print("scanReceiving")
        isReceiving = true
        isSpendingFrom = false
        isChange = false
        scanNow()
        
    }
    
    @IBAction func createRaw(_ sender: Any) {
        
        print("createRaw")
        
        if receivingField.text != "" && amountField.text != "" && changeField.text != "" && spendingField.text != ""{
            
            self.creatingView.addConnectingView(vc: self,
                                                description: "Creating Unsigned")
            
            createUnsigned.ssh = self.ssh
            createUnsigned.amount = Double(amountField.text!)!
            createUnsigned.changeAddress = changeField.text!
            createUnsigned.addressToPay = receivingField.text!
            createUnsigned.spendingAddress = spendingField.text!
            createUnsigned.makeSSHCall = self.makeSSHCall
            createUnsigned.torClient = self.torClient
            createUnsigned.torRPC = self.torRPC
            createUnsigned.isUsingSSH = self.isUsingSSH
            
            func getResult() {
                
                if !createUnsigned.errorBool {
                    
                    DispatchQueue.main.async {
                        
                        self.receivingField.removeFromSuperview()
                        self.spendingField.removeFromSuperview()
                        self.changeField.removeFromSuperview()
                        self.amountField.removeFromSuperview()
                        self.navBar.removeFromSuperview()
                        self.amountOutlet.removeFromSuperview()
                        self.recOutlet.removeFromSuperview()
                        self.recButtonOutlet.removeFromSuperview()
                        self.addressOutlet.removeFromSuperview()
                        self.addressButtOutlet.removeFromSuperview()
                        self.changeOutlet.removeFromSuperview()
                        self.changeButtOutlet.removeFromSuperview()
                        
                    }
                    
                    displayRaw(raw: createUnsigned.unsignedRawTx)
                    
                } else {
                    
                    creatingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: createUnsigned.errorDescription)
                    
                }
                
            }
            
            createUnsigned.createRawTransaction(completion: getResult)
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Ooops, you need to fill out an amount and recipient address")
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        amountField.delegate = self
        changeField.delegate = self
        receivingField.delegate = self
        spendingField.delegate = self

        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        imageView.alpha = 0
        imageView.backgroundColor = UIColor.black
        
        configureScanner()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        isUsingSSH = IsUsingSSH.sharedInstance
        
        if isUsingSSH {
            
            ssh = SSHService.sharedInstance
            makeSSHCall = SSHelper.sharedInstance
            
        } else {
            
            torRPC = MakeRPCCall.sharedInstance
            torClient = TorClient.sharedInstance
            
        }
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            self.amountField.resignFirstResponder()
            self.spendingField.resignFirstResponder()
            self.receivingField.resignFirstResponder()
            self.changeField.resignFirstResponder()
            
        }
        
    }
    
    func rounded(number: Double) -> Double {
        
        return Double(round(100000000*number)/100000000)
        
    }
    
    func removeSpinner() {
        
        DispatchQueue.main.async {
            
            self.creatingView.removeConnectingView()
            
        }
        
    }
    
    // MARK: QR SCANNER METHODS
    
    func scanNow() {
        print("scanNow")
        
        scannerShowing = true
        hideKeyboards()
        
        if isFirstTime {
            
            DispatchQueue.main.async {
                    
                self.qrScanner.scanQRCode()
                self.addScannerButtons()
                self.imageView.addSubview(self.qrScanner.closeButton)
                self.isFirstTime = false
                    
                UIView.animate(withDuration: 0.3, animations: {
                        
                    self.imageView.alpha = 1
                        
                })
                    
            }
            
        } else {
            
            self.qrScanner.startScanner()
            self.addScannerButtons()
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                })
                
            }
            
        }
        
    }
    
    func configureScanner() {
        
        isFirstTime = true
        
        imageView.alpha = 0
        imageView.frame = view.frame
        imageView.isUserInteractionEnabled = true
        
        qrScanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.keepRunning = false
        qrScanner.vc = self
        qrScanner.imageView = imageView
        qrScanner.textField.alpha = 0
        
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        qrScanner.downSwipeAction = { self.back() }
        
        qrScanner.uploadButton.addTarget(self,
                                         action: #selector(self.chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.torchButton.addTarget(self,
                                        action: #selector(toggleTorch),
                                        for: .touchUpInside)
        
        isTorchOn = false
        
        
        qrScanner.closeButton.addTarget(self,
                                        action: #selector(back),
                                        for: .touchUpInside)
        
    }
    
    func addScannerButtons() {
        
        self.addBlurView(frame: CGRect(x: self.imageView.frame.maxX - 80,
                                       y: self.imageView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.qrScanner.uploadButton)
        
        self.addBlurView(frame: CGRect(x: 10,
                                       y: self.imageView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.qrScanner.torchButton)
        
    }
    
    @objc func back() {
        print("back")
        
        DispatchQueue.main.async {
            
            self.imageView.alpha = 0
            self.scannerShowing = false
            
        }
        
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
    
    func addBlurView(frame: CGRect, button: UIButton) {
        
        button.removeFromSuperview()
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        self.imageView.addSubview(blur)
        
    }
    
    func getQRCode() {
        
        let stringURL = qrScanner.stringToReturn
        parseAddress(address: stringURL)
        
    }
    
    func didPickImage() {
        
        let qrString = qrScanner.qrString
        parseAddress(address: qrString)
        
    }
    
    func parseAddress(address: String) {
        
        addressParser.url = address
        let address = addressParser.parseAddress(url: address).address
        let errorBool = addressParser.parseAddress(url: address).errorBool
        let errorDescription = addressParser.parseAddress(url: address).errorDescription
        
        if !errorBool {
            
            if isSpendingFrom {
                
                DispatchQueue.main.async {
                    
                    self.back()
                    self.spendingField.text = address
                    print("update spending")
                    
                }
                
            }
            
            if isReceiving {
                
                DispatchQueue.main.async {
                    
                    self.back()
                    self.receivingField.text = address
                    print("update receiving")
                    
                }
                
            }
            
            if isChange {
                
                DispatchQueue.main.async {
                    
                    self.back()
                    self.changeField.text = address
                    print("update change")
                    
                }
                
            }
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: errorDescription)
            
        }
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        qrScanner.chooseQRCodeFromLibrary()
        
    }
    
    @objc func close() {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
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
            
            let textToShare = [self.unsignedTx]
            
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
            
            self.qrGenerator.textInput = self.unsignedTx
            let qrImage = self.qrGenerator.getQRCode()
            let objectsToShare = [qrImage]
            
            let activityController = UIActivityViewController(activityItems: objectsToShare,
                                                              applicationActivities: nil)
            
            activityController.completionWithItemsHandler = { (type,completed,items,error) in }
            activityController.popoverPresentationController?.sourceView = self.view
            self.present(activityController, animated: true) {}
            
        }
        
    }
    
    func displayRaw(raw: String) {
        
        DispatchQueue.main.async {
            
            self.rawDisplayer.titleString = "Unsigned Raw Transaction"
            self.rawDisplayer.rawString = raw
            self.unsignedTx = raw
            self.rawDisplayer.vc = self
            
            self.tapQRGesture = UITapGestureRecognizer(target: self,
                                                       action: #selector(self.shareQRCode(_:)))
            
            self.rawDisplayer.qrView.addGestureRecognizer(self.tapQRGesture)
            
            self.tapTextViewGesture = UITapGestureRecognizer(target: self,
                                                        action: #selector(self.shareRawText(_:)))
            
            self.rawDisplayer.textView.addGestureRecognizer(self.tapTextViewGesture)
            
            self.qrScanner.removeFromSuperview()
            self.imageView.removeFromSuperview()
            
            
            let backView = UIView()
            backView.frame = self.view.frame
            backView.backgroundColor = self.view.backgroundColor
            self.view.addSubview(backView)
            self.creatingView.removeConnectingView()
            self.rawDisplayer.addRawDisplay()
            
        }
        
    }
    
    // MARK: TEXTFIELD METHODS
    
    func hideKeyboards() {
        
        receivingField.resignFirstResponder()
        spendingField.resignFirstResponder()
        amountField.resignFirstResponder()
        changeField.resignFirstResponder()
        
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        if textField == receivingField  {
            
            isReceiving = true
            isSpendingFrom = false
            isChange = false
            
        } else if textField == spendingField {
            
            isSpendingFrom = true
            isReceiving = false
            isChange = false
            
        } else if textField == changeField {
            
            isChange = true
            isReceiving = false
            isSpendingFrom = false
            
        }
        
        if textField.text != "" {
            
            textField.becomeFirstResponder()
            
        } else {
            
            if let string = UIPasteboard.general.string {
                
                textField.becomeFirstResponder()
                textField.text = string
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textField.resignFirstResponder()
                }
                
            } else {
                
                textField.becomeFirstResponder()
                
            }
            
        }
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        textField.endEditing(true)
        return true
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        print("textFieldDidEndEditing")
        
        if textField == receivingField && receivingField.text != "" && isReceiving {
            
            let address = receivingField.text!
            addressParser.url = address
            parseAddress(address: address)
            
        } else if textField == spendingField && spendingField.text != "" && isSpendingFrom {
            
            let address = spendingField.text!
            addressParser.url = address
            parseAddress(address: address)
            
        } else if textField == changeField && changeField.text != "" && isChange {
            
            let address = changeField.text!
            addressParser.url = address
            parseAddress(address: address)
            
        } else if textField == amountField && amountField.text != "" {
            
            if let amountCheck = Double(amountField.text!) {
                
                self.amount = amountCheck
                
            } else {
                
                amountField.text = ""
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Only valid numbers allowed")
                
            }
            
        } else {
            
            //shakeAlert(viewToShake: textField)
            
        }
        
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        if textView.text != "" {
            
            textView.becomeFirstResponder()
            
        } else {
            
            if let string = UIPasteboard.general.string {
                
                textView.becomeFirstResponder()
                textView.text = string
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textView.resignFirstResponder()
                }
                
            } else {
                
                textView.becomeFirstResponder()
                
            }
            
        }
        
    }

}
