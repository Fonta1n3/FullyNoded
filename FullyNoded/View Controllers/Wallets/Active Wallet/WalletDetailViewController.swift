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
    var listdescriptorsResponse: String?
    var alertStyle = UIAlertController.Style.actionSheet
    private var labelField: UITextField!
    private var labelButton: UIButton!
    private var cellHeights = [IndexPath: CGFloat]()
    
    private enum Section: Int, CaseIterable {
        case label
        case backupText
        case walletExport
        case exportFile
        case filename
        case receiveDesc
        case changeDesc
        case listdescriptors
        case nextIndexExternal
        case nextIndexInternal
        case externalRange
        case internalRange
        case addressExplorer
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.delegate = self
        detailTable.delegate = self
        detailTable.dataSource = self
        addTapGesture()
                
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
        
        load()
    }
    
    private func nodelessButton(_ x: CGFloat) -> UIButton {
        let nodelessButton = UIButton()
        nodelessButton.setTitle("Nodeless", for: .normal)
        nodelessButton.tintColor = .tintColor
        nodelessButton.configuration = .tinted()
        nodelessButton.setTitleColor(.tintColor, for: .normal)
        nodelessButton.frame = CGRect(x: x, y: 10, width: 100, height: 40)
        nodelessButton.addTarget(self, action: #selector(nodeless(_:)), for: .touchUpInside)
        return nodelessButton
    }
    
    @objc func nodeless(_ sender: UIButton) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            performSegue(withIdentifier: "segueToNodelessFromWalletDetail", sender: self)
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
        guard let backup = wallet.walletBackup else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let backup = try decoder.decode(WalletBackup.self, from: backup)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .secondsSince1970
            
            let jsonData = try encoder.encode(backup).hex.utf8
            let fileName = "\(backup.lastUpdate.formattedDate).txt"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            activityVC.excludedActivityTypes = [
                .addToReadingList,
                .assignToContact,
                .markupAsPDF
            ]
            
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
    
    private func getAddresses() {
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
    
    private func prettyPrintedJSON(from data: Data) -> String? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
                let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              var prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        prettyString = prettyString.replacingOccurrences(of: "\\/", with: "/")
        return prettyString
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
                
                self.listdescriptorsResponse = prettyPrintedJSON(from: jsonData)
                                    
                for descriptor in listDescriptorResponse.descriptors {
                    if descriptor.desc == wallet.receiveDescriptor, let range = descriptor.range, let nextExternal = descriptor.nextIndex {
                        self.externalRange = range
                        self.externalNextIndex = nextExternal
                    }
                    
                    if descriptor.desc == wallet.changeDescriptor, let range = descriptor.range, let nextInternal = descriptor.nextIndex {
                        self.internalRange = range
                        self.internalNextIndex = nextInternal
                    }
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    detailTable.reloadSections(IndexSet(arrayLiteral: Section.externalRange.rawValue), with: .none)
                    detailTable.reloadSections(IndexSet(arrayLiteral: Section.internalRange.rawValue), with: .none)
                    detailTable.reloadSections(IndexSet(arrayLiteral: Section.nextIndexExternal.rawValue), with: .none)
                    detailTable.reloadSections(IndexSet(arrayLiteral: Section.nextIndexInternal.rawValue), with: .none)
                    detailTable.reloadSections(IndexSet(arrayLiteral: Section.listdescriptors.rawValue), with: .none)
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
                        
                        let generator = QRGenerator()
                        guard let backup = wallet.walletBackup else { return }
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.sortedKeys] // Optional: consistent ordering
                        encoder.dateEncodingStrategy = .secondsSince1970
                        do {
                            let jsonData = try encoder.encode(backup)
                            self.backupText = jsonData.hexString
                        } catch {
                            showAlert(title: " ", message: "Unable to encode backup.")
                        }
                        
                        guard self.wallet.receiveDescriptor != "" else {
                            showAlert(vc: self, title: "", message: "Unable to get receive descriptor.")
                            return
                        }
                        
                        if !wallet.receiveDescriptor.contains("sortedmulti_a"), let urOutput = URHelper.descriptorToUrOutput(Descriptor(self.wallet.receiveDescriptor)) {
                            generator.qrText = urOutput.uppercased()
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
                        generator.qrText = urBytes
                        self.exportWalletImageURBytes = generator.getQRCode()
                        
                        bbqrText = wallet.receiveDescriptor
                        generator.qrText = bbqrText
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
        CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] utxos in
            guard let self = self else { return }
            guard let utxos = utxos else { return }
            for utxo in utxos {
                let utxoStr = UTXO(from: utxo)
                if utxoStr.walletId == walletId, let utxoId = utxoStr.id {
                    CoreDataService.deleteEntity(id: utxoId, entityName: .utxos) { deleted in }
                }
            }
        }
        
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
            
        case .listdescriptors:
            exportItem(listdescriptorsResponse as Any)
            
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
    
    private func listDescriptorsCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailAdressesCell", for: indexPath)
        configureCell(cell)
        
        let textView = cell.viewWithTag(1) as! UITextView
        
        if let listdescriptorsRespone = listdescriptorsResponse {
            textView.text = listdescriptorsResponse
        } else {
            textView.text = "fetching addresses from your node..."
        }
        
        let exportButton = cell.viewWithTag(2) as! UIButton
        configureExportButton(exportButton, indexPath: indexPath)
        
        let segmentedControl = cell.viewWithTag(3) as! UISegmentedControl
        segmentedControl.alpha = 0
        
        return cell
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
            subheaderLabel.text = ""
            imageView.image = exportWalletImageURBytes
            exportText = urBytes
        }
        
        if bbqrFormat {
            headerLabel.text = "BBQr"
            subheaderLabel.text = ""
            imageView.image = exportWalletImageBBQr
            exportText = bbqrText
        }
        
        if outputDescFormat {
            headerLabel.text = "UR Output Descriptor"
            subheaderLabel.text = ""
            imageView.image = exportWalletImageCryptoOutput
            exportText = outputDescUr
        }
        
        return cell
    }
        
    private func exportFileCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletExportFileCell", for: indexPath)
        configureCell(cell)
        
        let textView = cell.viewWithTag(1) as! UITextView
        textView.text = backupText
        
        let exportButton = cell.viewWithTag(2) as! UIButton
        configureExportButton(exportButton, indexPath: indexPath)
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
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
        case .listdescriptors:
            return listDescriptorsCell(indexPath)
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
        case .listdescriptors:
            return 360
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
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 10
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 30)
        
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
        
        let nodelessButtonRec = nodelessButton(header.frame.maxX - 108)
        nodelessButtonRec.tag = section
        
        if let section = Section(rawValue: section) {
            let (text, image) = headerName(for: section)
            
            textLabel.text = text
            icon.image = image
            
            if section == .receiveDesc {
                textLabel.frame = CGRect(x: 33, y: nodelessButtonRec.frame.midY, width: 300, height: 25)
                icon.frame = CGRect(x: 0, y: nodelessButtonRec.frame.midY, width: 25, height: 25)
                header.addSubview(nodelessButtonRec)
            }
        }
        
        header.addSubview(icon)
        header.addSubview(textLabel)
        
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let section = Section(rawValue: section)
        switch section {
        case .receiveDesc:
            return 60
        default:
            return 30
        }
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
                    vc.isBbqr = true
                    vc.isUR = false
                }
                
                if outputDescFormat {
                    vc.headerText = "UR Wallet Export Descriptor"
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                    vc.isBbqr = false
                    vc.isUR = true
                }
                
                if urBytesFormat {
                    vc.headerText = "Wallet Export UR Bytes"
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                    vc.isUR = true
                    vc.isBbqr = false
                }
            }
        case"segueToNodelessFromWalletDetail":
            guard let vc = segue.destination as? NodelessTableViewController else { fallthrough }
            
            vc.primaryDescriptor = wallet.receiveDescriptor
            vc.changeDescriptor = wallet.changeDescriptor
            
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
        case .listdescriptors:
            return ("All descriptors", UIImage(systemName: "list.number")!)
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
