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
    
    @IBOutlet weak var invoiceHeader: UILabel!
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
        func getFromRpc() {
            OnchainUtils.getAddressInfo(address: addressString) { (addressInfo, message) in
                guard let addressInfo = addressInfo else { return }
                showAlert(vc: self, title: "", message: addressInfo.hdkeypath + ": " + "solvable: \(addressInfo.solvable)")
            }
        }
        
        activeWallet { w in
            guard let w = w else { getFromRpc(); return }
            
            if w.isJm {
                showAlert(vc: self, title: "", message: "Address fetched from joinmarket.")
            } else {
                getFromRpc()
            }
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
        param["private"] = true
        
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
        let commandId = UUID()
        spinner.addConnectingView(vc: self, description: "fetching cln config...")
        LightningRPC.sharedInstance.command(id: commandId, method: .listconfigs, param: nil) { (id, response, errorDesc) in
            guard id == commandId else { return }
                    
            guard let response = response as? [String:Any] else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error fetching config.", message: errorDesc ?? "unknown")
                return
            }
            
            guard let experimentalOffers = response["experimental-offers"] as? Bool, experimentalOffers else {
                self.createBolt11Invoice()
                return
            }
            
            self.promptForBolt12Or11()
        }
    }
    
    private func promptForBolt12Or11() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let alert = UIAlertController(title: "Select invoice type.", message: "", preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Bolt 11", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.createBolt11Invoice()
                }
            }))

            alert.addAction(UIAlertAction(title: "Bolt 12", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.createBolt12Invoice()
                }
            }))

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
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
            if wallet.isJm {
                self.getReceiveAddressJm(wallet: wallet)
            } else if wallet.type == WalletType.descriptor.stringValue {
                self.getReceieveAddressForFullyNodedWallet(wallet)
            } else {
                self.fetchAddress()
            }
        }
    }
    
    private func createBolt11Invoice() {
        var param:[String:Any] = ["expiry": 86400]
        var description = labelField.text ?? "Fully Noded CLN invoice"
        
        if description == "" {
            description = "Fully Noded CLN bolt11 invoice"
        }
        
        let label = "Fully Noded CLN invoice \(randomString(length: 10))"
        param["label"] = label
        
        if amountField.text != "" {
            if isBtc {
                if let dbl = Double(amountField.text!) {
                    param["amount_msat"] = Int(dbl * 100000000000.0)
                }
            } else if isSats {
                if let int = Double(amountField.text!) {
                    param["amount_msat"] = Int(int * 1000)
                }
            }
        } else {
            param["amount_msat"] = "any"
        }
        
        if messageField.text != "" {
            description += "\n\n" + messageField.text!
        }
        param["description"] = description
        let commandId = UUID()
        
        LightningRPC.sharedInstance.command(id: commandId, method: .invoice, param: param) { [weak self] (uuid, response, errorDesc) in
            guard let self = self else { return }
            
            guard let dict = response as? [String:Any] else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: errorDesc ?? "we had an issue getting your lightning invoice")
                return
            }
            
            var inv = "no invoice received..."
            
            if let bolt11 = dict["bolt11"] as? String {
                inv = bolt11
            } else if let bolt12 = dict["bolt12"] as? String {
                inv = bolt12
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.showLightningInvoice(inv)
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
    
    private func createBolt12Invoice() {
        // amount description [issuer] [label] [quantity_max] [absolute_expiry] [recurrence] [recurrence_base] [recurrence_paywindow] [recurrence_limit] [single_use]
        var param:[String:Any] = [:]
        let defDesc = "Fully Noded CLN bolt12 offer"
        var description = labelField.text ?? defDesc

        if amountField.text != "" {
            if isBtc {
                if let dbl = Double(amountField.text!) {
                    param["amount"] = Int(dbl * 100000000000.0)
                }
            } else if isSats {
                if let int = Double(amountField.text!) {
                    param["amount"] = Int(int * 1000)
                }
            }
        } else {
            param["amount"] = "any"
        }

        if messageField.text != "" {
            description += "\n\n" + messageField.text!
        }
        param["description"] = description
        let commandId = UUID()

        LightningRPC.sharedInstance.command(id: commandId, method: .offer, param: param) { [weak self] (uuid, response, errorDesc) in
            guard let self = self else { return }

            guard let dict = response as? [String:Any], let offer = dict["bolt12"] as? String else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: errorDesc ?? "we had an issue getting your lightning offer")
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.showLightningInvoice(offer)
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
    
    
    private func getReceiveAddressJm(wallet: Wallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            let title = "Select a mixdepth to deposit to."
            
            let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Mixdepth 0", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.getJmAddressFromMixDepth(mixDepth: 0, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 1", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.getJmAddressFromMixDepth(mixDepth: 1, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 2", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.getJmAddressFromMixDepth(mixDepth: 2, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 3", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.getJmAddressFromMixDepth(mixDepth: 3, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 4", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.getJmAddressFromMixDepth(mixDepth: 4, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func getJmAddressFromMixDepth(mixDepth: Int, wallet: Wallet) {
        spinner.addConnectingView(vc: self, description: "getting address from jm...")
        var w = wallet
        if w.token != nil {
            JMRPC.sharedInstance.command(method: .getaddress(jmWallet: w, mixdepth: mixDepth), param: nil) { [weak self] (response, errorDesc) in
                guard let self = self else { return }
                
                if errorDesc == "Invalid credentials." {
                    JMUtils.unlockWallet(wallet: w) { [weak self] (unlockedWallet, message) in
                        guard let self = self else { return }
                        guard let unlockedWallet = unlockedWallet else { return }
                        
                        guard let encryptedToken = Crypto.encrypt(unlockedWallet.token.utf8) else {
                            self.spinner.removeConnectingView()
                            showAlert(vc: self, title: "", message: "Unable to decrypt your jm auth token.")
                            return
                        }
                        
                        w.token = encryptedToken
                        self.getJmAddressFromMixDepth(mixDepth: mixDepth, wallet: w)
                    }
                    
                } else {
                    guard let response = response as? [String:Any],
                    let address = response["address"] as? String else {
                        showAlert(vc: self, title: "", message: errorDesc ?? "unknown error getting jm address.")
                        return
                    }
                    self.spinner.removeConnectingView()
                    self.showAddress(address: address)
                }
            }
        } else {
            JMUtils.unlockWallet(wallet: w) { [weak self] (unlockedWallet, message) in
                guard let self = self else { return }
                guard let unlockedWallet = unlockedWallet else { return }
                
                guard let encryptedToken = Crypto.encrypt(unlockedWallet.token.utf8) else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "", message: "Unable to decrypt your jm auth token.")
                    return
                }
                
                w.token = encryptedToken
                self.getJmAddressFromMixDepth(mixDepth: mixDepth, wallet: w)
            }
        }
    }
    
    private func getReceieveAddressForFullyNodedWallet(_ wallet: Wallet) {
        let index = Int(wallet.index) + 1
        
        CoreDataService.update(id: wallet.id, keyToUpdate: "index", newValue: Int64(index), entity: .wallets) { success in
            guard success else { return }
            
            let param:Derive_Addresses = .init(["descriptor":wallet.receiveDescriptor, "range":[index,index]])
            
                                                Reducer.sharedInstance.makeCommand(command: .deriveaddresses(param: param)) { [weak self] (response, errorMessage) in
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
        var addressType = ""
        
        if self.nativeSegwit {
            addressType = "bech32"
        } else if self.legacy {
            addressType = "legacy"
        } else if self.p2shSegwit {
            addressType = "p2sh-segwit"
        }
        
        let param:Get_New_Address = .init(["address_type":addressType])
        
        self.getAddress(param)
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
            if invoice.hasPrefix("lno") {
                self.addressOutlet.text = "see bolt12 lightning offer below"
                self.invoiceHeader.text = "Bolt12 Offer"
            } else {
                self.addressOutlet.text = "see bolt11 lightning invoice below"
            }
            
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
    
    func getAddress(_ params: Get_New_Address) {
        Reducer.sharedInstance.makeCommand(command: .getnewaddress(param: params)) { [weak self] (response, errorMessage) in
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
}
