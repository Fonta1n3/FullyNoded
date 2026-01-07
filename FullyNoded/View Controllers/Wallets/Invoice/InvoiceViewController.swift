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
    let spinner = ConnectingView.shared
    let qrGenerator = QRGenerator()
    let ud = UserDefaults.standard
    
    
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
        spinner.show(vc: self, description: "fetching address...")
        
        addressOutlet.text = ""
        
        guard let wallet = wallet else {
            self.getAddress()
            return
        }
        
        self.wallet = wallet
        
        getReceieveAddressForFullyNodedWallet(wallet)
    }
    
    private func getTimelockedAddress() {
        spinner.show(vc: self)
        
        guard let wallet = self.wallet else {
            spinner.dismiss()
            return
        }
        
        let p = Get_Address_Info(["address": addressString])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            guard let addressInfoResponse = response as? [String: Any] else {
                spinner.dismiss()
                return
            }
            
            let addressInfo = AddressInfo(addressInfoResponse)
            
            guard let pubkey = addressInfo.pubkey else {
                spinner.dismiss()
                showAlert(title: "", message: "There is no public key returned to create a timelock address with. If this wallet is multi-sig you may be seeing this error, multi-sig support is coming soon.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let timelockVC = TimelockViewController()
                
                timelockVC.completion = { [weak self] (timestamp, afterFragment, displayDate) in
                    guard let self = self else { return }
                    
                    do {
                        // Add red warning label about this address being timelocked until xxx
                        
                        let (timelockedAddress, descriptor) = try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet, pubkey: pubkey, timelock: timestamp)
                        
                        let param = Get_Descriptor_Info(["descriptor": descriptor])
                        OnchainUtils.getDescriptorInfo(param) { [weak self] (descriptorInfo, message) in
                            guard let self = self else { return }
                            
                            guard let descriptorInfo = descriptorInfo else {
                                spinner.dismiss()
                                showAlert(title: "", message: message ?? "Unknown arror getting descripr")
                                return
                            }
                            
                            let request = [
                                "desc": descriptorInfo.descriptor,
                                "timestamp": "now",
                                "label": "Locked until \(displayDate)"
                            ]
                            
                            let p = Import_Descriptors(["requests": [request]])
                            MakeRPCCall.sharedInstance.executeRPCCommand(method: .importdescriptors(param: p)) { [weak self] (response, errorDesc) in
                                guard let self = self else { return }
                                
                                guard let response = response as? [[String: Any]] else {
                                    showAlert(title: "", message: errorDesc ?? "Unknown error importing descriptor: \(descriptor)")
                                    return
                                }
                                
                                DispatchQueue.main.async {
                                    timelockVC.dismiss(animated: true) { [weak self] in
                                        guard let self = self else { return }
                                        
                                        BackupWarningView.show { [weak self] in
                                            guard let self = self else { return }
                                            
                                            self.addTimelockOutlet.isHidden = true
                                            
                                            for descriptor in response {
                                                let importResponse = ImportDescriportsResponse(descriptor)
                                                if importResponse.success {
                                                    showAddress(address: timelockedAddress)
                                                    
                                                    let item = BackupItem(
                                                        desc: descriptorInfo.descriptor,
                                                        active: false,
                                                        range: nil,
                                                        nextIndex: 0,
                                                        timestamp: .now,
                                                        internal: false,
                                                        label: "Locked until \(displayDate)"
                                                    )
                                                    
                                                    backUpNow(item: item)
                                                } else {
                                                    spinner.dismiss()
                                                    if let errorDesc = importResponse.error, let message = errorDesc["message"] as? String {
                                                        showAlert(title: "", message: message)
                                                    } else {
                                                        showAlert(title: "", message: "Unknown error importing time lock address.")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } catch {
                        spinner.dismiss()
                        showAlert(title: "", message: error.localizedDescription)
                    }
                }
                present(timelockVC, animated: true)
            }
        }
    }
    
    func backUpNow(item: BackupItem) {
        var descriptors: [BackupItem] = [item]
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listdescriptors) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            do {
                guard let response = response else { return }
                
                let jsonData = try JSONSerialization.data(withJSONObject: response, options: [])
                
                let listDescriptorResponse = try JSONDecoder().decode(ListDescriptorsResponse.self, from: jsonData)
                
                for (i, descriptor) in listDescriptorResponse.descriptors.enumerated() {
                    var rangeValue: RangeValue? = nil
                    
                    if let range = descriptor.range {
                        rangeValue = .range(start: range.startIndex, end: range.endIndex)
                    }
                    
                    var timestamp: Timestamp? = nil
                    if let timestampt = descriptor.timestamp {
                        timestamp = Timestamp.time(timestampt)
                    } else {
                        print("timestamp is nil")
                    }
                    
                    let backupitem: BackupItem = .init(desc: descriptor.desc, active: descriptor.active, range: rangeValue, nextIndex: descriptor.nextIndex ?? 0, timestamp: timestamp, internal: descriptor.internal_, label: descriptor.label ?? wallet!.label)
                    
                    descriptors.append(backupitem)
                    
                    if i + 1 == listDescriptorResponse.descriptors.count {
                        let backup = WalletBackup(
                            lastUpdate: Date(),           // or just Date() for now
                            descriptors: descriptors           // need to append existing descriptors
                        )
                        updateNow(backup: backup)
                        
                    }
                }
            } catch {
                print("listdescritpors response logic failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateNow(backup: WalletBackup) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970  // optional, but matches our custom logic

        do {
            let jsonData = try encoder.encode(backup)
            CoreDataService.update(id: wallet!.id, keyToUpdate: "walletBackup", newValue: jsonData, entity: .wallets) { walletBackupUpdated in
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    SuccessView.show(
                        in: self,
                        title: "Wallet backup updated!",
                        subtitle: "You will be prompted to choose a format to export. You can export your backup anytime from the export button on the Active Wallet view (top right button with square and up arrow)."
                    ) { [weak self] in
                        guard let self = self else { return }
                        self.promptForBackupExportFormat(backup: backup)
                    }
                }
            }
        } catch {
            showAlert(title: "", message: "Updating failed: \(error.localizedDescription)")
        }
    }
    
    private func showQRBackup(backup: WalletBackup) {
        do {
            let qrVC = QRViewController(
                text: try backup.jsonData().hex,
                headerText: "\(wallet!.label) Backup",
                descriptionText: "Last updated: " + backup.lastUpdate.formattedDate,
                headerIcon: UIImage(systemName: "qrcode"),
                isBbqr: true,
                isUR: false
            )

            let nav = UINavigationController(rootViewController: qrVC)
            nav.modalPresentationStyle = .fullScreen

            self.present(nav, animated: true) { [weak self] in
                guard let self = self else { return }
                
                spinner.dismiss()
            }
        } catch {
            showAlert(title: "", message: error.localizedDescription)
        }
    }
    
    private func promptForBackupExportFormat(backup: WalletBackup) {
        WalletExportFormatView.show(in: self) { [weak self] format in
            guard let self = self else {
                print("User canceled export")
                return
            }
            
            if let format = format {
                switch format {
                case .qr:
                    self.showQRBackup(backup: backup)
                case .file:
                    self.exportAsFile(backup: backup)
                case .text:
                    self.copyAsText(backup: backup)
                }
            } else {
                print("format is nil")
            }
        }
    }
    
    private func copyAsText(backup: WalletBackup) {
        do {
            // Encode WalletBackup to JSON data
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys] // Optional: consistent ordering
            encoder.dateEncodingStrategy = .secondsSince1970
            
            let jsonData = try encoder.encode(backup)
            let hexString = jsonData.hexString
            
            // Copy hex to clipboard
            UIPasteboard.general.string = hexString
            
            // Show success with explanation
            let byteCount = jsonData.count
            let charCount = hexString.count
            
            SuccessView.show(
                in: self,
                title: "Backup Copied as Hex",
                subtitle: "Hex-encoded backup (\(byteCount) bytes → \(charCount) chars) is now in your clipboard.\n\nPaste it into a secure location."
            ) {
                print("User acknowledged hex backup copy")
            }
            
            // Haptic feedback
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
            
        } catch {
            showAlert(title: "Encoding Failed", message: "Could not encode backup: \(error.localizedDescription)")
        }
    }
    
    private func exportAsFile(backup: WalletBackup) {
        do {
            // 2. Encode to pretty-printed JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .secondsSince1970
            
            let jsonData = try encoder.encode(backup)
                        
            // 3. Create a temporary file URL
            let fileName = "wallet-backup-\(Date().formatted(.iso8601)).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try jsonData.write(to: tempURL)
            
            // 4. Present UIActivityViewController (system share/export sheet)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            // Optional: Exclude some activities if desired
            activityVC.excludedActivityTypes = [
                .addToReadingList,
                .assignToContact,
                .markupAsPDF
            ]
            
            // On iPad/Mac, set popover source
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = self.view.bounds
                popover.permittedArrowDirections = []
            }
            
            activityVC.completionWithItemsHandler = { [weak self] activityType, completed, items, error in
                try? FileManager.default.removeItem(at: tempURL)
                
                if completed {
                    SuccessView.show(in: self!, title: "Backup Exported", subtitle: "Your wallet backup has been saved.") { }
                } else if let error = error {
                    showAlert(title: "Export Failed", message: error.localizedDescription)
                }
            }
            
            present(activityVC, animated: true)
            
        } catch {
            showAlert(title: "Error", message: "Failed to create backup file: \(error.localizedDescription)")
        }
    }

        
    private func getReceieveAddressForFullyNodedWallet(_ wallet: Wallet) {
        spinner.show(vc: self, description: "getting address from \(wallet.label)...")
        
        let addressType = Descriptor(wallet.receiveDescriptor).addressType
        
        let p = Get_New_Address(["address_type": addressType])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getnewaddress(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            spinner.dismiss()
            
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
            self.spinner.dismiss()
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
                    self.spinner.dismiss()
                    
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
