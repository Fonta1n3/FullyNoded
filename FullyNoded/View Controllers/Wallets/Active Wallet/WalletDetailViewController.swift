//
//  WalletDetailViewController.swift
//  BitSense
//
//  Created by Peter on 29/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

final class WalletDetailViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UINavigationControllerDelegate {
    
    private let detailTable = UITableView(frame: .zero, style: .grouped)
    
    var walletId: UUID!
    var wallet: Wallet!
    
    let spinner = ConnectingView.shared
    var coinType = "0"
    var addresses = ""
    var originalLabel = ""
    var exportWalletImageCryptoOutput: UIImage!
    var exportWalletImageURBytes: UIImage!
    var backupText = ""
    var backupFileText = ""
    var exportText = ""
    var textToShow = ""
    var showReceive = 0
    var outputDescUr = ""
    var urBytes = ""
    var outputDescFormat = false
    var urBytesFormat = true
    var externalRange: [Int] = []
    var internalRange: [Int] = []
    var externalNextIndex: Int?
    var internalNextIndex: Int?
    var listdescriptorsResponse: String?
    var alertStyle = UIAlertController.Style.actionSheet
    var receiveDescActive = false
    var changeDescActive = false
    var receiveDescTimestamp: Any = "now"
    var changeDescTimestamp: Any = "now"
    
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
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Cypher.bg
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = Cypher.green
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: Cypher.green,
            .font: Cypher.mono(17, weight: .semibold)
        ]
        
        detailTable.backgroundColor = Cypher.bg
        detailTable.separatorStyle = .none
        detailTable.indicatorStyle = .white
        
        view.backgroundColor = .systemBackground
        title = "Wallet"
        
        navigationController?.delegate = self
        if UIDevice.current.userInterfaceIdiom == .pad {
            alertStyle = .alert
        }
        
        configureNavigation()
        configureTable()
        addTapGesture()
        load()
    }
    
    private func configureNavigation() {
        let info = UIBarButtonItem(image: UIImage(systemName: "info.circle"), style: .plain, target: self, action: #selector(showGetWalletInfoAction))
        info.tintColor = Cypher.green

        let delete = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(deleteWallet))
        delete.tintColor = Cypher.danger

        let rescan = UIBarButtonItem(title: "RESCAN", style: .plain, target: self, action: #selector(rescanAction))
        rescan.tintColor = Cypher.green
        rescan.setTitleTextAttributes([.font: Cypher.mono(13, weight: .semibold)], for: .normal)

        navigationItem.rightBarButtonItems = [delete, rescan, info]
    }
    
    private func configureTable() {
        detailTable.rowHeight = UITableView.automaticDimension
        detailTable.estimatedRowHeight = 160
        detailTable.translatesAutoresizingMaskIntoConstraints = false
        detailTable.delegate = self
        detailTable.dataSource = self
        detailTable.separatorStyle = .none
        detailTable.register(UITableViewCell.self, forCellReuseIdentifier: "plain")
        view.addSubview(detailTable)
        
        NSLayoutConstraint.activate([
            detailTable.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            detailTable.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            detailTable.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            detailTable.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Helpers

    private func styledCard(_ views: [UIView], height: CGFloat? = nil) -> UIView {
        let card = UIView()
        card.backgroundColor = Cypher.card
        card.layer.cornerRadius = 2
        card.layer.borderWidth = 1
        card.layer.borderColor = Cypher.line.cgColor

        let stack = UIStackView(arrangedSubviews: views)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])
        return card
    }
    
    private func makeTextView(_ text: String, editable: Bool = false) -> UITextView {
        let tv = UITextView()
        tv.isEditable = editable
        tv.font = Cypher.mono(12)
        tv.textColor = Cypher.text
        tv.backgroundColor = .clear
        tv.tintColor = Cypher.green
        tv.text = text
        return tv
    }

    private func makeExportButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("EXPORT", for: .normal)
        button.titleLabel?.font = Cypher.mono(12, weight: .semibold)
        button.setTitleColor(Cypher.bg, for: .normal)
        button.backgroundColor = Cypher.green
        button.layer.cornerRadius = 2
        button.addTarget(self, action: #selector(exportButtonAction(_:)), for: .touchUpInside)
        return button
    }
    
    private func nodelessButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Nodeless", for: .normal)
        button.tintColor = .tintColor
        button.configuration = .tinted()
        button.setTitleColor(.tintColor, for: .normal)
        button.addTarget(self, action: #selector(nodeless(_:)), for: .touchUpInside)
        return button
    }
    
    @objc private func nodeless(_ sender: UIButton) {
        let vc = NodelessTableViewController()
        vc.primaryDescriptor = wallet.receiveDescriptor
        vc.changeDescriptor = wallet.changeDescriptor
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func showModal(data: [String: Any], title: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let modalVC = TextModalViewController(data: data, viewTitle: title)
            let nav = UINavigationController(rootViewController: modalVC)
            nav.modalPresentationStyle = .fullScreen
            nav.modalTransitionStyle = .coverVertical
            present(nav, animated: true)
        }
    }
    
    @objc func showGetWalletInfoAction() {
        spinner.show(vc: self, description: "Getting wallet info...")
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getwalletinfo) { [weak self] response, errorDesc in
            guard let self else { return }
            spinner.dismiss()
            guard let response = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: "No response from getwalletinfo.")
                return
            }
            showModal(data: response, title: "getwalletinfo")
        }
    }
    
    @objc func rescanAction() {
        promptToRescan()
    }
    
    private func exportJson() {
        guard !backupText.isEmpty else {
            showAlert(title: "Error", message: "No backup data to export.")
            return
        }

        let rawName = wallet.label.isEmpty ? wallet.name : wallet.label
        let safeName = rawName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        let fileName = "\(safeName)-wallet-backup.txt"

        let dir = FileManager.default.temporaryDirectory
        let tempURL = dir.appendingPathComponent(fileName, isDirectory: false)

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }

            guard let data = backupText.data(using: .utf8) else {
                showAlert(title: "Error", message: "Failed to encode backup hex.")
                return
            }

            try data.write(to: tempURL, options: .atomic)

            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            activityVC.excludedActivityTypes = [
                .addToReadingList,
                .assignToContact,
                .markupAsPDF
            ]

            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = view.bounds
                popover.permittedArrowDirections = []
            }

            activityVC.completionWithItemsHandler = { [weak self] _, completed, _, error in
                try? FileManager.default.removeItem(at: tempURL)
                if completed {
                    SuccessView.show(in: self!, title: "Backup Exported", subtitle: "Your wallet backup has been saved.") { }
                } else if let error {
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
        let p: Get_Descriptor_Info = .init(["descriptor": descriptor])
        OnchainUtils.getDescriptorInfo(p) { [weak self] descriptorInfo, message in
            guard let self else { return }
            guard let descriptorInfo else {
                spinner.dismiss()
                showAlert(vc: self, title: "", message: message ?? "Can not get descriptorinfo.")
                return
            }
            let desc = descriptorInfo.descriptor
            var range = externalRange
            if descriptor == wallet.changeDescriptor {
                range = internalRange
            }
            let param: Derive_Addresses = .init(["descriptor": desc, "range": range])
            OnchainUtils.deriveAddresses(param: param) { [weak self] response, message in
                guard let self else { return }
                spinner.dismiss()
                if let addr = response as? NSArray {
                    for (i, address) in addr.enumerated() {
                        addresses += "#\(i): \(address)\n\n"
                        if i + 1 == addr.count {
                            DispatchQueue.main.async {
                                self.detailTable.reloadSections(IndexSet(integer: Section.addressExplorer.rawValue), with: .none)
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
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return prettyString.replacingOccurrences(of: "\\/", with: "/")
    }
    
    private func listDescriptors() {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listdescriptors) { [weak self] response, errorDesc in
            guard let self else { return }
            guard let response else {
                showAlert(vc: self, title: "", message: errorDesc ?? "No response from listdescriptors.")
                return
            }
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: response, options: [])
                let listDescriptorResponse = try JSONDecoder().decode(ListDescriptorsResponse.self, from: jsonData)
                listdescriptorsResponse = prettyPrintedJSON(from: jsonData)
                
                for descriptor in listDescriptorResponse.descriptors {
                    if descriptor.desc == wallet.receiveDescriptor, let range = descriptor.range, let nextExternal = descriptor.nextIndex {
                        externalRange = range
                        externalNextIndex = nextExternal
                        receiveDescActive = descriptor.active
                        receiveDescTimestamp = descriptor.timestamp ?? "now"
                    }
                    if descriptor.desc == wallet.changeDescriptor, let range = descriptor.range, let nextInternal = descriptor.nextIndex {
                        internalRange = range
                        internalNextIndex = nextInternal
                        changeDescActive = descriptor.active
                        changeDescTimestamp = descriptor.timestamp ?? "now"
                    }
                }
                
                DispatchQueue.main.async {
                    let sections: [Section] = [.externalRange, .internalRange, .nextIndexExternal, .nextIndexInternal, .listdescriptors]
                    self.detailTable.reloadSections(IndexSet(sections.map(\.rawValue)), with: .none)
                }
            } catch {
                showAlert(vc: self, title: "", message: error.localizedDescription)
            }
            deriveAddresses(wallet.receiveDescriptor)
        }
    }
    
    private func addTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }
    
    @objc func deleteWallet() {
        promptToDeleteWallet()
    }
        
    private func load() {
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self, let wallets else { return }

            for w in wallets {
                guard w["id"] != nil else { continue }
                let walletStruct = Wallet(dictionary: w)
                guard walletStruct.id == walletId else { continue }

                applyLocalWallet(walletStruct)

                DispatchQueue.main.async {
                    self.detailTable.reloadData()
                }

                self.getAddresses()
                return
            }
        }
    }
    
    private func applyLocalWallet(_ walletStruct: Wallet) {
        wallet = walletStruct
        originalLabel = wallet.label

        coinType = (wallet.receiveDescriptor.contains("xpub") || wallet.receiveDescriptor.contains("xprv")) ? "0" : "1"

        if let backup = wallet.walletBackup {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .secondsSince1970
            if let jsonData = try? encoder.encode(backup) {
                backupText = jsonData.hexString
            }
        }

        let receiveDescriptor = Descriptor(walletStruct.receiveDescriptor)
        var keysText = ""
        var deriv = ""

        if receiveDescriptor.isMulti {
            let xfpArr = xfpArray(xfpString: receiveDescriptor.fingerprint)
            for (i, key) in receiveDescriptor.multiSigKeys.enumerated() {
                keysText += "\(xfpArr[i].condenseWhitespace()):\(key)\n\n"
            }
            let dervs = receiveDescriptor.derivationArray
            let allEqual = dervs.dropLast().allSatisfy { $0 == dervs.last }
            deriv = allEqual ? (dervs.first ?? "") : "Multiple derivations!"
        } else if !wallet.receiveDescriptor.isEmpty {
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

        let generator = QRGenerator()

        if !wallet.receiveDescriptor.contains("sortedmulti_a"),
           let urOutput = URHelper.descriptorToUrOutput(Descriptor(wallet.receiveDescriptor)) {
            outputDescUr = urOutput.uppercased()
            generator.qrText = outputDescUr
            exportWalletImageCryptoOutput = generator.getQRCode()
        }

        if let urBytesCheck = URHelper.dataToUrBytes(backupFileText.utf8) {
            urBytes = urBytesCheck.qrString
            generator.qrText = urBytes
            exportWalletImageURBytes = generator.getQRCode()
        }
    }
    
    private func xfpArray(xfpString: String) -> [String] {
        xfpString
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .components(separatedBy: ",")
    }
    
    private func promptToDeleteWallet() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let message = "Removing the wallet hides it from your \"Fully Noded Wallets\". The wallet will still exist on your node and be accessed via the \"Wallet Manager\" or via bitcoin-cli and bitcoin-qt. In order to completely delete the wallet you need to find the \"Filename\" as listed above on your nodes machine in the .bitcoin directory and manually delete it there."
            let alert = UIAlertController(title: "Remove this wallet?", message: message, preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
                self?.deleteNow()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.popoverPresentationController?.sourceView = view
            present(alert, animated: true)
        }
    }
    
    private func deleteNow() {
        CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] utxos in
            guard let self, let utxos else { return }
            for utxo in utxos {
                let utxoStr = UTXO(from: utxo)
                if utxoStr.walletId == walletId, let utxoId = utxoStr.id {
                    CoreDataService.deleteEntity(id: utxoId, entityName: .utxos) { _ in }
                }
            }
        }
        CoreDataService.deleteEntity(id: walletId, entityName: .wallets) { [weak self] success in
            guard let self else { return }
            if success {
                DispatchQueue.main.async {
                    self.walletDeleted()
                    if self.wallet.name == UserDefaults.standard.object(forKey: "walletName") as? String {
                        UserDefaults.standard.removeObject(forKey: "walletName")
                        NotificationCenter.default.post(name: .refreshWallet, object: nil)
                    }
                }
            } else {
                showAlert(vc: self, title: "Error", message: "We had an error deleting your wallet.")
            }
        }
    }
    
    private func walletDeleted() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let alert = UIAlertController(title: "Fully Noded wallet removed", message: "It will no longer appear in your list of \"Fully Noded Wallets\".", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Done", style: .cancel) { [weak self] _ in
                self?.navigationController?.popToRootViewController(animated: true)
            })
            alert.popoverPresentationController?.sourceView = view
            present(alert, animated: true)
        }
    }
    
    private func updateLabel(_ newLabel: String) {
        CoreDataService.update(id: walletId, keyToUpdate: "label", newValue: newLabel, entity: .wallets) { [weak self] success in
            guard let self else { return }
            guard success else {
                showAlert(vc: self, title: "", message: "There was an error saving your new wallet label.")
                return
            }
            if UserDefaults.standard.object(forKey: "walletName") as? String == wallet.name {
                activeWallet { wallet in
                    guard let wallet else { return }
                    self.wallet = wallet
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .updateWalletLabel, object: nil)
                }
            } else {
                updateLocalWallet()
            }
            showAlert(vc: self, title: "", message: "Wallet label updated ✓")
        }
    }
    
    private func updateLocalWallet() {
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self, let wallets else { return }
            for w in wallets where w["id"] != nil {
                let str = Wallet(dictionary: w)
                if str.id == walletId { wallet = str }
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
            guard let self else { return }
            let activity = UIActivityViewController(activityItems: [item], applicationActivities: nil)
            if UIDevice.current.userInterfaceIdiom == .pad {
                activity.popoverPresentationController?.sourceView = view
                activity.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
            present(activity, animated: true)
        }
    }
    
    @objc func chooseExportFormatButtonAction(_ sender: UIButton) {
        urBytesFormat.toggle()
        outputDescFormat = !urBytesFormat

        DispatchQueue.main.async {
            self.detailTable.reloadSections(IndexSet(integer: Section.walletExport.rawValue), with: .fade)
        }
    }
    
    @objc func enlargeButtonAction(_ sender: UIButton) {
        textToShow = exportText
        showQr()
    }
    
    @objc func exportButtonAction(_ sender: UIButton) {
        guard let section = Section(rawValue: sender.tag) else { return }
        switch section {
        case .backupText: exportItem(backupFileText)
        case .filename: exportItem(wallet.name)
        case .listdescriptors: exportItem(listdescriptorsResponse as Any)
        case .walletExport:
            if outputDescFormat {
                exportItem(exportWalletImageCryptoOutput as Any)
            } else {
                exportItem(exportWalletImageURBytes as Any)
            }
        case .exportFile: exportJson()
        case .receiveDesc: exportItem(wallet.receiveDescriptor)
        case .changeDesc: exportItem(wallet.changeDescriptor)
        case .addressExplorer: exportItem(addresses)
        default: break
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if textField === labelField { updateLabelAction() }
        return true
    }
    
    private func showQr() {
        //let vc = QRDisplayerViewController()
        
        //navigationController?.pushViewController(vc, animated: true)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToAccountMap", sender: self)
        }
    }
    
    // MARK: - Table
    
    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cellHeights[indexPath] = cell.frame.size.height
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        cellHeights[indexPath] ?? UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard wallet != nil else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "plain")
            ?? UITableViewCell(style: .default, reuseIdentifier: "plain")
            cell.textLabel?.textColor = Cypher.dim
            return cell
        }
        
        originalLabel = wallet.label
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "plain", for: indexPath)
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let content: UIView
        switch Section(rawValue: indexPath.section) {
        case .label: content = labelContent()
        case .backupText: content = walletInfoContent()
        case .walletExport: content = exportWalletContent()
        case .exportFile: content = backupFileExportContent()
        case .filename: content = filenameContent()
        case .receiveDesc: content = descriptorContent(wallet.receiveDescriptor, section: .receiveDesc, isActive: receiveDescActive)
        case .changeDesc: content = descriptorContent(wallet.changeDescriptor, section: .changeDesc, isActive: changeDescActive)
        case .listdescriptors: content = listDescriptorsContent()
        case .externalRange: content = valueFieldContent("\(externalRange)")
        case .internalRange: content = valueFieldContent("\(internalRange)")
        case .nextIndexExternal: content = valueFieldContent(externalNextIndex.map(String.init) ?? "")
        case .nextIndexInternal: content = valueFieldContent(internalNextIndex.map(String.init) ?? "")
        case .addressExplorer: content = addressesContent()
        default: content = UIView()
        }
        
        content.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
            content.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4)
        ])
        return cell
    }
    
    private func labelContent() -> UIView {
        let field = UITextField()
        field.text = wallet.label
        field.textColor = Cypher.text
        field.isUserInteractionEnabled = false
        field.returnKeyType = .done
        field.delegate = self
        field.borderStyle = .none
        labelField = field
        
        let button = UIButton(type: .system)
        button.setTitle("edit", for: .normal)
        button.addTarget(self, action: #selector(startEditingLabel), for: .touchUpInside)
        labelButton = button
        
        let row = UIStackView(arrangedSubviews: [field, button])
        row.axis = .horizontal
        row.spacing = 8
        button.setContentHuggingPriority(.required, for: .horizontal)
        return styledCard([row])
    }
    
    private func walletInfoContent() -> UIView {
        let tv = makeTextView(backupFileText)
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        tv.setContentCompressionResistancePriority(.required, for: .vertical)

        let export = makeExportButton()
        export.tag = Section.backupText.rawValue
        export.setContentHuggingPriority(.required, for: .horizontal)

        let exportRow = UIStackView(arrangedSubviews: [UIView(), export])
        exportRow.axis = .horizontal
        exportRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [tv, exportRow])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill

        return styledCard([stack])
    }
    
    private func backupFileExportContent() -> UIView {
        let label = UILabel()
        label.text = "This wallet backup file export is for Fully Noded usage only. It is your wallet's descriptors in JSON data format, encoded as a hex string."
        label.numberOfLines = 0
        //label.font = .systemFont(ofSize: 15)
        label.font = Cypher.mono(13)
        label.textColor = Cypher.text//.label

        let export = makeExportButton()
        export.tag = Section.exportFile.rawValue
        export.setContentHuggingPriority(.required, for: .horizontal)

        let exportRow = UIStackView(arrangedSubviews: [UIView(), export])
        exportRow.axis = .horizontal
        exportRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [label, exportRow])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill

        return styledCard([stack])
    }
    
    private func filenameContent() -> UIView {
        let label = UILabel()
        label.text = wallet.name + ".dat"
        //label.tintColor = Cypher.text
        label.textColor = Cypher.text
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)

        let export = makeExportButton()
        export.tag = Section.filename.rawValue
        export.setContentHuggingPriority(.required, for: .horizontal)

        let exportRow = UIStackView(arrangedSubviews: [UIView(), export])
        exportRow.axis = .horizontal
        exportRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [label, exportRow])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill

        return styledCard([stack])
    }
    
    private func listDescriptorsContent() -> UIView {
        let tv = makeTextView(listdescriptorsResponse ?? "fetching addresses from your node...")
        tv.isScrollEnabled = true
        tv.isEditable = false
        tv.showsVerticalScrollIndicator = true
        tv.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        tv.textContainer.lineFragmentPadding = 0

        let textHeight = tv.heightAnchor.constraint(equalToConstant: 280)
        textHeight.priority = .required
        textHeight.isActive = true

        let export = makeExportButton()
        export.tag = Section.listdescriptors.rawValue
        export.setContentHuggingPriority(.required, for: .horizontal)
        export.setContentCompressionResistancePriority(.required, for: .vertical)

        let exportRow = UIStackView(arrangedSubviews: [UIView(), export])
        exportRow.axis = .horizontal
        exportRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [tv, exportRow])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        return styledCard([stack])
    }
    
    private func addressesContent() -> UIView {
        let tv = makeTextView(addresses.isEmpty ? "fetching addresses from your node..." : addresses)
        tv.isScrollEnabled = true
        tv.isEditable = false
        tv.showsVerticalScrollIndicator = true
        tv.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        tv.textContainer.lineFragmentPadding = 0
        tv.heightAnchor.constraint(equalToConstant: 440).isActive = true

        let control = UISegmentedControl(items: ["Receive", "Change"])
        control.backgroundColor = Cypher.card
        control.selectedSegmentTintColor = Cypher.green
        control.selectedSegmentIndex = showReceive
        control.addTarget(self, action: #selector(updateAddressExplorer(_:)), for: .valueChanged)
        control.heightAnchor.constraint(equalToConstant: 32).isActive = true
        control.setContentCompressionResistancePriority(.required, for: .vertical)
        control.setTitleTextAttributes([.font: Cypher.mono(12), .foregroundColor: Cypher.dim], for: .normal)
        control.setTitleTextAttributes([.font: Cypher.mono(12, weight: .semibold), .foregroundColor: Cypher.bg], for: .selected)

        let export = makeExportButton()
        export.tag = Section.addressExplorer.rawValue
        export.setContentHuggingPriority(.required, for: .horizontal)
        export.setContentCompressionResistancePriority(.required, for: .vertical)
        export.widthAnchor.constraint(equalToConstant: 88).isActive = true

        let exportRow = UIStackView(arrangedSubviews: [UIView(), export])
        exportRow.axis = .horizontal
        exportRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [tv, control, exportRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .fill
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        return styledCard([stack])
    }
    
    private func valueFieldContent(_ text: String) -> UIView {
        let field = UITextField()
        field.text = text
        field.textColor = Cypher.text
        field.isUserInteractionEnabled = false
        field.borderStyle = .none
        return styledCard([field])
    }
    
    private func textExportContent(_ text: String, section: Section, showExport: Bool) -> UIView {
        let tv = makeTextView(text)
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        tv.setContentCompressionResistancePriority(.required, for: .vertical)

        var views: [UIView] = [tv]
        if showExport {
            let export = makeExportButton()
            export.tag = section.rawValue
            export.setContentHuggingPriority(.required, for: .horizontal)

            let exportRow = UIStackView(arrangedSubviews: [UIView(), export])
            exportRow.axis = .horizontal
            exportRow.alignment = .center
            views.append(exportRow)
        }

        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill

        return styledCard([stack])
    }
    
    private func descriptorContent(_ text: String, section: Section, isActive: Bool) -> UIView {
        let status = UILabel()
        //status.font = .systemFont(ofSize: 15, weight: .medium)
        //status.text = isActive ? "Active" : "Inactive"
        //status.textColor = isActive ? Cypher.text : .secondaryLabel
        status.setContentCompressionResistancePriority(.required, for: .vertical)
        status.font = Cypher.mono(13, weight: .semibold)
        status.text = isActive ? "ACTIVE" : "INACTIVE"
        status.textColor = isActive ? Cypher.green : Cypher.dim

        let toggle = UISwitch()
        toggle.isOn = isActive
        toggle.onTintColor = Cypher.green
        toggle.isEnabled = !isActive
        toggle.tag = section.rawValue
        toggle.addTarget(self, action: #selector(activeToggleChanged(_:)), for: .valueChanged)
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)

        let activeRow = UIStackView(arrangedSubviews: [status, UIView(), toggle])
        activeRow.axis = .horizontal
        activeRow.alignment = .center
        activeRow.spacing = 8

        let tv = makeTextView(text)
        tv.isScrollEnabled = false
        tv.isEditable = false
        tv.textColor = isActive ? Cypher.text : Cypher.dim
        tv.alpha = isActive ? 1 : 0.7
        tv.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        tv.setContentHuggingPriority(.defaultLow, for: .vertical)

        let export = makeExportButton()
        export.tag = section.rawValue
        export.setContentHuggingPriority(.required, for: .horizontal)
        export.setContentCompressionResistancePriority(.required, for: .vertical)

        let exportRow = UIStackView(arrangedSubviews: [UIView(), export])
        exportRow.axis = .horizontal
        exportRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [activeRow, tv, exportRow])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        return styledCard([stack])
    }
    
    private func exportWalletContent() -> UIView {
        let header = UILabel()
        header.font = .systemFont(ofSize: 17, weight: .semibold)
        header.textAlignment = .center

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.heightAnchor.constraint(equalToConstant: 160).isActive = true

        if outputDescFormat {
            header.text = "UR Output Descriptor"
            imageView.image = exportWalletImageCryptoOutput
            exportText = outputDescUr
        } else {
            header.text = "UR Bytes"
            imageView.image = exportWalletImageURBytes
            exportText = urBytes
            urBytesFormat = true
            outputDescFormat = false
        }

        let format = UIButton(type: .system)
        format.setTitle("Format", for: .normal)
        format.addTarget(self, action: #selector(chooseExportFormatButtonAction(_:)), for: .touchUpInside)

        let enlarge = UIButton(type: .system)
        enlarge.setTitle("Enlarge", for: .normal)
        enlarge.addTarget(self, action: #selector(enlargeButtonAction(_:)), for: .touchUpInside)

        let controls = UIStackView(arrangedSubviews: [format, enlarge])
        controls.axis = .horizontal
        controls.alignment = .center
        controls.spacing = 16
        controls.distribution = .equalSpacing
        controls.translatesAutoresizingMaskIntoConstraints = false

        let controlsHost = UIView()
        controlsHost.addSubview(controls)
        NSLayoutConstraint.activate([
            controls.centerXAnchor.constraint(equalTo: controlsHost.centerXAnchor),
            controls.topAnchor.constraint(equalTo: controlsHost.topAnchor),
            controls.bottomAnchor.constraint(equalTo: controlsHost.bottomAnchor),
            controls.leadingAnchor.constraint(greaterThanOrEqualTo: controlsHost.leadingAnchor),
            controls.trailingAnchor.constraint(lessThanOrEqualTo: controlsHost.trailingAnchor)
        ])

        let export = makeExportButton()
        export.tag = Section.walletExport.rawValue
        export.setContentHuggingPriority(.required, for: .horizontal)

        let exportRow = UIStackView(arrangedSubviews: [UIView(), export])
        exportRow.axis = .horizontal
        exportRow.alignment = .center

        return styledCard([header, imageView, controlsHost, exportRow])
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section) {
        case .nextIndexExternal, .nextIndexInternal, .label, .externalRange, .internalRange: return 50
        case .filename, .exportFile, .backupText, .walletExport, .receiveDesc, .changeDesc, .listdescriptors, .addressExplorer:
            return UITableView.automaticDimension
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 10 }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionKind = Section(rawValue: section) else { return nil }
        let header = UIView()
        header.backgroundColor = .clear
        
        let icon = UIImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit
        
        let textLabel = UILabel()
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        
        textLabel.font = Cypher.mono(13, weight: .medium)
        textLabel.textColor = Cypher.dim
        icon.tintColor = Cypher.green
        header.backgroundColor = .clear
        
        let (text, image) = headerName(for: sectionKind)
        textLabel.text = text
        icon.image = image
        
        header.addSubview(icon)
        header.addSubview(textLabel)
        
        var constraints = [
            icon.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 25),
            icon.heightAnchor.constraint(equalToConstant: 25),
            textLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            textLabel.centerYAnchor.constraint(equalTo: icon.centerYAnchor)
        ]
        
        if sectionKind == .receiveDesc {
            let button = nodelessButton()
            button.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(button)
            constraints.append(contentsOf: [
                button.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
                button.centerYAnchor.constraint(equalTo: header.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 100),
                button.heightAnchor.constraint(equalToConstant: 40)
            ])
        }
        
        NSLayoutConstraint.activate(constraints)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        Section(rawValue: section) == .receiveDesc ? 60 : 30
    }
    
    @objc private func activeToggleChanged(_ sender: UISwitch) {
        guard let section = Section(rawValue: sender.tag) else { return }
        
        let alreadyActive = (section == .receiveDesc && receiveDescActive) || (section == .changeDesc && changeDescActive)
        
        if alreadyActive {
            sender.setOn(true, animated: false)
            sender.isEnabled = false
            return
        }

        if let cell = sender.ancestor(ofType: UITableViewCell.self) {
            applyActiveStyle(in: cell, isActive: sender.isOn)
        }
        
        if section == .receiveDesc { receiveDescActive = sender.isOn }
        if section == .changeDesc { changeDescActive = sender.isOn }
        
        guard sender.isOn else { return }

        let isChange = section == .changeDesc
        let desc = isChange ? wallet.changeDescriptor : wallet.receiveDescriptor
        let range = isChange ? internalRange : externalRange
        let next = isChange ? internalNextIndex : externalNextIndex
        let existingTimestamp = isChange ? changeDescTimestamp : receiveDescTimestamp

        pruneSafeTimestamp(existing: existingTimestamp) { [weak self] safeTimestamp in
            guard let self else { return }
            
            guard !desc.isEmpty else {
                sender.setOn(false, animated: true)
                showAlert(vc: self, title: "", message: "Missing descriptor.")
                return
            }

            var request: [String: Any] = [
                "desc": desc,
                "active": true,
                "internal": isChange,
                "timestamp": safeTimestamp
            ]

            if range.count == 2 {
                request["range"] = range
            }
            if let next {
                request["next_index"] = next
            }

            spinner.show(vc: self, description: "Setting descriptor active...")

            let param: Import_Descriptors = .init(["requests": [request]])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .importdescriptors(param: param)) { [weak self] response, errorDesc in
                guard let self else { return }
                spinner.dismiss()

                if let errorDesc, !errorDesc.isEmpty {
                    sender.setOn(false, animated: true)
                    showAlert(vc: self, title: "importdescriptors failed", message: errorDesc)
                    return
                }

                if let arr = response as? [[String: Any]],
                   arr.contains(where: { ($0["success"] as? Bool) != true }) {
                    let msg = (arr.first?["error"] as? [String: Any])?["message"] as? String
                    sender.setOn(false, animated: true)
                    showAlert(vc: self, title: "importdescriptors failed", message: msg ?? "Unknown error.")
                    return
                }

                if isChange {
                    changeDescActive = true
                } else {
                    receiveDescActive = true
                }

                DispatchQueue.main.async {
                    self.addresses = ""
                    self.load()
                    showAlert(vc: self, title: "", message: "Descriptor set to active.")
                }
            }
        }
    }
    
    private func applyActiveStyle(in cell: UITableViewCell, isActive: Bool) {
        func walk(_ view: UIView) {
            if let label = view as? UILabel, label.text == "Active" || label.text == "Inactive" {
                label.text = isActive ? "Active" : "Inactive"
                label.textColor = isActive ? Cypher.text : Cypher.dim
            }
            if let tv = view as? UITextView {
                tv.textColor = isActive ? Cypher.text : Cypher.dim
                tv.alpha = isActive ? 1.0 : 0.7
            }
            view.subviews.forEach(walk)
        }
        walk(cell.contentView)
    }
    
    private func pruneSafeTimestamp(existing: Any, completion: @escaping (Any) -> Void) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getblockchaininfo) { response, _ in
            guard let info = response as? [String: Any],
                  info["pruned"] as? Bool == true,
                  let pruneHeight = info["pruneheight"] as? Int else {
                completion(existing)
                return
            }

            let ts: Int
            if let n = existing as? Int {
                ts = n
            } else if let n = existing as? Int64 {
                ts = Int(n)
            } else if let s = existing as? String, s != "now", let n = Int(s) {
                ts = n
            } else {
                completion(existing)
                return
            }

            let hashParam: Get_Block_Hash = .init(["height": pruneHeight])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .getblockhash(hashParam)) { hashResponse, _ in
                let hash: String?
                if let s = hashResponse as? String {
                    hash = s
                } else if let dict = hashResponse as? [String: Any] {
                    hash = dict["result"] as? String
                } else {
                    hash = nil
                }

                guard let hash else {
                    completion("now")
                    return
                }

                let blockParam: Get_Block = .init(["blockhash": hash])
                MakeRPCCall.sharedInstance.executeRPCCommand(method: .getblock(blockParam)) { blockResponse, _ in
                    let pruneTime = (blockResponse as? [String: Any])?["time"] as? Int ?? 0
                    completion(ts < pruneTime ? "now" : existing)
                }
            }
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
            guard let self else { return }
            let alert = UIAlertController(title: "Rescan?", message: "Input the year you'd like to rescan from.", preferredStyle: .alert)
            let rescan = UIAlertAction(title: "Rescan", style: .default) { [weak self] _ in
                guard let self else { return }
                let textField = alert.textFields![0]
                var blockheight = 0
                let currentYear = Int(Calendar.current.component(.year, from: .now))
                if let text = textField.text {
                    var yearToScanFrom = Int(text) ?? 2009
                    if yearToScanFrom <= currentYear {
                        if yearToScanFrom < 2010 { yearToScanFrom = 2010 }
                        let yearsToScan = (currentYear - yearToScanFrom) + 1
                        let blocksToScan = yearsToScan * 55000
                        spinner.show(vc: self, description: "rescanning...")
                        OnchainUtils.getBlockchainInfo { [weak self] blockchainInfo, message in
                            guard let self else { return }
                            guard let blockchainInfo else {
                                spinner.dismiss()
                                showAlert(vc: self, title: "", message: message ?? "Unknown issue getblockchaininfo.")
                                return
                            }
                            if !blockchainInfo.initialblockdownload {
                                blockheight = blockchainInfo.blockheight - blocksToScan
                                if blockchainInfo.pruned, blockheight < blockchainInfo.pruneheight {
                                    blockheight = blockchainInfo.pruneheight
                                }
                                OnchainUtils.rescanNow(from: blockheight) { [weak self] started, message in
                                    guard let self else { return }
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
            alert.addTextField { field in
                field.placeholder = "From year"
                field.keyboardAppearance = .dark
                field.keyboardType = .numberPad
                field.text = "2009"
            }
            alert.addAction(rescan)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.popoverPresentationController?.sourceView = view
            present(alert, animated: true)
        }
    }
    
    private func headerName(for section: Section) -> (text: String, icon: UIImage) {
        switch section {
        case .backupText: return ("Wallet Info", UIImage(systemName: "info.circle")!)
        case .label: return ("Label", UIImage(systemName: "rectangle.and.paperclip")!)
        case .walletExport: return ("Wallet export", UIImage(systemName: "square.and.arrow.up")!)
        case .exportFile: return ("Backup file", UIImage(systemName: "folder")!)
        case .filename: return ("Bitcoin Core filename", UIImage(systemName: "rectangle.and.paperclip")!)
        case .receiveDesc: return ("Receive descriptor - keypool", UIImage(systemName: "arrow.down.left")!)
        case .changeDesc: return ("Change descriptor - keypool", UIImage(systemName: "arrow.2.circlepath")!)
        case .listdescriptors: return ("All descriptors", UIImage(systemName: "list.number")!)
        case .nextIndexExternal: return ("Next receive address index", UIImage(systemName: "number")!)
        case .nextIndexInternal: return ("Next change address index", UIImage(systemName: "number")!)
        case .externalRange: return ("Receive address range", UIImage(systemName: "list.number")!)
        case .internalRange: return ("Change address range", UIImage(systemName: "list.number")!)
        case .addressExplorer: return ("Address explorer", UIImage(systemName: "list.number")!)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "segueToAccountMap":
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.text = textToShow
                
                if outputDescFormat {
                    vc.headerText = "UR Wallet Export Descriptor"
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                    vc.isUR = true
                }
                
                if urBytesFormat {
                    vc.headerText = "Wallet Export UR Bytes"
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                    vc.isUR = true
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

extension UIView {
    func ancestor<T: UIView>(ofType type: T.Type) -> T? {
        var view: UIView? = self
        while let current = view {
            if let match = current as? T { return match }
            view = current.superview
        }
        return nil
    }
}

private enum Cypher {
    static let bg = UIColor.black
    static let card = UIColor(white: 0.06, alpha: 1)
    static let line = UIColor(red: 0.2, green: 1.0, blue: 0.45, alpha: 0.55)
    static let green = UIColor(red: 0.25, green: 1.0, blue: 0.48, alpha: 1)
    static let dim = UIColor(red: 0.35, green: 0.7, blue: 0.45, alpha: 1)
    static let text = UIColor(red: 0.75, green: 1.0, blue: 0.82, alpha: 1)
    static let danger = UIColor(red: 1.0, green: 0.28, blue: 0.32, alpha: 1)

    static func mono(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: weight)
    }
}
