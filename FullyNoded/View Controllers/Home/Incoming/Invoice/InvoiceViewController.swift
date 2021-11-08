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
    var nativeSegwit = Bool()
    var p2shSegwit = Bool()
    var legacy = Bool()
    let spinner = ConnectingView()
    let qrGenerator = QRGenerator()
    var isHDInvoice = Bool()
    var descriptor = ""
    var wallet = [String:Any]()
    let ud = UserDefaults.standard
    var isBtc = false
    var isSats = false
    var isFiat = false
    
    @IBOutlet weak var denominationControl: UISegmentedControl!
    @IBOutlet weak var addressImageView: UIImageView!
    @IBOutlet var amountField: UITextField!
    @IBOutlet var labelField: UITextField!
    @IBOutlet var qrView: UIImageView!
    @IBOutlet var addressOutlet: UILabel!
    @IBOutlet private weak var invoiceText: UITextView!
    @IBOutlet private weak var messageField: UITextField!
    @IBOutlet weak var fieldsBackground: UIView!
    @IBOutlet weak var addressBackground: UIView!
    @IBOutlet weak var invoiceBackground: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setDelegates()
        configureView(fieldsBackground)
        configureView(addressBackground)
        configureView(invoiceBackground)
        addressImageView.layer.magnificationFilter = .nearest
        confirgureFields()
        configureTap()
        getAddressSettings()
        addDoneButtonOnKeyboard()
        addressOutlet.text = ""
        invoiceText.text = ""
        qrView.image = generateQrCode(key: "bitcoin:")
        generateOnchainInvoice()
        
        if isFiat || isBtc {
            isBtc = true
            denominationControl.selectedSegmentIndex = 0
        } else if isSats {
            denominationControl.selectedSegmentIndex = 1
        }
    }
    
    @IBAction func switchDenominationsAction(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            self.isBtc = true
            self.isSats = false
            self.isFiat = false
        default:
            self.isBtc = false
            self.isSats = true
            self.isFiat = false
        }
        
        if self.invoiceText.text.hasPrefix("l")  {
            createLightningInvoice()
        } else {
           updateQRImage()
        }
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
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "getAddressInfo", sender: self)
        }
    }
    
    @IBAction func shareAddressAction(_ sender: Any) {
        shareText(addressString)
    }
    
    @IBAction func copyAddressAction(_ sender: Any) {
        UIPasteboard.general.string = addressString
        displayAlert(viewController: self, isError: false, message: "address copied ✓")
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
        displayAlert(viewController: self, isError: false, message: "qr copied ✓")
    }
    
    @IBAction func shareInvoiceTextAction(_ sender: Any) {
        shareText(invoiceText.text)
    }
    
    @IBAction func copyInvoiceTextAction(_ sender: Any) {
        UIPasteboard.general.string = invoiceText.text
        displayAlert(viewController: self, isError: false, message: "invoice text copied ✓")
    }
    
    @IBAction func generateLightningAction(_ sender: Any) {
        createLightningInvoice()
    }
    
    private func createLightningInvoice() {
        spinner.addConnectingView(vc: self, description: "creating lightning invoice...")
        
        isLndNode { [weak self] isLnd in
            guard let self = self else { return }
            
            guard isLnd else {
                self.createCLInvoice()
                return
            }
            
            self.createLNDInvoice()
        }
    }
    
    private func createLNDInvoice() {
        var amount = ""
        var param:[String:Any] = [:]

        if amountField.text != "" {
            if isBtc {
                if let dbl = Double(amountField.text!) {
                    let int = Int(dbl * 100000000.0)
                    amount = "\(int)"
                }
            } else if isSats {
                if let int = Double(amountField.text!) {
                    amount = "\(Int(int))"
                }
            }
            
            param["value"] = amount
        }
        
        var memoValue = labelField.text ?? "Fully Noded LND Invoice ⚡️"
        
        if memoValue == "" {
            memoValue = "Fully Noded LND Invoice ⚡️"
        }
        
        if messageField.text != "" {
            memoValue += "- \(messageField.text!)"
        }
        
        param["memo"] = "\(memoValue)"
        
        LndRpc.sharedInstance.command(.addinvoice, param, nil, nil) { (response, error) in
            guard let dict = response, let bolt11 = dict["payment_request"] as? String else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: error ?? "we had an issue getting your lightning invoice")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.showLightningInvoice(bolt11)
            }
        }
    }
    
    private func createCLInvoice() {
        var millisats = "\"any\""
        
        var description = labelField.text ?? "Fully Noded c-lightning invoice ⚡️"
        
        if description == "" {
            description = "Fully Noded c-lightning invoice ⚡️"
        }
        
        let label = "Fully Noded c-lightning invoice ⚡️ \(randomString(length: 10))"
        
        if amountField.text != "" {
            if isBtc {
                if let dbl = Double(amountField.text!) {
                    let int = Int(dbl * 100000000000.0)
                    millisats = "\(int)"
                }
            } else if isSats {
                if let int = Double(amountField.text!) {
                    millisats = "\(Int(int * 1000))"
                }
            }
        }
        
        if messageField.text != "" {
            description += "\n\nmessage: " + messageField.text!
        }
        
        let param = "\(millisats), \"\(label)\", \"\(description)\", \(86400)"
        let commandId = UUID()
        
        LightningRPC.command(id: commandId, method: .invoice, param: param) { [weak self] (uuid, response, errorDesc) in
            guard commandId == uuid, let self = self else { return }
            
            guard let dict = response as? NSDictionary, let bolt11 = dict["bolt11"] as? String else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: errorDesc ?? "we had an issue getting your lightning invoice")
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.showLightningInvoice(bolt11)
            }
            
            if let warning = dict["warning_capacity"] as? String {
                if warning != "" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showAlert(vc: self, title: "Warning", message: warning)
                    }
                }
            }
        }
    }
    
    @IBAction func generateOnchainAction(_ sender: Any) {
        generateOnchainInvoice()
    }
    
    func generateOnchainInvoice() {
        spinner.addConnectingView(vc: self, description: "fetching address...")
        
        addressOutlet.text = ""
        
        activeWallet { [weak self] wallet in
            guard let self = self else { return }
            
            guard let wallet = wallet else {
                self.fetchAddress()
                return
            }
            
            let descriptorStruct = Descriptor(wallet.receiveDescriptor)
            
            if wallet.type == WalletType.descriptor.stringValue || wallet.type == "JoinMarket" {
                self.fetchDescriptorAddress()
            } else {
                if descriptorStruct.isMulti {
                    self.getReceieveAddressForFullyNodedMultiSig(wallet)
                } else {
                    self.fetchAddress()
                }
            }
        }
    }
    
    private func getReceieveAddressForFullyNodedMultiSig(_ wallet: Wallet) {
        let index = Int(wallet.index) + 1
        
        CoreDataService.update(id: wallet.id, keyToUpdate: "index", newValue: Int64(index), entity: .wallets) { success in
            guard success else { return }
            
            let param = "\"\(wallet.receiveDescriptor)\", [\(index),\(index)]"
            
            Reducer.makeCommand(command: .deriveaddresses, param: param) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let addresses = response as? NSArray, let address = addresses[0] as? String else {
                    showAlert(vc: self, title: "", message: errorMessage ?? "error getting multisig address")
                    return
                }
                
                self.showAddress(address: address)
            }
        }
    }
    
    func getAddressSettings() {
        let ud = UserDefaults.standard
        nativeSegwit = ud.object(forKey: "nativeSegwit") as? Bool ?? true
        p2shSegwit = ud.object(forKey: "p2shSegwit") as? Bool ?? false
        legacy = ud.object(forKey: "legacy") as? Bool ?? false
    }
    
    func fetchAddress() {
        var params = ""
        
        if self.nativeSegwit {
            params = "\"\", \"bech32\""
        } else if self.legacy {
            params = "\"\", \"legacy\""
        } else if self.p2shSegwit {
            params = "\"\", \"p2sh-segwit\""
        }
        
        self.getAddress(params)
    }
    
    private func fetchDescriptorAddress() {
        getAddress("")
    }
    
    func showAddress(address: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addressOutlet.alpha = 1
            self.addressOutlet.text = address
            self.addressString = address
            self.updateQRImage()
            self.addressImageView.image = LifeHash.image(address)
            self.spinner.removeConnectingView()
        }
    }
    
    private func showLightningInvoice(_ invoice: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addressOutlet.text = "see lightning invoice below"
            self.addressString = invoice
            self.qrView.image = self.generateQrCode(key: invoice)
            self.invoiceText.text = invoice
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
    
    func getAddress(_ params: String) {
        Reducer.makeCommand(command: .getnewaddress, param: params) { [weak self] (response, errorMessage) in
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
                
        if isSats {
            if amount != "" {
                if let dbl = Double(amount) {
                    amount = (dbl / 100000000.0).avoidNotation
                }
            }
        }
        
        if !addressString.hasPrefix("lntb") && !addressString.hasPrefix("lightning:") && !addressString.hasPrefix("lnbc") && !addressString.hasPrefix("lnbcrt") {
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "getAddressInfo" {
            guard let vc = segue.destination as? GetInfoViewController else { return }
            vc.address = addressString
            vc.getAddressInfo = true
        }
    }
}
