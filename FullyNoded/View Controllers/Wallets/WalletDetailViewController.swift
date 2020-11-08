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
    var alertStyle = UIAlertController.Style.actionSheet
    private var labelField: UITextField!
    private var labelButton: UIButton!
    private var cellHeights = [IndexPath: CGFloat]()
    
    private enum Section: Int {
        case label
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
        setCoinType()
        
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
    }
    
    @IBAction func showAccountMap(_ sender: Any) {
        promptToExportWallet()
    }
    
    @IBAction func showHelp(_ sender: Any) {
        let message = "These are the details for your \"Fully Noded Wallet\". \"Label\" is the label we assing the wallet which can be edited by tapping it. \"Filename\" is your wallet.dat filename that this wallet is represented by on your node, in order to truly delete the wallet you need to delete this file on your node. \"Receive Descriptor Keypool\" is the descriptor your wallet will use to create invoices with. \"Change Descriptor Keypool\" is the descriptor your wallet will use to create change addresses with. \"Maximum Index\" field is the maximum address index your wallet is watching for, in order to increase it simply tap the text field and input a higher number. \"Current Index\" is the highest address index you have a utxo for. You will see the \"Signer\" which can sign for this wallet and any descriptors this wallet is watching for which will be quite a few if this is a Recovery Wallet."
        showAlert(vc: self, title: "Fully Noded Wallets", message: message)
    }
    
    private func promptToExportWallet() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Export wallet?", message: "You can export your wallet as a QR code or a .json file.\n\nIt is recommended to do both.\n\nThe wallet export information contains **public keys only**\n\nYour seed words are something seperate and should be backed up in a much more secure way.\n\nFor multisig it is especially important to keep your public keys backed up as losing them **and** losing one of your seeds can cause permanent loss.", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "QR", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    self?.performSegue(withIdentifier: "segueToAccountMap", sender: self)
                }
            }))
            
            alert.addAction(UIAlertAction(title: ".json file", style: .default, handler: { [weak self] action in
                self?.exportJson()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func exportJson() {
        if let json = AccountMap.create(wallet: wallet) {
            if let url = exportWalletJson(name: wallet.label, data: json.dataUsingUTF8StringEncoding) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let activityViewController = UIActivityViewController(activityItems: ["\(self.wallet.label) Export", url], applicationActivities: nil)
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        activityViewController.popoverPresentationController?.sourceView = self.view
                        activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
                    }
                    self.present(activityViewController, animated: true) {}
                }
            }
        }
    }
    
    private func getAddresses() {
        var desc = wallet.receiveDescriptor
        
        if wallet.type == "Single-Sig" {
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
                
            } else if wallet.watching != nil/* && wallet.name.contains("Coldcard")*/ {
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
                            self?.detailTable.reloadSections(IndexSet(arrayLiteral: 8), with: .none)
                        }
                    }
                }
            }
        }
    }
    
    private func setCoinType() {
        spinner.addConnectingView(vc: self, description: "fetching chain type...")
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { [weak self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                guard let self = self else { return }
                if let chain = dict["chain"] as? String {
                    if chain == "test" {
                        self.coinType = "1"
                        self.load()
                        self.spinner.removeConnectingView()
                    } else {
                        self.load()
                        self.spinner.removeConnectingView()
                    }
                }
            } else {
                self?.showError(error: "Error getting blockchain info, please chack your connection to your node.")
                DispatchQueue.main.async {
                    self?.navigationController?.popToRootViewController(animated: true)
                }
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
        
//        if sender.view != labelButton {
//            disableLabelField()
//        }
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
            guard let decryptedData = Crypto.decrypt(signerStruct.words) else { return }
            
            parseWords(decryptedData, signerStruct)
            
            if i + 1 == signers.count {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.detailTable.reloadData()
                }
            }
        }
    }
    
    private func parseWords(_ decryptedData: Data, _ signer: SignerStruct) {
        let descriptorParser = DescriptorParser()
        let descriptor = descriptorParser.descriptor(self.wallet.receiveDescriptor)
        guard let words = String(bytes: decryptedData, encoding: .utf8) else { return }
        
        if signer.passphrase != nil {
            parsePassphrase(words, signer.passphrase!, descriptor)
        } else {
            guard let masterKey = Keys.masterKey(words: words, coinType: self.coinType, passphrase: "") else { return }
            
            self.crossCheckXpubs(descriptor, masterKey, words)
        }
    }
    
    private func parsePassphrase(_ words: String, _ passphrase: Data, _ descriptor: Descriptor) {
        guard let decryptedPass = Crypto.decrypt(passphrase),
            let pass = String(bytes: decryptedPass, encoding: .utf8),
            let masterKey = Keys.masterKey(words: words, coinType: coinType, passphrase: pass) else {
            return
        }
        
        crossCheckXpubs(descriptor, masterKey, words)
    }
    
    private func crossCheckXpubs(_ descriptor: Descriptor, _ masterKey: String, _ words: String) {
        if descriptor.isMulti {
            for (x, xpub) in descriptor.multiSigKeys.enumerated() {
                if let derivedXpub = Keys.xpub(path: descriptor.derivationArray[x], masterKey: masterKey) {
                    if xpub == derivedXpub {
                        guard let fingerprint = Keys.fingerprint(masterKey: masterKey) else { return }
                        
                        self.signer += fingerprint + "\n\n"
                    }
                }                
            }
        } else {
            if let derivedXpub = Keys.xpub(path: descriptor.derivation, masterKey: masterKey) {
                if descriptor.accountXpub == derivedXpub {
                    guard let fingerprint = Keys.fingerprint(masterKey: masterKey) else { return }
                    
                    self.signer += fingerprint + "\n\n"
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
    
//    private func promptToEditLabel(newLabel: String) {
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//
//            let alert = UIAlertController(title: "Update wallet label?", message: "Selecting yes will update this wallets label.", preferredStyle: self.alertStyle)
//
//            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
//                self.updateLabel(newLabel)
//            }))
//
//            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
//            alert.popoverPresentationController?.sourceView = self.view
//            self.present(alert, animated: true, completion: nil)
//        }
//    }
    
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
            
            showAlert(vc: self, title: "", message: "Wallet label updated ✓")
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
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        guard let sectionString = textField.restorationIdentifier, let section = Int(sectionString) else { return true }
        
        switch Section(rawValue: section) {
        case .label:
            disableLabelField()
        default:
            break
        }
        
        return true
    }
    
//    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        return 1761
//    }
    
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
        labelField.text = wallet.label
        labelField.isUserInteractionEnabled = false
        labelField.returnKeyType = .done
        labelField.delegate = self
        labelField.restorationIdentifier = "\(indexPath.section)"
        configureView(labelField)
        
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
        configureView(label)
        return cell
    }
    
    private func recDescCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailReceiveDescCell", for: indexPath)
        configureCell(cell)
        let textView = cell.viewWithTag(1) as! UITextView
        textView.text = wallet.receiveDescriptor
        configureView(textView)
        return cell
    }
    
    private func changeDescCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailChangeDescCell", for: indexPath)
        configureCell(cell)
        let textView = cell.viewWithTag(1) as! UITextView
        textView.text = wallet.changeDescriptor
        configureView(textView)
        return cell
    }
    
    private func currentIndexCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailCurrentIndexCell", for: indexPath)
        configureCell(cell)
        let field = cell.viewWithTag(1) as! UITextField
        field.text = "\(wallet.index)"
        configureView(field)
        return cell
    }
    
    private func maxIndexCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailMaxIndexCell", for: indexPath)
        configureCell(cell)
        let field = cell.viewWithTag(1) as! UITextField
        field.text = "\(wallet.maxIndex)"
        configureView(field)
        return cell
    }
    
    private func signerCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = detailTable.dequeueReusableCell(withIdentifier: "walletDetailSignerCell", for: indexPath)
        configureCell(cell)
        let textView = cell.viewWithTag(1) as! UITextView
        textView.text = signer
        configureView(textView)
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
            textView.text = watching
        }
        configureView(textView)
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
        configureView(textView)
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 9
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        cell.selectionStyle = .none
    }
    
    private func configureView(_ view: UIView) {
        view.layer.cornerRadius = 8
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor.darkGray.cgColor
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard self.wallet != nil else {
            return UITableViewCell()
        }
        
        originalLabel = wallet.label
        
        switch Section(rawValue: indexPath.section) {
        case .label:
            return labelCell(indexPath)
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
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .white
        textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
        
        if let section = Section(rawValue: section) {
            textLabel.text = headerName(for: section)
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    @objc func indexDidChange(_ sender: UITextField) {
        if sender.text != "" {
            if let updatedIndex = Int(sender.text!) {
                if updatedIndex > wallet.maxIndex {
                    promptToUpdateMaxIndex(max: updatedIndex)
                }
            }
        }
    }
    
//    @objc func labelDidChange(_ sender: UITextField) {
//        if sender.text != "" {
//            if sender.text != originalLabel {
//                originalLabel = sender.text!
//                promptToEditLabel(newLabel: sender.text!)
//            }
//        }
//    }
    
    private func promptToUpdateMaxIndex(max: Int) {
        if (max - (Int(self.wallet.maxIndex) + 1)) < 20001 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let alert = UIAlertController(title: "Import index \(self.wallet.maxIndex + 1) to \(max) public keys?", message: "Selecting yes will trigger a series of calls to your node to import \(max - (Int(self.wallet.maxIndex) + 1)) additional keys for each descriptor your wallet holds. This can take a bit of time so please be patient and wait for the spinner to dismiss.", preferredStyle: self.alertStyle)
                
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
        let descriptorParser = DescriptorParser()
        let descriptorStruct = descriptorParser.descriptor(wallet.receiveDescriptor)
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
            updateSpinnerText(text: "starting a rescan...")
            Reducer.makeCommand(command: .getblockchaininfo, param: "") { [weak self] (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    if let pruned = dict["pruned"] as? Bool {
                        if pruned {
                            if let pruneHeight = dict["pruneheight"] as? Int {
                                Reducer.makeCommand(command: .rescanblockchain, param: "\(pruneHeight)") { (_, _) in }
                                self?.updateMaxIndex(max: maxRange)
                            }
                        } else {
                            Reducer.makeCommand(command: .rescanblockchain, param: "") { (_, _) in }
                            self?.updateMaxIndex(max: maxRange)
                        }
                    }
                } else {
                    self?.showError(error: "Error starting a rescan, your wallet has not been saved. Please check your connection to your node and try again.")
                }
            }
        }
    }
    
    private func importMulti(params: String, completion: @escaping ((Bool)) -> Void) {
        Reducer.makeCommand(command: .importmulti, param: params) { (response, errorDescription) in
            if let result = response as? NSArray {
                if result.count > 0 {
                    if let dict = result[0] as? NSDictionary {
                        if let success = dict["success"] as? Bool {
                            completion((success))
                        } else {
                            completion((false))
                        }
                    }
                } else {
                    completion((false))
                }
            } else {
                completion((false))
            }
        }
    }
    
    private func updateMaxIndex(max: Int) {
        CoreDataService.update(id: walletId, keyToUpdate: "maxIndex", newValue: Int64(max), entity: .wallets) { [weak self] success in
            if success {
                self?.spinner.removeConnectingView()
                showAlert(vc: self, title: "Success, you have imported up to \(max) public keys.", message: "Your wallet is now rescanning, you can check the progress at Tools > Get Wallet Info, if you want to abort the rescan you can do that from Tools as well. In order to see balances for all your addresses you'll need to wait for the rescan to complete.")
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
            if let json = AccountMap.create(wallet: wallet!) {
                vc.text = json
                vc.headerText = "Wallet Export QR"
                vc.descriptionText = "Save this QR in lots of places so you can always easily recreate this wallet as watch-only."
                vc.headerIcon = UIImage(systemName: "rectangle.and.paperclip")
            }
        }
        default:
            break
        }
    }

}

extension WalletDetailViewController {
    
    private func headerName(for section: Section) -> String {
        switch section {
        case .label:
            return "Wallet label"
        case .filename:
            return "Wallet filename - Bitcoin Core"
        case .receiveDesc:
            return "Receive descriptor - keypool"
        case .changeDesc:
            return "Change descriptor - keypool"
        case .currentIndex:
            return "Current address index"
        case .maxIndex:
            return "Maximum address index"
        case .signer:
            return "Signers for this wallet"
        case .watching:
            return "Watching descriptors"
        case .addressExplorer:
            return "Address explorer"
        }
    }
    
}
