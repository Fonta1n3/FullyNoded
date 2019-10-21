//
//  CreatePSBTViewController.swift
//  BitSense
//
//  Created by Peter on 12/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class CreatePSBTViewController: UIViewController, UITextFieldDelegate {
    
    let addressParser = AddressParser()
    let qrScanner = QRScanner()
    let qrGenerator = QRGenerator()
    let rawDisplayer = RawDisplayer()
    let creatingView = ConnectingView()
    
    var isFirstTime = Bool()
    var isTorchOn = Bool()
    var blurArray = [UIVisualEffectView]()
    
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var scannerShowing = false
    var psbt = ""
    var amount = Double()
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var receivingField: UITextField!
    @IBOutlet var amountField: UITextField!
    @IBOutlet var amountOutlet: UILabel!
    @IBOutlet var receivingOutlet: UILabel!
    @IBOutlet var scanOutlet: UIButton!
    @IBOutlet var coldSwitchOutlet: UISwitch!
    @IBOutlet var switchLabel: UILabel!
    
    @IBAction func coldSwitchAction(_ sender: Any) {
        
        if coldSwitchOutlet.isOn {
         
            displayAlert(viewController: self, isError: false, message: "this psbt will include inputs that are watch-only and will still need to be \"updated\" by a wallet that can sign it.")
            
        }
        
    }
    
    
    @IBAction func scanReceiving(_ sender: Any) {
        
        scanNow()
        
    }
    
    @IBAction func goBack(_ sender: Any) {
        
        if !scannerShowing {
            
            DispatchQueue.main.async {
                
                self.dismiss(animated: true, completion: nil)
                
            }
            
        }
        
    }
    
    @IBAction func createPSBT(_ sender: Any) {
        
        print("createPSBT")
        
        if receivingField.text != "" && amountField.text != "" {
            
            let amountToSend = Double(amountField.text!)!
            let receivingAddress = receivingField.text!
            
            creatingView.addConnectingView(vc: self,
                                           description: "creating wallet funded psbt")
            
            let feeTarget = UserDefaults.standard.object(forKey: "feeTarget") as! Int
            let output = "[{\"\(receivingAddress)\":\(amountToSend)}]"
            let param = "[],\(output), 0, {\"includeWatching\": \(coldSwitchOutlet.isOn), \"replaceable\": true, \"conf_target\": \(feeTarget)}, true"
            
            executeNodeCommand(method: .walletcreatefundedpsbt,
                                  param: param)
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "you need to fill out an amount and recipient address")
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        amountField.delegate = self
        receivingField.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        imageView.alpha = 0
        imageView.backgroundColor = UIColor.black
        
        configureScanner()
        coldSwitchOutlet.isOn = false
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            self.amountField.resignFirstResponder()
            self.receivingField.resignFirstResponder()
            
        }
        
    }
    
    func removeViews() {
     
        DispatchQueue.main.async {
            
            self.scanOutlet.removeFromSuperview()
            self.amountOutlet.removeFromSuperview()
            self.amountField.removeFromSuperview()
            self.receivingOutlet.removeFromSuperview()
            self.receivingField.removeFromSuperview()
            self.switchLabel.removeFromSuperview()
            self.coldSwitchOutlet.removeFromSuperview()
            
        }
        
    }
    
    // MARK: NODE COMMANDS
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                switch method {
                    
                case .walletprocesspsbt:
                    
                    let dict = reducer.dictToReturn
                    
                    let isComplete = dict["complete"] as! Bool
                    let processedPSBT = dict["psbt"] as! String
                    
                    self.removeViews()
                    
                    creatingView.removeConnectingView()
                    
                    displayRaw(raw: processedPSBT)
                    
                    //convertPSBTtoData(string: processedPSBT)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        
                        if isComplete {
                            
                            displayAlert(viewController: self,
                                         isError: false,
                                         message: "psbt is complete")
                            
                        } else {
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "psbt is incomplete")
                            
                        }
                        
                    }
                    
                case .walletcreatefundedpsbt:
                    
                    let result = reducer.dictToReturn
                    let psbt = result["psbt"] as! String
                    
                    self.executeNodeCommand(method: BTC_CLI_COMMAND.walletprocesspsbt,
                                               param: "\"\(psbt)\"")
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.removeSpinner()
                    
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
    
    func convertPSBTtoData(string: String) {
     
        if let data = Data(base64Encoded: string) {
         
            DispatchQueue.main.async {
                
                let activityViewController = UIActivityViewController(activityItems: [data],
                                                                      applicationActivities: nil)
                
                activityViewController.popoverPresentationController?.sourceView = self.view
                self.present(activityViewController, animated: true) {}
                
            }
            
        }
        
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
            
            DispatchQueue.main.async {
                
                self.back()
                self.receivingField.text = address
                
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
            
            let alert = UIAlertController(title: "Share as raw data or text?", message: "Sharing as raw data allows you to send the unsigned psbt directly to your Coldcard Wallets SD card for signing", preferredStyle: .actionSheet)
            
            alert.addAction(UIAlertAction(title: "Raw Data", style: .default, handler: { action in
                
                self.convertPSBTtoData(string: self.psbt)
                
            }))
            
            alert.addAction(UIAlertAction(title: "Text", style: .default, handler: { action in
                
                DispatchQueue.main.async {
                    
                    let textToShare = [self.psbt]
                    
                    let activityViewController = UIActivityViewController(activityItems: textToShare,
                                                                          applicationActivities: nil)
                    
                    activityViewController.popoverPresentationController?.sourceView = self.view
                    self.present(activityViewController, animated: true) {}
                    
                }
                
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                
            }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
            
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
            
            self.qrGenerator.textInput = self.psbt
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
            
            self.navigationController?.navigationBar.topItem?.title = "PSBT"
            self.rawDisplayer.rawString = raw
            self.psbt = raw
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
        amountField.resignFirstResponder()
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        textField.endEditing(true)
        return true
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        print("textFieldDidEndEditing")
        
        if textField == receivingField && receivingField.text != "" {
            
            let address = receivingField.text!
            addressParser.url = address
            parseAddress(address: address)
            
        } else if textField == amountField && amountField.text != "" {
            
            if let amountCheck = Double(amountField.text!) {
                
                self.amount = amountCheck
                
            } else {
                
                amountField.text = ""
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "only valid numbers allowed")
                
            }
            
        } else {
            
            //shakeAlert(viewToShake: textField)
            
        }
        
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        if textField != amountField {
            
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
        
    }

}
