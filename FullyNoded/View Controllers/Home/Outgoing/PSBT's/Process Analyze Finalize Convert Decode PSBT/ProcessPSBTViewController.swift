//
//  ProcessPSBTViewController.swift
//  BitSense
//
//  Created by Peter on 16/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ProcessPSBTViewController: UIViewController {
    
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
    var verify = Bool()
    var finalize = Bool()
    var analyze = Bool()
    var convert = Bool()
    var txChain = Bool()
    var decodePSBT = Bool()
    var broadcast = Bool()
    var decodeRaw = Bool()
    var connectingString = ""
    var navBarTitle = ""
    var method:BTC_CLI_COMMAND!
    
    var outputsString = ""
    var inputsString = ""
    var inputArray = [[String:Any]]()
    var index = Int()
    var inputTotal = Double()
    var outputTotal = Double()
    
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
        
        if verify {
            
            method = .decoderawtransaction
            connectingString = "verifying"
            navBarTitle = "Verify"
            
        }
        
        if broadcast {
            
            method = .sendrawtransaction
            connectingString = "broadcasting"
            navBarTitle = "Broadcast"
            
        }
        
        if process {
            
            method = .walletprocesspsbt
            connectingString = "processing psbt"
            navBarTitle = "Process PSBT"
            
        }
        
        if analyze {
            
            method = .analyzepsbt
            connectingString = "analyzing psbt"
            navBarTitle = "Analyze PSBT"
            
        }
        
        if convert {
            
            method = .converttopsbt
            connectingString = "converting psbt"
            navBarTitle = "Convert PSBT"
            
        }
        
        if finalize {
            
            method = .finalizepsbt
            connectingString = "finalizing psbt"
            navBarTitle = "Finalize PSBT"
            
        }
        
        if decodePSBT || decodeRaw {
            
            if decodeRaw {
                
                method = .decoderawtransaction
                
            }
            
            if decodePSBT {
                
                method = .decodepsbt
                
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
                    
                    method = .decoderawtransaction
                    
                } else {
                    
                    method = .decodepsbt
                    
                }
                
            }
            
            if txChain {
                
                //addTXChainLink(psbt: psbt)
                
            } else {
                
                if broadcast {
                    
                    DispatchQueue.main.async { [unowned vc = self] in
                        
                        vc.creatingView.removeConnectingView()
                        
                        let alert = UIAlertController(title: "Broadcast with your node?", message: "You can optionally broadcast this transaction using Blockstream's esplora API over Tor V3 for improved privacy.", preferredStyle: .actionSheet)
                        
                        func success(txid: String) {
                            DispatchQueue.main.async { [unowned vc = self] in
                                displayAlert(viewController: vc, isError: false, message: "Sent ✓")
                                UIPasteboard.general.string = txid
                                vc.creatingView.removeConnectingView()
                                vc.textView.text = "txid: \(txid)"
                            }
                        }
                        
                        alert.addAction(UIAlertAction(title: "Privately", style: .default, handler: { action in
                            
                            vc.creatingView.addConnectingView(vc: vc, description: "broadcasting...")
                            
                            Broadcaster.sharedInstance.send(rawTx: psbt) { [unowned vc = self] (txid) in
                                
                                if txid != nil {
                                    
                                    success(txid: txid!)
                                    
                                } else {
                                    
                                    vc.creatingView.removeConnectingView()
                                    showAlert(vc: self, title: "Error", message: "error broadcasting")
                                    
                                }
                            }
                            
                        }))
                        
                        alert.addAction(UIAlertAction(title: "Use my node", style: .default, handler: { action in
                            
                            vc.creatingView.addConnectingView(vc: vc, description: "broadcasting...")
                            vc.executeNodeCommand(method: vc.method, param: "\"\(psbt)\"")
                            
                        }))
                        
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                        alert.popoverPresentationController?.sourceView = self.view
                        self.present(alert, animated: true) {}
                        
                    }
                    
                } else {
                    
                    self.executeNodeCommand(method: method, param: "\"\(psbt)\"")
                    
                }
                
            }
            
        } else {
            
            creatingView.removeConnectingView()
            showAlert(vc: self, title: "Error", message: "You need to add a PSBT into the text field first")
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        configureScanner()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        configureView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
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
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                case .sendrawtransaction:
                    vc.parseSendRawTx(response: response)
                    
                case .walletprocesspsbt:
                    vc.parseProcessPsbt(response: response)
                    
                case .finalizepsbt:
                    vc.parseFinalizedPsbt(response: response)
                    
                case .analyzepsbt:
                    vc.parseAnalyzedPsbt(response: response)
                    
                case .converttopsbt:
                    vc.parseConvertToPsbt(response: response)
                    
                case .decodepsbt:
                    vc.parseDecodedPsbt(response: response)
                    
                case .decoderawtransaction:
                    vc.parseDecodedTx(response: response)
                    
                default:
                    break
                }
            } else {
                vc.creatingView.removeConnectingView()
                showAlert(vc: vc, title: "Error", message: errorMessage!)
            }
        }
    }
    
    private func parseSendRawTx(response: Any?) {
        if let result = response as? String {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.setTextView(text: "txid: \(result)")
                displayAlert(viewController: vc, isError: false, message: "Sent ✓")
            }
        }
    }
    
    private func parseProcessPsbt(response: Any?) {
        if let dict = response as? NSDictionary {
            let isComplete = dict["complete"] as! Bool
            let processedPSBT = dict["psbt"] as! String
            creatingView.removeConnectingView()
            displayRaw(raw: processedPSBT, title: "PSBT")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [unowned vc = self] in
                if isComplete {
                    displayAlert(viewController: vc, isError: false, message: "PSBT is complete")
                } else {
                    displayAlert(viewController: vc, isError: true, message: "PSBT is incomplete")
                }
            }
        }
    }
    
    private func parseFinalizedPsbt(response: Any?) {
        if let dict = response as? NSDictionary {
            let isComplete = dict["complete"] as! Bool
            var finalizedPSBT = ""
            if let check = dict["hex"] as? String {
                finalizedPSBT = check
                
            } else if let psbt = dict["psbt"] as? String {
                finalizedPSBT = psbt
                
            } else {
                finalizedPSBT = "error"
                
            }
            creatingView.removeConnectingView()
            displayRaw(raw: finalizedPSBT, title: "Finalized PSBT")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [unowned vc = self] in
                if isComplete {
                    displayAlert(viewController: vc, isError: false, message: "PSBT is finalized")
                    
                } else {
                    displayAlert(viewController: vc, isError: true, message: "PSBT is incomplete")
                    
                }
            }
        }
    }
    
    private func parseAnalyzedPsbt(response: Any?) {
        if let dict = response as? NSDictionary {
            setTextView(text: "\(dict)")
        }
    }
    
    private func parseConvertToPsbt(response: Any?) {
        if let psbt = response as? String {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.displayRaw(raw: psbt, title: "PSBT")
                vc.creatingView.removeConnectingView()
            }
        }
    }
    
    private func parseDecodedPsbt(response: Any?) {
        if let dict = response as? NSDictionary {
            setTextView(text: "\(dict)")
        }
    }
    
    private func setTextView(text: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.textView.text = text
            vc.creatingView.removeConnectingView()
        }
    }
    
    private func parseDecodedTx(response: Any?) {
        if let dict = response as? NSDictionary {
            if !verify {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.textView.text = "\(dict)"
                    vc.creatingView.removeConnectingView()
                }
            } else {
                // parse the inputs and outputs and display to user
                parseTransaction(tx: dict)
            }
        }
    }
    
    func parsePrevTx(method: BTC_CLI_COMMAND, param: String, vout: Int) {
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                case .decoderawtransaction:
                    if let txDict = response as? NSDictionary {
                        let outputs = txDict["vout"] as! NSArray
                        vc.parsePrevTxOutput(outputs: outputs, vout: vout)
                    }
                    
                case .gettransaction:
                    if let dict = response as? NSDictionary {
                        let rawTransaction = dict["hex"] as! String
                        vc.parsePrevTx(method: .decoderawtransaction, param: "\"\(rawTransaction)\"", vout: vout)
                    }
                    
                default:
                    break
                }
            } else {
                vc.creatingView.removeConnectingView()
                showAlert(vc: self, title: "Error", message: errorMessage!)
            }
        }
    }
    
    func parsePrevTxOutput(outputs: NSArray, vout: Int) {
        
        for o in outputs {
            
            let output = o as! NSDictionary
            let n = output["n"] as! Int
            
            if n == vout {
                
                //this is our inputs output, get amount and address
                let scriptpubkey = output["scriptPubKey"] as! NSDictionary
                let addresses = scriptpubkey["addresses"] as! NSArray
                let amount = output["value"] as! Double
                var addressString = ""
                
                for a in addresses {
                    
                    addressString += a as! String + " "
                    
                }
                
                inputTotal += amount
                inputsString += "Input #\(index + 1):\nAmount: \(amount.avoidNotation)\nAddress: \(addressString)\n\n"
                
            }
            
        }
        
        if index + 1 < inputArray.count {
            
            index += 1
            getInputInfo(index: index)
            
        } else if index + 1 == inputArray.count {
            
            DispatchQueue.main.async {
                
                let txfee = (self.inputTotal - self.outputTotal).avoidNotation
                let miningFee = "Mining Fee: \(txfee)"
                self.textView.text = self.inputsString + "\n\n\n" + self.outputsString + "\n\n\n" + miningFee
                self.creatingView.removeConnectingView()
                
            }
            
        }
        
    }
    
    func parseTransaction(tx: NSDictionary) {
        
        let inputs = tx["vin"] as! NSArray
        let outputs = tx["vout"] as! NSArray
        parseOutputs(outputs: outputs)
        parseInputs(inputs: inputs, completion: getFirstInputInfo)
        
    }
    
    func getFirstInputInfo() {
        
        index = 0
        getInputInfo(index: index)
        
    }
    
    func getInputInfo(index: Int) {
        
        let dict = inputArray[index]
        
        if let txid = dict["txid"] as? String {
            
            if let vout = dict["vout"] as? Int {
                
                parsePrevTx(method: .gettransaction,
                            param: "\"\(txid)\", true",
                            vout: vout)
                
            }
        }
        
        
    }
    
    func parseInputs(inputs: NSArray, completion: @escaping () -> Void) {
        
        for (index, i) in inputs.enumerated() {
            
            let input = i as! NSDictionary
            print("input = \(input)")
            
            if let txid = input["txid"] as? String {
                
                if let vout = input["vout"] as? Int {
                    
                    let dict = ["inputNumber":index + 1, "txid":txid, "vout":vout as Any] as [String : Any]
                    inputArray.append(dict)
                    
                    if index + 1 == inputs.count {
                        
                        completion()
                        
                    }
                    
                }
                
            } else if let coinbase = input["coinbase"] as? String {
                
                let dict = ["coinbase":coinbase] as [String : Any]
                inputArray.append(dict)
                
                DispatchQueue.main.async { [unowned vc = self] in
                    
                    vc.textView.text = "Coinbase: \(coinbase)" + "\n\n\n" + vc.outputsString
                    vc.creatingView.removeConnectingView()
                    
                }
                
            }
            
        }
        
    }
    
    func parseOutputs(outputs: NSArray) {
        
        for (i, o) in outputs.enumerated() {
            
            let output = o as! NSDictionary
            let scriptpubkey = output["scriptPubKey"] as! NSDictionary
            let addresses = scriptpubkey["addresses"] as? NSArray ?? []
            let amount = output["value"] as! Double
            let number = i + 1
            var addressString = ""
            let type = scriptpubkey["type"] as? String ?? ""
            let hex = scriptpubkey["hex"] as? String ?? ""
            
            for a in addresses {
                
                addressString += a as! String + " "
                
            }
            
            outputTotal += amount
            outputsString += "Output #\(number):\nAmount: \(amount.avoidNotation)\nAddress: \(addressString)\n"
            
            if type == "nulldata" {
                
                if hex != "" {
                    outputsString += "NullData: \(hex)"
                    
                }                
                
            }
            
            outputsString += "\n\n"
            
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
            
            let alert = UIAlertController(title: "Share as raw data or text?", message: "Sharing as raw data allows you to send the unsigned psbt directly to your Coldcard Wallets SD card for signing", preferredStyle: .actionSheet)
            
            alert.addAction(UIAlertAction(title: "Raw Data", style: .default, handler: { action in
                
                self.convertPSBTtoData(string: self.processedPSBT)
                
            }))
            
            alert.addAction(UIAlertAction(title: "Text", style: .default, handler: { action in
                
                DispatchQueue.main.async {
                    
                    let textToShare = [self.processedPSBT]
                    
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
    
//    func addTXChainLink(psbt: String) {
//
//        let txChain = TXChain()
//        txChain.tx = psbt
//
//        func getResult() {
//
//            if !txChain.errorBool {
//
//                creatingView.removeConnectingView()
//
//                let chain = txChain.chainToReturn
//                displayRaw(raw: chain, title: "TXChain")
//
//                displayAlert(viewController: self,
//                             isError: false,
//                             message: "Link added to the TXChain!")
//
//            } else {
//
//                creatingView.removeConnectingView()
//                showAlert(vc: self, title: "Error", message: txChain.errorDescription)
//
//            }
//
//        }
//
//        txChain.addALink(completion: getResult)
//
//    }

}
