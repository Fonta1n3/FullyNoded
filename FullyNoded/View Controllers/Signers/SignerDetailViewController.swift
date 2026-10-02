//
//  SignerDetailViewController.swift
//  BitSense
//
//  Created by Peter on 05/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit
import LocalAuthentication

/// Signer detail screen, built entirely in code (no storyboard scene, outlets or segues).
/// Push it with `SignerDetailViewController(id:)`.
class SignerDetailViewController: UIViewController, UINavigationControllerDelegate {
    
    var id:UUID!
    var cosigner:Descriptor?
    private let spinner = ConnectingView.shared
    private var signer: SignerStruct!
    private var tableDict = [[String:Any]]()
    private var network = 0
    private var stringToExport = ""
    private var descriptionText = ""
    private var headerText = ""
    private var nodelessDescriptor = ""
    private var showWords = false
    
    private enum Section: Int {
        case label
        case words
        case masterKeyFingerprint
        case passphrase
        case dateAdded
        case signableWallets
        case cosigner
        case singleSigBip84
        case singleSigBip86
        case silentPayment
        case silentPaymentScanKey
    }
    
    // MARK: - Views (programmatic)
    
    /// Network switch (main / test), top right under the navigation bar.
    private let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["main", "test"])
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.backgroundColor = .clear
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 61
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(UITableViewCell.self, forCellReuseIdentifier: "defaultCell")
        return table
    }()
    
    // MARK: - Init
    
    init(id: UUID) {
        self.id = id
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        extendedLayoutIncludesOpaqueBars = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        hidesBottomBarWhenPushed = true
        extendedLayoutIncludesOpaqueBars = true
    }
    
    private func setupViews() {
        view.backgroundColor = SignerTheme.bg
        overrideUserInterfaceStyle = .dark
        navigationItem.title = "Signers"
        SignerTheme.styleNavigation(navigationItem)
        
        // Same buttons as before: rightmost trash (delete signer), then eye (show words).
        let deleteItem = UIBarButtonItem(image: UIImage(systemName: "trash.circle"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(deleteAction(_:)))
        deleteItem.tintColor = SignerTheme.danger
        
        let showItem = UIBarButtonItem(image: UIImage(systemName: "eye"),
                                       style: .plain,
                                       target: self,
                                       action: #selector(showSignerAction(_:)))
        showItem.tintColor = SignerTheme.accent
        
        navigationItem.rightBarButtonItems = [deleteItem, showItem]
        
        segmentedControl.addTarget(self, action: #selector(switchNetwork(_:)), for: .valueChanged)
        SignerTheme.style(segmentedControl)

        tableView.backgroundColor = SignerTheme.bg
        tableView.separatorStyle = .none
        tableView.indicatorStyle = .white
        
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            segmentedControl.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -20)
        ])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        
        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.estimatedSectionFooterHeight = 50
        navigationController?.delegate = self
        
        tableDict = [
            [
                "text":"",
             "footerText": "Tap the label to edit it."
            ],// label 0
            [
                "text": "", "censoredText": "", "footerText": "BIP39 seed words, you need these to sign transactions and recover your wallet."
            ],// words 1
            [
                "text": "", "footerText": "The fingerprint of your master key. Some hardware wallets require this infomation in order to sign PSBT's."
            ],// xfp 2
            [
                "text": "", "footerText": "Tap the passphrase to edit it. ⚠️ This has MAJOR implications, for experts only!"
            ],// passphrase 3
            [
                "text": "", "footerText": "When you added this signer."
            ],// dateAdded 4
            [
                "text": "", "footerText": "The wallets which this signer can sign for. Tap the + button to create a wallet with this signer."
            ],// wallets 5
            [
                "text": "", "ur": "", "footerText": "This can be used to create multisig wallets via the multisig creator."
            ],// cosigner 6
            [
                "text": "", "ur": "", "footerText": "The native segwit watch-only descriptor, can be used to create a segwit watch-only wallet from this signer."
            ],// singlesigbip84 7
            [
                "text": "", "ur": "", "footerText": "The taproot watch-only descriptor, can be used to create a taproot watch-only wallet from this signer."
            ],// singlesigbip86 8
            [
                "text": "", "footerText": "Your BIP352 silent payment address. Share it publicly to receive bitcoin privately: every payment to it lands at a new address that can't be linked to it on-chain. Tap the QR button to export it."
            ],// silentPayment 9
            [
                "text": "Hidden. Tap the QR button to export it (requires authentication).", "footerText": "Your BIP352 scan private key, for a silent payment scanner you control such as Fully Noded Server. It can't spend your bitcoin, but anyone who has it can see every silent payment you receive, so never share it with a third party."
            ]// silentPaymentScanKey 10
        ]
        
        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        if chain != "main" {
            network = 1
        }
        segmentedControl.selectedSegmentIndex = network
        getData()
    }
    
    private func headerName(for section: Section) -> String {
        switch section {
        case .label:
            return "Label"
        case .words:
            return "BIP39 words"
        case .masterKeyFingerprint:
            return "Fingerprint"
        case .passphrase:
            return "Passphrase"
        case .dateAdded:
            return "Date added"
        case .signableWallets:
            return "Wallets"
        case .cosigner:
            return "Cosigner - BIP48"
        case .singleSigBip84:
            return "Descriptor - BIP84"
        case .singleSigBip86:
            return "Descriptor - BIP86"
        case .silentPayment:
            return "Silent Payment Address"
        case .silentPaymentScanKey:
            return "SP Scan Private Key"
        }
    }
    
    /// SF Symbol shown next to each section header (as on the wallet detail screen).
    private func headerIconName(for section: Section) -> String {
        switch section {
        case .label: return "rectangle.and.paperclip"
        case .words: return "key"
        case .masterKeyFingerprint: return "touchid"
        case .passphrase: return "lock"
        case .dateAdded: return "calendar"
        case .signableWallets: return "wallet.pass"
        case .cosigner: return "person.2"
        case .singleSigBip84, .singleSigBip86: return "doc.text"
        case .silentPayment: return "eye.slash"
        case .silentPaymentScanKey: return "eye"
        }
    }

    @objc func switchNetwork(_ sender: Any) {
        network = segmentedControl.selectedSegmentIndex
        getData()
    }
    
    private func configureField(_ field: UIView) {
        field.clipsToBounds = true
        field.layer.cornerRadius = 0
        field.layer.borderWidth = 1
        field.layer.borderColor = SignerTheme.line.cgColor
    }
    
    private func reloadTable() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.tableView.reloadData()
        }
    }
    
    @objc func showSignerAction(_ sender: Any) {
        guard let _ = KeyChain.getData("UnlockPassword") else {
            showAlert(vc: self, title: "You are not using the app securely...", message: "You can only show signers if the app has a lock/unlock password. Tap the lock button on the home screen to add a password.")
            
            return
        }
        
        // Face ID / Touch ID, else the APP password. Never the device passcode.
        AppAuthentication.authenticate(from: self, reason: "To show your seed words") { [weak self] success in
            guard let self = self, success else { return }

            //self.tableDict[1]["censoredText"] = self.tableDict[1]["text"] as? String ?? "no seed words"
            //tableDict.removeAll()
            self.showWords = true
            self.getData()
        }
    }
    
    @objc func deleteAction(_ sender: Any) {
        promptToDeleteSigner()
    }
    
    private func promptToDeleteSigner() {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.alert
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            
            let alert = UIAlertController(title: "Remove this signer?", message: "YOU WILL NOT BE ABLE TO SPEND BITCOIN ASSOCIATED WITH THIS SIGNER IF YOU DELETE THIS SIGNER", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [unowned vc = self] action in
                vc.deleteNow()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func deleteNow() {
        CoreDataService.deleteEntity(id: id, entityName: .signers) { [unowned vc = self] success in
            if success {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.navigationController?.popViewController(animated: true)
                }
            } else {
                showAlert(vc: vc, title: "Error", message: "We had an error deleting your wallet.")
            }
        }
    }
    
    private func getData() {
        CoreDataService.retrieveEntity(entityName: .signers) { [weak self] signers in
            guard let self = self else { return }
            
            guard let signers = signers, signers.count > 0, self.id != nil else { return }
            
            for signer in signers {
                let signerStruct = SignerStruct(dictionary: signer)
                if signerStruct.id == self.id {
                    self.signer = signerStruct
                    self.setFields(signerStruct)
                }
            }
        }
    }
    
    private func setFields(_ signer: SignerStruct) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.tableDict[0]["text"] = signer.label
            self.tableDict[4]["text"] = "  " +  self.formattedDate(signer.added)
            
            var passphrase = ""
            
            if var encryptedPassphrase = signer.passphrase {
                guard var decryptedPassphrase = Crypto.decrypt(encryptedPassphrase),
                        var string = decryptedPassphrase.utf8String else { return }
                
                defer {
                    string.secureWipe()
                    decryptedPassphrase.secureZero()
                    encryptedPassphrase.secureZero()
                }
                
                passphrase = string
                self.tableDict[3]["text"] = "  " + "*********"
                
            } else {
                self.tableDict[3]["text"] = "  ** no passphrase **"
            }
            
            defer {
                passphrase.secureWipe()
            }
            
            let encryptedXfp = signer.xfp ?? "".utf8
            let decryptedXfp = Crypto.decrypt(encryptedXfp) ?? "".utf8
            let xfp = decryptedXfp.utf8String ?? ""
            self.tableDict[2]["text"] = "  " + xfp
            
            if self.network == 0 {
                if let encryptedbip84xpub = signer.bip84xpub,
                    let decryptedbip84xpub = Crypto.decrypt(encryptedbip84xpub),
                    let xpub = decryptedbip84xpub.utf8String {
                    let descriptor = "wpkh([\(xfp)/84h/0h/0h]\(xpub)/0/*)"
                    //self.accountBip84Pubkey = xpub
                    //self.bip84AccountPath = "m/84h/0h/0h"
                    self.tableDict[7]["text"] = descriptor
                    if let singleSigCryptoAccount = URHelper.descriptorToUrAccount(Descriptor(descriptor)) {
                        self.tableDict[7]["ur"] = singleSigCryptoAccount
                    }
                }
                
                if let encryptedbip86xpub = signer.bip86xpub,
                    let decryptedbip86xpub = Crypto.decrypt(encryptedbip86xpub),
                    let xpub = decryptedbip86xpub.utf8String {
                    let descriptor = "tr([\(xfp)/86h/0h/0h]\(xpub)/0/*)"
                    //self.accountBip86Pubkey = xpub
                    //self.bip86AccountPath = "m/86h/0h/0h"
                    self.tableDict[8]["text"] = descriptor
                    if let singleSigCryptoAccount = URHelper.descriptorToUrAccount(Descriptor(descriptor)) {
                        self.tableDict[8]["ur"] = singleSigCryptoAccount
                    }
                }
                
                if let encryptedbip48xpub = signer.bip48xpub,
                    let decryptedbip48xpub = Crypto.decrypt(encryptedbip48xpub),
                    let xpub = decryptedbip48xpub.utf8String {
                    let cosigner = "wsh([\(xfp)/48h/0h/0h/2h]\(xpub)/0/*)"
                    self.tableDict[6]["text"] = cosigner
                    if let singleSigCryptoAccount = URHelper.descriptorToUrAccount(Descriptor(cosigner)) {
                        self.tableDict[6]["ur"] = singleSigCryptoAccount
                    }
                }
                
            } else {
                if let encryptedbip84tpub = signer.bip84tpub,
                    let decryptedbip84tpub = Crypto.decrypt(encryptedbip84tpub),
                    let tpub = decryptedbip84tpub.utf8String {
                    let descriptor = "wpkh([\(xfp)/84h/1h/0h]\(tpub)/0/*)"
                    //self.accountBip84Pubkey = tpub
                    //self.bip84AccountPath = "m/84h/1h/0h"
                    self.tableDict[7]["text"] = descriptor
                    if let singleSigCryptoAccount = URHelper.descriptorToUrAccount(Descriptor(descriptor)) {
                        self.tableDict[7]["ur"] = singleSigCryptoAccount
                    }
                }
                
                if let encryptedbip86tpub = signer.bip86tpub,
                    let decryptedbip86tpub = Crypto.decrypt(encryptedbip86tpub),
                    let tpub = decryptedbip86tpub.utf8String {
                    let descriptor = "tr([\(xfp)/86h/1h/0h]\(tpub)/0/*)"
                    //self.accountBip86Pubkey = tpub
                    //self.bip86AccountPath = "m/86h/1h/0h"
                    self.tableDict[8]["text"] = descriptor
                    if let singleSigCryptoAccount = URHelper.descriptorToUrAccount(Descriptor(descriptor)) {
                        self.tableDict[8]["ur"] = singleSigCryptoAccount
                    }
                }
                
                if let encryptedbip48tpub = signer.bip48tpub,
                    let decryptedbip48tpub = Crypto.decrypt(encryptedbip48tpub),
                    let tpub = decryptedbip48tpub.utf8String {
                    let cosigner = "wsh([\(xfp)/48h/1h/0h/2h]\(tpub)/0/*)"
                    self.tableDict[6]["text"] = cosigner
                    if let singleSigCryptoAccount = URHelper.descriptorToUrAccount(Descriptor(cosigner)) {
                        self.tableDict[6]["ur"] = singleSigCryptoAccount
                    }
                }
            }
            
            if signer.words == nil {
                // The address is derived from the seed, so it can't be shown once the seed is gone.
                self.tableDict[Section.silentPayment.rawValue]["text"] = "Seed words deleted, silent payment address unavailable."
                self.tableDict[Section.silentPaymentScanKey.rawValue]["text"] = "Seed words deleted, scan private key unavailable."
            }
            
            if var encryptedWords = signer.words {
                guard var decrypted = Crypto.decrypt(encryptedWords),
                      var words = decrypted.utf8String else { return }
                
                // Silent payment address for the selected network (sp1… / tsp1…), derived
                // with the same stored passphrase as the descriptors above. Only the
                // address is returned; no private keys reach this view (the scan private
                // key is derived separately, on export).
                if let spAddress = WalletLogic.shared.silentPaymentAddress(mnemonic: words,
                                                                           passphrase: passphrase,
                                                                           mainnet: self.network == 0) {
                    self.tableDict[Section.silentPayment.rawValue]["text"] = spAddress
                } else {
                    self.tableDict[Section.silentPayment.rawValue]["text"] = "Unable to derive the silent payment address."
                }
                
                guard var masterKey = Keys.masterKey(words: words, coinType: "\(self.network)", passphrase: passphrase) else {
                    showAlert(vc: self, title: "", message: "Unable to derive your master key.")
                    return
                }
                                
                var arr = words.split(separator: " ")
                
                for (i, _) in arr.enumerated() {
                    if i > 0 && i < arr.count - 1 {
                        arr[i] = "******"
                    }
                }
                
                self.tableDict[1]["censoredText"] = arr.joined(separator: " ")
                
                defer {
                    arr.removeAll()
                    masterKey.secureWipe()
                    decrypted.secureZero()
                    words.secureWipe()
                    encryptedWords.secureZero()
                }
                    
                if showWords {
                    let plainArr = words.split(separator: " ")
                    var toDisplay = ""
                    for (i, word) in plainArr.enumerated() {
                        toDisplay += "\(i + 1): \(word)   "
                    }
                    self.tableDict[1]["text"] = toDisplay
                } else {
                    self.tableDict[1]["text"] = "Deleted."
                }
                self.setWallets(masterKey)
            }
            self.reloadTable()
        }
    }
    
    private func setWallets(_ masterKey: String) {
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets, wallets.count > 0 else {
                self.tableDict[5]["text"] = ""
                self.reloadTable()
                return
            }
            
            var signableWallets = ""
            
            for (w, wallet) in wallets.enumerated() {
                if wallet["id"] != nil {
                    let walletStruct = Wallet(dictionary: wallet)
                    let descriptor = Descriptor(walletStruct.receiveDescriptor)
                    
                    if descriptor.isMulti {
                        for (x, xpub) in descriptor.multiSigKeys.enumerated() {
                            if let derivedXpub = Keys.xpub(path: descriptor.derivationArray[x], masterKey: masterKey) {
                                if xpub == derivedXpub {
                                    signableWallets += walletStruct.label + "  "
                                }
                            }
                        }
                    } else {
                        if let derivedXpub = Keys.xpub(path: descriptor.derivation, masterKey: masterKey) {
                            if descriptor.accountXpub == derivedXpub {
                                signableWallets += walletStruct.label + "  "
                            }
                        }
                    }
                    
                    if w + 1 == wallets.count {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.tableDict[5]["text"] = "  " + signableWallets
                            self.reloadTable()
                        }
                    }
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
        return dateFormatter.string(from: date)
    }
    
    private func updateLabel(_ label: String) {
        CoreDataService.update(id: id, keyToUpdate: "label", newValue: label, entity: .signers) { [weak self] (success) in
            guard let self = self else { return }
            
            if success {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.tableDict[0]["text"] = label
                    self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .fade)
                }
            } else {
                showAlert(vc: self, title: "Error", message: "Label did not update.")
            }
        }
    }
    
    private func updatePassphrase(_ encryptedPassphrase: Data, _ passphrase: String) {
        CoreDataService.update(id: id, keyToUpdate: "passphrase", newValue: encryptedPassphrase, entity: .signers) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.tableDict[3]["text"] = "**********"
                    
                    self.updateSigner(passphrase)
                }
            } else {
                showAlert(vc: self, title: "Error", message: "Label did not update.")
            }
        }
    }
    
    private func updateSigner(_ passphrase: String) {
        if let encryptedWords = self.signer.words,
           var decryptedSigner = Crypto.decrypt(encryptedWords),
           var words = decryptedSigner.utf8String,
           var mkMain = Keys.masterKey(words: words, coinType: "0", passphrase: passphrase),
           let xfp = Keys.fingerprint(masterKey: mkMain),
           let encryptedXfp = Crypto.encrypt(xfp.utf8),
           let mkTest = Keys.masterKey(words: words, coinType: "1", passphrase: passphrase),
           let bip84xpub = Keys.bip84AccountXpub(masterKey: mkMain, coinType: "0", account: 0),
           let bip84tpub = Keys.bip84AccountXpub(masterKey: mkTest, coinType: "1", account: 0),
           let bip86xpub = Keys.bip86AccountXpub(masterKey: mkMain, coinType: "0", account: 0),
           let bip86tpub = Keys.bip86AccountXpub(masterKey: mkTest, coinType: "1", account: 0),
           let bip48xpub = Keys.xpub(path: "m/48'/0'/0'/2'", masterKey: mkMain),
           let bip48tpub = Keys.xpub(path: "m/48'/1'/0'/2'", masterKey: mkTest),
           let encryptedbip84xpub = Crypto.encrypt(bip84xpub.utf8),
           let encryptedbip84tpub = Crypto.encrypt(bip84tpub.utf8),
           let encryptedbip86xpub = Crypto.encrypt(bip86xpub.utf8),
           let encryptedbip86tpub = Crypto.encrypt(bip86tpub.utf8),
           let encryptedbip48xpub = Crypto.encrypt(bip48xpub.utf8),
           let encryptedbip48tpub = Crypto.encrypt(bip48tpub.utf8) {
            
            defer {
                decryptedSigner.secureZero()
                words.secureWipe()
                mkMain.secureWipe()
            }
            
            CoreDataService.update(id: self.signer.id, keyToUpdate: "bip84xpub", newValue: encryptedbip84xpub, entity: .signers) { _ in }
            CoreDataService.update(id: self.signer.id, keyToUpdate: "bip84tpub", newValue: encryptedbip84tpub, entity: .signers) { _ in }
            
            CoreDataService.update(id: self.signer.id, keyToUpdate: "bip86xpub", newValue: encryptedbip86xpub, entity: .signers) { _ in }
            CoreDataService.update(id: self.signer.id, keyToUpdate: "bip86tpub", newValue: encryptedbip86tpub, entity: .signers) { _ in }
            
            CoreDataService.update(id: self.signer.id, keyToUpdate: "bip48xpub", newValue: encryptedbip48xpub, entity: .signers) { _ in }
            CoreDataService.update(id: self.signer.id, keyToUpdate: "bip48tpub", newValue: encryptedbip48tpub, entity: .signers) { _ in }
            CoreDataService.update(id: self.signer.id, keyToUpdate: "xfp", newValue: encryptedXfp, entity: .signers) { _ in }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                
                self.getData()
                
                showAlert(vc: self, title: "Signer updated ✓", message: "")
            }
        }
    }
    
    @objc func exportQrNow(_ sender: UIButton) {
        segueToQr()
    }
    
    private func segueToQr() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let vc = UIStoryboard(name: "Main", bundle: nil)
                    .instantiateViewController(withIdentifier: "QRDisplayer") as? QRDisplayerViewController else { return }
            
            vc.descriptionText = self.descriptionText
            vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
            vc.headerText = self.headerText
            vc.text = self.stringToExport
            
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func showMultisigCreator() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let vc = UIStoryboard(name: "Main", bundle: nil)
                    .instantiateViewController(withIdentifier: "MultisigCreator") as? CreateMultisigViewController else { return }
            
            vc.cosigner = self.cosigner
            
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func showNodeless() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let vc = UIStoryboard(name: "Main", bundle: nil)
                    .instantiateViewController(withIdentifier: "NodelessTable") as? NodelessTableViewController else { return }
            
            vc.signer = self.signer
            vc.primaryDescriptor = self.nodelessDescriptor
            
            if self.segmentedControl.selectedSegmentIndex == 0 {
                vc.network = .bitcoin
            }
            
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func editLabel(_ existingLabel: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Edit Label"
            let message = ""
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let edit = UIAlertAction(title: "Save", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                let text = (alert.textFields![0] as UITextField).text
                
                guard let text = text, text != "" else {
                    showAlert(vc: self, title: "", message: "No label added.")
                    
                    return
                }
                
                self.updateLabel(text)
            }
            
            alert.addTextField { textField in
                textField.text = existingLabel
                textField.keyboardAppearance = .dark
            }
            
            alert.addAction(edit)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    private func promptToEditPassphrase() {
        if signer.words != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let title = "⚠️ Editing the passphrase has major implications!"
                
                let message = "Editing or adding a passphrase is useful if you want to password protect your bitcoin transactions. When you go to send a transaction Fully Noded will prompt you to add a passphrase if you enable the \"Prompt with passphrase\" setting in Settings > Security. Fully Noded only saves this passphrase here in the Signer Detail view so that you may export xpubs and descriptors to other wallets so they will work with this particular passphrase / signer combination. After you have created the wallet or exported your descriptor to another HWW or software wallet you should delete the passphrase here as Fully Noded will not use it anywhere outside of the app except here in the Signer Detail view."
                
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                
                let edit = UIAlertAction(title: "Edit Passphrase", style: .default) { [weak self] alertAction in
                    guard let self = self else { return }
                    
                    self.editPassphrase()
                }
                
                alert.addAction(edit)
                
                let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
                alert.addAction(cancel)
                
                self.present(alert, animated:true, completion: nil)
            }
        } else {
            showAlert(vc: self, title: "No seed words exist.", message: "If the seed words have been deleted then you can not edit the passphrase. Please add a new signer with the seed words first then you may edit the passphrase as many times as you would like.")
        }
    }
    
    private func editPassphrase() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Edit Passphrase"
            let message = ""
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let edit = UIAlertAction(title: "Save", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                var text1 = (alert.textFields![0] as UITextField).text
                var text2 = (alert.textFields![1] as UITextField).text
                
                guard var _ = text1, var _ = text2, text1 == text2 else {
                    showAlert(vc: self, title: "", message: "Passphrases did not match or were empty. Try again.")
                    
                    return
                }
                                
                guard let encryptedPassphrase = Crypto.encrypt(text1!.utf8) else {
                    showAlert(vc: self, title: "Encryption error...", message: "Please let us know about this bug, unable to encrypt your new passphrase")
                    return
                }
                
                defer {
                    text1?.secureWipe()
                    text2?.secureWipe()
                }
                
                self.updatePassphrase(encryptedPassphrase, text1!)
            }
            
            alert.addTextField { textField in
                textField.keyboardAppearance = .dark
                textField.isSecureTextEntry = true
                textField.placeholder = "passphrase"
            }
            
            alert.addTextField { textField in
                textField.keyboardAppearance = .dark
                textField.isSecureTextEntry = true
                textField.placeholder = "confirm passphrase"
            }
            
            alert.addAction(edit)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { alertAction in }
            alert.addAction(cancel)
            
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    private func exportQrButton(_ x: CGFloat) -> UIButton {
        let qrButton = UIButton()
        qrButton.setImage(.init(systemName: "qrcode"), for: .normal)
        qrButton.tintColor = SignerTheme.accent
        qrButton.imageView?.tintColor = SignerTheme.accent
        qrButton.frame = CGRect(x: x, y: 5, width: 40, height: 40)
        qrButton.addTarget(self, action: #selector(promptForQRFormat(_:)), for: .touchUpInside)
        return qrButton
    }
    
    private func nodelessButton(_ x: CGFloat) -> UIButton {
        let nodelessButton = UIButton()
        var config = UIButton.Configuration.tinted()
        config.baseForegroundColor = SignerTheme.accent
        config.baseBackgroundColor = SignerTheme.accent
        config.background.cornerRadius = 0
        var title = AttributedString("NODELESS")
        title.font = SignerTheme.mono(12, weight: .semibold)
        config.attributedTitle = title
        nodelessButton.configuration = config
        nodelessButton.frame = CGRect(x: x, y: 5, width: 100, height: 40)
        nodelessButton.addTarget(self, action: #selector(nodeless(_:)), for: .touchUpInside)
        return nodelessButton
    }
    
    private func createWalletButton(_ x: CGFloat) -> UIButton {
        let createWalletButton = UIButton()
        createWalletButton.setImage(.init(systemName: "plus"), for: .normal)
        createWalletButton.tintColor = SignerTheme.accent
        createWalletButton.imageView?.tintColor = SignerTheme.accent
        createWalletButton.frame = CGRect(x: x, y: 5, width: 40, height: 40)
        createWalletButton.addTarget(self, action: #selector(createWallet), for: .touchUpInside)
        return createWalletButton
    }
    
    private func deleteButton(_ x: CGFloat) -> UIButton {
        let deleteButton = UIButton()
        deleteButton.setImage(.init(systemName: "trash"), for: .normal)
        deleteButton.tintColor = SignerTheme.danger
        deleteButton.imageView?.tintColor = SignerTheme.danger
        deleteButton.frame = CGRect(x: x, y: 5, width: 40, height: 40)
        return deleteButton
    }
    
    private func deletePassphrase() {
        CoreDataService.deleteValue(id: signer.id, keyToDelete: "passphrase", entity: .signers) { [weak self] deleted in
            guard let self = self else { return }
            
            guard deleted else {
                showAlert(vc: self, title: "There was an issue...", message: "Unable to delete your passphrase, please let us know about this bug.")
                return
            }
            
            self.updateSigner("")
        }
    }
    
    @objc func promptToDeletePassphrase() {
        if signer.passphrase != nil {
            if signer.words != nil {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    let title = "⚠️ Deleting the passphrase has major implications!"
                    
                    let message = "Editing or adding a passphrase is useful if you want to password protect your bitcoin transactions. When you go to send a transaction Fully Noded will prompt you to add a passphrase if you enable the \"Prompt with passphrase\" setting in Settings > Security. Fully Noded only saves this passphrase here in the Signer Detail view so that you may export xpubs and descriptors to other wallets so they will work with this particular passphrase / signer combination. After you have created the wallet or exported your descriptor to another HWW or software wallet you should delete the passphrase here as Fully Noded will not use it anywhere outside of the app except here in the Signer Detail view."
                    
                    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    
                    let delete = UIAlertAction(title: "Delete Passphrase", style: .destructive) { [weak self] alertAction in
                        guard let self = self else { return }
                        
                        self.deletePassphrase()
                    }
                    
                    alert.addAction(delete)
                    
                    let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
                    alert.addAction(cancel)
                    
                    self.present(alert, animated:true, completion: nil)
                }
            } else {
                showAlert(vc: self, title: "No seed words exist.", message: "If the seed words have been deleted then you can not delete the passphrase. Please add a new signer with the seed words first, optionally adding/deleting/editing the passphrase afterwards. It makes more sense to just delete this signer completely.")
            }
        } else {
            showAlert(vc: self, title: "No passphrase exists...", message: "")
        }
    }
    
    @objc func promptToDeleteSeed() {
        if signer.words != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let title = "⚠️ Deleting the seed has major implications!"
                
                let message = "This signer will no longer be able to sign transactions! All other data will remain intact so that you may easily create watch-only wallets and export the public key based cosigner to other hardware/software wallets."
                
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                
                let delete = UIAlertAction(title: "Delete Seed", style: .destructive) { [weak self] alertAction in
                    guard let self = self else { return }
                    
                    self.deleteSeed()
                }
                
                alert.addAction(delete)
                
                let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
                alert.addAction(cancel)
                
                self.present(alert, animated:true, completion: nil)
            }
        } else {
            showAlert(vc: self, title: "No seed exists...", message: "")
        }
    }
    
    private func deleteSeed() {
        CoreDataService.deleteValue(id: signer.id, keyToDelete: "words", entity: .signers) { [weak self] deleted in
            guard let self = self else { return }
            
            guard deleted else {
                showAlert(vc: self, title: "There was an issue...", message: "Unable to delete your seed, please let us know about this bug.")
                return
            }
            
            self.tableDict[1]["text"] = ""
            self.tableDict[1]["censoredText"] = ""
            self.getData()
        }
    }
    
//    private func setClipBoard(_ string: String) {
//        let clipBoard = UIPasteboard.general
//        clipBoard.string = string
//        showAlert(vc: self, title: "", message: "Copied to clipboard ✓")
//    }
    
    private func importAccountMap(_ descriptor: String, _ label: String, _ password: String) {
        spinner.show(vc: self, description: "creating wallet...")
        
        OnchainUtils.getBlockchainInfo { [weak self] (blockchainInfo, message) in
            guard let self = self else { return }
            guard let blockchainInfo = blockchainInfo else {
                self.spinner.dismiss()
                showAlert(vc: self, title: "", message: message ?? "error getting blockchaininfo")
                return
            }
            
            var accountMap = ["descriptor": descriptor, "watching": [], "label": label, "password": password] as [String : Any]
            
            if blockchainInfo.pruned {
                accountMap["blockheight"] = blockchainInfo.pruneheight
            } else {
                accountMap["blockheight"] = 0
            }
            
            ImportWallet.accountMap(accountMap) { (success, errorDescription) in
                self.spinner.dismiss()
                
                guard success else {
                    showAlert(vc: self, title: "There was an issue creating your wallet...", message: errorDescription ?? "Unknown...")
                    return
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    let tit = "Wallet created ✓"
                    
                    let mess = "Navigate to the active wallet view, optionally go to the wallet detail view to rescan for a missing balance."
                    
                    let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
                    
                    alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { action in
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.tabBarController?.selectedIndex = 1
                        }
                    }))
                    
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    @objc func createWallet() {
        if signer.words != nil {
            creatWalletLive()
        } else {
            createWalletFromMemory()
        }
    }
    
    private func createWalletFromMemory() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Create a single sig wallet with this signer?"
            let message = "You deleted the seed words so we can only automatically create the wallet using the saved BIP84 xpub. To create a multi-sig wallet with this signer navigate to the wallet creator, choose multi-sig > derive cosigner from existing signer."
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let p2wpkh = UIAlertAction(title: "Segwit Single-sig", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                if let descriptor = self.tableDict[7]["text"] as? String {
                    self.importAccountMap(descriptor, self.signer.label + " segwit", "")
                } else {
                    showAlert(vc: self, title: "There was an issue...", message: "Unable to get your bip84 descriptor.")
                }
            }
            
            let p2wsh = UIAlertAction(title: "Segwit Multi-sig", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                if let descriptor = self.tableDict[6]["text"] as? String {
                    self.cosigner = Descriptor(descriptor)
                    self.showMultisigCreator()
                } else {
                    showAlert(vc: self, title: "There was an issue...", message: "Unable to get your bip84 descriptor.")
                }
            }
            
            alert.addAction(p2wpkh)
            alert.addAction(p2wsh)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    private func prompToChoosePrimaryDesc(descriptors: [String]) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Choose a wallet format.", message: "", preferredStyle: .alert)
            
            for (i, descriptor) in descriptors.enumerated() {
                let descStr = Descriptor(descriptor)
                
                alert.addAction(UIAlertAction(title: descStr.scriptType, style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.setPrimDesc(descriptors: descriptors, descriptorToUseIndex: i)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func setPrimDesc(descriptors: [String], descriptorToUseIndex: Int) {
        let primDesc = descriptors[descriptorToUseIndex]
        let desc = Descriptor("\(primDesc)")
        
        if desc.isCosigner {
            self.cosigner = desc
            self.showMultisigCreator()
        } else {
            self.importAccountMap(primDesc, signer.label, "")
        }
    }
        
    private func creatWalletLive() {
        guard var encryptedWords = signer.words,
                var wordsData = Crypto.decrypt(encryptedWords),
                var words = wordsData.utf8String else {
                    return
                }
        
        defer {
            encryptedWords.secureZero()
            wordsData.secureZero()
            words.secureWipe()
        }
        
        if var encryptedPassphrase = signer.passphrase {
            var passphrase = ""
            
            guard var decryptedPassphrase = Crypto.decrypt(encryptedPassphrase) else {
                showAlert(vc: self, title: "Decryption error.", message: "There was an issue decrypting your passphrase...")
                return
            }
            
            defer {
                encryptedPassphrase.secureZero()
                decryptedPassphrase.secureZero()
                passphrase.secureWipe()
            }
            
            passphrase = decryptedPassphrase.utf8String ?? ""
            
            let (bip84, bip86, segwitCosigner, taprootCosigner, message) = Keys.descriptorsFromSigner(signer: words, passphrase: passphrase)
            
            guard message == nil else {
                showAlert(vc: self, title: "", message: message!)
                return
            }

            prompToChoosePrimaryDesc(descriptors: [bip84!, bip86!, segwitCosigner!, taprootCosigner!])
            
        } else {
            let (bip84, bip86, segwitCosigner, taprootCosigner, message) = Keys.descriptorsFromSigner(signer: words, passphrase: nil)
            
            guard message == nil else {
                showAlert(vc: self, title: "", message: message!)
                return
            }
            
            prompToChoosePrimaryDesc(descriptors: [bip84!, bip86!, segwitCosigner!, taprootCosigner!])
        }
    }
    
    @objc func nodeless(_ sender: UIButton) {
        switch sender.tag {
        case 7:
            nodelessDescriptor = tableDict[7]["text"] as! String
        case 8:
            nodelessDescriptor = tableDict[8]["text"] as! String
        default:
            break
            
        }
        showNodeless()
    }
    
    @objc func promptForQRFormat(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Export QR Code",
            message: "Choose the desired format.",
            preferredStyle: .alert
        )
        
//        alert.addAction(UIAlertAction(title: "BBQR", style: .default) { [weak self] _ in
//            guard let self = self else { return }
//            self.isBbqr = true
//            exportQr(isBbqr: true, plainText: false, section: sender.tag)
//        })
        
        alert.addAction(UIAlertAction(title: "UR", style: .default) { [weak self] _ in
            guard let self = self else { return }
            exportQr(isBbqr: false, plainText: false, section: sender.tag)
        })
        
        alert.addAction(UIAlertAction(title: "Plain text", style: .default) { [weak self] _ in
            guard let self = self else { return }
            exportQr(isBbqr: false, plainText: true, section: sender.tag)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in })
        
        self.present(alert, animated: true)
    }
    
    /// Silent payment address QR: always plain text (it isn't a UR type), straight to
    /// the existing QR displayer.
    @objc func exportSilentPaymentQr(_ sender: UIButton) {
        let address = tableDict[Section.silentPayment.rawValue]["text"] as? String ?? ""
        
        guard address.lowercased().hasPrefix("sp1") || address.lowercased().hasPrefix("tsp1") else {
            showAlert(vc: self, title: "", message: "No silent payment address available for this signer.")
            return
        }
        
        stringToExport = address
        headerText = "Silent Payment Address"
        descriptionText = "Share this silent payment address to receive bitcoin privately. Every payment to it creates a new output that can't be linked to it on-chain."
        segueToQr()
    }
    
    // MARK: - Silent payment scan private key export
    
    /// Exports the BIP352 scan private key as a QR, e.g. to set up Fully Noded Server.
    /// Requires an app password, an explicit confirmation and Face ID / Touch ID or the
    /// app password (never the device passcode). The key is derived on demand from the
    /// seed (with the signer's passphrase, like the address above) and handed straight to
    /// the QR screen: it is never stored or kept in this view.
    @objc func exportScanPrivateKey(_ sender: Any) {
        guard let _ = KeyChain.getData("UnlockPassword") else {
            showAlert(vc: self, title: "You are not using the app securely...", message: "You can only export private keys if the app has a lock/unlock password. Tap the lock button on the home screen to add a password.")
            return
        }
        
        guard signer?.words != nil else {
            showAlert(vc: self, title: "", message: "This signer's seed words were deleted, so its scan private key can't be derived.")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(
                title: "Export scan private key?",
                message: "Only give this key to a silent payment scanner you control, such as your own Fully Noded Server. It can't spend your bitcoin, but whoever has it can see every silent payment you receive.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Export", style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                
                AppAuthentication.authenticate(from: self, reason: "To export your silent payment scan private key") { [weak self] success in
                    guard let self = self, success else { return }
                    self.showScanPrivateKeyQr()
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alert, animated: true)
        }
    }
    
    private func showScanPrivateKeyQr() {
        guard let encryptedWords = signer?.words,
              var decryptedWords = Crypto.decrypt(encryptedWords),
              var words = decryptedWords.utf8String else {
            showAlert(vc: self, title: "", message: "Unable to decrypt your seed words.")
            return
        }
        
        var passphrase = ""
        if let encryptedPassphrase = signer?.passphrase,
           var decryptedPassphrase = Crypto.decrypt(encryptedPassphrase) {
            passphrase = decryptedPassphrase.utf8String ?? ""
            decryptedPassphrase.secureZero()
        }
        
        let mainnet = network == 0
        let scanKey = WalletLogic.shared.silentPaymentScanPrivateKey(mnemonic: words,
                                                                     passphrase: passphrase,
                                                                     mainnet: mainnet)
        decryptedWords.secureZero()
        words.secureWipe()
        passphrase.secureWipe()
        
        // Handed straight to the QR screen; nothing keeps a copy in this view.
        guard let key = scanKey else {
            showAlert(vc: self, title: "", message: "Unable to derive the scan private key.")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let vc = UIStoryboard(name: "Main", bundle: nil)
                    .instantiateViewController(withIdentifier: "QRDisplayer") as? QRDisplayerViewController else { return }
            
            vc.headerIcon = UIImage(systemName: "eye")
            vc.headerText = "SP Scan Private Key"
            vc.descriptionText = "BIP352 scan private key (\(mainnet ? "mainnet" : "testnet / signet"), hex) at m/352'/\(mainnet ? 0 : 1)'/0'/1'/0. For your own silent payment scanner only: it reveals every silent payment you receive, but can't spend them."
            vc.text = key
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func exportQr(isBbqr: Bool, plainText: Bool, section: Int) {
        var dict = tableDict[section]
        let text = dict["text"] as? String ?? ""
        
        // Descriptor exports have no description (as before); don't carry over the
        // silent payment one.
        descriptionText = ""
        
        defer {
            dict.removeAll()
        }
        
        if plainText || isBbqr {
            stringToExport = text
        }
        
        if !plainText && !isBbqr {
            stringToExport = dict["ur"] as? String ?? ""
        }
                
        switch section {
        case 6:
            headerText = "Cosigner BIP48"
            segueToQr()
            
        case 7:
            headerText = "BIP84 Account"
            segueToQr()
            
        case 8:
            headerText = "BIP86 Account"
            segueToQr()
            
        default:
            break
        }
    }
}

extension SignerDetailViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = DynamicFooterView(frame: .zero)
        let text = tableDict[section]["footerText"] as? String ?? ""
        footerView.configure(with: text)
        footerView.textLabel.font = SignerTheme.mono(11)
        footerView.textLabel.textColor = SignerTheme.dim
        return footerView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let dict = tableDict[indexPath.section]
                
        switch indexPath.section {
        case 0:
            editLabel(dict["text"] as? String ?? "")
            
//        case 2:
//            setClipBoard(dict["text"] as? String ?? "")
        
        case 3:
            promptToEditPassphrase()
            
        case Section.silentPaymentScanKey.rawValue:
            exportScanPrivateKey(self)
            
//        case 6, 7:
//            setClipBoard(dict["text"] as? String ?? "")
            
        default:
            break
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return tableDict.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "defaultCell", for: indexPath)
        cell.backgroundColor = SignerTheme.card
        cell.contentView.backgroundColor = SignerTheme.card
        WalletTheme.squareCorners(cell)   // square edges, no section rounding
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = SignerTheme.mono(13)
        cell.textLabel?.textColor = SignerTheme.text
        cell.textLabel?.sizeToFit()
        cell.sizeToFit()
        cell.selectionStyle = .none
        
        configureField(cell)
        
        var dict = self.tableDict[indexPath.section]
        
        defer {
            dict.removeAll()
        }
        
        switch Section(rawValue: indexPath.section) {
        case .label:
            cell.textLabel?.text = dict["text"] as? String ?? "no label"
            
        case .words:
            if showWords {
                cell.textLabel?.text = dict["text"] as? String ?? "no seed words"
            } else {
                cell.textLabel?.text = dict["censoredText"] as? String ?? "no seed words"
            }
            
        case .masterKeyFingerprint:
            cell.textLabel?.text = dict["text"] as? String ?? "no fingerprint"
            
        case .passphrase:
            cell.textLabel?.text = dict["text"] as? String ?? "*** no passphrase ***"
            
        case .dateAdded:
            cell.textLabel?.text = dict["text"] as? String ?? "no date added"
            
        case .signableWallets:
            cell.textLabel?.text = dict["text"] as? String ?? "no signable wallets"
            
        case .cosigner:
            cell.textLabel?.text = dict["text"] as? String ?? "no multi-sig cosigner"
            
        case .singleSigBip84:
            cell.textLabel?.text = dict["text"] as? String ?? "no descriptor"
            
        case .singleSigBip86:
            cell.textLabel?.text = dict["text"] as? String ?? "no descriptor"
            
        case .silentPayment:
            cell.textLabel?.text = dict["text"] as? String ?? "no silent payment address"
            
        case .silentPaymentScanKey:
            // Never shown in the table; only exported on demand (see exportScanPrivateKey).
            cell.textLabel?.text = dict["text"] as? String ?? "Hidden."
            cell.textLabel?.textColor = SignerTheme.dim
            
        case .none:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = SignerTheme.mono(13, weight: .medium)
        textLabel.textColor = SignerTheme.dim
        textLabel.frame = CGRect(x: 33, y: 0, width: 260, height: 50)
                        
        let exportQrButtonGeneric = exportQrButton(header.frame.maxX - 46)
        exportQrButtonGeneric.tag = section
        
        let nodelessButton = nodelessButton(exportQrButtonGeneric.frame.minX - 108)
        nodelessButton.tag = section
        
        if let section = Section(rawValue: section) {
            switch section {
            case .signableWallets:
                header.addSubview(createWalletButton(header.frame.maxX - 46))
                textLabel.text = headerName(for: section)
                
            case .words:
                let deleteButtonSeed = deleteButton(header.frame.maxX - 46)
                deleteButtonSeed.addTarget(self, action: #selector(promptToDeleteSeed), for: .touchUpInside)
                header.addSubview(deleteButtonSeed)
                textLabel.text = "BIP39 Seed Words"
                
            case .passphrase:
                let deleteButtonPassphrase = deleteButton(header.frame.maxX - 46)
                textLabel.text = headerName(for: section)
                deleteButtonPassphrase.addTarget(self, action: #selector(promptToDeletePassphrase), for: .touchUpInside)
                header.addSubview(deleteButtonPassphrase)
                
            case .cosigner:
                header.addSubview(exportQrButtonGeneric)
                textLabel.text = headerName(for: section)
                
            case .singleSigBip84, .singleSigBip86:
                header.addSubview(exportQrButtonGeneric)
                header.addSubview(nodelessButton)
                textLabel.text = headerName(for: section)
                
            case .silentPayment:
                // Plain-text QR only, so skip the UR / plain text format prompt.
                exportQrButtonGeneric.removeTarget(nil, action: nil, for: .allEvents)
                exportQrButtonGeneric.addTarget(self, action: #selector(exportSilentPaymentQr(_:)), for: .touchUpInside)
                header.addSubview(exportQrButtonGeneric)
                textLabel.text = headerName(for: section)
                
            case .silentPaymentScanKey:
                // Warn + authenticate, then derive the key on demand and show its QR.
                exportQrButtonGeneric.removeTarget(nil, action: nil, for: .allEvents)
                exportQrButtonGeneric.addTarget(self, action: #selector(exportScanPrivateKey(_:)), for: .touchUpInside)
                header.addSubview(exportQrButtonGeneric)
                textLabel.text = headerName(for: section)
                
            default:
                textLabel.text = headerName(for: section)
            }
        }
        
        if let kind = Section(rawValue: section) {
            let icon = UIImageView(image: UIImage(systemName: headerIconName(for: kind)))
            icon.contentMode = .scaleAspectFit
            icon.tintColor = SignerTheme.accent
            icon.frame = CGRect(x: 0, y: 12.5, width: 25, height: 25)
            header.addSubview(icon)
        }

        textLabel.text = textLabel.text?.uppercased()
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
}

extension SignerDetailViewController: UITableViewDataSource {}

// MARK: - Theme

/// Cypherpunk deep purple / gray palette for the signer screens. Same structure as the
/// green `Cypher` palette used by the home and wallet detail screens.
enum SignerTheme {
    static let bg = UIColor(red: 0.035, green: 0.03, blue: 0.05, alpha: 1)      // near-black, violet tint
    static let card = UIColor(red: 0.09, green: 0.085, blue: 0.11, alpha: 1)    // charcoal gray
    static let line = UIColor(red: 0.50, green: 0.30, blue: 0.95, alpha: 0.55)  // deep purple border
    static let accent = UIColor(red: 0.58, green: 0.38, blue: 1.0, alpha: 1)    // deep purple neon
    static let dim = UIColor(red: 0.56, green: 0.53, blue: 0.64, alpha: 1)      // muted gray-lavender
    static let text = UIColor(red: 0.86, green: 0.84, blue: 0.93, alpha: 1)     // light gray
    static let danger = UIColor(red: 1.0, green: 0.28, blue: 0.32, alpha: 1)

    static func mono(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        WalletTheme.mono(size, weight: weight)
    }

    /// Per-screen navigation bar look (set on the navigationItem, so it doesn't leak into
    /// the home / wallet screens' green bar when navigating back).
    static func styleNavigation(_ item: UINavigationItem) {
        let appearance = WalletTheme.navigationAppearance(background: bg, line: line, accent: accent)

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        if let chevron = UIImage(systemName: "chevron.backward", withConfiguration: chevronConfig)?
            .withTintColor(accent, renderingMode: .alwaysOriginal) {
            appearance.setBackIndicatorImage(chevron, transitionMaskImage: chevron)
        }

        WalletTheme.setNavigationAppearance(appearance, on: item)
    }

    static func style(_ control: UISegmentedControl) {
        WalletTheme.styleSegmented(control, background: card, accent: accent, text: dim, selectedText: bg)
    }

    /// Bordered charcoal card used as a cell background (inset vertically so rows read
    /// as separate cards).
    static func cardBackground(verticalInset: CGFloat = 4) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = SignerTheme.card
        card.layer.cornerRadius = 0
        card.layer.borderWidth = 1
        card.layer.borderColor = line.cgColor
        container.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor, constant: verticalInset),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -verticalInset),
            // Horizontal inset keeps the inset-grouped section rounding off the border.
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5)
        ])
        return container
    }
}
