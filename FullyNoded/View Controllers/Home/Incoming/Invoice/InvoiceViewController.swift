//
//  InvoiceViewController.swift
//  BitSense
//
//  Created by Peter on 21/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
//import secp256k1

class InvoiceViewController: UIViewController, UITextFieldDelegate {
    
    var textToShareViaQRCode = ""
    var addressString = ""
    var qrCode = UIImage()
    let spinner = ConnectingView()
    let qrGenerator = QRGenerator()
    let ud = UserDefaults.standard
    
    @IBOutlet private weak var invoiceHeader: UILabel!
    @IBOutlet private weak var amountField: UITextField!
    @IBOutlet private weak var labelField: UITextField!
    @IBOutlet private weak var qrView: UIImageView!
    @IBOutlet private weak var addressOutlet: UILabel!
    @IBOutlet private weak var invoiceText: UITextView!
    @IBOutlet private weak var messageField: UITextField!
    @IBOutlet private weak var fieldsBackground: UIView!
    @IBOutlet private weak var addressBackground: UIView!
    @IBOutlet private weak var invoiceBackground: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setDelegates()
        configureView(fieldsBackground)
        configureView(addressBackground)
        configureView(invoiceBackground)
        confirgureFields()
        configureTap()
        addDoneButtonOnKeyboard()
        addressOutlet.text = ""
        invoiceText.text = ""
        qrView.image = generateQrCode(key: "bitcoin:")
        generateOnchainInvoice()
    }
    
    private func setDelegates() {
        messageField.delegate = self
        amountField.delegate = self
        labelField.delegate = self
    }
    
    private func confirgureFields() {
        amountField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        labelField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        messageField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
    }
    
    private func configureTap() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        amountField.removeGestureRecognizer(tap)
        labelField.removeGestureRecognizer(tap)
        messageField.removeGestureRecognizer(tap)
    }
    
    private func configureView(_ view: UIView) {
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
        view.layer.borderColor = UIColor.darkGray.cgColor
        view.layer.borderWidth = 0.5
    }
    
    @IBAction func getAddressInfoAction(_ sender: Any) {
        OnchainUtils.getAddressInfo(address: addressString) { [weak self] (addressInfo, message) in
            guard let self = self else { return }
            guard let addressInfo = addressInfo else { return }
            showModal(data: addressInfo.rawData, title: "getaddressinfo")
        }
    }
    
    private func showModal(data: [String: Any], title: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let modalVC = TextModalViewController(data: data, viewTitle: title)
            let nav = UINavigationController(rootViewController: modalVC)
            nav.modalPresentationStyle = .fullScreen
            nav.modalTransitionStyle = .coverVertical
            present(nav, animated: true)
        }
    }
    
    @IBAction func shareAddressAction(_ sender: Any) {
        shareText(addressString)
    }
    
    @IBAction func copyAddressAction(_ sender: Any) {
        UIPasteboard.general.string = addressString
        showAlert(vc: self, title: "", message: "Address text copied ✓")
    }
    
    @IBAction func shareQrAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let activityController = UIActivityViewController(activityItems: [self.qrView.image as Any], applicationActivities: nil)
            activityController.popoverPresentationController?.sourceView = self.view
            activityController.popoverPresentationController?.sourceRect = self.view.bounds
            self.present(activityController, animated: true) {}
        }
    }
    
    @IBAction func copyQrAction(_ sender: Any) {
        UIPasteboard.general.image = self.qrView.image
        showAlert(vc: self, title: "", message: "QR copied ✓")
    }
    
    @IBAction func shareInvoiceTextAction(_ sender: Any) {
        shareText(invoiceText.text)
    }
    
    @IBAction func copyInvoiceTextAction(_ sender: Any) {
        UIPasteboard.general.string = invoiceText.text
        showAlert(vc: self, title: "", message: "Invoice text copied ✓")
    }
                    
    func generateOnchainInvoice() {
        spinner.addConnectingView(vc: self, description: "fetching address...")
        
        addressOutlet.text = ""
        
        activeWallet { [weak self] wallet in
            guard let self = self else { return }
            
            guard let wallet = wallet else {
                self.getAddress()
                return
            }
            if wallet.type == WalletType.descriptor.stringValue {
                self.getReceieveAddressForFullyNodedWallet(wallet)
            } else {
                self.getAddress()
            }
        }
    }
    
    private func getReceieveAddressForFullyNodedWallet(_ wallet: Wallet) {
        let index = Int(wallet.index) + 1
        
        CoreDataService.update(id: wallet.id, keyToUpdate: "index", newValue: Int64(index), entity: .wallets) { success in
            guard success else { return }
            
            let param: Derive_Addresses = .init(["descriptor":wallet.receiveDescriptor, "range":[index,index]])
            
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .deriveaddresses(param: param)) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let addresses = response as? NSArray, let address = addresses[0] as? String else {
                    showAlert(vc: self, title: "", message: errorMessage ?? "error getting multisig address")
                    return
                }
                
                self.showAddress(address: address)
            }
        }
    }
    
    func showAddress(address: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addressOutlet.alpha = 1
            self.addressOutlet.text = address
            self.addressString = address
            self.updateQRImage()
            self.spinner.removeConnectingView()
        }
    }
        
    private func shareText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let textToShare = [text]
            let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.view
            activityViewController.popoverPresentationController?.sourceRect = self.view.bounds
            self.present(activityViewController, animated: true) {}
        }
    }
    
    func getAddress() {
        let param: Get_New_Address = .init(["":""])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getnewaddress(param: param)) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            guard let address = response as? String else {
                self.spinner.removeConnectingView()
                
                showAlert(vc: self, title: "Error", message: errorMessage ?? "unknown error fetching address")
                
                return
            }
            
            self.showAddress(address: address)
        }
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        updateQRImage()
    }
    
    func generateQrCode(key: String) -> UIImage {
        qrGenerator.textInput = key
        let qr = qrGenerator.getQRCode()
        return qr
    }
    
    func updateQRImage() {
        var newImage = UIImage()
        var amount = self.amountField.text ?? ""
        let label = self.labelField.text?.replacingOccurrences(of: " ", with: "%20") ?? ""
        let message = self.messageField.text?.replacingOccurrences(of: " ", with: "%20") ?? ""
        textToShareViaQRCode = "bitcoin:\(self.addressString)"
        let dict = ["amount": amount, "label": label, "message": message]
        
        if amount != "" || label != "" || message != "" {
            textToShareViaQRCode += "?"
        }
        
        for (key, value) in dict {
            if textToShareViaQRCode.contains("amount=") || textToShareViaQRCode.contains("label=") || textToShareViaQRCode.contains("message=") {
                if value != "" {
                    textToShareViaQRCode += "&\(key)=\(value)"
                }
            } else {
                if value != "" {
                    textToShareViaQRCode += "\(key)=\(value)"
                }
            }
        }
        
        newImage = self.generateQrCode(key:textToShareViaQRCode)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            UIView.transition(with: self.qrView,
                              duration: 0.75,
                              options: .transitionCrossDissolve,
                              animations: { self.qrView.image = newImage },
                              completion: nil)
            
            self.invoiceText.text = self.textToShareViaQRCode
        }
    }
    
    @objc func doneButtonAction() {
        self.amountField.resignFirstResponder()
        self.labelField.resignFirstResponder()
        self.messageField.resignFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        updateQRImage()
    }
    
    func addDoneButtonOnKeyboard() {
        let doneToolbar = UIToolbar()
        doneToolbar.frame = CGRect(x: 0, y: 0, width: 320, height: 50)
        doneToolbar.barStyle = .default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonAction))
        
        let items = NSMutableArray()
        items.add(flexSpace)
        items.add(done)
        
        doneToolbar.items = (items as! [UIBarButtonItem])
        doneToolbar.sizeToFit()
        
        self.amountField.inputAccessoryView = doneToolbar
        self.labelField.inputAccessoryView = doneToolbar
        self.messageField.inputAccessoryView = doneToolbar
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
//    func silentPayment() {
//        let privateSign1 = try! secp256k1.Signing.PrivateKey()
//        let privateSign2 = try! secp256k1.Signing.PrivateKey()
//        
//        let privateKey1 = try! secp256k1.KeyAgreement.PrivateKey(rawRepresentation: privateSign1.rawRepresentation)
//        let privateKey2 = try! secp256k1.KeyAgreement.PrivateKey(rawRepresentation: privateSign2.rawRepresentation)
//        
//        let sharedSecret1 = try! privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey)
//        let sharedSecret2 = try! privateKey2.sharedSecretFromKeyAgreement(with: privateKey1.publicKey)
//        
//        let sharedSecretSign1 = try! secp256k1.Signing.PrivateKey(rawRepresentation: sharedSecret1.bytes)
//        let sharedSecretSign2 = try! secp256k1.Signing.PrivateKey(rawRepresentation: sharedSecret2.bytes)
//        
//        // Payable Silent Payment public key
//        let xonlyTweak2 = try! sharedSecretSign2.publicKey.xonly.add(privateSign1.publicKey.xonly.bytes)
//        
//        // Spendable Silent Payment private key
//        let privateTweak1 = try! sharedSecretSign1.add(xonly: privateSign1.publicKey.xonly.bytes)
//         
//    }
    
}
