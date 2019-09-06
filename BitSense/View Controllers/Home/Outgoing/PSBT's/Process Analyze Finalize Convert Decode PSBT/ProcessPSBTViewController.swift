//
//  ProcessPSBTViewController.swift
//  BitSense
//
//  Created by Peter on 16/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ProcessPSBTViewController: UIViewController {
    
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var torRPC:MakeRPCCall!
    var torClient:TorClient!
    var isUsingSSH = IsUsingSSH.sharedInstance
    
    let rawDisplayer = RawDisplayer()
    var processedPSBT = ""
    let creatingView = ConnectingView()
    let qrScanner = QRScanner()
    let qrGenerator = QRGenerator()
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var isFirstTime = Bool()
    var isTorchOn = Bool()
    var blurArray = [UIVisualEffectView]()
    var scannerShowing = false
    
    var firstLink = ""
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var textView: UITextView!
    
    var process = Bool()
    var finalize = Bool()
    var analyze = Bool()
    var convert = Bool()
    var txChain = Bool()
    var decodePSBT = Bool()
    var decodeRaw = Bool()
    
    var connectingString = ""
    var navBarTitle = ""
    var method:BTC_CLI_COMMAND!
    
    @IBAction func scan(_ sender: Any) {
        
        print("scanNow")
        
        scannerShowing = true
        textView.resignFirstResponder()
        
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
    
    func configureView() {
        
        print("convert = \(convert)")
        
        if process {
            
            method = BTC_CLI_COMMAND.walletprocesspsbt
            connectingString = "processing psbt"
            navBarTitle = "Process PSBT"
            
        }
        
        if analyze {
            
            method = BTC_CLI_COMMAND.analyzepsbt
            connectingString = "analyzing psbt"
            navBarTitle = "Analyze PSBT"
            
        }
        
        if convert {
            
            method = BTC_CLI_COMMAND.converttopsbt
            connectingString = "converting psbt"
            navBarTitle = "Convert PSBT"
            
        }
        
        if finalize {
            
            method = BTC_CLI_COMMAND.finalizepsbt
            connectingString = "finalizing psbt"
            navBarTitle = "Finalize PSBT"
            
        }
        
        if decodePSBT || decodeRaw {
            
            if decodeRaw {
                
                method = BTC_CLI_COMMAND.decoderawtransaction
                
            }
            
            if decodePSBT {
                
                method = BTC_CLI_COMMAND.decodepsbt
                
            }
            
            connectingString = "decoding"
            navBarTitle = "Decode"
            
        }
        
        if txChain {
            
            connectingString = "txchaining"
            navBarTitle = "TXChain"
            
        }
        
        DispatchQueue.main.async {
            
            self.navigationController?.navigationBar.topItem?.title = self.navBarTitle
            
        }
        
    }
    
    
    @IBAction func processNow(_ sender: Any) {
        
        if textView.text != "" {
            
            creatingView.addConnectingView(vc: self,
                                           description: connectingString)
            
            let psbt = textView.text!
            
            if decodePSBT || decodeRaw {
                
                if psbt.hasPrefix("0") || psbt.hasPrefix("1") {
                    
                    method = BTC_CLI_COMMAND.decoderawtransaction
                    
                } else {
                    
                    method = BTC_CLI_COMMAND.decodepsbt
                    
                }
                
            }
            
            if txChain {
                
                addTXChainLink(psbt: textView.text!)
                
            } else {
                
                self.executeNodeCommandSsh(method: method,
                                           param: "\"\(psbt)\"")
                
            }
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "You need to add a PSBT into the text field first")
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureScanner()
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        configureView()
        
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
        
        if firstLink != "" {
            
            displayRaw(raw: firstLink, title: "First Link")
            
        } else {
            
            if let string = UIPasteboard.general.string {
                
                textView.text = string
                
            } else {
                
                textView.becomeFirstResponder()
                
            }
            
        }
        
    }
    
    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.walletprocesspsbt:
                    
                    let dict = makeSSHCall.dictToReturn
                    
                    let isComplete = dict["complete"] as! Bool
                    let processedPSBT = dict["psbt"] as! String
                    
                    creatingView.removeConnectingView()
                    
                    displayRaw(raw: processedPSBT, title: "PSBT")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        
                        if isComplete {
                            
                            displayAlert(viewController: self,
                                         isError: false,
                                         message: "PSBT is complete")
                            
                        } else {
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "PSBT is incomplete")
                            
                        }
                        
                    }
                    
                case BTC_CLI_COMMAND.finalizepsbt:
                    
                    let dict = makeSSHCall.dictToReturn
                    let isComplete = dict["complete"] as! Bool
                    var finalizedPSBT = ""
                    
                    if let check = dict["hex"] as? String {
                        
                        finalizedPSBT = check
                        
                    } else {
                        
                        finalizedPSBT = "error"
                        
                    }
                    
                    creatingView.removeConnectingView()
                    
                    displayRaw(raw: finalizedPSBT, title: "Finalized PSBT")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        
                        if isComplete {
                            
                            displayAlert(viewController: self,
                                         isError: false,
                                         message: "PSBT is finalized")
                            
                        } else {
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "PSBT is incomplete")
                            
                        }
                        
                    }
                    
                case BTC_CLI_COMMAND.analyzepsbt:
                    
                    let dict = makeSSHCall.dictToReturn
                    creatingView.removeConnectingView()
                    
                    DispatchQueue.main.async {
                        
                        self.textView.text = "\(dict)"
                        
                    }
                    
                case BTC_CLI_COMMAND.converttopsbt:
                    
                    let psbt = makeSSHCall.stringToReturn
                    creatingView.removeConnectingView()
                    
                    DispatchQueue.main.async {
                        
                        self.displayRaw(raw: psbt, title: "PSBT")
                        
                    }
                    
                case BTC_CLI_COMMAND.decodepsbt:
                    
                    let dict = makeSSHCall.dictToReturn
                    creatingView.removeConnectingView()
                    
                    DispatchQueue.main.async {
                        
                        self.textView.text = "\(dict)"
                        
                    }
                    
                case BTC_CLI_COMMAND.decoderawtransaction:
                    
                    let dict = makeSSHCall.dictToReturn
                    creatingView.removeConnectingView()
                    
                    DispatchQueue.main.async {
                        
                        self.textView.text = "\(dict)"
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                creatingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: makeSSHCall.errorDescription)
                
            }
            
        }
        
        if ssh != nil {
            
            if ssh.session.isConnected {
                
                makeSSHCall.executeSSHCommand(ssh: ssh,
                                              method: method,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                creatingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "SSH not connected")
                
            }
            
        } else {
            
            creatingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "SSH not connected")
            
        }
        
    }
    
    func displayRaw(raw: String, title: String) {
        
        DispatchQueue.main.async {
            
            self.navigationController?.navigationBar.topItem?.title = title
            self.rawDisplayer.rawString = raw
            self.processedPSBT = raw
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
            
            let textToShare = [self.processedPSBT]
            
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
            
            self.qrGenerator.textInput = self.processedPSBT
            let qrImage = self.qrGenerator.getQRCode()
            let objectsToShare = [qrImage]
            
            let activityController = UIActivityViewController(activityItems: objectsToShare,
                                                              applicationActivities: nil)
            
            activityController.completionWithItemsHandler = { (type,completed,items,error) in }
            activityController.popoverPresentationController?.sourceView = self.view
            self.present(activityController, animated: true) {}
            
        }
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            self.textView.resignFirstResponder()
            
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
    
    @objc func chooseQRCodeFromLibrary() {
        
        qrScanner.chooseQRCodeFromLibrary()
        
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
        
        back()
        let stringURL = qrScanner.stringToReturn
        textView.text = stringURL
        
    }
    
    func didPickImage() {
        
        back()
        let qrString = qrScanner.qrString
        textView.text = qrString
        
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        if textView.text != "" {
            
            textView.becomeFirstResponder()
            
        } else {
            
            if let string = UIPasteboard.general.string {
                
                textView.resignFirstResponder()
                textView.text = string
                
            } else {
                
                textView.becomeFirstResponder()
                
            }
            
        }
        
    }
    
    func addTXChainLink(psbt: String) {
        
        let txChain = TXChain()
        txChain.ssh = self.ssh
        txChain.makeSSHCall = self.makeSSHCall
        txChain.isUsingSSH = self.isUsingSSH
        txChain.torRPC = self.torRPC
        txChain.torClient = self.torClient
        txChain.tx = psbt
        
        func getResult() {
            
            if !txChain.errorBool {
                
                creatingView.removeConnectingView()
                
                let chain = txChain.chainToReturn
                displayRaw(raw: chain, title: "TXChain")
                
                displayAlert(viewController: self,
                             isError: false,
                             message: "Link added to the TXChain!")
                
            } else {
                
                creatingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: txChain.errorDescription)
                
            }
            
        }
        
        txChain.addALink(completion: getResult)
        
    }

}
