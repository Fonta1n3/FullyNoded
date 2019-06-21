//
//  MultiOutputViewController.swift
//  BitSense
//
//  Created by Peter on 28/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class MultiOutputViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    
    
    var outputArray = [["address":"","amount":0.0], ["address":"","amount":0.0]]
    var index = Int()
    var isTorchOn = Bool()
    var scannerShowing = Bool()
    var blurArray = [UIVisualEffectView]()
    var isFirstTime = Bool()
    @IBOutlet var multiOutputTable: UITableView!
    @IBOutlet var imageView: UIImageView!
    var outputs = [Any]()
    var outputsString = ""
    var totalAmount = 0.0
    var rawTxSigned = ""
    var miningFee = Double()
    
    var torRPC:MakeRPCCall!
    var torClient:TorClient!
    var makeSSHCall:SSHelper!
    var ssh:SSHService!
    
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    
    let qrGenerator = QRGenerator()
    let scanner = QRScanner()
    let connectingView = ConnectingView()
    let rawDisplayer = RawDisplayer()
    
    @IBAction func creatRaw(_ sender: Any) {
        
        print("createRaw")
        
        connectingView.addConnectingView(vc: self, description: "Creating Raw")
        
        hideKeyboards()
        
        var isvalid = Bool()
        
        if outputArray.count > 0 {
            
            for output in outputArray {
                
                if let amount = output["amount"] as? Double {
                    
                    totalAmount = totalAmount + amount
                    
                    if let address = output["address"] as? String {
                        
                        if address != "" {
                            
                            let out = [address:amount]
                            outputs.append(out)
                            isvalid = true
                            
                        } else {
                            
                            isvalid = false
                            
                        }
                        
                    }
                    
                }
                
            }
            
            if isvalid {
                
                outputsString = outputs.description
                outputsString = outputsString.replacingOccurrences(of: "[", with: "")
                outputsString = outputsString.replacingOccurrences(of: "]", with: "")
                
                self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.getrawchangeaddress,
                                           param: "")
                
            } else {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Error not a valid bitcoin address")
                
            }
            
        } else {
            
            displayAlert(viewController: self, isError: true, message: "Create at least one output")
            
        }
        
    }
    
    @IBAction func back(_ sender: Any) {
        print("back")
        
        if scannerShowing {
            
            closeScanner()
            
        } else {
            
            DispatchQueue.main.async {
                
                self.dismiss(animated: true, completion: nil)
                
            }
            
        }
        
    }
    
    @IBAction func add(_ sender: Any) {
        
        let output = ["address":"","amount":0.0] as [String : Any]
        outputArray.append(output)
        let ind = outputArray.count - 1
        multiOutputTable.insertRows(at: [IndexPath.init(row: ind, section: 0)], with: .automatic)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        multiOutputTable.dataSource = self
        multiOutputTable.delegate = self
        multiOutputTable.tableFooterView = UIView(frame: .zero)
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        scanner.uploadButton.addTarget(self,
                                       action: #selector(chooseQRCodeFromLibrary),
                                       for: .touchUpInside)
        
        scanner.torchButton.addTarget(self,
                                      action: #selector(toggleTorch),
                                      for: .touchUpInside)
        
        imageView.alpha = 0
        imageView.backgroundColor = UIColor.black
        scanner.imageView = imageView
        scanner.vc = self
        scanner.textField.alpha = 0
        scanner.completion = { self.getQRCode() }
        scanner.didChooseImage = { self.didPickImage() }
        
        isFirstTime = true
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
        
        let miningFeeCheck = UserDefaults.standard.object(forKey: "miningFee") as! String
        var miningFeeString = ""
        miningFeeString = miningFeeCheck
        miningFeeString = miningFeeString.replacingOccurrences(of: ",", with: "")
        let fee = (Double(miningFeeString)!) / 100000000
        miningFee = fee
        
    }
    
    @objc func keyboardWillShow(_ notification:Notification) {
        
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            multiOutputTable.contentInset = UIEdgeInsets.init(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
        }
    }
    
    @objc func keyboardWillHide(_ notification:Notification) {
        
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            multiOutputTable.contentInset = UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 0)
        }
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        for (i, _) in outputArray.enumerated() {
            
            if let cell = multiOutputTable.cellForRow(at: IndexPath.init(row: i, section: 0)) as? UITableViewCell {
                
                if let amountField = cell.viewWithTag(1) as? UITextField {
                    
                    amountField.resignFirstResponder()
                    
                }
                
                if let addressInput = cell.viewWithTag(2) as? UITextField {
                    
                    addressInput.resignFirstResponder()
                    
                }
                
            }
            
        }
        
    }
    
    func hideKeyboards() {
        
        for (i, _) in outputArray.enumerated() {
            
            if let cell = multiOutputTable.cellForRow(at: IndexPath.init(row: i, section: 0)) as? UITableViewCell {
                
                if let amountField = cell.viewWithTag(1) as? UITextField {
                    
                    amountField.resignFirstResponder()
                    
                }
                
                if let addressInput = cell.viewWithTag(2) as? UITextField {
                    
                    addressInput.resignFirstResponder()
                    
                }
                
            }
            
        }
        
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return outputArray.count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "output", for: indexPath)
        cell.selectionStyle = .none
        
        let button = cell.viewWithTag(3) as! UIButton
        let amountField = cell.viewWithTag(1) as! UITextField
        let addressField = cell.viewWithTag(2) as! UITextField
        let recipientLabel = cell.viewWithTag(4) as! UILabel
        
        recipientLabel.text = "Recipient #" + "\(indexPath.row + 1)"
        
        amountField.delegate = self
        addressField.delegate = self
        amountField.accessibilityLabel = "\(indexPath.row)"
        addressField.accessibilityLabel = "\(indexPath.row)"
        button.accessibilityLabel = "\(indexPath.row)"
        
        button.addTarget(self,
                         action: #selector(scanNow),
                         for: .touchUpInside)
        
        amountField.text = String(outputArray[indexPath.row]["amount"] as! Double)
        addressField.text = (outputArray[indexPath.row]["address"] as! String)
        
        return cell
        
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
        blurArray.append(blur)
        
    }
    
    func amountField() -> UITextField {
        
        let cell = multiOutputTable.cellForRow(at: IndexPath.init(row: index, section: 0))!
        return cell.viewWithTag(1) as! UITextField
        
    }
    
    func addressField() -> UITextField {
        
        let cell = multiOutputTable.cellForRow(at: IndexPath.init(row: index, section: 0))!
        return cell.viewWithTag(2) as! UITextField
        
    }
    
    func getQRCode() {
        
        let stringURL = scanner.stringToReturn
        processBIP21(url: stringURL)
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        scanner.chooseQRCodeFromLibrary()
        
    }
    
    @objc func scanNow(sender: UIButton) {
        
        hideKeyboards()
        
        index = Int(sender.accessibilityLabel!)!
        print("index = \(index)")
        
        
        
        if isFirstTime {
            
            DispatchQueue.main.async {
                
                self.addScannerButtons()
                self.scanner.scanQRCode()
                self.isFirstTime = false
                self.imageView.addSubview(self.scanner.closeButton)
                
                DispatchQueue.main.async {
                    
                    UIView.animate(withDuration: 0.3, animations: {
                        
                        self.imageView.alpha = 1
                        
                    })
                    
                }
                
            }
            
        } else {
            
            scanner.startScanner()
            
            self.addScannerButtons()
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                })
                
            }
            
            
        }
        
        scannerShowing = true
        
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
    
    func hideScanner() {
        print("hideScanner")
        
        DispatchQueue.main.async {
            
            self.scanner.stopScanner()
            
            UIView.animate(withDuration: 0.3, animations: {
                
                self.imageView.alpha = 0
                
            })
            
        }
        
        for blur in blurArray {
            
            blur.removeFromSuperview()
            
        }
        
        self.scannerShowing = false
        
    }
    
    @objc func closeScanner() {
        
        hideScanner()
        
    }
    
    func didPickImage() {
        
        let qrString = scanner.qrString
        processBIP21(url: qrString)
        
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
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            
            outputArray.remove(at: indexPath.row)
            
            UIView.animate(withDuration: 0.4, animations: {
                
                tableView.deleteRows(at: [indexPath], with: .fade)
                
            }) { _ in
                
                tableView.reloadData()
                
            }
            
        }
        
    }
    
    func processBIP21(url: String) {
        
        let addressField = self.addressField()
        let amountField = self.amountField()
        
        let addressParser = AddressParser()
        
        let errorBool = addressParser.parseAddress(url: url).errorBool
        let errorDescription = addressParser.parseAddress(url: url).errorDescription
        
        let address = addressParser.parseAddress(url: url).address
        let cell = self.multiOutputTable.cellForRow(at: IndexPath.init(row: self.index, section: 0))!
        let textfield = cell.viewWithTag(2) as! UITextField
        
        if !errorBool {
            
            DispatchQueue.main.async {
                
                textfield.text = address
                self.outputArray[self.index]["address"] = address
                self.hideScanner()
                let amount = addressParser.parseAddress(url: url).amount
                
                if amount != 0.0 {
                   
                    self.outputArray[self.index]["amount"] = amount
                    amountField.text = "\(amount)"
                    
                }
                
            }
            
            if isTorchOn {
                
                toggleTorch()
                
            }
            
            DispatchQueue.main.async {
                
                let impact = UIImpactFeedbackGenerator()
                impact.impactOccurred()
                
            }
            
        } else {
            
            textfield.text = ""
            
            displayAlert(viewController: self,
                         isError: true,
                         message: errorDescription)
            
        }
        
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        print("textFieldDidBeginEditing")
        
        index = Int(textField.accessibilityLabel!)!
        
        let amountTextField = amountField()
        
        if textField == amountTextField && textField.text == "0.0" {
            
            textField.text = ""
            
        }
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        print("textFieldDidEndEditing")
        
        let amountTextField = amountField()
        let addressTextField = addressField()
        
        if textField == amountTextField {
            
            if amountTextField.text != "" {
                
                if let _ = Double(amountTextField.text!) {
                    print("its a double")
                    
                    if amountTextField.text != "0.0" {
                        
                        outputArray[index]["amount"] = Double(amountTextField.text!)
                        
                    }
                    
                } else {
                    
                    amountTextField.text = "0.0"
                    outputArray[index]["amount"] = 0.0
                    displayAlert(viewController: self, isError: true, message: "Only valid deimal numbers allowed")
                    
                }
                
            } else {
                
                amountTextField.text = "0.0"
                
            }
            
        }
        
        if textField == addressTextField && addressTextField.text != "" {
            
            //validate address first
            processBIP21(url: addressTextField.text!)
            
            //outputArray[index]["address"] = addressTextField.text
            
        }
        
        print("outputArray = \(outputArray)")
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        textField.resignFirstResponder()
        
        return true
        
    }
    
    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.decoderawtransaction:
                    
                    let decodedTx = makeSSHCall.dictToReturn
                    parseDecodedTx(decodedTx: decodedTx)
                    
                case BTC_CLI_COMMAND.getrawchangeaddress:
                    
                    let changeAddress = makeSSHCall.stringToReturn
                    self.getRawTx(changeAddress: changeAddress)
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.outputArray.removeAll()
                    
                    self.connectingView.removeConnectingView()
                    
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
            
            self.outputArray.removeAll()
            
            connectingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Not connected")
            
        }
        
    }
    
    
    func getSmartFee() {
        
        let getSmartFee = GetSmartFee()
        getSmartFee.rawSigned = rawTxSigned
        getSmartFee.ssh = ssh
        getSmartFee.makeSSHCall = makeSSHCall
        getSmartFee.vc = self
        getSmartFee.getSmartFee()
        
    }
    
    func getRawTx(changeAddress: String) {
        
        let rawTransaction = MultiOutputTx()
        rawTransaction.changeAddress = changeAddress
        rawTransaction.outputs = self.outputsString
        rawTransaction.amount = self.totalAmount
        rawTransaction.miningFee = miningFee
        rawTransaction.ssh = self.ssh
        
        func getResult() {
            
            if !rawTransaction.errorBool {
                
                rawTxSigned = rawTransaction.signedRawTx
                showRaw(raw: rawTxSigned)
                getSmartFee()
                
            } else {
                
                self.connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: rawTransaction.errorDescription)
                
            }
            
        }
        
        rawTransaction.createRawTransaction(completion: getResult)
        
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
            
            let newView = UIView()
            newView.backgroundColor = self.view.backgroundColor
            newView.frame = self.view.frame
            self.view.addSubview(newView)
            self.scanner.removeFromSuperview()
            self.connectingView.removeConnectingView()
            self.rawDisplayer.addRawDisplay()
            
        }
        
    }
    
    @objc func close() {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    @objc func decode() {
        
        print("decode")
        
        self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.decoderawtransaction,
                                   param: "\"\(self.rawTxSigned)\"")
        
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

}
