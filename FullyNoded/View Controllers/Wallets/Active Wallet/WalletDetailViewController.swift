//
//  WalletDetailViewController.swift
//  BitSense
//
//  Created by Peter on 29/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class WalletDetailViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var detailTable: UITableView!
    var walletId:UUID!
    var wallet:Wallet!
    let spinner = ConnectingView.shared
    var coinType = "0"
    var addresses = ""
    var originalLabel = ""
    var exportWalletImageCryptoOutput: UIImage!
    var exportWalletImageURBytes: UIImage!
    var exportWalletImageBBQr: UIImage!
    var backupText = ""
    var backupFileText = ""
    var exportText = ""
    var textToShow = ""
    var json = ""
    var showReceive = 0
    var outputDescUr = ""
    var urBytes = ""
    var bbqrText = ""
    var outputDescFormat = false
    var urBytesFormat = false
    var bbqrFormat = true
    var externalRange: [Int] = []
    var internalRange: [Int] = []
    var externalNextIndex: Int?
    var internalNextIndex: Int?
    var alertStyle = UIAlertController.Style.actionSheet
    private var labelField: UITextField!
    private var labelButton: UIButton!
    private var cellHeights = [IndexPath: CGFloat]()
    
    private enum Section: Int {
        case label
        case backupText
        case walletExport
        case exportFile
        case filename
        case receiveDesc
        case changeDesc
        case nextIndexExternal
        case nextIndexInternal
        case externalRange
        case internalRange
        case addressExplorer
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        spinner.show(vc: self, description: "loading")
        navigationController?.delegate = self
        detailTable.delegate = self
        detailTable.dataSource = self
        addTapGesture()
                
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
        
        load()
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
    
    @IBAction func showGetWalletInfoAction(_ sender: Any) {
        spinner.show(vc: self, description: "Getting wallet info...")
        
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getwalletinfo) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            spinner.dismiss()
            
            guard let response = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: "No response from getwalletinfo.")
                return
            }
            
            showModal(data: response, title: "getwalletinfo")
        }
        
    }
    
    @IBAction func rescanAction(_ sender: Any) {
        promptToRescan()
    }
        
    private func exportJson() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            let fileURL = fileManager.temporaryDirectory.appendingPathComponent("\(self.wallet.label).wallet")
            
            try? self.json.dataUsingUTF8StringEncoding.write(to: fileURL)
            
            if #available(iOS 14, *) {
                let controller = UIDocumentPickerViewController(forExporting: [fileURL]) // 5
                self.present(controller, animated: true)
            } else {
                let controller = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
                self.present(controller, animated: true)
            }
        }
    }
    
    private func getAddresses() {
        spinner.dismiss()
        listDescriptors()
    }
    
    private func deriveAddresses(_ descriptor: String) {
        let p:Get_Descriptor_Info = .init(["descriptor": descriptor])
        OnchainUtils.getDescriptorInfo(p) { [weak self] (descriptorInfo, message) in
            guard let self = self else { return }
            
            guard let descriptorInfo = descriptorInfo else {
                spinner.dismiss()
                showAlert(vc: self, title: "", message: message ?? "Can not get descriptorinfo.")
                return
            }
            
            let desc = descriptorInfo.descriptor
            var range = self.externalRange
            
            if descriptor == wallet.changeDescriptor {
                range = self.internalRange
            }
            
            let param: Derive_Addresses = .init(["descriptor": desc, "range": range])
            OnchainUtils.deriveAddresses(param: param) { [weak self] (response, message) in
                guard let self = self else { return }
                spinner.dismiss()
                if let addr = response as? NSArray {
                    for (i, address) in addr.enumerated() {
                        self.addresses += "#\(i): \(address)\n\n"
                        if i + 1 == addr.count {
                            DispatchQueue.main.async { [weak self] in
                                self?.detailTable.reloadSections(IndexSet(arrayLiteral: Section.addressExplorer.rawValue), with: .none)
                            }
                        }
                    }
                } else {
                    showAlert(vc: self, title: "We were unable to derive your addresses", message: "")
                }
            }
        }
    }
    
    private func listDescriptors() {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listdescriptors) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            guard let response = response else {
                showAlert(vc: self, title: "", message: errorDesc ?? "No response from listdescriptors.")
                return
            }
                        
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: response, options: [])
                let listDescriptorResponse = try JSONDecoder().decode(ListDescriptorsResponse.self, from: jsonData)
                
                if listDescriptorResponse.descriptors.count == 2 {
                    guard let externalRange = listDescriptorResponse.descriptors[0].range else {
                        showAlert(vc: self, title: "", message: "Failed parsing listdescriptor.")
                        return
                    }
                    
                    guard let internalRange = listDescriptorResponse.descriptors[1].range else {
                        showAlert(vc: self, title: "", message: "Failed parsing listdescriptor.")
                        return
                    }
                    
                    self.externalRange = externalRange
                    self.internalRange = internalRange
                    
                    guard let nextExternal = listDescriptorResponse.descriptors[0].nextIndex else {
                        showAlert(vc: self, title: "", message: "Failed parsing listdescriptor.")
                        return
                    }
                    
                    guard let nextInternal = listDescriptorResponse.descriptors[1].nextIndex else {
                        showAlert(vc: self, title: "", message: "Failed parsing listdescriptor.")
                        return
                    }
                    
                    self.externalNextIndex = nextExternal
                    self.internalNextIndex = nextInternal
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    detailTable.reloadSections(IndexSet(arrayLiteral: Section.externalRange.rawValue), with: .none)
                    detailTable.reloadSections(IndexSet(arrayLiteral: Section.internalRange.rawValue), with: .none)
                    detailTable.reloadSections(IndexSet(arrayLiteral: Section.nextIndexExternal.rawValue), with: .none)
                    detailTable.reloadSections(IndexSet(arrayLiteral: Section.nextIndexInternal.rawValue), with: .none)
                }
                
            } catch {
                showAlert(vc: self, title: "", message: error.localizedDescription)
            }
            
            deriveAddresses(wallet.receiveDescriptor)
        }
    }
    
    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        self.detailTable.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            view.endEditing(true)
        }
        
        sender.cancelsTouchesInView = false
    }
    
    @IBAction func deleteWallet(_ sender: Any) {
        promptToDeleteWallet()
    }
    
    private func load() {
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self = self, let wallets = wallets, wallets.count > 0 else { return }
            
            for w in wallets {
                if w["id"] != nil {
                    let walletStruct = Wallet(dictionary: w)
                    if walletStruct.id == self.walletId {
                        self.wallet = walletStruct
                        
                        if self.wallet.receiveDescriptor.contains("xpub") || self.wallet.receiveDescriptor.contains("xprv") {
                            self.coinType = "0"
                        } else {
                            self.coinType = "1"
                        }
                        
                        guard let json = CreateAccountMap.create(wallet: self.wallet) else {
                            showAlert(vc: self, title: "", message: "Unable to derive account map.")
                            return
                        }
                        
                        self.json = json
                        
                        let generator = QRGenerator()
                        generator.textInput = self.json
                        self.backupText = self.json
                        //self.backupQrImage = generator.getQRCode()
                        
                        guard self.wallet.receiveDescriptor != "" else {
                            showAlert(vc: self, title: "", message: "Unable to get receive descriptor.")
                            return
                        }
                        
                        if !wallet.receiveDescriptor.contains("sortedmulti_a"), let urOutput = URHelper.descriptorToUrOutput(Descriptor(self.wallet.receiveDescriptor)) {
                            generator.textInput = urOutput.uppercased()
                            self.outputDescUr = urOutput.uppercased()
                            self.exportWalletImageCryptoOutput = generator.getQRCode()
                        }
                                                
                        let receiveDescriptor = Descriptor(walletStruct.receiveDescriptor)
                        var keysText = ""
                        var deriv = ""
                        
                        if receiveDescriptor.isMulti {
                            let xfpArray = xfpArray(xfpString: receiveDescriptor.fingerprint)
                            
                            for (i, key) in receiveDescriptor.multiSigKeys.enumerated() {
                                keysText += "\(xfpArray[i].condenseWhitespace()):\(key)\n\n"
                            }
                            
                            let multisigDervArr = receiveDescriptor.derivationArray
                            let allItemsEqual = multisigDervArr.dropLast().allSatisfy { $0 == multisigDervArr.last }
                            
                            if allItemsEqual {
                                deriv = multisigDervArr[0]
                            } else {
                                deriv = "Multiple derivations!"
                            }
                        } else {
                            keysText = receiveDescriptor.fingerprint + ":" + receiveDescriptor.accountXpub
                            deriv = receiveDescriptor.derivation
                        }
                        
                        backupFileText = """
                        Name: \(wallet.label)
                        Policy: \(receiveDescriptor.mOfNType)
                        Derivation: \(deriv)
                        Format: \(receiveDescriptor.format)
                        
                        \(keysText)
                        """
                        
                        guard let urBytesCheck = URHelper.dataToUrBytes(backupFileText.utf8) else {
                            showAlert(vc: self, title: "Error", message: "Unable to convert the text into a UR.")
                            return
                        }
                        
                        urBytes = urBytesCheck.qrString
                        generator.textInput = urBytes
                        self.exportWalletImageURBytes = generator.getQRCode()
                        
                        bbqrText = wallet.receiveDescriptor
                        generator.textInput = bbqrText
                        exportWalletImageBBQr = generator.getQRCode()
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else {
                                return
                            }
                            
                            detailTable.reloadData()
                        }
                        
                        self.getAddresses()
                    }
                }
            }
        }
    }
    
    private func xfpArray(xfpString: String) -> [String] {
        var fingerprintsString = xfpString
        fingerprintsString = fingerprintsString.replacingOccurrences(of: "[", with: "")
        fingerprintsString = fingerprintsString.replacingOccurrences(of: "]", with: "")
        return fingerprintsString.components(separatedBy: ",")
    }
    
    private func accountXpub() -> String {
        if wallet.receiveDescriptor != "" {
            let desc = wallet.receiveDescriptor
            let arr = desc.split(separator: "]")
            let xpubWithPath = "\(arr[1])"
            let arr2 = xpubWithPath.split(separator: "/")
            return "\(arr2[0])"
        } else {
            return ""
        }
    }
    
    private func promptToDeleteWallet() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let message = "Removing the wallet hides it from your \"Fully Noded Wallets\". The wallet will still exist on your node and be accessed via the \"Wallet Manager\" or via bitcoin-cli and bitcoin-qt. In order to completely delete the wallet you need to find the \"Filename\" as listed above on your nodes machine in the .bitcoin directory and manually delete it there."
            
            let alert = UIAlertController(title: "Remove this wallet?", message: message, preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { [weak self] action in
                self?.deleteNow()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func deleteNow() {
        CoreDataService.deleteEntity(id: walletId, entityName: .wallets) { [unowned vc = self] success in
            if success {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.walletDeleted()
                    if vc.wallet.name == UserDefaults.standard.object(forKey: "walletName") as? String {
                        UserDefaults.standard.removeObject(forKey: "walletName")
                        NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    }
                }
            } else {
                showAlert(vc: vc, title: "Error", message: "We had an error deleting your wallet.")
            }
        }
    }
    
    private func walletDeleted() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Fully Noded wallet removed", message: "It will no longer appear in your list of \"Fully Noded Wallets\".", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    self?.navigationController?.popToRootViewController(animated: true)
                }
            }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func updateLabel(_ newLabel: String) {
        CoreDataService.update(id: walletId, keyToUpdate: "label", newValue: newLabel, entity: .wallets) { [weak self] success in
            guard let self = self else { return }
            
            guard success else {
                showAlert(vc: self, title: "", message: "There was an error saving your new wallet label.")
                return
            }
            
            if UserDefaults.standard.object(forKey: "walletName") as? String == self.wallet.name {
                activeWallet { wallet in
                    guard let wallet = wallet else { return }
                    
                    self.wallet = wallet
                }
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .updateWalletLabel, object: nil, userInfo: nil)
                }
            } else {
                // its not the current active wallet
                self.updateLocalWallet()
            }
            
            showAlert(vc: self, title: "", message: "Wallet label updated ✓")
        }
    }
    
    private func updateLocalWallet() {
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self = self, let wallets = wallets, wallets.count > 0 else { return }
            
            for w in wallets {
                if w["id"] != nil {
                    let str = Wallet(dictionary: w)
                    if str.id == self.walletId {
                        self.wallet = str
                    }
                }
            }
        }
    }
    
    @objc func updateLabelAction() {
        disableLabelField()
        
        guard let newLabel = labelField.text, newLabel != "" else { return }
        
        updateLabel(newLabel)
    }
    
    private func enableLabelField() {
        labelButton.setTitle("save", for: .normal)
        labelButton.removeTarget(self, action: #selector(startEditingLabel), for: .touchUpInside)
        labelButton.addTarget(self, action: #selector(updateLabelAction), for: .touchUpInside)
        labelField.isUserInteractionEnabled = true
        labelField.becomeFirstResponder()
    }
    
    private func disableLabelField() {
        labelButton.setTitle("edit", for: .normal)
        labelButton.removeTarget(self, action: #selector(updateLabelAction), for: .touchUpInside)
        labelButton.addTarget(self, action: #selector(startEditingLabel), for: .touchUpInside)
        labelField.isUserInteractionEnabled = false
        labelField.resignFirstResponder()
    }
    
    @objc func startEditingLabel() {
        enableLabelField()
    }
    
    private func exportItem(_ item: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let activityViewController = UIActivityViewController(activityItems: [item], applicationActivities: nil)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = self.view
                activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
            
            self.present(activityViewController, animated: true) {}
        }
    }
    
    @objc func chooseExportFormatButtonAction(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let section = Int(sectionString) else { return }
        
        switch Section(rawValue: section) {
        case .walletExport:
            if outputDescFormat {
                outputDescFormat = false
                bbqrFormat = false
                urBytesFormat = true
            } else if urBytesFormat {
                urBytesFormat = false
                bbqrFormat = true
                outputDescFormat = false
            } else {
                outputDescFormat = true
                bbqrFormat = false
                urBytesFormat = false
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                detailTable.reloadSections(IndexSet(integer: Section.walletExport.rawValue), with: .fade)
            }
            
        default:
            break
        }
    }
    
    @objc func enlargeButtonAction(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let section = Int(sectionString) else { return }
        
        switch Section(rawValue: section) {
        case .walletExport:
            textToShow = exportText
            showQr()
            
        default:
            break
        }
    }
    
    
    @objc func exportButtonAction(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let section = Int(sectionString) else { return }
        
        switch Section(rawValue: section) {
        case .filename:
            exportItem(wallet.name)
            
        case .walletExport:
            if outputDescFormat {
                exportItem(exportWalletImageCryptoOutput as Any)
            }
            
            if urBytesFormat {
                exportItem(exportWalletImageURBytes as Any)
            }
            
            if bbqrFormat {
                exportItem(exportWalletImageBBQr as Any)
            }
            
        case .exportFile:
            exportJson()
            
        case .receiveDesc:
            exportItem(wallet.receiveDescriptor)
            
        case .changeDesc:
            exportItem(wallet.changeDescriptor)
            
        case .addressExplorer:
            exportItem(addresses)
            
        default:
            break
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        guard let sectionString = textField.restorationIdentifier, let section = Int(sectionString) else { return true }
        
        switch Section(rawValue: section) {
        case .label:
            updateLabelAction()
            
        default:
            break
        }
        
        return true
    }
    
    private func showQr() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToAccountMap", sender: self)
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cellHeights[indexPath] = cell.frame.size.height
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return cellHeights[indexPath] ?? UITableView.automaticDimension
    }
    
    private func labelCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailLabelCell", for: indexPath)
        configureCell(cell)
        
        labelField = (cell.viewWithTag(1) as! UITextField)
        labelField.layer.borderColor = UIColor.clear.cgColor
        labelField.text = wallet.label
        labelField.isUserInteractionEnabled = false
        labelField.returnKeyType = .done
        labelField.delegate = self
        labelField.restorationIdentifier = "\(indexPath.section)"
        
        labelButton = (cell.viewWithTag(2) as! UIButton)
        labelButton.addTarget(self, action: #selector(startEditingLabel), for: .touchUpInside)
        
        return cell
    }
    
    private func backupTextCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "backupTextCell", for: indexPath)
        configureCell(cell)
        
        let textView = cell.viewWithTag(1) as! UITextView
        textView.text = backupFileText
        
        return cell
    }
    
    private func filenameCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailFilenameCell", for: indexPath)
        configureCell(cell)
        
        let label = cell.viewWithTag(1) as! UILabel
        label.text = "  " + wallet.name + ".dat"
        
        let exportButton = cell.viewWithTag(2) as! UIButton
        configureExportButton(exportButton, indexPath: indexPath)
        
        return cell
    }
    
    private func recDescCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailReceiveDescCell", for: indexPath)
        configureCell(cell)
        
        let textView = cell.viewWithTag(1) as! UITextView
        textView.text = wallet.receiveDescriptor
        
        let exportButton = cell.viewWithTag(2) as! UIButton
        configureExportButton(exportButton, indexPath: indexPath)
        
        return cell
    }
    
    private func changeDescCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailChangeDescCell", for: indexPath)
        configureCell(cell)
        
        let textView = cell.viewWithTag(1) as! UITextView
        textView.text = wallet.changeDescriptor
        
        let exportButton = cell.viewWithTag(2) as! UIButton
        configureExportButton(exportButton, indexPath: indexPath)
        
        return cell
    }
    
    private func externalRangeCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailCurrentIndexCell", for: indexPath)
        configureCell(cell)
        
        let field = cell.viewWithTag(1) as! UITextField
        field.text = "\(externalRange)"
        field.layer.borderColor = UIColor.clear.cgColor
        
        return cell
    }
    
    private func internalRangeCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailCurrentIndexCell", for: indexPath)
        configureCell(cell)
        
        let field = cell.viewWithTag(1) as! UITextField
        field.text = "\(internalRange)"
        field.layer.borderColor = UIColor.clear.cgColor
        
        return cell
    }
    
    private func nextExternalIndexCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailMaxIndexCell", for: indexPath)
        configureCell(cell)
        
        let field = cell.viewWithTag(1) as! UITextField
        if let externalNextIndex = self.externalNextIndex {
            field.text = "\(externalNextIndex)"
        }
        field.isUserInteractionEnabled = false
        field.layer.borderColor = UIColor.clear.cgColor
        
        return cell
    }
    
    private func nextInternalIndexCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailMaxIndexCell", for: indexPath)
        configureCell(cell)
        
        let field = cell.viewWithTag(1) as! UITextField
        if let internalNextIndex = self.internalNextIndex {
            field.text = "\(internalNextIndex)"
        }
        field.isUserInteractionEnabled = false
        field.layer.borderColor = UIColor.clear.cgColor
        
        return cell
    }
    
    private func addressesCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailAdressesCell", for: indexPath)
        configureCell(cell)
        
        let textView = cell.viewWithTag(1) as! UITextView
        
        if addresses == "" {
            textView.text = "fetching addresses from your node..."
        } else {
            textView.text = addresses
        }
        
        let exportButton = cell.viewWithTag(2) as! UIButton
        configureExportButton(exportButton, indexPath: indexPath)
        
        let segmentedControl = cell.viewWithTag(3) as! UISegmentedControl
        segmentedControl.selectedSegmentIndex = showReceive
        segmentedControl.addTarget(self, action: #selector(updateAddressExplorer(_:)), for: .valueChanged)
        
        return cell
    }
    
    private func exportWalletCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletExportQrCell", for: indexPath)
        configureCell(cell)
        
        let imageView = cell.viewWithTag(1) as! UIImageView
        let exportButton = cell.viewWithTag(2) as! UIButton
        configureExportButton(exportButton, indexPath: indexPath)
        
        let chooseFormatButton = cell.viewWithTag(3) as! UIButton
        configureChooseExportFormatButton(chooseFormatButton, indexPath: indexPath)
        
        let headerLabel = cell.viewWithTag(4) as! UILabel
        let subheaderLabel = cell.viewWithTag(5) as! UILabel
        
        let enlargeButton = cell.viewWithTag(6) as! UIButton
        configureEnlargeButton(enlargeButton, indexPath: indexPath)
        
        if urBytesFormat {
            headerLabel.text = "UR Bytes"
            subheaderLabel.text = "Passport, Keystone, Blue, Fully Noded and more."
            imageView.image = exportWalletImageURBytes
            exportText = urBytes
        }
        
        if bbqrFormat {
            headerLabel.text = "BBQr"
            subheaderLabel.text = "Coldcard, Fully Noded and more."
            imageView.image = exportWalletImageBBQr
            exportText = bbqrText
        }
        
        if outputDescFormat {
            headerLabel.text = "UR Output Descriptor"
            subheaderLabel.text = "Sparrow, Blue, Fully Noded and more."
            imageView.image = exportWalletImageCryptoOutput
            exportText = outputDescUr
        }
        
        return cell
    }
        
    private func exportFileCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletExportFileCell", for: indexPath)
        configureCell(cell)
        
        let textView = cell.viewWithTag(1) as! UITextView
        textView.text = json
        
        let exportButton = cell.viewWithTag(2) as! UIButton
        configureExportButton(exportButton, indexPath: indexPath)
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 13
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    private func configureExportButton(_ button: UIButton, indexPath: IndexPath) {
        button.restorationIdentifier = "\(indexPath.section)"
        button.addTarget(self, action: #selector(exportButtonAction(_:)), for: .touchUpInside)
    }
    
    private func configureChooseExportFormatButton(_ button: UIButton, indexPath: IndexPath) {
        button.restorationIdentifier = "\(indexPath.section)"
        button.addTarget(self, action: #selector(chooseExportFormatButtonAction(_:)), for: .touchUpInside)
    }
    
    private func configureEnlargeButton(_ button: UIButton, indexPath: IndexPath) {
        button.restorationIdentifier = "\(indexPath.section)"
        button.addTarget(self, action: #selector(enlargeButtonAction(_:)), for: .touchUpInside)
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        cell.selectionStyle = .none
        cell.layer.cornerRadius = 8
        cell.layer.borderWidth = 0.5
        cell.layer.borderColor = UIColor.darkGray.cgColor
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard self.wallet != nil else {
            return UITableViewCell()
        }
        
        originalLabel = wallet.label
        
        switch Section(rawValue: indexPath.section) {
        case .backupText:
            return backupTextCell(indexPath)
        case .label:
            return labelCell(indexPath)
        case .walletExport:
            return exportWalletCell(indexPath)
        case .exportFile:
            return exportFileCell(indexPath)
        case .filename:
            return filenameCell(indexPath)
        case .receiveDesc:
            return recDescCell(indexPath)
        case .changeDesc:
            return changeDescCell(indexPath)
        case .externalRange:
            return externalRangeCell(indexPath)
        case .internalRange:
            return internalRangeCell(indexPath)
        case .nextIndexExternal:
            return nextExternalIndexCell(indexPath)
        case .nextIndexInternal:
            return nextInternalIndexCell(indexPath)
        case .addressExplorer:
            return addressesCell(indexPath)
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section) {
        case .backupText, .addressExplorer:
            return 180
        case .walletExport:
            return 270
        case .exportFile, .receiveDesc, .changeDesc:
            return 120
        case .nextIndexExternal, .nextIndexInternal, .label, .filename, .externalRange, .internalRange:
            return 50
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footer = UIView()
        footer.backgroundColor = UIColor.clear
        footer.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 100)
        
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        textLabel.textColor = .lightGray
        textLabel.numberOfLines = 0
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.sizeToFit()
        textLabel.frame = CGRect(x: 0, y: 0, width: footer.frame.width, height: 100)
        
        if let section = Section(rawValue: section) {
            switch section {
            case .walletExport:
                textLabel.text = "This QR is for exporting your wallet to Hardware Wallets and Software wallets. Compatible with Sparrow, Blue Wallet, Passport, Coldcard and Fully Noded."
                                
            default:
                break
            }
        }
        
        footer.addSubview(textLabel)
        
        return footer
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if let section = Section(rawValue: section) {
            switch section {
            case .walletExport:
                return 100
            default:
                return 10
            }
        } else {
            return 10
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 30)
        
//        let background = UIView()
//        background.frame = CGRect(x: 0, y: header.frame.minY + 25, width: 35, height: 35)
//        background.clipsToBounds = true
//        background.layer.cornerRadius = 5
//        background.center.y = header.center.y
        
        let icon = UIImageView()
        icon.frame = CGRect(x: 0, y: 0, width: 25, height: 25)
        icon.tintColor = .tintColor
        icon.contentMode = .scaleAspectFit
        
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        textLabel.textColor = .secondaryLabel
        textLabel.frame = CGRect(x: 33, y: 0, width: 300, height: 25)
        textLabel.center.y = icon.center.y
        
        if let section = Section(rawValue: section) {
            let (text, image) = headerName(for: section)
            
            textLabel.text = text
            icon.image = image
        }
        
        header.addSubview(icon)
        header.addSubview(textLabel)
        
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    @objc func updateAddressExplorer(_ sender: UISegmentedControl) {
        showReceive = sender.selectedSegmentIndex
        addresses = ""
        
        if showReceive == 0 {
            spinner.show(vc: self, description: "deriving receive addresses...")
            deriveAddresses(wallet.receiveDescriptor)
        } else {
            spinner.show(vc: self, description: "deriving change addresses...")
            deriveAddresses(wallet.changeDescriptor)
        }
    }
    
    private func promptToRescan() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Rescan?", message: "Input the year you'd like to rescan from.", preferredStyle: .alert)
            
            let rescan = UIAlertAction(title: "Rescan", style: .default) { [weak self] (alertAction) in
                guard let self = self else { return }
                let textField = (alert.textFields![0] as UITextField)
                var blockheight = 0
                let currentYear = Int(Calendar.current.component(.year, from: .now))
                if let text = textField.text {
                    var yearToScanFrom = Int(text) ?? 2009
                    
                    if yearToScanFrom <= currentYear {
                        if yearToScanFrom < 2010 {
                            yearToScanFrom = 2010
                        }
                        let yearsToScan = (currentYear - yearToScanFrom) + 1
                        let blocksToScan = yearsToScan * 55000
                        
                        spinner.show(vc: self, description: "rescanning...")
                        
                        OnchainUtils.getBlockchainInfo { [weak self] (blockchainInfo, message) in
                            guard let self = self else { return }
                            
                            guard let blockchainInfo = blockchainInfo else {
                                spinner.dismiss()
                                showAlert(vc: self, title: "", message: message ?? "Unknown issue getblockchaininfo.")
                                return
                            }
                            
                            if !blockchainInfo.initialblockdownload {
                                blockheight = blockchainInfo.blockheight - blocksToScan
                                
                                if blockchainInfo.pruned {
                                    if blockheight < blockchainInfo.pruneheight {
                                        blockheight = blockchainInfo.pruneheight
                                    }
                                }
                                
                                OnchainUtils.rescanNow(from: blockheight) { [weak self] (started, message) in
                                    guard let self = self else { return }
                                    
                                    guard started else {
                                        spinner.dismiss()
                                        showAlert(vc: self, title: "", message: message ?? "Unknown issue from rescan.")
                                        return
                                    }
                                    
                                    self.spinner.dismiss()
                                    showAlert(vc: self, title: "", message: "Rescanning, you can refresh this page to see completion status.")
                                }
                            } else {
                                spinner.dismiss()
                                showAlert(vc: self, title: "", message: "Wait till your node is done syncing before attempting to rescan or use wallets.")
                            }
                        }
                    }
                }
            }
            
            alert.addTextField { (textField) in
                textField.placeholder = "From year"
                textField.keyboardAppearance = .dark
                textField.keyboardType = .numberPad
                textField.text = "2009"
            }
            
            alert.addAction(rescan)
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
        
    private func showError(error:String) {
        DispatchQueue.main.async { [weak self] in
            self?.spinner.dismiss()
            showAlert(vc: self, title: "Error", message: error)
        }
    }

    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "segueToAccountMap":
        if let vc = segue.destination as? QRDisplayerViewController {
            vc.text = textToShow
            
            if bbqrFormat {
                vc.headerText = "Wallet Export BBQr"
                vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                vc.descriptionText = "This QR code is best for exporting this wallet to Coldcard, also works with Fully Noded."
                vc.isBbqr = true
                vc.isUR = false
            }
            
            if outputDescFormat {
                vc.headerText = "Wallet Export Descriptor"
                vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                vc.descriptionText = "This QR code is best for exporting this wallet to Sparrow, Passport, Blue Wallet and more, including Fully Noded."
                vc.isBbqr = false
                vc.isUR = true
            }
            
            if urBytesFormat {
                vc.headerText = "Wallet Export UR Bytes"
                vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                vc.descriptionText = "This QR code is best for exporting this wallet to Passport, Blue Wallet and others, including Fully Noded."
                vc.isUR = true
                vc.isBbqr = false
            }
        }
        default:
            break
        }
    }
}

extension WalletDetailViewController {
    
    private func headerName(for section: Section) -> (text: String, icon: UIImage) {
        switch section {
        case .backupText:
            return ("Wallet Info", UIImage(systemName: "info.circle")!)
        case .label:
            return ("Label", UIImage(systemName: "rectangle.and.paperclip")!)
        case .walletExport:
            return ("Wallet export", UIImage(systemName: "square.and.arrow.up")!)
        case .exportFile:
            return ("Backup file", UIImage(systemName: "folder")!)
        case .filename:
            return ("Bitcoin Core filename", UIImage(systemName: "rectangle.and.paperclip")!)
        case .receiveDesc:
            return ("Receive descriptor - keypool", UIImage(systemName: "arrow.down.left")!)
        case .changeDesc:
            return ("Change descriptor - keypool", UIImage(systemName: "arrow.2.circlepath")!)
        case .nextIndexExternal:
            return ("Next receive address index", UIImage(systemName: "number")!)
        case .nextIndexInternal:
            return ("Next change address index", UIImage(systemName: "number")!)
        case .externalRange:
            return ("Receive address range", UIImage(systemName: "list.number")!)
        case .internalRange:
            return ("Change address range", UIImage(systemName: "list.number")!)
        case .addressExplorer:
            return ("Address explorer", UIImage(systemName: "list.number")!)
        }
    }
    
}
