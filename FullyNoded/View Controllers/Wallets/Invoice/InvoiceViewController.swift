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
    
    var wallet: Wallet?
    var textToShareViaQRCode = ""
    var addressString = ""
    var qrCode = UIImage()
    let qrGenerator = QRGenerator()
    let ud = UserDefaults.standard
    
    
    @IBOutlet private weak var timelockWarningLabel: UILabel!
    @IBOutlet private weak var addTimelockOutlet: UIButton!
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
        
        if let w = wallet {
            let fnDesc = Descriptor(w.receiveDescriptor)
            if fnDesc.isP2TR || fnDesc.isP2WPKH {
                addTimelockOutlet.alpha = 1
            } else {
                addTimelockOutlet.alpha = 0
            }
        } else {
            addTimelockOutlet.alpha = 0
        }
        // Cypherpunk teal look (see WalletTheme in ActiveWalletViewController.swift).
        WalletTheme.apply(to: self, tint: .receive)
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
    
    @IBAction func addTimelockAction(_ sender: Any) {
        getTimelockedAddress()
    }
    
    @IBAction func shareAddressAction(_ sender: Any) {
        shareText(addressString)
    }
    
    @IBAction func copyAddressAction(_ sender: Any) {
        UIPasteboard.general.string = addressString
        SuccessView.toast("Address text copied", in: self)
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
        SuccessView.toast("QR copied", in: self)
    }
    
    @IBAction func shareInvoiceTextAction(_ sender: Any) {
        shareText(invoiceText.text)
    }
    
    @IBAction func copyInvoiceTextAction(_ sender: Any) {
        UIPasteboard.general.string = invoiceText.text
        SuccessView.toast("Invoice text copied", in: self)
    }
                    
    func generateOnchainInvoice() {
        showActivity("fetching address...")
        
        addressOutlet.text = ""
        
        guard let wallet = wallet else {
            self.getAddress()
            return
        }
        
        self.wallet = wallet
        
        getReceieveAddressForFullyNodedWallet(wallet)
    }
    
   
    
    private func getTimelockedAddress() {
        showActivity("fetching address...")
        
        guard let wallet = self.wallet else {
            hideActivity()
            return
        }
        
        let p = Get_Address_Info(["address": addressString])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            guard let addressInfoResponse = response as? [String: Any] else {
                hideActivity()
                return
            }
            
            let addressInfo = AddressInfo(addressInfoResponse)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let timelockVC = TimelockViewController()
                
                timelockVC.completion = { [weak self] (timestamp, afterFragment, displayDate) in
                    guard let self = self else { return }
                    
                    // The timelock is built on this address's own key: its child index comes from
                    // its hdkeypath (a timelock on the wrong key would lock the wrong coins).
                    guard let keyIndex = Self.childIndex(of: addressInfo) else {
                        self.hideActivity()
                        showAlert(title: "", message: "Can't tell which key this address uses, so a timelock can't be created for it.")
                        return
                    }
                    
                    do {
                        let (timelockedAddress, descriptor) = try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet, pubkey: nil, descriptor: addressInfo.parent_desc, timelock: timestamp, keyIndex: keyIndex, derivedDescriptor: addressInfo.desc)
                        
                        OnchainUtils.getDescriptorInfo(Get_Descriptor_Info(["descriptor": descriptor])) { [weak self] (descriptorInfo, message) in
                            guard let self = self else { return }
                            
                            guard let descriptorInfo = descriptorInfo else {
                                self.hideActivity()
                                showAlert(title: "", message: message ?? "Unknown error getting the descriptor info.")
                                return
                            }
                            
                            let request = [
                                "desc": descriptorInfo.descriptor,
                                "timestamp": "now",
                                "label": "Locked until \(displayDate)"
                            ]
                            
                            // Import FIRST, pinned to this wallet. Nothing is saved locally unless the node accepted it.
                            MakeRPCCall.sharedInstance.executeRPCCommand(method: .importdescriptors(param: Import_Descriptors(["requests": [request]])), walletName: wallet.name) { [weak self] (response, errorDesc) in
                                guard let self = self else { return }
                                
                                guard let items = response as? [[String: Any]], !items.isEmpty else {
                                    self.hideActivity()
                                    showAlert(title: "", message: errorDesc ?? "Unknown error importing the timelock descriptor.")
                                    return
                                }
                                
                                // Every request must have succeeded, or none of the success steps run.
                                if let failed = items.map({ ImportDescriportsResponse($0) }).first(where: { !$0.success }) {
                                    self.hideActivity()
                                    let message = (failed.error?["message"] as? String) ?? "Unknown error importing the timelock descriptor."
                                    showAlert(title: "", message: message)
                                    return
                                }
                                
                                let record: [String: Any] = ["descriptor": descriptor, "id": UUID()]
                                CoreDataService.saveEntity(dict: record, entityName: .timelocks) { saved in
                                    if !saved {
                                        showAlert(title: "Timelock not saved locally.", message: "The timelocked address was imported on your node, but saving it in Fully Noded failed. Your backup will still include it.")
                                    }
                                    
                                    DispatchQueue.main.async {
                                        timelockVC.dismiss(animated: true) { [weak self] in
                                            guard let self = self else { return }
                                            
                                            BackupWarningView.show { [weak self] in
                                                guard let self = self else { return }
                                                
                                                self.addTimelockOutlet.isHidden = true
                                                self.showAddress(address: timelockedAddress)
                                                self.backUpNow(displayDate: displayDate)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } catch {
                        self.hideActivity()
                        showAlert(title: "", message: error.localizedDescription)
                    }
                }
                present(timelockVC, animated: true)
            }
        }
    }
    
    /// Refreshes the stored wallet backup so it includes the new timelocked descriptor. Pinned to
    /// this wallet and only saved if the node answered for exactly this wallet, so a hiccup (or the
    /// wrong wallet being active) can never replace a good backup with someone else's descriptors.
    /// The child index the address was derived at: from hdkeypath for single-sig, otherwise from
    /// the derivation path inside the derived descriptor (multisig addresses have no hdkeypath),
    /// where every cosigner's key sits at the same index.
    static func childIndex(of info: AddressInfo) -> UInt32? {
        if let last = info.hdkeypath.split(separator: "/").last, let index = UInt32(last) { return index }
        
        let desc = info.desc
        guard let regex = try? NSRegularExpression(pattern: #"\[[0-9a-fA-F]{8}[^\]]*/[01]/(\d+)\]"#) else { return nil }
        let matches = regex.matches(in: desc, range: NSRange(desc.startIndex..., in: desc))
        let indexes = Set(matches.compactMap { match -> UInt32? in
            guard let range = Range(match.range(at: 1), in: desc) else { return nil }
            return UInt32(desc[range])
        })
        return indexes.count == 1 ? indexes.first : nil
    }
    
    func backUpNow(displayDate: String) {
        guard let wallet = wallet else { return }
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listdescriptors, walletName: wallet.name) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            guard let response = response,
                  let data = try? JSONSerialization.data(withJSONObject: response),
                  let listed = try? JSONDecoder().decode(ListDescriptorsResponse.self, from: data),
                  listed.walletName == wallet.name,
                  !listed.descriptors.isEmpty else {
                showAlert(title: "Backup not updated", message: errorDesc ?? "Couldn't read this wallet's descriptors from your node. Export a fresh backup from the Active Wallet view as soon as you can.")
                return
            }
            
            let backup = WalletBackup(lastUpdate: Date(), descriptors: listed.descriptors.map(BackupItem.init(listed:)))
            self.updateNow(backup: backup, displayDate: displayDate)
        }
    }
    
    private func updateNow(backup: WalletBackup, displayDate: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        do {
            let jsonData = try encoder.encode(backup)
            CoreDataService.update(id: wallet!.id, keyToUpdate: "walletBackup", newValue: jsonData, entity: .wallets) { walletBackupUpdated in
                guard walletBackupUpdated else {
                    showAlert(title: "Backup not saved", message: "The timelocked address exists, but updating the stored backup failed. Export a fresh backup from the Active Wallet view now.")
                    return
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    SuccessView.show(
                        in: self,
                        title: "Wallet backup updated",
                        subtitle: "Export it now to keep a copy that includes this timelock. You can also export it later from the Active Wallet view with the export button in the top right.",
                        onDismiss: {
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                
                                timelockWarningLabel.text = "⚠️ Timelocked until \(displayDate): FUNDS WILL NOT BE SPENDABLE UNTIL THIS DATE!"
                                timelockWarningLabel.alpha = 1
                                
                                NotificationCenter.default.post(name: .refreshWallet, object: nil)
                            }
                        },
                        secondaryTitle: "Export backup",
                        onSecondary: { [weak self] in
                            self?.presentBackupExport(backup, walletLabel: self?.wallet?.label)
                        }
                    )
                }
            }
        } catch {
            showAlert(title: "", message: "Updating failed: \(error.localizedDescription)")
        }
    }
        
    private func getReceieveAddressForFullyNodedWallet(_ wallet: Wallet) {
        showActivity("getting address from \(wallet.label)...")
        
        let addressType = Descriptor(wallet.receiveDescriptor).addressType
        
        let p = Get_New_Address(["address_type": addressType])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getnewaddress(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            hideActivity()
            
            guard let address = response as? String else {
                showAlert(vc: self, title: "", message: errorDesc ?? "Unknown error fetching a new address.")
                return
            }
            
            self.showAddress(address: address)
        }
    }
    
    func showAddress(address: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addressOutlet.alpha = 1
            self.addressOutlet.text = address.addressExpanded
            self.addressString = address
            self.updateQRImage()
            self.hideActivity()
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
        promptBitcoinAddressType { addressType in
            let param: Get_New_Address = .init(["address_type": addressType])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .getnewaddress(param: param)) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                guard let address = response as? String else {
                    self.hideActivity()
                    
                    showAlert(vc: self, title: "Error", message: errorMessage ?? "unknown error fetching address")
                    
                    return
                }
                
                self.showAddress(address: address)
            }
        }
    }
    
    // Only gets called when a user is using a non Fully Noded wallet.
    func promptBitcoinAddressType(completion: @escaping (String) -> Void) {
        let alert = UIAlertController(
            title: "Choose Address Type",
            message: "Select the Bitcoin address format (only required when using non Fully Noded wallets, for experts only):",
            preferredStyle: .alert
        )
        
        let options: [(title: String, value: String)] = [
            ("Legacy (P2PKH)",          "legacy"),
            ("Nested SegWit (P2SH)",    "p2sh-segwit"),
            ("Native SegWit (Bech32)",  "bech32"),
            ("Taproot (Bech32m)",       "bech32m")
        ]
        
        for opt in options {
            alert.addAction(UIAlertAction(title: opt.title, style: .default) { _ in
                completion(opt.value)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion("")
        })
        
        self.present(alert, animated: true)
    }

   


    
    @objc func textFieldDidChange(_ textField: UITextField) {
        updateQRImage()
    }
    
    func generateQrCode(key: String) -> UIImage {
        qrGenerator.qrText = key
        let qr = qrGenerator.getQRCode()
        return qr
    }
    
    
    
    func updateQRImage() {
        var newImage = UIImage()
        let amount = self.amountField.text ?? ""
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

extension Date {
    var unixTimestamp: Int {
        return Int(self.timeIntervalSince1970)
    }
    
    var unixTimestampUInt32: UInt32 {
        return UInt32(self.timeIntervalSince1970)
    }
}
