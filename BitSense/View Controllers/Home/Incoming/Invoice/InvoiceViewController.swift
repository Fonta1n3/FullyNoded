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
    var qrCode = UIImage()
    let descriptionLabel = UILabel()
    var tapQRGesture = UITapGestureRecognizer()
    var tapAddressGesture = UITapGestureRecognizer()
    var nativeSegwit = Bool()
    var p2shSegwit = Bool()
    var legacy = Bool()
    let connectingView = ConnectingView()
    let qrGenerator = QRGenerator()
    let copiedLabel = UILabel()
    
    var isHDMusig = Bool()
    
    var isHDInvoice = Bool()
    
    let cd = CoreDataService()
    
    var descriptor = ""
    
    var wallet = [String:Any]()
    
    @IBOutlet var amountField: UITextField!
    @IBOutlet var labelField: UITextField!
    @IBOutlet var qrView: UIImageView!
    @IBOutlet var addressOutlet: UILabel!
    
    @IBOutlet var minusOutlet: UIButton!
    @IBOutlet var plusOutlet: UIButton!
    @IBOutlet var indexDisplay: UILabel!
    @IBOutlet var indexLabel: UILabel!
    
    @IBAction func minusAction(_ sender: Any) {
        
        if indexDisplay.text != "" {
            
            let index = Int(indexDisplay.text!)!
            
            if index != 0 {
                
                //fetch new address then save the updated index
                connectingView.addConnectingView(vc: self, description: "fetching address index \(index - 1)")
                
                DispatchQueue.main.async {
                    
                    self.indexDisplay.text = "\(index - 1)"
                    
                }
                
                let param = "\(descriptor), [\(index - 1),\(index - 1)]"
                
                self.executeNodeCommandSSH(method: BTC_CLI_COMMAND.deriveaddresses,
                                           param: param)
            }
            
        }
        
    }
    
    @IBAction func plusAction(_ sender: Any) {
        
        if indexDisplay.text != "" {
            
            let index = Int(indexDisplay.text!)!
            
            if index >= 0 {
                
                //fetch new address then save the updated index
                connectingView.addConnectingView(vc: self, description: "fetching address index \(index + 1)")
                
                DispatchQueue.main.async {
                    
                    self.indexDisplay.text = "\(index + 1)"
                    
                }
                
                let param = "\(descriptor), [\(index + 1),\(index + 1)]"
                
                self.executeNodeCommandSSH(method: BTC_CLI_COMMAND.deriveaddresses,
                                           param: param)
            }
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        connectingView.addConnectingView(vc: self,
                                         description: "")
        
        addressOutlet.isUserInteractionEnabled = true
        
        addressOutlet.text = ""
        minusOutlet.alpha = 0
        plusOutlet.alpha = 0
        indexLabel.alpha = 0
        indexDisplay.alpha = 0
        
        amountField.delegate = self
        labelField.delegate = self
        
        configureCopiedLabel()
        
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
        
        addressOutlet.text = ""
        
        isUsingSSH = IsUsingSSH.sharedInstance
        
        if isUsingSSH {
            
            ssh = SSHService.sharedInstance
            makeSSHCall = SSHelper.sharedInstance
            
        } else {
            
            torRPC = MakeRPCCall.sharedInstance
            torClient = TorClient.sharedInstance
            
        }
    
        if isHDInvoice {
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.minusOutlet.alpha = 1
                    self.plusOutlet.alpha = 1
                    self.indexLabel.alpha = 1
                    self.indexDisplay.alpha = 1
                    
                }) { _ in
                    
                    self.getHDMusigAddress()
                    
                }
                
            }
            
        } else {
            
            loadAddress()
            
        }
        
    }
    
    @IBAction func getAddressInfo(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: "getAddressInfo", sender: self)
            
        }
        
    }
    
    func getHDMusigAddress() {
        
        let getAddress = GetHDMusigAddress()
        getAddress.torClient = torClient
        getAddress.torRPC = torRPC
        getAddress.ssh = ssh
        getAddress.makeSSHCall = makeSSHCall
        getAddress.wallet = wallet
        
        func completion() {
            
            if !getAddress.errorBool {
                
                let address = getAddress.addressToReturn
                addressString = address
                showAddress(address: address)
                descriptor = getAddress.descriptor
                connectingView.removeConnectingView()
                
                DispatchQueue.main.async {
                    
                    self.navigationController?.navigationBar.topItem?.title = getAddress.label
                    self.indexDisplay.text = getAddress.addressIndex
                    self.addressOutlet.text = address
                    
                }
                
            }
            
        }
        
        getAddress.getHDMusigAddress(completion: completion)
        
    }
    
    func loadAddress() {
        
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
        
        if isHDMusig {
            
            showAddress(address: addressString)
            connectingView.removeConnectingView()
            
            DispatchQueue.main.async {
                
                self.addressOutlet.text = self.addressString
                
            }
            
        } else {
            
            var params = ""
            
            if self.nativeSegwit {
                
                params = "\"\", \"bech32\""
                
            } else if self.legacy {
                
                params = "\"\", \"legacy\""
                
            }
            
            self.executeNodeCommandSSH(method: BTC_CLI_COMMAND.getnewaddress,
                                       param: params)
            
        }
        
    }
    
    func showAddress(address: String) {
        
        DispatchQueue.main.async {
            
            let pasteboard = UIPasteboard.general
            pasteboard.string = address
            
            self.qrCode = self.generateQrCode(key: address)
            
            self.qrView.image = self.qrCode
            self.qrView.isUserInteractionEnabled = true
            self.qrView.alpha = 0
            self.view.addSubview(self.qrView)
            
            self.descriptionLabel.frame = CGRect(x: 10,
                                            y: self.view.frame.maxY - 30,
                                            width: self.view.frame.width - 20,
                                            height: 20)
            
            self.descriptionLabel.textAlignment = .center
            
            self.descriptionLabel.font = UIFont.init(name: "HelveticaNeue-Light",
                                                size: 12)
            
            self.descriptionLabel.textColor = UIColor.white
            self.descriptionLabel.text = "Tap the QR Code or text to copy/save/share"
            self.descriptionLabel.adjustsFontSizeToFitWidth = true
            self.descriptionLabel.alpha = 0
            self.view.addSubview(self.descriptionLabel)
            
            /*self.label.removeFromSuperview()
            
            self.label.frame = CGRect(x: 10,
                                 y: self.qrView.frame.maxY + 10,
                                 width: self.view.frame.width - 20,
                                 height: 20)
            
            self.label.textAlignment = .center
            
            self.label.font = UIFont.init(name: "HelveticaNeue",
                                     size: 18)
            
            self.label.textColor = UIColor.green
            self.label.alpha = 0
            self.label.text = address
            self.label.isUserInteractionEnabled = true
            self.label.adjustsFontSizeToFitWidth = true
            self.view.addSubview(self.label)*/
            
            self.tapAddressGesture = UITapGestureRecognizer(target: self,
                                                       action: #selector(self.shareAddressText(_:)))
            
            self.addressOutlet.addGestureRecognizer(self.tapAddressGesture)
            
            self.tapQRGesture = UITapGestureRecognizer(target: self,
                                                  action: #selector(self.shareQRCode(_:)))
            
            self.qrView.addGestureRecognizer(self.tapQRGesture)
            
            UIView.animate(withDuration: 0.3, animations: {
                
                self.descriptionLabel.alpha = 1
                self.qrView.alpha = 1
                self.addressOutlet.alpha = 1
                
            }) { _ in
                
                self.addCopiedLabel()
                
            }
            
        }
        
    }
    
    func addCopiedLabel() {
        
        view.addSubview(copiedLabel)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            
            UIView.animate(withDuration: 0.3, animations: {
                
                self.copiedLabel.frame = CGRect(x: 0,
                                                y: self.view.frame.maxY - 97,
                                                width: self.view.frame.width,
                                                height: 50)
                
            })
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.copiedLabel.frame = CGRect(x: 0,
                                                    y: self.view.frame.maxY + 100,
                                                    width: self.view.frame.width,
                                                    height: 50)
                    
                }, completion: { _ in
                    
                    self.copiedLabel.removeFromSuperview()
                    
                })
                
            })
            
        }
        
    }
    
    @objc func shareAddressText(_ sender: UITapGestureRecognizer) {
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.addressOutlet.alpha = 0
            
        }) { _ in
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.addressOutlet.alpha = 1
                
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
                    
                case BTC_CLI_COMMAND.deriveaddresses:
                    
                    let addressToReturn = makeSSHCall.arrayToReturn[0] as! String
                    
                    DispatchQueue.main.async {
                        
                        self.connectingView.removeConnectingView()
                        self.addressString = addressToReturn
                        self.addressOutlet.text = addressToReturn
                        self.showAddress(address: addressToReturn)
                        
                        let id = self.wallet["id"] as! String
                        let aes = AESService()
                        let encIndex = aes.encryptKey(keyToEncrypt: self.indexDisplay.text!)
                        
                        let success = self.cd.updateWallet(viewController: self,
                                                           id: id,
                                                           newValue: encIndex,
                                                           keyToEdit: "index")

                        if success {

                            print("updated index")

                        } else {
                            
                            print("index update failed")
                            
                        }
                        
                    }
                    
                case BTC_CLI_COMMAND.getnewaddress:
                    
                    let address = makeSSHCall.stringToReturn
                    
                    DispatchQueue.main.async {
                        
                        self.connectingView.removeConnectingView()
                        self.addressString = address
                        self.addressOutlet.text = address
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
    
    func configureCopiedLabel() {
        
        copiedLabel.text = "copied to clipboard ✓"
        
        copiedLabel.frame = CGRect(x: 0,
                                   y: view.frame.maxY + 100,
                                   width: view.frame.width,
                                   height: 50)
        
        copiedLabel.textColor = UIColor.darkGray
        copiedLabel.font = UIFont.init(name: "HiraginoSans-W3", size: 17)
        copiedLabel.backgroundColor = UIColor.black
        copiedLabel.textAlignment = .center
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "getAddressInfo" {
            
            if let vc = segue.destination as? GetInfoViewController {
                
                vc.address = addressString
                vc.getAddressInfo = true
                
            }
            
        }
        
    }

}
