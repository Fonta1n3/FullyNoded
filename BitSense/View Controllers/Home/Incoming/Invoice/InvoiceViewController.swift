//
//  InvoiceViewController.swift
//  BitSense
//
//  Created by Peter on 21/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class InvoiceViewController: UIViewController, UITextFieldDelegate {
    
    var isUsingSSH = IsUsingSSH.sharedInstance
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var makeSSHCall:SSHelper!
    var ssh:SSHService!
    
    var textToShareViaQRCode = String()
    var addressString = String()
    let label = UILabel()
    var qrCode = UIImage()
    let descriptionLabel = UILabel()
    var tapQRGesture = UITapGestureRecognizer()
    var tapAddressGesture = UITapGestureRecognizer()
    var nativeSegwit = Bool()
    var p2shSegwit = Bool()
    var legacy = Bool()
    let connectingView = ConnectingView()
    let qrGenerator = QRGenerator()
    @IBOutlet var amountField: UITextField!
    @IBOutlet var labelField: UITextField!
    @IBOutlet var qrView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        amountField.delegate = self
        labelField.delegate = self
        
        amountField.addTarget(self,
                              action: #selector(textFieldDidChange(_:)),
                              for: .editingChanged)
        
        labelField.addTarget(self,
                             action: #selector(textFieldDidChange(_:)),
                             for: .editingChanged)
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self,
                                                                 action: #selector(dismissKeyboard))
        
        view.addGestureRecognizer(tap)
        getAddressSettings()
        addDoneButtonOnKeyboard()
        
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
        
        showAddress()
        
    }
    
    func getAddressSettings() {
        
        let userDefaults = UserDefaults.standard
        
        if userDefaults.object(forKey: "nativeSegwit") != nil {
            
            nativeSegwit = userDefaults.bool(forKey: "nativeSegwit")
            
        } else {
            
            nativeSegwit = true
            
        }
        
        if userDefaults.object(forKey: "p2shSegwit") != nil {
            
            p2shSegwit = userDefaults.bool(forKey: "p2shSegwit")
            
        } else {
            
            p2shSegwit = false
            
        }
        
        if userDefaults.object(forKey: "legacy") != nil {
            
            legacy = userDefaults.bool(forKey: "legacy")
            
        } else {
            
            legacy = false
            
        }
        
    }
    

   @IBAction func backAction(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    func showAddress() {
        
        DispatchQueue.main.async {
            
            self.connectingView.addConnectingView(vc: self,
                                                  description: "Getting Address")
            
            if self.nativeSegwit {
                
                self.executeNodeCommandSSH(method: BTC_CLI_COMMAND.getnewaddress,
                                           param: "\"\", \"bech32\"")
                
            } else if self.legacy {
                
                self.executeNodeCommandSSH(method: BTC_CLI_COMMAND.getnewaddress,
                                           param: "\"\", \"legacy\"")
                
            } else if self.p2shSegwit {
                
                self.executeNodeCommandSSH(method: BTC_CLI_COMMAND.getnewaddress,
                                           param: "")
                
            }
            
        }
        
    }
    
    func showAddress(address: String) {
        
        self.qrCode = generateQrCode(key: address)
        
        qrView.image = self.qrCode
        qrView.isUserInteractionEnabled = true
        qrView.alpha = 0
        self.view.addSubview(qrView)
        
        descriptionLabel.frame = CGRect(x: 10,
                                        y: view.frame.maxY - 30,
                                        width: view.frame.width - 20,
                                        height: 20)
        
        descriptionLabel.textAlignment = .center
        
        descriptionLabel.font = UIFont.init(name: "HelveticaNeue-Light",
                                            size: 12)
        
        descriptionLabel.textColor = UIColor.white
        descriptionLabel.text = "Tap the QR Code or text to copy/save/share"
        descriptionLabel.adjustsFontSizeToFitWidth = true
        descriptionLabel.alpha = 0
        view.addSubview(self.descriptionLabel)
        
        label.removeFromSuperview()
        
        label.frame = CGRect(x: 10,
                             y: qrView.frame.maxY + 50,
                             width: view.frame.width - 20,
                             height: 20)
        
        label.textAlignment = .center
        
        label.font = UIFont.init(name: "HelveticaNeue",
                                 size: 18)
        
        label.textColor = UIColor.white
        label.alpha = 0
        label.text = address
        label.isUserInteractionEnabled = true
        label.adjustsFontSizeToFitWidth = true
        view.addSubview(self.label)
        
        tapAddressGesture = UITapGestureRecognizer(target: self,
                                                   action: #selector(shareAddressText(_:)))
        
        label.addGestureRecognizer(tapAddressGesture)
        
        tapQRGesture = UITapGestureRecognizer(target: self,
                                              action: #selector(shareQRCode(_:)))
        
        qrView.addGestureRecognizer(tapQRGesture)
        
        UIView.animate(withDuration: 0.3, animations: {
            
            self.descriptionLabel.alpha = 1
            self.qrView.alpha = 1
            self.label.alpha = 1
            
        }) { _ in
            
        }
        
    }
    
    @objc func shareAddressText(_ sender: UITapGestureRecognizer) {
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.label.alpha = 0
            
        }) { _ in
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.label.alpha = 1
                
            })
            
        }
        
        DispatchQueue.main.async {
            
            let textToShare = [self.addressString]
            
            let activityViewController = UIActivityViewController(activityItems: textToShare,
                                                                  applicationActivities: nil)
            
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true) {}
            
        }
        
    }
    
    @objc func shareQRCode(_ sender: UITapGestureRecognizer) {
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.qrView.alpha = 0
            
        }) { _ in
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.qrView.alpha = 1
                
            })
            
        }
        
        let activityViewController = UIActivityViewController(activityItems: [self.qrView.image!],
                                                              applicationActivities: [])
        
        activityViewController.popoverPresentationController?.sourceView = self.view
        self.present(activityViewController, animated: true) {}
        
        
        
        
        
    }
    
    func executeNodeCommandSSH(method: BTC_CLI_COMMAND, param: String) {
        print("executeNodeCommand")
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.getnewaddress:
                    
                    let address = makeSSHCall.stringToReturn
                    
                    DispatchQueue.main.async {
                        
                        self.connectingView.removeConnectingView()
                        self.addressString = address
                        self.showAddress(address: address)
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                self.connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: makeSSHCall.errorDescription)
                
            }
            
        }
        
        if self.ssh != nil {
            
            if self.ssh.session.isConnected {
                
                makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                              method: method,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                self.connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Not connected")
                
            }
            
        } else {
            
            self.connectingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Not connected")
            
        }
        
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        print("textFieldDidChange")
        
        createBIP21Invoice()
        
    }
    
    func createBIP21Invoice() {
        print("createBIP21Invoice")
        
        updateQRImage()
        
    }
    
    func generateQrCode(key: String) -> UIImage {
        
        qrGenerator.textInput = key
        let qr = qrGenerator.getQRCode()
        
        return qr
        
    }
    
    func updateQRImage() {
        
        var newImage = UIImage()
        
        if self.amountField.text == "" && self.labelField.text == "" {
            
            newImage = self.generateQrCode(key:"bitcoin:\(self.addressString)")
            textToShareViaQRCode = "bitcoin:\(self.addressString)"
            
        } else if self.amountField.text != "" && self.labelField.text != "" {
            
            newImage = self.generateQrCode(key:"bitcoin:\(self.addressString)?amount=\(self.amountField.text!)&label=\(self.labelField.text!)")
            textToShareViaQRCode = "bitcoin:\(self.addressString)?amount=\(self.amountField.text!)&label=\(self.labelField.text!)"
            
        } else if self.amountField.text != "" && self.labelField.text == "" {
            
            newImage = self.generateQrCode(key:"bitcoin:\(self.addressString)?amount=\(self.amountField.text!)")
            textToShareViaQRCode = "bitcoin:\(self.addressString)?amount=\(self.amountField.text!)"
            
        } else if self.amountField.text == "" && self.labelField.text != "" {
            
            newImage = self.generateQrCode(key:"bitcoin:\(self.addressString)?label=\(self.labelField.text!)")
            textToShareViaQRCode = "bitcoin:\(self.addressString)?label=\(self.labelField.text!)"
            
        }
        
        DispatchQueue.main.async {
            
            UIView.transition(with: self.qrView,
                              duration: 0.75,
                              options: .transitionCrossDissolve,
                              animations: { self.qrView.image = newImage },
                              completion: nil)
            
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
        }
        
    }
    
    @objc func doneButtonAction() {
        
        self.amountField.resignFirstResponder()
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        view.endEditing(true)
        return false
        
    }
    
    func addDoneButtonOnKeyboard() {
        
        let doneToolbar = UIToolbar()
        
        doneToolbar.frame = CGRect(x: 0,
                                   y: 0,
                                   width: 320,
                                   height: 50)
        
        doneToolbar.barStyle = UIBarStyle.default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace,
                                        target: nil,
                                        action: nil)
        
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done",
                                                    style: UIBarButtonItem.Style.done,
                                                    target: self,
                                                    action: #selector(doneButtonAction))
        
        let items = NSMutableArray()
        items.add(flexSpace)
        items.add(done)
        
        doneToolbar.items = (items as! [UIBarButtonItem])
        doneToolbar.sizeToFit()
        
        self.amountField.inputAccessoryView = doneToolbar
        
    }
    
    @objc func dismissKeyboard() {
        
        view.endEditing(true)
        
    }

}
