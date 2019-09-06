//
//  ImportMultiSigViewController.swift
//  BitSense
//
//  Created by Peter on 18/07/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ImportMultiSigViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var makeSSHCall:SSHelper!
    var ssh:SSHService!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var isUsingSSH = IsUsingSSH.sharedInstance
    
    @IBOutlet var pubKeyTable: UITableView!
    @IBOutlet var signaturesField: UITextField!
    @IBOutlet var p2shSwitchOutlet: UISwitch!
    @IBOutlet var p2shp2wshOutlet: UISwitch!
    @IBOutlet var p2wshOutlet: UISwitch!
    @IBOutlet var imageView: UIImageView!
    
    let qrScanner = QRScanner()
    let connectingView = ConnectingView()
    
    var isFirstTime = Bool()
    var isTorchOn = Bool()
    var blurArray = [UIVisualEffectView]()
    var scannerShowing = false
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    
    var addToKeypool = false
    var reScan = Bool()
    
    var pubKeyArray = [""]
    
    var p2sh = Bool()
    var p2shP2wsh = Bool()
    var p2wsh = Bool()
    
    var address = ""
    var script = ""
    
    var dict = [String:Any]()
    
    var isHD = false
    
    @IBAction func p2shAction(_ sender: Any) {
        
        if p2shSwitchOutlet.isOn {
            
            print("p2sh turned on")
            p2shp2wshOutlet.isOn = false
            p2wshOutlet.isOn = false
            
        } else {
            
            print("p2sh turned off")
            
        }
        
        p2sh = p2shSwitchOutlet.isOn
        p2wsh = p2wshOutlet.isOn
        p2shP2wsh = p2shp2wshOutlet.isOn
        
    }
    
    @IBAction func p2shp2wshAction(_ sender: Any) {
        
        if p2shp2wshOutlet.isOn {
            
            print("p2sh-p2wsh turned on")
            p2shSwitchOutlet.isOn = false
            p2wshOutlet.isOn = false
            
        } else {
            
            print("p2sh-p2wsh turned off")
            
        }
        
        p2sh = p2shSwitchOutlet.isOn
        p2wsh = p2wshOutlet.isOn
        p2shP2wsh = p2shp2wshOutlet.isOn
        
    }
    
    @IBAction func p2wshAction(_ sender: Any) {
        
        if p2wshOutlet.isOn {
            
            print("p2wsh turned on")
            p2shSwitchOutlet.isOn = false
            p2shp2wshOutlet.isOn = false
            
        } else {
            
            print("p2wsh turned off")
            
        }
        
        p2sh = p2shSwitchOutlet.isOn
        p2wsh = p2wshOutlet.isOn
        p2shP2wsh = p2shp2wshOutlet.isOn
        
    }
    @IBAction func scanPubKey(_ sender: Any) {
        
        scanNow()
        
    }
    
    @IBAction func importNow(_ sender: Any) {
        
        connectingView.addConnectingView(vc: self, description: "Creating multisig")
        
        if signaturesField.text != "" && pubKeyArray.count > 1 {
            
            guard p2sh || p2wsh || p2shP2wsh else {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "You need to select a multisig type first")
                
                return
                
            }
            
            guard pubKeyArray.count >= Int(signaturesField.text!)! else {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "You can not have more signatures then public keys")
                
                return
                
            }
            
            createMultiSig()
            
        } else {
            
            connectingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "You need to fill out all the info first...")
            
        }
        
    }
    
    func createMultiSig() {
        
        let sigsRequired = signaturesField.text!
        
        var type = ""
        
        if p2sh {
            
            type = "\"legacy\""
            
        }
        
        if p2wsh {
            
            type = "\"bech32\""
            
        }
        
        if p2shP2wsh {
            
            type = "\"p2sh-segwit\""
            
        }
        
        if !isHD {
            
            let param = "\(sigsRequired), \(pubKeyArray), \(type)"
            
            executeNodeCommandSsh(method: BTC_CLI_COMMAND.createmultisig,
                                  param: param)
            
        } else {
            
            getHDMusigDescriptor()
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        pubKeyTable.delegate = self
        signaturesField.delegate = self
        
        pubKeyTable.tableFooterView = UIView(frame: .zero)
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        imageView.alpha = 0
        imageView.backgroundColor = UIColor.black
        
        configureScanner()
        
        getSettings()
        
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
    
    func getSettings() {
        
        p2wsh = true
        p2sh = false
        p2shP2wsh = false
        
        p2shp2wshOutlet.isOn = p2shP2wsh
        p2shSwitchOutlet.isOn = p2sh
        p2wshOutlet.isOn = p2wsh
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            self.qrScanner.textField.resignFirstResponder()
            self.signaturesField.resignFirstResponder()
            
        }
        
    }
    
    func hideKeyboards() {
        
        self.qrScanner.textField.resignFirstResponder()
        self.signaturesField.resignFirstResponder()
        
    }
    
    func removeSpinner() {
        
        DispatchQueue.main.async {
            
            self.connectingView.removeConnectingView()
            
        }
        
    }
    
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
        processString(string: qrScanner.stringToReturn)
        
    }
    
    func didPickImage() {
        
        back()
        processString(string: qrScanner.qrString)
        
    }
    
    func processString(string: String) {
        
        if string.hasPrefix("xpub") || string.hasPrefix("tpub") {
            
            isHD = true
            
        } else {
            
            isHD = false
            
        }
        
        if pubKeyArray[0] == "" {
            
            pubKeyArray[0] = string
            
        } else {
            
            pubKeyArray.append(string)
            
        }
        
        DispatchQueue.main.async {
            
            self.pubKeyTable.reloadData()
            
        }
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        qrScanner.chooseQRCodeFromLibrary()
        
    }
    
    func getHDMusigDescriptor() {
        
        connectingView.addConnectingView(vc: self,
                                         description: "creating HD multisig descriptor")
        
        let sigsRequired = signaturesField.text!
        
        func completion() {
            
            let result = self.makeSSHCall.dictToReturn
            
            if makeSSHCall.errorBool {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self.navigationController!,
                             isError: true,
                             message: makeSSHCall.errorDescription)
                
            } else {
                
                let descriptor = "\"\(result["descriptor"] as! String)\""
                dict["descriptor"] = descriptor
                
                DispatchQueue.main.async {
                    
                    self.performSegue(withIdentifier: "chooseRangeForHDMusig", sender: self)
                    
                }
                
            }
            
        }
        
        var descriptor = ""
        
        //descriptor = sh(multi(2,XPUB/*,XPUB/*))
        var pubkeys = (pubKeyArray.description).replacingOccurrences(of: "[", with: "")
        pubkeys = pubkeys.replacingOccurrences(of: ",", with: "/*,")
        pubkeys = pubkeys.replacingOccurrences(of: "]", with: "/*]")
        pubkeys = pubkeys.replacingOccurrences(of: "]", with: "")
        
        if p2sh {
            
            descriptor = "sh(multi(\(sigsRequired),\(pubkeys)))"
            
        }
        
        if p2wsh {
            
            descriptor = "wsh(multi(\(sigsRequired),\(pubkeys)))"
            
            
        }
        
        if p2shP2wsh {
            
            descriptor = "sh(wsh(multi(\(sigsRequired),\(pubkeys))))"
            
        }
        
        descriptor = descriptor.replacingOccurrences(of: "\"", with: "")
        descriptor = descriptor.replacingOccurrences(of: " ", with: "")
        
        makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                      method: BTC_CLI_COMMAND.getdescriptorinfo,
                                      param: "\"\(descriptor)\"", completion: completion)
        
    }
    
    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                DispatchQueue.main.async {
                    
                    self.qrScanner.removeFromSuperview()
                    
                }
                
                switch method {
                    
                case BTC_CLI_COMMAND.createmultisig:
                    
                    let dict = makeSSHCall.dictToReturn
                    parseResponse(dict: dict)
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: self.makeSSHCall.errorDescription)
                    
                }
                
            }
            
        }
        
        if self.ssh != nil {
            
            if self.ssh.session.isConnected {
                
                makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                              method: method,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Not connected")
                
            }
            
        } else {
            
            connectingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Not connected")
            
        }
        
    }
    
    func parseResponse(dict: NSDictionary) {
        
        address = dict["address"] as! String
        script = dict["redeemScript"] as! String
        
        DispatchQueue.main.async {
            
            self.connectingView.removeConnectingView()
            
            self.performSegue(withIdentifier: "verifyImport",
                              sender: self)
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return pubKeyArray.count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        if pubKeyArray[0] == "" {
            
            cell.textLabel?.text = "tap the + button to add public keys"
            
        } else {
            
            cell.textLabel?.text = "#\(indexPath.row + 1)" + " " + pubKeyArray[indexPath.row]
            
        }
        
        return cell
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "verifyImport" {
         
            if let vc = segue.destination as? MuSigDisplayerTableViewController {
             
                vc.pubkeyArray = pubKeyArray
                vc.p2shP2wsh = p2shP2wsh
                vc.p2sh = p2sh
                vc.p2wsh = p2wsh
                vc.sigsRequired = signaturesField.text!
                vc.address = address
                vc.script = script
                vc.dict = dict
                
            }
            
        }
        
        if segue.identifier == "chooseRangeForHDMusig" {
            
            if let vc = segue.destination as? ChooseRangeViewController {
                
                vc.dict = dict
                vc.isHDMusig = true
                
            }
            
        }
        
    }

}
