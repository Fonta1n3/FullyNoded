//
//  UtxoTableViewController.swift
//  BitSense
//
//  Created by Peter on 26/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import AES256CBC
import SwiftKeychainWrapper
import EFQRCode
import AVFoundation
import EFQRCode

class UtxoTableViewController: UITableViewController, AVCaptureMetadataOutputObjectsDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {
    
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    let label = UILabel()
    var rawSigned = String()
    let avCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer()
    let titleLabel = UILabel()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark))
    let addressInput = UITextField()
    var stringURL = String()
    let imageImportView = UIImageView()
    let avCaptureSession = AVCaptureSession()
    let uploadButton = UIButton()
    let imagePicker = UIImagePickerController()
    var amountTotal = 0.0
    let refresher = UIRefreshControl()
    var sizeArray = [[String:String]]()
    var currentIndex = Int()
    var ssh:SSHService!
    var isUsingSSH = Bool()
    var utxoArray = [Any]()
    var inputArray = [Any]()
    var inputs = ""
    var address = ""
    var changeAddress = ""
    var changeAmount = ""
    var miningFee = Double()
    
    @IBOutlet var utxoTable: UITableView!
    
    @IBAction func createRaw(_ sender: UIBarButtonItem) {
        
        if self.inputArray.count > 0 {
            
            self.getAddress()
            
        } else {
         
            displayAlert(viewController: self, title: "Error", message: "You need to select at least one UTXO first")
            
        }
        
    }
    
    func rounded(number: Double) -> Double {
        
        return Double(round(100000000*number)/100000000)
        
    }
    
    func createRawNow() {
    
        self.inputs = self.inputArray.description
        self.inputs = self.inputs.replacingOccurrences(of: "[\"", with: "[")
        self.inputs = self.inputs.replacingOccurrences(of: "\"]", with: "]")
        self.inputs = self.inputs.replacingOccurrences(of: "\"{", with: "{")
        self.inputs = self.inputs.replacingOccurrences(of: "}\"", with: "}")
        self.inputs = self.inputs.replacingOccurrences(of: "\\", with: "")
        
        if !isUsingSSH {
            
            
            
            let roundedAmount = rounded(number: self.amountTotal - miningFee)
          
            self.executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction, param: "\(self.inputs), {\"\(self.address)\":\(roundedAmount)}", index: 0)
            
        } else {
         
            self.createRawTransaction()
            
        }
        
        
   }
    
    
    @IBAction func back(_ sender: UIBarButtonItem) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        utxoTable.tableFooterView = UIView(frame: .zero)
        refresher.tintColor = UIColor.white
        refresher.addTarget(self, action: #selector(refresh), for: UIControlEvents.valueChanged)
        utxoTable.addSubview(refresher)
        refresh()
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        addressInput.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        blurView.addGestureRecognizer(tapGesture)
        
        imageImportView.isUserInteractionEnabled = true
        label.isUserInteractionEnabled = true
        
        let miningFeeCheck = UserDefaults.standard.object(forKey: "miningFee") as! String
        var miningFeeString = ""
        miningFeeString = miningFeeCheck
        miningFeeString = miningFeeString.replacingOccurrences(of: ",", with: "")
        let fee = (Double(miningFeeString)!) / 100000000
        miningFee = fee
        
    }
    
    @objc func refresh() {
        
        addSpinner()
        currentIndex = 0
        utxoArray.removeAll()
        
        if !isUsingSSH {
            
            executeNodeCommand(method: BTC_CLI_COMMAND.listunspent, param: "", index: 0)
            
        } else {
            
            listUnspent()
            
        }
        
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
        
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return utxoArray.count
        
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        if utxoArray.count > 0 {
            
            let dict = utxoArray[indexPath.row] as! NSDictionary
            let address = cell.viewWithTag(1) as! UILabel
            let txId = cell.viewWithTag(2) as! UILabel
            let redScript = cell.viewWithTag(3) as! UILabel
            let amount = cell.viewWithTag(4) as! UILabel
            let scriptPubKey = cell.viewWithTag(5) as! UILabel
            let vout = cell.viewWithTag(6) as! UILabel
            let solvable = cell.viewWithTag(7) as! UILabel
            let confs = cell.viewWithTag(8) as! UILabel
            let safe = cell.viewWithTag(9) as! UILabel
            let spendable = cell.viewWithTag(10) as! UILabel
            let size = cell.viewWithTag(11) as! UILabel
            let vsize = cell.viewWithTag(12) as! UILabel
            let checkMark = cell.viewWithTag(13) as! UIImageView
            
            if !cell.isSelected {
                
                checkMark.alpha = 0
                
            }
            
            if self.sizeArray.count == utxoArray.count {
                
                size.text = sizeArray[indexPath.row]["size"]
                vsize.text = sizeArray[indexPath.row]["vsize"]
                
            }
            
            for (key, value) in dict {
                
                let keyString = key as! String
                
                switch keyString {
                    
                case "address":
                    
                    address.text = "\(value)"
                    
                case "txid":
                    
                    txId.text = "\(value)"
                    
                case "redeemScript":
                    
                    redScript.text = "\(value)"
                    
                case "amount":
                    
                    amount.text = "\(value)"
                    
                case "scriptPubKey":
                    
                    scriptPubKey.text = "\(value)"
                    
                case "vout":
                    
                    vout.text = "\(value)"
                    
                case "solvable":
                    
                    if (value as! Int) == 1 {
                        
                        solvable.text = "True"
                        
                    } else if (value as! Int) == 0 {
                        
                        solvable.text = "False"
                        
                    }
                    
                case "confirmations":
                    
                    confs.text = "\(value)"
                    
                case "safe":
                    
                    if (value as! Int) == 1 {
                        
                        safe.text = "True"
                        
                    } else if (value as! Int) == 0 {
                        
                        safe.text = "False"
                        
                    }
                    
                case "spendable":
                    
                    if (value as! Int) == 1 {
                        
                        spendable.text = "True"
                        
                    } else if (value as! Int) == 0 {
                        
                        spendable.text = "False"
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            }
            
        }
        
        return cell
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = utxoTable.cellForRow(at: indexPath)
        let checkmark = cell?.viewWithTag(13) as! UIImageView
        cell?.isSelected = true
        
        DispatchQueue.main.async {
            
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell?.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell?.alpha = 1
                    checkmark.alpha = 1
                    
                })
                
            }
            
        }
        
        let utxo = utxoArray[indexPath.row] as! [String:Any]
        let amount = utxo["amount"] as! Double
        amountTotal = amountTotal + amount
        let txid = utxo["txid"] as! String
        let vout = utxo["vout"] as! Int
        let input = "{\"txid\":\"\(txid)\",\"vout\": \(vout),\"sequence\": 1}"
        inputArray.append(input)
        
    }
    
    
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        
        let cell = utxoTable.cellForRow(at: indexPath)
        let checkmark = cell?.viewWithTag(13) as! UIImageView
        cell?.isSelected = false
        
        let impact = UIImpactFeedbackGenerator()
        impact.impactOccurred()
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                checkmark.alpha = 0
                cell?.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell?.alpha = 1
                    
                })
                
            }
            
        }
        
        if inputArray.count == indexPath.row || inputArray.count > indexPath.row {
         
            inputArray.remove(at: indexPath.row)
            
        }
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: Any, index: Int) {
        
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
        request.httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method.rawValue)\",\"params\":[\(param)]}".data(using: .utf8)
        
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
                                        
                                    case BTC_CLI_COMMAND.signrawtransaction:
                                        
                                        if let result = resultCheck as? NSDictionary {
                                            
                                            let hex = result["hex"] as! String
                                            self.rawSigned = hex
                                            self.displayRaw(raw: hex)
                                            
                                        }
                                        
                                    case BTC_CLI_COMMAND.createrawtransaction:
                                        
                                        if let unsigned = resultCheck as? String {
                                            
                                            self.executeNodeCommand(method: BTC_CLI_COMMAND.signrawtransaction, param: "\"\(unsigned)\"", index: 0)
                                            
                                        }
                                        
                                    case BTC_CLI_COMMAND.decoderawtransaction:
                                        
                                        if let dict = resultCheck as? NSDictionary {
                                            
                                            let size = dict["size"] as! Int
                                            let vsize = dict["vsize"] as! Int
                                            
                                            DispatchQueue.main.async {
                                                
                                                let dict = ["size":"\(size)", "vsize":"\(vsize)"]
                                                self.sizeArray.append(dict)
                                                self.currentIndex = self.currentIndex + 1
                                                self.utxoTable.reloadData()
                                                self.getUtxoSizeRPC()
                                                
                                                if self.currentIndex == self.utxoArray.count {
                                                    
                                                    self.removeSpinner()
                                                    
                                                }
                                                
                                            }
                                            
                                        }
                                        
                                    case BTC_CLI_COMMAND.getrawtransaction:
                                        
                                        let rawtx = resultCheck as! String
                                        self.executeNodeCommand(method: BTC_CLI_COMMAND.decoderawtransaction, param: "\"\(rawtx)\"", index: index)
                                        
                                    case BTC_CLI_COMMAND.listunspent:
                                        
                                        if let resultArray = resultCheck as? NSArray {
                                            
                                            if resultArray.count > 0 {
                                                
                                                self.utxoArray = resultArray as! Array
                                                
                                                self.getUtxoSizeRPC()
                                                
                                                DispatchQueue.main.async {
                                                    
                                                    self.utxoTable.reloadData()
                                                    
                                                }
                                                
                                            } else {
                                                
                                                self.removeSpinner()
                                                
                                            }
                                            
                                        }
                                        
                                    default:
                                        
                                        break
                                        
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
    
    func createRawTransaction() {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            
            let roundedAmount = self.rounded(number: self.amountTotal - self.miningFee)
            
            self.ssh.executeStringResponse(command: BTC_CLI_COMMAND.createrawtransaction, params: "\'\(self.inputs)\' \'{\"\(self.address)\":\(roundedAmount)}\'", response: { (result, error) in
                
                if error != nil {
                    
                    print("error createrawtransaction = \(String(describing: error))")
                    
                } else {
                    
                    if let rawTx = result as? String {
                        
                        self.signRawTransaction(raw: rawTx)
                        
                    }
                    
                }
                
            })
            
        }
        
    }
    
    func signRawTransaction(raw: String) {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            
            self.ssh.execute(command: BTC_CLI_COMMAND.signrawtransaction, params: "\'\(raw)\'", response: { (result, error) in
                if error != nil {
                    
                    print("error signrawtransaction = \(String(describing: error))")
                    
                } else {
                    
                    if let signedTransaction = result as? NSDictionary {
                        
                        self.rawSigned = signedTransaction["hex"] as! String
                        self.displayRaw(raw: self.rawSigned)
                        
                    }
                    
                }
                
            })
            
        }
        
    }
    
    func listUnspent() {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            
            self.ssh.execute(command: BTC_CLI_COMMAND.listunspent, params: "", response: { (result, error) in
                
                if error != nil {
                    
                    print("error listunspent")
                    
                } else {
                    
                    if let resultArray = result as? NSArray {
                        
                        if resultArray.count > 0 {
                            
                            self.utxoArray = resultArray as! Array
                            
                            self.getUtxoSizeSSH()
                            
                            DispatchQueue.main.async {
                                
                                self.utxoTable.reloadData()
                                
                            }
                            
                        } else {
                            
                            self.removeSpinner()
                            
                        }
                        
                    }
                    
                }
                
            })
            
        }
        
    }
    
    func getUtxoSizeSSH() {
        
        var txidArray = [String]()
        txidArray.removeAll()
        
        for utxo in self.utxoArray {
         
            let dict = utxo as! NSDictionary
            let txid = dict["txid"] as! String
            txidArray.append(txid)
                
        }
        
        if txidArray.count > 0 && currentIndex == 0 {
            
            self.getRawTx(txid: txidArray[0], index: 0)
            
        } else if currentIndex > 0 && currentIndex < txidArray.count {
            
            self.getRawTx(txid: txidArray[currentIndex], index: currentIndex)
            
        }
        
    }
    
    func getUtxoSizeRPC() {
        
        var txidArray = [String]()
        txidArray.removeAll()
        
        for utxo in self.utxoArray {
            
            let dict = utxo as! NSDictionary
            let txid = dict["txid"] as! String
            txidArray.append(txid)
            
        }
        
        if txidArray.count > 0 && currentIndex == 0 {
            
            self.executeNodeCommand(method: BTC_CLI_COMMAND.getrawtransaction, param: "\"\(txidArray[0])\"", index: 0)
            
        } else if currentIndex > 0 && currentIndex < txidArray.count {
            
            self.executeNodeCommand(method: BTC_CLI_COMMAND.getrawtransaction, param: "\"\(txidArray[currentIndex])\"", index: currentIndex)
            
        }
        
    }
    
    func getRawTx(txid: String, index: Int) {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            
            self.ssh.executeStringResponse(command: BTC_CLI_COMMAND.getrawtransaction, params: "\"\(txid)\"", response: { (result, error) in
                
                if error != nil {
                    
                    print("error getRawTx")
                    displayAlert(viewController: self, title: "Error", message: "\(String(describing: error))")
                    
                } else {
                    
                    self.decodeRawTx(rawtx: result!, index: index)
                    
                }
                
            })
            
        }
        
    }
    
    func decodeRawTx(rawtx: String, index: Int) {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            
            self.ssh.execute(command: BTC_CLI_COMMAND.decoderawtransaction, params: "\"\(rawtx)\"", response: { (result, error) in
                
                if error != nil {
                    
                    print("error decodeRawTx")
                    displayAlert(viewController: self, title: "Error", message: "\(String(describing: error))")
                    
                } else {
                    
                    if let dict = result as? NSDictionary {
                        
                        let size = dict["size"] as! Int
                        let vsize = dict["vsize"] as! Int
                        
                        DispatchQueue.main.async {
                            
                            let dict = ["size":"\(size)", "vsize":"\(vsize)"]
                            self.sizeArray.append(dict)
                            self.currentIndex = self.currentIndex + 1
                            self.utxoTable.reloadData()
                            self.getUtxoSizeSSH()
                            
                            if self.currentIndex == self.utxoArray.count {
                                
                                self.removeSpinner()
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            })
            
        }
        
    }
    
    func removeSpinner() {
        
        DispatchQueue.main.async {
            
            self.refresher.endRefreshing()
            
        }
        
    }
    
    func addSpinner() {
        
        DispatchQueue.main.async {
            
            self.refresher.beginRefreshing()
            
        }
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        addressInput.resignFirstResponder()
        
    }
    
    @objc func goBack() {
        
        blurView.removeFromSuperview()
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        if addressInput.text != "" {
            
            self.address = addressInput.text!
            self.avCaptureVideoPreviewLayer.removeFromSuperlayer()
            self.addressInput.alpha = 0
            self.uploadButton.alpha = 0
            self.createRawNow()
            
        }
        
        return true
        
    }
    
    func getAddress() {
        
        blurView.frame = view.frame
        view.addSubview(blurView)
        
        addressInput.frame = CGRect(x: blurView.frame.minX + 25, y: blurView.frame.maxY / 7, width: blurView.frame.width - 50, height: 50)
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
        
        imageImportView.frame = CGRect(x: blurView.center.x - ((blurView.frame.width - 50)/2), y: addressInput.frame.maxY + 10, width: blurView.frame.width - 50, height: blurView.frame.width - 50)
        
        uploadButton.frame = CGRect(x: 0, y: imageImportView.frame.maxY + 20, width: blurView.frame.width, height: 25)
        uploadButton.showsTouchWhenHighlighted = true
        uploadButton.setTitle("From Photos", for: .normal)
        uploadButton.setTitleColor(UIColor.white, for: .normal)
        uploadButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Bold", size: 20)
        uploadButton.titleLabel?.textAlignment = .center
        uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary), for: .touchUpInside)
        
        let closeButton = UIButton()
        closeButton.frame = CGRect(x: 10, y: 20, width: 20, height: 20)
        closeButton.setImage(UIImage(named: "back.png"), for: .normal)
        closeButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        
        func scanQRCode() {
            
            do {
                
                try scanQRNow()
                print("scanQRNow")
                
            } catch {
                
                print("Failed to scan QR Code")
            }
            
        }
        
        DispatchQueue.main.async {
            
            self.blurView.contentView.addSubview(self.imageImportView)
            self.blurView.contentView.addSubview(self.titleLabel)
            self.blurView.contentView.addSubview(self.addressInput)
            self.blurView.contentView.addSubview(self.uploadButton)
            self.blurView.contentView.addSubview(closeButton)
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
            
            if qrCodeLink != "" {
                
                DispatchQueue.main.async {
                    
                    self.address = qrCodeLink
                    self.avCaptureVideoPreviewLayer.removeFromSuperlayer()
                    self.addressInput.alpha = 0
                    self.uploadButton.alpha = 0
                    self.createRawNow()
                    
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
        
        avCaptureSession.addInput(avCaptureInput)
        avCaptureSession.addOutput(avCaptureMetadataOutput)
        avCaptureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        avCaptureVideoPreviewLayer.session = avCaptureSession
        avCaptureVideoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        avCaptureVideoPreviewLayer.frame = self.imageImportView.bounds
        imageImportView.layer.addSublayer(avCaptureVideoPreviewLayer)
        avCaptureSession.startRunning()
        
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        if metadataObjects.count > 0 {
            print("metadataOutput")
            
            let machineReadableCode = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
            
            if machineReadableCode.type == AVMetadataObject.ObjectType.qr {
                
                self.address = machineReadableCode.stringValue!
                self.avCaptureSession.stopRunning()
                self.avCaptureVideoPreviewLayer.removeFromSuperlayer()
                self.addressInput.alpha = 0
                self.uploadButton.alpha = 0
                self.createRawNow()
                
            }
            
        }
        
    }
    
    func getQR(raw: String) -> UIImage {
        
        var imageToReturn = UIImage()
        
        if let cgImage = EFQRCode.generate(content: raw,
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
            label.frame = CGRect(x: 0, y: self.imageImportView.frame.minY + 20, width: self.imageImportView.frame.width, height: 40)
            label.textColor = UIColor.white
            label.textAlignment = .center
            self.imageImportView.addSubview(label)
            
        }
        
        return imageToReturn
        
    }
    
    func displayRaw(raw: String) {
        
        DispatchQueue.main.async {
            
            //get qr code
            let image = self.getQR(raw: raw)
            self.label.numberOfLines = 0
            self.label.textColor = UIColor.white
            self.label.textAlignment = .natural
            self.label.font = UIFont.init(name: "HelveticaNeue", size: 10)
            self.label.alpha = 0
            self.label.text = raw
            self.label.frame = CGRect(x: 10, y: self.blurView.frame.maxY + 300, width: self.blurView.frame.width - 20, height: 200)
            self.label.sizeToFit()
            self.blurView.contentView.addSubview(self.label)
            
            UIView.animate(withDuration: 0.75, animations: {
                
                self.imageImportView.image = image
                self.imageImportView.frame = CGRect(x: self.blurView.center.x - ((self.blurView.frame.width - 10)/2), y: 45, width: self.blurView.frame.width - 10, height: self.blurView.frame.width - 10)
                self.label.frame = CGRect(x: 10, y: self.imageImportView.frame.maxY + 5, width: self.blurView.frame.width - 20, height: self.label.frame.height)
                self.label.alpha = 1
                
            }, completion: { _ in
                
                self.addressInput.removeFromSuperview()
                self.uploadButton.removeFromSuperview()
                self.tapTextViewGesture = UITapGestureRecognizer(target: self, action: #selector(self.shareRawText(_:)))
                self.label.addGestureRecognizer(self.tapTextViewGesture)
                self.tapQRGesture = UITapGestureRecognizer(target: self, action: #selector(self.shareQRCode(_:)))
                self.imageImportView.addGestureRecognizer(self.tapQRGesture)
                
                if !self.isUsingSSH {
                    
                    self.getSmartFeeRPC(method: BTC_CLI_COMMAND.decoderawtransaction, param: "\"\(self.rawSigned)\"", index: 0, vsize: 0)
                    
                } else {
                    
                   self.estimateFeeSSH()
                    
                }
                
            })
            
        }
        
    }
    
    @objc func shareRawText(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                self.label.alpha = 0
            }) { _ in
                UIView.animate(withDuration: 0.2, animations: {
                    self.label.alpha = 1
                })
            }
            
            let textToShare = [self.rawSigned]
            let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true) {}
        }
        
    }
    
    @objc func shareQRCode(_ sender: UITapGestureRecognizer) {
        print("shareQRCode")
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.imageImportView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.imageImportView.alpha = 1
                    
                })
                
            }
            
            if let cgImage = EFQRCode.generate(content: self.rawSigned,
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
    
    func estimateFeeSSH() {
     
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            
            self.ssh.execute(command: BTC_CLI_COMMAND.decoderawtransaction, params: "\"\(self.rawSigned)\"", response: { (result, error) in
                
                if error != nil {
                    
                    print("error decodeRawTx")
                    displayAlert(viewController: self, title: "Error", message: "\(String(describing: error))")
                    
                } else {
                    
                    if let dict = result as? NSDictionary {
                        
                        let vsize = dict["vsize"] as! Int
                        
                        self.getSmartFee(vsize: vsize)
                        
                    }
                    
                }
                
            })
            
        }
        
    }
    
    func getSmartFee(vsize: Int) {
     
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            
            self.ssh.execute(command: BTC_CLI_COMMAND.estimatesmartfee, params: "6", response: { (result, error) in
                
                if error != nil {
                    
                    print("error decodeRawTx")
                    displayAlert(viewController: self, title: "Error", message: "\(String(describing: error))")
                    
                } else {
                    
                    if let dict = result as? NSDictionary {
                        
                        let txSize = Double(vsize)
                        let btcPerKbyte = dict["feerate"] as! Double
                        let btcPerByte = btcPerKbyte / 1000
                        let satsPerByte = btcPerByte * 100000000
                        let optimalFeeForSixBlocks = satsPerByte * txSize
                        let actualFeeInSats = (self.miningFee * 100000000)
                        let diff = optimalFeeForSixBlocks - actualFeeInSats
                        
                        if diff < 0 {
                            
                            //overpaying
                            let percentageDifference = Int(((actualFeeInSats / optimalFeeForSixBlocks) * 100)).avoidNotation
                            
                            DispatchQueue.main.async {
                                
                                let alert = UIAlertController(title: NSLocalizedString("Fee Alert", comment: ""), message: "The optimal fee to get this tx included in the next 6 blocks is \(Int(optimalFeeForSixBlocks)) satoshis.\n\nYou are currently paying a fee of \(Int(actualFeeInSats)) satoshis which is \(percentageDifference)% higher then necessary.\n\nWe suggest going to settings and lowering your mining fee to the suggested amount.", preferredStyle: UIAlertControllerStyle.alert)
                                
                                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { (action) in
                                }))
                                
                                self.present(alert, animated: true)
                                
                            }
                            
                        } else {
                            
                            //underpaying
                            let percentageDifference = Int((((optimalFeeForSixBlocks - actualFeeInSats) / optimalFeeForSixBlocks) * 100)).avoidNotation
                            
                            DispatchQueue.main.async {
                                
                                let alert = UIAlertController(title: NSLocalizedString("Fee Alert", comment: ""), message: "The optimal fee to get this tx included in the next 6 blocks is \(Int(optimalFeeForSixBlocks)) satoshis.\n\nYou are currently paying a fee of \(Int(actualFeeInSats)) satoshis which is \(percentageDifference)% lower then necessary.\n\nWe suggest going to settings and raising your mining fee to the suggested amount, however RBF is enabled by default, you can always tap an unconfirmed tx in the home screen to bump the fee.", preferredStyle: UIAlertControllerStyle.alert)
                                
                                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { (action) in
                                }))
                                
                                self.present(alert, animated: true)
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            })
            
        }
    }
    
    func getSmartFeeRPC(method: BTC_CLI_COMMAND, param: Any, index: Int, vsize: Int) {
        
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
        request.httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method.rawValue)\",\"params\":[\(param)]}".data(using: .utf8)
        
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
                                        
                                    case BTC_CLI_COMMAND.estimatesmartfee:
                                        
                                        if let dict = resultCheck as? NSDictionary {
                                            
                                            let txSize = Double(vsize)
                                            let btcPerKbyte = dict["feerate"] as! Double
                                            let btcPerByte = btcPerKbyte / 1000
                                            let satsPerByte = btcPerByte * 100000000
                                            let optimalFeeForSixBlocks = satsPerByte * txSize
                                            let actualFeeInSats = (self.miningFee * 100000000)
                                            let diff = optimalFeeForSixBlocks - actualFeeInSats
                                            
                                            if diff < 0 {
                                                
                                                //overpaying
                                                let percentageDifference = Int(((actualFeeInSats / optimalFeeForSixBlocks) * 100)).avoidNotation
                                                
                                                DispatchQueue.main.async {
                                                    
                                                    let alert = UIAlertController(title: NSLocalizedString("Fee Alert", comment: ""), message: "The optimal fee to get this tx included in the next 6 blocks is \(Int(optimalFeeForSixBlocks)) satoshis.\n\nYou are currently paying a fee of \(Int(actualFeeInSats)) satoshis which is \(percentageDifference)% higher then necessary.\n\nWe suggest going to settings and lowering your mining fee to the suggested amount.", preferredStyle: UIAlertControllerStyle.alert)
                                                    
                                                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { (action) in
                                                    }))
                                                    
                                                    self.present(alert, animated: true)
                                                    
                                                }
                                                
                                            } else {
                                                
                                                //underpaying
                                                let percentageDifference = Int((((optimalFeeForSixBlocks - actualFeeInSats) / optimalFeeForSixBlocks) * 100)).avoidNotation
                                                //(40-30)/40 * 100 = 25%
                                                
                                                DispatchQueue.main.async {
                                                    
                                                    let alert = UIAlertController(title: NSLocalizedString("Fee Alert", comment: ""), message: "The optimal fee to get this tx included in the next 6 blocks is \(Int(optimalFeeForSixBlocks)) satoshis.\n\nYou are currently paying a fee of \(Int(actualFeeInSats)) satoshis which is \(percentageDifference)% lower then necessary.\n\nWe suggest going to settings and raising your mining fee to the suggested amount, however RBF is enabled by default, you can always tap an unconfirmed tx in the home screen to bump the fee.", preferredStyle: UIAlertControllerStyle.alert)
                                                    
                                                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { (action) in
                                                    }))
                                                    
                                                    self.present(alert, animated: true)
                                                    
                                                }
                                                
                                            }
                                            
                                        }
                                        
                                    case BTC_CLI_COMMAND.decoderawtransaction:
                                        
                                        if let dict = resultCheck as? NSDictionary {
                                            
                                            let vsize = dict["vsize"] as! Int
                                            
                                            self.getSmartFeeRPC(method: BTC_CLI_COMMAND.estimatesmartfee, param: "6", index: 0, vsize: vsize)
                                            
                                        }
                                        
                                    default:
                                        
                                        break
                                        
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

extension Int {
    
    var avoidNotation: String {
        
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 8
        numberFormatter.numberStyle = .decimal
        return numberFormatter.string(for: self) ?? ""
        
    }
}
