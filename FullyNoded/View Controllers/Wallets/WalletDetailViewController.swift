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
    var signer = ""
    var spinner = ConnectingView()
    var coinType = "0"
    var addresses = ""
    var originalLabel = ""
    var backupQrImage: UIImage!
    var exportWalletImage: UIImage!
    var backupText = ""
    var exportText = ""
    var textToShow = ""
    var json = ""
    var showReceive = 0
    var alertStyle = UIAlertController.Style.actionSheet
    private var labelField: UITextField!
    private var labelButton: UIButton!
    private var cellHeights = [IndexPath: CGFloat]()
    
    private enum Section: Int {
        case label
        case walletExport
        case backupQr
        case exportFile
        case filename
        case receiveDesc
        case changeDesc
        case currentIndex
        case maxIndex
        case signer
        case watching
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
        var desc = wallet.receiveDescriptor
        
        if wallet.type == WalletType.single.stringValue {
            let ud = UserDefaults.standard
            let nativeSegwit = ud.object(forKey: "nativeSegwit") as? Bool ?? true
            let p2shSegwit = ud.object(forKey: "p2shSegwit") as? Bool ?? false
            let legacy = ud.object(forKey: "legacy") as? Bool ?? false
            
            if desc.hasPrefix("combo") {
                
                if nativeSegwit {
                    desc = desc.replacingOccurrences(of: "combo", with: "wpkh")
                } else if legacy {
                    desc = desc.replacingOccurrences(of: "combo", with: "pkh")
                } else if p2shSegwit {
                    desc = desc.replacingOccurrences(of: "combo", with: "sh(wpkh")
                    desc = desc.replacingOccurrences(of: "#", with: ")#")
                }
                
                let arr = desc.split(separator: "#")
                let bareDesc = "\(arr[0])"
                
                Reducer.makeCommand(command: .getdescriptorinfo, param: "\"\(bareDesc)\"") { [weak self] (response, errorMessage) in
                    if let dict = response as? NSDictionary {
                        if let descriptor = dict["descriptor"] as? String {
                            guard let self = self else { return }
                            self.deriveAddresses(descriptor)
                        }
                    }
                }
                
            } else if wallet.watching != nil {
                let descriptors = wallet.watching!
                var prefix = ""
                var descriptorToUse = ""
                if nativeSegwit {
                    descriptorToUse = wallet.receiveDescriptor
                    
                } else if legacy {
                    prefix = "pkh"
                    for desc in descriptors {
                        if desc.hasPrefix(prefix) && desc.contains("/0/*") {
                            descriptorToUse = desc
                        }
                    }
                    
                } else if p2shSegwit {
                    prefix = "sh(wpkh("
                    for desc in descriptors {
                        if desc.hasPrefix(prefix) && desc.contains("/0/*") {
                            descriptorToUse = desc
                        }
                    }
                }
                deriveAddresses(descriptorToUse)
            } else {
                deriveAddresses(desc)
            }
        } else {
            deriveAddresses(wallet.receiveDescriptor)
        }
    }
    
    private func deriveAddresses(_ descriptor: String) {
        let param = "\"\(descriptor)\", [0,2500]"
        Reducer.makeCommand(command: .deriveaddresses, param: param) { [weak self] (response, errorMessage) in
            if let addr = response as? NSArray {
                for (i, address) in addr.enumerated() {
                    guard let self = self else { return }
                    self.addresses += "#\(i): \(address)\n\n"
                    if i + 1 == addr.count {
                        DispatchQueue.main.async { [weak self] in
                            self?.spinner.removeConnectingView()
                            self?.detailTable.reloadSections(IndexSet(arrayLiteral: Section.addressExplorer.rawValue), with: .none)
                        }
                    }
                }
            } else {
                self?.spinner.removeConnectingView()
                showAlert(vc: self, title: "We were unable to derive your addresses", message: "")
            }
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
                let walletStruct = Wallet(dictionary: w)
                if walletStruct.id == self.walletId {
                    self.wallet = walletStruct
                    
                    if self.wallet.receiveDescriptor.contains("xpub") || self.wallet.receiveDescriptor.contains("xprv") {
                        self.coinType = "0"
                    } else {
                        self.coinType = "1"
                    }
                    
                    self.json = AccountMap.create(wallet: self.wallet) ?? ""
                    
                    let generator = QRGenerator()
                    generator.textInput = self.json
                    self.backupText = self.json
                    self.backupQrImage = generator.getQRCode()
                    
                    guard let urOutput = URHelper.descriptorToUrOutput(Descriptor(self.wallet.receiveDescriptor)) else {
                        showAlert(vc: self, title: "", message: "Unable to convert your wallet to crypto-output.")
                        return
                    }
                    
                    generator.textInput = urOutput.uppercased()
                    self.exportText = urOutput
                    self.exportWalletImage = generator.getQRCode()
                    
                    self.findSigner()
                    self.getAddresses()
                }
            }
        }
    }
    
    private func findSigner() {
        CoreDataService.retrieveEntity(entityName: .signers) { [weak self] signers in
            guard let signers = signers, signers.count > 0 else {
                DispatchQueue.main.async {
                    self?.detailTable.reloadData()
                }
                return
            }
            
            self?.parseSigners(signers)
        }
    }
    
    private func parseSigners(_ signers: [[String:Any]]) {
        for (i, signer) in signers.enumerated() {
            let signerStruct = SignerStruct(dictionary: signer)
            
            if let encryptedWords = signerStruct.words {
                guard let decryptedData = Crypto.decrypt(encryptedWords) else { return }
                
                parseWords(decryptedData, signerStruct)
            }
            
            if i + 1 == signers.count {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.detailTable.reloadData()
                }
            }
        }
    }
    
    private func parseWords(_ decryptedData: Data, _ signer: SignerStruct) {
        let descriptor = Descriptor(self.wallet.receiveDescriptor)
        guard let words = String(bytes: decryptedData, encoding: .utf8) else { return }
        
        if signer.passphrase != nil {
            parsePassphrase(words, signer.passphrase!, descriptor, signer)
        } else {
            guard let masterKey = Keys.masterKey(words: words, coinType: self.coinType, passphrase: "") else { return }
            
            self.crossCheckXpubs(descriptor, masterKey, words, signer)
        }
    }
    
    private func parsePassphrase(_ words: String, _ passphrase: Data, _ descriptor: Descriptor, _ signerStr: SignerStruct) {
        guard let decryptedPass = Crypto.decrypt(passphrase),
            let pass = String(bytes: decryptedPass, encoding: .utf8),
            let masterKey = Keys.masterKey(words: words, coinType: coinType, passphrase: pass) else {
            return
        }
        
        crossCheckXpubs(descriptor, masterKey, words, signerStr)
    }
    
    private func crossCheckXpubs(_ descriptor: Descriptor, _ masterKey: String, _ words: String, _ signerStr: SignerStruct) {
        if descriptor.isMulti {
            for (x, xpub) in descriptor.multiSigKeys.enumerated() {
                if let derivedXpub = Keys.xpub(path: descriptor.derivationArray[x], masterKey: masterKey) {
                    if xpub == derivedXpub {
                        guard let fingerprint = Keys.fingerprint(masterKey: masterKey) else { return }
                        
                        var toDisplay = fingerprint
                        
                        if fingerprint != signerStr.label {
                            toDisplay += ":" + " \(signerStr.label)"
                        }
                        
                        self.signer += toDisplay + "\n\n"
                    }
                }                
            }
        } else {
            if let derivedXpub = Keys.xpub(path: descriptor.derivation, masterKey: masterKey) {
                if descriptor.accountXpub == derivedXpub {
                    guard let fingerprint = Keys.fingerprint(masterKey: masterKey) else { return }
                    
                    var toDisplay = fingerprint
                    
                    if fingerprint != signerStr.label {
                        toDisplay += ":" + " \(signerStr.label)"
                    }
                    
                    self.signer += toDisplay + "\n\n"
                }
            }
        }
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
                    if vc.wallet.name == UserDefaults.standard.object(forKey: "walletName") as? String {
                        UserDefaults.standard.removeObject(forKey: "walletName")
                        NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    }
                    vc.walletDeleted()
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
                    self?.navigationController?.popViewController(animated: true)
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
                let str = Wallet(dictionary: w)
                if str.id == self.walletId {
                    self.wallet = str
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
    
    @objc func export(_ sender: UIButton) {
        guard let sectionString = sender.restorationIdentifier, let section = Int(sectionString) else { return }
        
        switch Section(rawValue: section) {
        case .filename:
            exportItem(wallet.name)
            
        case .walletExport:
            exportItem(exportWalletImage as Any)
            
        case .backupQr:
            exportItem(backupQrImage as Any)
    
        case .exportFile:
            exportJson()
            
        case .receiveDesc:
            exportItem(wallet.receiveDescriptor)
            
        case .changeDesc:
            exportItem(wallet.changeDescriptor)
            
        case .watching:
            guard let watching = wallet.watching else { return }
            
            exportItem(watching.description)
            
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section) {
        case .walletExport:
            textToShow = exportText
            showQr()
        case .backupQr:
            textToShow = backupText
            showQr()
        default:
            break
        }
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
        labelButton.showsTouchWhenHighlighted = true
        
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
    
    private func currentIndexCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailCurrentIndexCell", for: indexPath)
        configureCell(cell)
        
        let field = cell.viewWithTag(1) as! UITextField
        field.text = "\(wallet.index)"
        field.layer.borderColor = UIColor.clear.cgColor
        
        return cell
    }
    
    private func maxIndexCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailMaxIndexCell", for: indexPath)
        configureCell(cell)
        
        let field = cell.viewWithTag(1) as! UITextField
        field.text = "\(wallet.maxIndex)"
        field.isUserInteractionEnabled = false
        field.layer.borderColor = UIColor.clear.cgColor
        
        let increaseButton = cell.viewWithTag(2) as! UIButton
        increaseButton.showsTouchWhenHighlighted = true
        increaseButton.addTarget(self, action: #selector(increaseGapLimit), for: .touchUpInside)
        
        return cell
    }
    
    private func signerCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailSignerCell", for: indexPath)
        configureCell(cell)
        
        let textView = cell.viewWithTag(1) as! UITextView
        textView.text = signer
        
        return cell
    }
    
    private func watchingCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailWatchingCell", for: indexPath)
        configureCell(cell)
        
        let textView = cell.viewWithTag(1) as! UITextView
        var watching = ""
        
        if wallet.watching != nil {
            for watch in wallet.watching! {
                watching += watch + "\n\n"
            }
        }
        
        textView.text = watching
        
        let exportButton = cell.viewWithTag(2) as! UIButton
        configureExportButton(exportButton, indexPath: indexPath)
        
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
        
        imageView.image = exportWalletImage
        
        let exportButton = cell.viewWithTag(2) as! UIButton
        configureExportButton(exportButton, indexPath: indexPath)
        
        return cell
    }
    
    private func backupQrCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletExportQrCell", for: indexPath)
        configureCell(cell)
        
        let imageView = cell.viewWithTag(1) as! UIImageView
        
        imageView.image = backupQrImage
        
        let exportButton = cell.viewWithTag(2) as! UIButton
        configureExportButton(exportButton, indexPath: indexPath)
        
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
        button.showsTouchWhenHighlighted = true
        button.addTarget(self, action: #selector(export(_:)), for: .touchUpInside)
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
        case .label:
            return labelCell(indexPath)
        case .walletExport:
            return exportWalletCell(indexPath)
        case .backupQr:
            return backupQrCell(indexPath)
        case .exportFile:
            return exportFileCell(indexPath)
        case .filename:
            return filenameCell(indexPath)
        case .receiveDesc:
            return recDescCell(indexPath)
        case .changeDesc:
            return changeDescCell(indexPath)
        case .currentIndex:
            return currentIndexCell(indexPath)
        case .maxIndex:
            return maxIndexCell(indexPath)
        case .signer:
            return signerCell(indexPath)
        case .watching:
            return watchingCell(indexPath)
        case .addressExplorer:
            return addressesCell(indexPath)
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section) {
        case .label:
            return 50
        case .backupQr, .walletExport:
            return 192
        case .exportFile:
            return 120
        case .filename:
            return 50
        case .receiveDesc:
            return 120
        case .changeDesc:
            return 120
        case .currentIndex:
            return 50
        case .maxIndex:
            return 50
        case .signer:
            return 50
        case .watching:
            return 120
        case .addressExplorer:
            return 180
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 60)
        
        let background = UIView()
        background.frame = CGRect(x: 0, y: header.frame.minY + 25, width: 35, height: 35)
        background.clipsToBounds = true
        background.layer.cornerRadius = 5
        background.center.y = header.center.y
        
        let icon = UIImageView()
        icon.frame = CGRect(x: 5, y: 5, width: 25, height: 25)
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        textLabel.textColor = .white
        textLabel.frame = CGRect(x: 43, y: 0, width: 300, height: 50)
        textLabel.center.y = background.center.y
        
        if let section = Section(rawValue: section) {
            let (text, image, color) = headerName(for: section)
            
            textLabel.text = text
            icon.image = image
            background.backgroundColor = color
        }
        
        background.addSubview(icon)
        header.addSubview(background)
        header.addSubview(textLabel)
        
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    @objc func updateAddressExplorer(_ sender: UISegmentedControl) {
        showReceive = sender.selectedSegmentIndex
        addresses = ""
        
        if showReceive == 0 {
            spinner.addConnectingView(vc: self, description: "deriving receive addresses...")
            deriveAddresses(wallet.receiveDescriptor)
        } else {
            spinner.addConnectingView(vc: self, description: "deriving change addresses...")
            deriveAddresses(wallet.changeDescriptor)
        }
    }
    
    @objc func increaseGapLimit() {
        var max = Int(wallet.maxIndex) + 2500
        if max > 99999 {
            max = 99999
        }
        
        promptToUpdateMaxIndex(max: max)
    }
    
    private func promptToUpdateMaxIndex(max: Int) {
        if (max - (Int(self.wallet.maxIndex) + 1)) < 20001 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let alert = UIAlertController(title: "Increase the gap limit to \(max)?", message: "Selecting yes will trigger a series of calls to your node to import \(max - (Int(self.wallet.maxIndex) + 1)) additional keys for each descriptor your wallet holds. This can take a bit of time so please be patient and wait for the spinner to dismiss.", preferredStyle: self.alertStyle)
                
                alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
                    self.importUpdatedIndex(maxRange: max)
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            showAlert(vc: self, title: "Thats too many keys...", message: "Please only attempt to import less then 20,000 keys at a time otherwise things can get weird.")
        }
    }
    
    private func updateSpinnerText(text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.spinner.label.text = text
        }
    }
    
    private func importUpdatedIndex(maxRange: Int) {
        spinner.addConnectingView(vc: self, description: "importing \(maxRange - Int(wallet.maxIndex) + 1) public keys...")
        
        var descriptorsToImport = [String]()
        descriptorsToImport.append(wallet.receiveDescriptor)
        descriptorsToImport.append(wallet.changeDescriptor)
        
        if wallet.watching != nil {
            if wallet.watching!.count > 0 {
                for watcher in wallet.watching! {
                    descriptorsToImport.append(watcher)
                }
            }
        }
        
        importDescriptors(index: 0, maxRange: maxRange, descriptorsToImport: descriptorsToImport)
    }
    
    private func importDescriptors(index: Int, maxRange: Int, descriptorsToImport: [String]) {
        let descriptorStruct = Descriptor(wallet.receiveDescriptor)
        var keypool = true
        
        if descriptorStruct.isMulti {
            keypool = false
        }
        
        if index < descriptorsToImport.count {
            updateSpinnerText(text: "importing descriptor #\(index + 1), \(maxRange - Int(wallet.maxIndex) + 1) public keys...")
            
            let descriptor = descriptorsToImport[index]
            
            var params = "[{ \"desc\": \"\(descriptor)\", \"timestamp\": \"now\", \"range\": [\(wallet.maxIndex),\(maxRange)], \"watchonly\": true, \"label\": \"\(wallet.label)\", \"keypool\": false, \"internal\": false }], {\"rescan\": false}"
            
            if descriptor.contains(wallet.receiveDescriptor) {
                params = "[{ \"desc\": \"\(descriptor)\", \"timestamp\": \"now\", \"range\": [\(wallet.maxIndex),\(maxRange)], \"watchonly\": true, \"label\": \"\(wallet.label)\", \"keypool\": \(keypool), \"internal\": false }], {\"rescan\": false}"
            } else if descriptor.contains(wallet.changeDescriptor) {
                params = "[{ \"desc\": \"\(descriptor)\", \"timestamp\": \"now\", \"range\": [\(wallet.maxIndex),\(maxRange)], \"watchonly\": true, \"keypool\": \(keypool), \"internal\": \(keypool) }], {\"rescan\": false}"
            }
            
            importMulti(params: params) { [weak self] success in
                if success {
                    self?.importDescriptors(index: index + 1, maxRange: maxRange, descriptorsToImport: descriptorsToImport)
                } else {
                    self?.showError(error: "Error importing a recovery descriptor.")
                }
            }
        } else {
            self.updateMaxIndex(max: maxRange)
            promptToRescan()
        }
    }
    
    private func promptToRescan() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Rescan now?", message: "You have increased the gap limit but you will need to rescan the blockchain to see updated balances and transaction history.", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Rescan", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.updateSpinnerText(text: "starting a rescan...")
                
                OnchainUtils.rescan { [weak self] (started, message) in
                    guard let self = self else { return }
                    
                    if started {
                        self.spinner.removeConnectingView()
                    } else {
                        self.showError(error: "Error starting a rescan, your wallet has not been saved. Please check your connection to your node and try again.")
                    }
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func importMulti(params: String, completion: @escaping ((Bool)) -> Void) {
        OnchainUtils.importMulti(params) { (imported, message) in
            completion((imported))
        }
    }
    
    private func updateMaxIndex(max: Int) {
        CoreDataService.update(id: walletId, keyToUpdate: "maxIndex", newValue: Int64(max), entity: .wallets) { [weak self] success in
            if success {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.updateLocalWallet()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.detailTable.reloadSections(IndexSet(arrayLiteral: Section.maxIndex.rawValue), with: .none)
                    }
                }
                
                self?.spinner.removeConnectingView()
                showAlert(vc: self, title: "Success, you have imported up to \(max) public keys.", message: "Your wallet is now rescanning. In order to see balances for all your addresses you'll need to wait for the rescan to complete.")
            } else {
                self?.showError(error: "There was an error updating the wallets maximum index.")
            }
        }
    }
    
    private func showError(error:String) {
        DispatchQueue.main.async { [weak self] in
            self?.spinner.removeConnectingView()
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
            
            if textToShow == backupText {
                vc.headerText = "Wallet Backup QR"
                vc.headerIcon = UIImage(systemName: "rectangle.and.paperclip")
                vc.descriptionText = "Save this QR in lots of places so you can always easily recreate this wallet as watch-only. This QR code is best used with Fully Noded only."
            } else {
                vc.headerText = "Wallet Export QR"
                vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                vc.descriptionText = "This QR code is best for exporting this wallet to other software and hardware wallets."
            }
        }
        default:
            break
        }
    }

}

extension WalletDetailViewController {
    
    private func headerName(for section: Section) -> (text: String, icon: UIImage, color: UIColor) {
        switch section {
        case .label:
            return ("Label", UIImage(systemName: "rectangle.and.paperclip")!, .systemBlue)
        case .walletExport:
            return ("Wallet export", UIImage(systemName: "square.and.arrow.up")!, .systemIndigo)
        case .backupQr:
            return ("Backup QR", UIImage(systemName: "qrcode")!, .systemGreen)
        case .exportFile:
            return ("Backup file", UIImage(systemName: "folder")!, .systemPink)
        case .filename:
            return ("Bitcoin Core filename", UIImage(systemName: "rectangle.and.paperclip")!, .systemOrange)
        case .receiveDesc:
            return ("Receive descriptor - keypool", UIImage(systemName: "arrow.down.left")!, .systemBlue)
        case .changeDesc:
            return ("Change descriptor - keypool", UIImage(systemName: "arrow.2.circlepath")!, .systemPurple)
        case .currentIndex:
            return ("Current address index", UIImage(systemName: "number")!, .systemGreen)
        case .maxIndex:
            return ("Gap limit", UIImage(systemName: "exclamationmark.triangle")!, .systemRed)
        case .signer:
            return ("Signers", UIImage(systemName: "pencil.and.ellipsis.rectangle")!, .darkGray)
        case .watching:
            return ("Watching descriptors", UIImage(systemName: "eye")!, .systemOrange)
        case .addressExplorer:
            return ("Address explorer", UIImage(systemName: "list.number")!, .systemBlue)
        }
    }
    
}
