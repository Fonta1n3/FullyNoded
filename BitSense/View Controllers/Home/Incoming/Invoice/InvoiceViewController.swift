//
//  InvoiceViewController.swift
//  BitSense
//
//  Created by Peter on 21/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class InvoiceViewController: UIViewController, UITextFieldDelegate {
    
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
                
                self.executeNodeCommand(method: BTC_CLI_COMMAND.deriveaddresses,
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
                
                self.executeNodeCommand(method: BTC_CLI_COMMAND.deriveaddresses,
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
        load()
        
    }
    
    func load() {
        
        addressOutlet.text = ""
        
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
            
            showAddress()
            
        }
        
    }
    
    @IBAction func getAddressInfo(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: "getAddressInfo", sender: self)
            
        }
        
    }
    
    func getHDMusigAddress() {
        
        let aes = AESService()
        let walletStr = Wallet(dictionary: wallet)
        descriptor = aes.decryptKey(keyToDecrypt: walletStr.descriptor)
        //let range = aes.decryptKey(keyToDecrypt: walletStr.range)
        let label = aes.decryptKey(keyToDecrypt: walletStr.label)
        let addressIndex = aes.decryptKey(keyToDecrypt: walletStr.index)
        let param = "\(descriptor), [\(addressIndex),\(addressIndex)]"
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                let result = reducer.arrayToReturn
                let addressToReturn = result[0] as! String
                
                DispatchQueue.main.async {
                    
                    self.indexDisplay.text = addressIndex
                    self.addressOutlet.text = addressToReturn
                    self.navigationController?.navigationBar.topItem?.title = label
                    self.addressString = addressToReturn
                    self.isHDMusig = true
                    self.showAddress()
                    
                }
                
            } else {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: reducer.errorDescription)
                
            }
            
        }
        
        reducer.makeCommand(command: BTC_CLI_COMMAND.deriveaddresses,
                            param: param,
                            completion: getResult)
        
    }
    
    func getAddressSettings() {
        
        let ud = UserDefaults.standard
        nativeSegwit = ud.object(forKey: "nativeSegwit") as? Bool ?? true
        p2shSegwit = ud.object(forKey: "p2shSegwit") as? Bool ?? false
        legacy = ud.object(forKey: "legacy") as? Bool ?? false
        
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
            
            self.executeNodeCommand(method: BTC_CLI_COMMAND.getnewaddress,
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
                
                if self.tabBarController != nil {
                    
                    self.copiedLabel.frame = CGRect(x: 0,
                                                    y: self.tabBarController!.tabBar.frame.minY - 50,
                                                    width: self.view.frame.width,
                                                    height: 50)
                    
                }
                
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
                
            }) { _ in
                
                let activityController = UIActivityViewController(activityItems: [self.qrView.image!],
                                                                  applicationActivities: nil)
                
                activityController.popoverPresentationController?.sourceView = self.view
                self.present(activityController, animated: true) {}
                
            }
            
        }
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        print("executeNodeCommand")
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                switch method {
                    
                case .deriveaddresses:
                    
                    let addressToReturn = reducer.arrayToReturn[0] as! String
                    
                    DispatchQueue.main.async {
                        
                        self.connectingView.removeConnectingView()
                        self.addressString = addressToReturn
                        self.addressOutlet.text = addressToReturn
                        self.showAddress(address: addressToReturn)
                        
                        let id = self.wallet["id"] as! String
                        let aes = AESService()
                        let encIndex = aes.encryptKey(keyToEncrypt: self.indexDisplay.text!)
                        
                        let success = self.cd.updateEntity(viewController: self,
                                                           id: id,
                                                           newValue: encIndex,
                                                           keyToEdit: "index",
                                                           entityName: ENTITY.hdWallets)
                        
                        if success {
                            
                            print("updated index")
                            
                        } else {
                            
                            print("index update failed")
                            
                        }
                        
                    }
                    
                case .getnewaddress:
                    
                    let address = reducer.stringToReturn
                    
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
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: reducer.errorDescription)
            }
            
        }
        
        reducer.makeCommand(command: method,
                            param: param,
                            completion: getResult)
        
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        print("textFieldDidChange")
        
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
