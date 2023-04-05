//
//  SignerDetailViewController.swift
//  BitSense
//
//  Created by Peter on 05/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit
import LocalAuthentication

class SignerDetailViewController: UIViewController, UINavigationControllerDelegate {
    
    var id:UUID!
    var cosigner:Descriptor?
    private var spinner = ConnectingView()
    private var signer: SignerStruct!
    private var tableDict = [[String:Any]]()
    private var network = 0
    private var stringToExport = ""
    private var descriptionText = ""
    private var headerText = ""
    private var masterKey = ""
    
    private enum Section: Int {
        case label
        case words
        case masterKeyFingerprint
        case passphrase
        case dateAdded
        case signableWallets
        case cosigner
        case singleSig
        case rootXpub
    }
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self
        navigationController?.delegate = self
        
        tableDict = [
            ["text":"", "footerText": "Tap the label to edit it."],// label 0
            ["text": "", "ur": "", "selectedSegmentIndex": 0, "censoredText": "", "censoredUr": "", "footerText": "UR for exporting this signer to iOS Seed Tool, Gordian Wallet, Gordian Signer and any other wallet which supports UR crypto-seed. Tap to copy the text."],// words 1
            ["text": "", "footerText": ""],// xfp 2
            ["text": "", "footerText": "Tap the passphrase to edit it. ⚠️ This has MAJOR implications, for experts only!"],// passphrase 3
            ["text": "", "footerText": ""],// dateAdded 4
            ["text": "", "footerText": "The wallets which this signer can sign for. Tap the + button to create a wallet with this signer."],// wallets 5
            ["text": "", "ur": "", "selectedSegmentIndex": 1, "footerText": "UR for exporting the segwit mutli-sig cosigner to any wallet which supports UR crypto-account (Blue Wallet, Passport, Keystone, SeedSigner, Cobo, Sparrow). Tap to copy the text."],// cosigner 6
            ["text": "", "ur": "", "selectedSegmentIndex": 1, "footerText": "UR for exporting the segwit single-sig watch-only wallet to any wallet which supports UR crypto-account (Blue Wallet, Passport, Keystone, SeedSigner, Cobo, Sparrow). Tap to copy the text."],// singlesig 7
            ["text": "", "ur": "", "selectedSegmentIndex": 1, "footerText": "Export your root xpub UR to Casa App by selecting the Keystone option when adding a HWW key to Casa App. Also compatible with Gordian Wallet and Gordian Cosigner. Tap to copy the text."]// casa hdkey 8
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
        case .singleSig:
            return "Descriptor - BIP84"
        case .rootXpub:
            return "Root xpub"
        }
    }
    
    @IBAction func switchNetwork(_ sender: Any) {
        network = segmentedControl.selectedSegmentIndex
        getData()
    }
    
    private func configureField(_ field: UIView) {
        field.clipsToBounds = true
        field.layer.cornerRadius = 8
        field.layer.borderWidth = 0.5
        field.layer.borderColor = UIColor.lightGray.cgColor
    }
    
    private func reloadTable() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.tableView.reloadData()
        }
    }
    
    @IBAction func showSignerAction(_ sender: Any) {
        guard let _ = KeyChain.getData("UnlockPassword") else {
            showAlert(vc: self, title: "You are not using the app securely...", message: "You can only show signers if the app has a lock/unlock password. Tap the lock button on the home screen to add a password.")
            
            return
        }
        
        let localAuthenticationContext = LAContext()
        localAuthenticationContext.localizedFallbackTitle = "Use Passcode"
        var authError: NSError?
        let reasonString = "To Unlock"

        if localAuthenticationContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            localAuthenticationContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reasonString) { [weak self] (success, evaluateError) in
                guard let self = self else { return }
                
                if success {
                    let selectedSegmentIndex = self.tableDict[1]["selectedSegmentIndex"] as? Int ?? 0
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        switch selectedSegmentIndex {
                        case 0:
                            self.tableDict[1]["censoredText"] = self.tableDict[1]["text"] as? String ?? "no seed words"
                            
                        case 1:
                            self.tableDict[1]["censoredUr"] = self.tableDict[1]["ur"] as? String ?? "no crypto-seed"
                            
                        default:
                            break
                        }
                        
                        self.tableView.reloadSections(IndexSet(arrayLiteral: 1), with: .fade)
                    }
                } else {
                    guard let error = evaluateError else { return }
                    showAlert(vc: self, title: "Auth failed...", message: error.localizedDescription)
                }
            }

        } else {
            guard let error = authError else { return }
            showAlert(vc: self, title: "Auth failed...", message: error.localizedDescription)
        }
    }
    
    @IBAction func deleteAction(_ sender: Any) {
        promptToDeleteSigner()
    }
    
    private func promptToDeleteSigner() {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
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
            
            if let encryptedPassphrase = signer.passphrase {
                guard let decryptedPassphrase = Crypto.decrypt(encryptedPassphrase),
                        let string = decryptedPassphrase.utf8String else { return }
                
                passphrase = string
                self.tableDict[3]["text"] = "  " + "*********"
            } else {
                self.tableDict[3]["text"] = "  ** no passphrase **"
            }
            
            guard let encryptedXfp = signer.xfp,
                let decryptedXfp = Crypto.decrypt(encryptedXfp),
                let xfp = decryptedXfp.utf8String else {
                    showAlert(vc: self, title: "", message: "Error getting your xfp.")
                return
            }
            
            self.tableDict[2]["text"] = "  " + xfp
            
            if self.network == 0 {
                if let encryptedbip84xpub = signer.bip84xpub,
                    let decryptedbip84xpub = Crypto.decrypt(encryptedbip84xpub),
                    let xpub = decryptedbip84xpub.utf8String {
                    let descriptor = "wpkh([\(xfp)/84h/0h/0h]\(xpub)/0/*)"
                    
                    guard let singleSigCryptoAccount = URHelper.descriptorToUrAccount(Descriptor(descriptor)) else {
                        showAlert(vc: self, title: "UR error.", message: "Unable to convert your descriptor to crypto-account.")
                        return
                    }
                    
                    self.tableDict[7]["text"] = descriptor
                    self.tableDict[7]["ur"] = singleSigCryptoAccount
                }
                
                if let encryptedbip48xpub = signer.bip48xpub,
                    let decryptedbip48xpub = Crypto.decrypt(encryptedbip48xpub),
                    let xpub = decryptedbip48xpub.utf8String {
                    let cosigner = "wsh([\(xfp)/48h/0h/0h/2h]\(xpub)/0/*)"
                    
                    guard let cosignerAccount = URHelper.descriptorToUrAccount(Descriptor(cosigner)) else {
                        showAlert(vc: self, title: "UR error.", message: "Unable to convert your cosigner to crypto-account.")
                        return
                    }
                    
                    self.tableDict[6]["text"] = cosigner
                    self.tableDict[6]["ur"] = cosignerAccount
                    
                    if let encryptedRootXpub = signer.rootXpub,
                       let decryptedRootXpub = Crypto.decrypt(encryptedRootXpub),
                       let xpub = decryptedRootXpub.utf8String {
                        
                        guard let rootHdkey = URHelper.rootXpubToUrHdkey(xpub) else {
                            showAlert(vc: self, title: "UR error.", message: "Unable to convert your root xpub to crypto-hdkey.")
                            return
                        }
                        
                        self.tableDict[8]["text"] = xpub
                        self.tableDict[8]["ur"] = rootHdkey
                    }
                }
                
            } else {
                if let encryptedbip84tpub = signer.bip84tpub,
                    let decryptedbip84tpub = Crypto.decrypt(encryptedbip84tpub),
                    let tpub = decryptedbip84tpub.utf8String {
                    let descriptor = "wpkh([\(xfp)/84h/1h/0h]\(tpub)/0/*)"
                    
                    guard let singleSigCryptoAccount = URHelper.descriptorToUrAccount(Descriptor(descriptor)) else {
                        showAlert(vc: self, title: "UR error.", message: "Unable to convert your descriptor to crypto-account.")
                        return
                    }
                    
                    self.tableDict[7]["text"] = descriptor
                    self.tableDict[7]["ur"] = singleSigCryptoAccount
                }
                
                if let encryptedbip48tpub = signer.bip48tpub,
                    let decryptedbip48tpub = Crypto.decrypt(encryptedbip48tpub),
                   let tpub = decryptedbip48tpub.utf8String {
                    let cosigner = "wsh([\(xfp)/48h/1h/0h/2h]\(tpub)/0/*)"
                    
                    guard let cosignerAccount = URHelper.descriptorToUrAccount(Descriptor(cosigner)) else {
                        showAlert(vc: self, title: "UR error.", message: "Unable to convert your cosigner to crypto-account.")
                        return
                    }
                    
                    self.tableDict[6]["text"] = cosigner
                    self.tableDict[6]["ur"] = cosignerAccount
                    
                    if let encryptedRootTpub = signer.rootTpub,
                       let decryptedRootTpub = Crypto.decrypt(encryptedRootTpub),
                       let tpub = decryptedRootTpub.utf8String {
                        
                        guard let rootHdkey = URHelper.rootXpubToUrHdkey(tpub) else {
                            showAlert(vc: self, title: "UR error.", message: "Unable to convert your root tpub to crypto-hdkey.")
                            return
                        }
                        
                        self.tableDict[8]["text"] = tpub
                        self.tableDict[8]["ur"] = rootHdkey
                    }
                }
            }
            
            if let encryptedWords = signer.words {
                guard let decrypted = Crypto.decrypt(encryptedWords),
                        let words = decrypted.utf8String else { return }
                
                guard let masterKey = Keys.masterKey(words: words, coinType: "\(self.network)", passphrase: passphrase) else {
                    showAlert(vc: self, title: "", message: "Unable to derive your master key.")
                    return
                }
                
                self.masterKey = masterKey
                                            
                var arr = words.split(separator: " ")
                
                for (i, _) in arr.enumerated() {
                    if i > 0 && i < arr.count - 1 {
                        arr[i] = "******"
                    }
                }
                                        
                guard let urSeed = URHelper.mnemonicToCryptoSeed(words) else { return }
                
                var firstHalf = ""
                var secondHalf = ""
                
                for (i, c) in urSeed.enumerated() {
                    if i < 20 {
                        firstHalf += "\(c)"
                    }
                    
                    if i > urSeed.count - 5 {
                        secondHalf += "\(c)"
                    }
                }
                
                let displaySeed = "\(firstHalf + "*****" + secondHalf)"
                
                self.tableDict[1]["text"] = words
                self.tableDict[1]["ur"] = urSeed
                self.tableDict[1]["censoredText"] = arr.joined(separator: " ")
                self.tableDict[1]["censoredUr"] = displaySeed
                self.setWallets(masterKey)
            } else {
                self.reloadTable()
            }
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
           let decryptedSigner = Crypto.decrypt(encryptedWords),
           let words = decryptedSigner.utf8String,
           let mkMain = Keys.masterKey(words: words, coinType: "0", passphrase: passphrase),
           let xfp = Keys.fingerprint(masterKey: mkMain),
           let encryptedXfp = Crypto.encrypt(xfp.utf8),
           let mkTest = Keys.masterKey(words: words, coinType: "1", passphrase: passphrase),
           let bip84xpub = Keys.bip84AccountXpub(masterKey: mkMain, coinType: "0", account: 0),
           let bip84tpub = Keys.bip84AccountXpub(masterKey: mkTest, coinType: "1", account: 0),
           let bip48xpub = Keys.xpub(path: "m/48'/0'/0'/2'", masterKey: mkMain),
           let bip48tpub = Keys.xpub(path: "m/48'/1'/0'/2'", masterKey: mkTest),
           let rootTpub = Keys.xpub(path: "m", masterKey: mkTest),
           let rootXpub = Keys.xpub(path: "m", masterKey: mkMain),
           let encryptedRootTpub = Crypto.encrypt(rootTpub.utf8),
           let encryptedRootXpub = Crypto.encrypt(rootXpub.utf8),
           let encryptedbip84xpub = Crypto.encrypt(bip84xpub.utf8),
           let encryptedbip84tpub = Crypto.encrypt(bip84tpub.utf8),
           let encryptedbip48xpub = Crypto.encrypt(bip48xpub.utf8),
           let encryptedbip48tpub = Crypto.encrypt(bip48tpub.utf8) {
            
            CoreDataService.update(id: self.signer.id, keyToUpdate: "bip84xpub", newValue: encryptedbip84xpub, entity: .signers) { _ in }
            CoreDataService.update(id: self.signer.id, keyToUpdate: "bip84tpub", newValue: encryptedbip84tpub, entity: .signers) { _ in }
            CoreDataService.update(id: self.signer.id, keyToUpdate: "bip48xpub", newValue: encryptedbip48xpub, entity: .signers) { _ in }
            CoreDataService.update(id: self.signer.id, keyToUpdate: "bip48tpub", newValue: encryptedbip48tpub, entity: .signers) { _ in }
            CoreDataService.update(id: self.signer.id, keyToUpdate: "xfp", newValue: encryptedXfp, entity: .signers) { _ in }
            CoreDataService.update(id: self.signer.id, keyToUpdate: "rootTpub", newValue: encryptedRootTpub, entity: .signers) { _ in }
            CoreDataService.update(id: self.signer.id, keyToUpdate: "rootXpub", newValue: encryptedRootXpub, entity: .signers) { _ in }
            
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
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToExportKeystore", sender: self)
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
                
                let message = "This signer will no longer be able to sign transactions that invlove the previous passphrase, this will change the cosigner and descriptor used to create new wallets with this signer. Wallets that are associated with this signer will no longer be associated this signer. If you have exported your cosigner or descriptor to other wallets they will no longer be associated with this signer. If you do not understand what any of this means then just STOP."
                
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
                
                let text = (alert.textFields![0] as UITextField).text
                
                guard let text = text else {
                    showAlert(vc: self, title: "", message: "No passphrase added.")
                    
                    return
                }
                
                guard let encryptedPassphrase = Crypto.encrypt(text.utf8) else {
                    showAlert(vc: self, title: "Encryption error...", message: "Please let us know about this bug, unable to encrypt your new passphrase")
                    return
                }
                
                self.updatePassphrase(encryptedPassphrase, text)
            }
            
            alert.addTextField { textField in
                textField.keyboardAppearance = .dark
                textField.isSecureTextEntry = true
            }
            
            alert.addAction(edit)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { alertAction in }
            alert.addAction(cancel)
            
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    private func segmentedControll(_ x: CGFloat, _ selectedSegmentIndex: Int) -> UISegmentedControl {
        let segmentedControll = UISegmentedControl(items: ["text", "ur"])
        segmentedControll.frame = CGRect(x: x, y: 10, width: 100, height: 30)
        segmentedControll.setTitle("text", forSegmentAt: 0)
        segmentedControll.setTitle("ur", forSegmentAt: 1)
        segmentedControll.selectedSegmentIndex = selectedSegmentIndex
        segmentedControll.addTarget(self, action: #selector(segmentedControlValueDidChange(_:)), for: .valueChanged)
        return segmentedControll
    }
    
    private func exportQrButton(_ x: CGFloat) -> UIButton {
        let qrButton = UIButton()
        qrButton.setImage(.init(systemName: "qrcode"), for: .normal)
        qrButton.imageView?.tintColor = .systemTeal
        qrButton.frame = CGRect(x: x, y: 5, width: 40, height: 40)
        qrButton.showsTouchWhenHighlighted = true
        qrButton.addTarget(self, action: #selector(exportQr(_:)), for: .touchUpInside)
        return qrButton
    }
    
    private func createWalletButton(_ x: CGFloat) -> UIButton {
        let createWalletButton = UIButton()
        createWalletButton.setImage(.init(systemName: "plus"), for: .normal)
        createWalletButton.imageView?.tintColor = .systemTeal
        createWalletButton.frame = CGRect(x: x, y: 5, width: 40, height: 40)
        createWalletButton.showsTouchWhenHighlighted = true
        createWalletButton.addTarget(self, action: #selector(createWallet), for: .touchUpInside)
        return createWalletButton
    }
    
    private func deleteButton(_ x: CGFloat) -> UIButton {
        let deleteButton = UIButton()
        deleteButton.setImage(.init(systemName: "trash"), for: .normal)
        deleteButton.imageView?.tintColor = .systemRed
        deleteButton.frame = CGRect(x: x, y: 5, width: 40, height: 40)
        deleteButton.showsTouchWhenHighlighted = true
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
                    
                    let message = "This signer will no longer be able to sign transactions that invlove the previous passphrase, this will change the cosigner and descriptor used to create new wallets with this signer. Wallets that are associated with this signer will no longer be associated this signer. If you have exported your cosigner or descriptor to other wallets they will no longer be associated with this signer. If you do not understand what any of this means then just STOP."
                    
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
            
            self.tableDict[1]["ur"] = ""
            self.tableDict[1]["text"] = ""
            self.tableDict[1]["censoredText"] = ""
            self.tableDict[1]["censoredUr"] = ""
            
            self.getData()
        }
    }
    
    private func setClipBoard(_ string: String) {
        let clipBoard = UIPasteboard.general
        clipBoard.string = string
        showAlert(vc: self, title: "", message: "Copied to clipboard ✓")
    }
    
    @objc func segmentedControlValueDidChange(_ sender: UISegmentedControl) {
        tableDict[sender.tag]["selectedSegmentIndex"] = sender.selectedSegmentIndex
        tableView.reloadSections(IndexSet(arrayLiteral: sender.tag), with: .fade)
    }
    
    private func importAccountMap(_ descriptor: String, _ label: String, _ password: String) {
        spinner.addConnectingView(vc: self, description: "creating wallet...")
        
        OnchainUtils.getBlockchainInfo { [weak self] (blockchainInfo, message) in
            guard let self = self else { return }
            guard let blockchainInfo = blockchainInfo else {
                self.spinner.removeConnectingView()
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
                self.spinner.removeConnectingView()
                
                guard success else {
                    showAlert(vc: self, title: "There was an issue creating your wallet...", message: errorDescription ?? "Unknown...")
                    return
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    let tit = "Wallet created ✓"
                    
                    let mess = "A rescan was triggered, you may not see transactions or balances until the rescan completes."
                    
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

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }

                        self.performSegue(withIdentifier: "segueToCreateMultiSigFromSigner", sender: self)
                    }
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
    
    private func prompToChoosePrimaryDesc(descriptors: [String], jmDescriptors: [String]) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Choose a wallet format.", message: "", preferredStyle: .alert)
            
            for (i, descriptor) in descriptors.enumerated() {
                let descStr = Descriptor(descriptor)
                
                alert.addAction(UIAlertAction(title: descStr.scriptType, style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.setPrimDesc(descriptors: descriptors, descriptorToUseIndex: i)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Join Market", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.recoverJm(jmDescriptors: jmDescriptors)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func recoverJm(jmDescriptors: [String]) {
        spinner.addConnectingView(vc: self, description: "creating jm wallet...")
        
        //let blockheight = UserDefaults.standard.object(forKey: "blockheight") as? Int ?? 0
        OnchainUtils.getBlockchainInfo { [weak self] (blockchainInfo, message) in
            guard let self = self else { return }
            guard let blockchainInfo = blockchainInfo else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "", message: message ?? "error getting blockchaininfo")
                return
            }
            
            var accountMap:[String:Any] = [
                "descriptor":jmDescriptors[0],
                "watching":Array(jmDescriptors[2...jmDescriptors.count - 1]),
                "label":"Join Market"
            ]
            
            if blockchainInfo.pruned {
                accountMap["blockheight"] = blockchainInfo.pruneheight
            } else {
                accountMap["blockheight"] = 0
            }
            
            ImportWallet.accountMap(accountMap) { [weak self] (success, errorDescription) in
                guard let self = self else { return }

                guard success else {
                    showAlert(vc: self, title: "There was an issue creating your wallet...", message: errorDescription ?? "Unknown...")
                    return
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    let tit = "JM wallet created ✓"

                    let mess = "A rescan was triggered, you may not see transactions or balances until the rescan completes."

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
    
    private func setPrimDesc(descriptors: [String], descriptorToUseIndex: Int) {
        let primDesc = descriptors[descriptorToUseIndex]
        let desc = Descriptor("\(primDesc)")
        
        if desc.isP2TR {
            promptForEncryptionPassword(primDesc)
        } else {
            if desc.isCosigner {
                self.cosigner = desc

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.performSegue(withIdentifier: "segueToCreateMultiSigFromSigner", sender: self)
                }
            } else {
                self.importAccountMap(primDesc, signer.label, "")
            }
        }
    }
    
    private func promptForEncryptionPassword(_ primDesc: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Add a password?"
            let message = "Taproot wallets store the private keys on your node, this password is used to encrypt them. You must remember this password as Fully Noded does not save it."
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let setPassword = UIAlertAction(title: "Set password", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                let password = (alert.textFields![0] as UITextField).text
                
                guard let password = password else {
                    showAlert(vc: self, title: "", message: "No password added, try again.")
                    
                    return
                }
                
                self.importAccountMap(primDesc, "Taproot: " + self.signer.label, password)
            }
            
            alert.addTextField { textField in
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .dark
            }
            
            alert.addAction(setPassword)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    private func creatWalletLive() {
        guard let encryptedWords = signer.words,
                let wordsData = Crypto.decrypt(encryptedWords),
                let words = wordsData.utf8String else {
                    return
                }
        
        let (descriptors, message) = Keys.descriptorsFromSigner(words)
        
        guard let descriptors = descriptors else {
            showAlert(vc: self, title: "There was an issue deriving your descriptors...", message: message ?? "Unknown")
            return
        }
        
        var passphrase = ""
        
        if let encryptedPassphrase = signer.passphrase {
            guard let decryptedPassphrase = Crypto.decrypt(encryptedPassphrase) else {
                showAlert(vc: self, title: "There was an issue decrypting your passphrase...", message: message ?? "Unknown")
                return
            }
            
            passphrase = decryptedPassphrase.utf8String ?? ""
        }
        
        guard let mk = Keys.masterKey(words: words, coinType: "\(self.network)", passphrase: passphrase),
              let xfp = Keys.fingerprint(masterKey: mk) else {
                  showAlert(vc: self, title: "There was an issue deriving your master key", message: message ?? "Unknown")
                  return
              }
        
        JoinMarket.descriptors(mk, xfp) { [weak self] jmDescriptors in
            guard let self = self else { return }
            
            guard let jmDescriptors = jmDescriptors else {
                showAlert(vc: self, title: "There was an issue deriving your jm descriptors...", message: message ?? "Unknown")
                return
            }
            
            self.prompToChoosePrimaryDesc(descriptors: descriptors, jmDescriptors: jmDescriptors)
        }
    }
    
    @objc func exportQr(_ sender: UIButton) {
        let section = sender.tag
        
        let dict = tableDict[section]
        let selectedSegment = dict["selectedSegmentIndex"] as? Int ?? 0
                
        switch section {
        case 1:
            switch selectedSegment {
            case 0:
                stringToExport = dict["text"] as? String ?? ""
                headerText = "BIP39 Seed Words"
                descriptionText = "⚠️ Do not share with others! These words can be used to spend your btc, or recover your wallet."
                
            case 1:
                stringToExport = dict["ur"] as? String ?? ""
                headerText = "UR Crypto Seed"
                descriptionText = "⚠️ Do not share with others! This is a new format for exporting your seed to other wallets."
                
            default:
                break
            }
            
            segueToQr()
            
        case 6:
            switch selectedSegment {
            case 0:
                stringToExport = dict["text"] as? String ?? ""
                headerText = "Cosigner BIP48"
                descriptionText = "This can be shared with other wallets like Specter and Sparrow to create segwit multi-sig wallets."
                
            case 1:
                stringToExport = dict["ur"] as? String ?? ""
                headerText = "Cosigner BIP48"
                descriptionText = "This can be shared with other wallets like Blue Wallet, Passport, Sparrow, and Keystone to create segwit multi-sig wallets."
                
            default:
                break
            }
            
            segueToQr()
            
        case 7:
            switch selectedSegment {
            case 0:
                stringToExport = dict["text"] as? String ?? ""
                headerText = "BIP84 Account"
                descriptionText = "This can be shared with other wallets to create watch-only segwit single-sig wallets."
                
            case 1:
                stringToExport = dict["ur"] as? String ?? ""
                headerText = "BIP84 Account"
                descriptionText = "This can be shared with other wallets like Blue Wallet, Passport, Sparrow, Keystone to create watch-only segwit single-sig wallets."
                
            default:
                break
            }
            
            segueToQr()
            
        case 8:
            switch selectedSegment {
            case 0:
                stringToExport = dict["text"] as? String ?? ""
                headerText = "Root xpub"
                descriptionText = "This can be used with other wallets to create *non hardened* accounts."
                
            case 1:
                stringToExport = dict["ur"] as? String ?? ""
                headerText = "Root xpub hdkey"
                descriptionText = "You can scan this with your Casa App to add a multi-sig cosigner from Fully Noded.\n\n⚠️ Currently Casa App does not display Fully Noded as an option, select Keystone instead."
                
            default:
                break
            }
            
            segueToQr()
            
        default:
            break
        }
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        
        switch segue.identifier {
        case "segueToCreateMultiSigFromSigner":
            guard let vc = segue.destination as? CreateMultisigViewController else { fallthrough }
            
            vc.cosigner = self.cosigner
            
        case "segueToExportKeystore":
            guard let vc = segue.destination as? QRDisplayerViewController else { fallthrough }
            
            vc.descriptionText = descriptionText
            vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
            vc.headerText = headerText
            vc.text = stringToExport
        default:
            break
        }
        
    }
    

}

extension SignerDetailViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let vw = UIView()
        vw.backgroundColor = .clear
        let titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.backgroundColor = .clear
        titleLabel.font = .systemFont(ofSize: 14)
        titleLabel.textColor = .systemGreen
        
        let text = tableDict[section]["footerText"] as? String ?? ""
        titleLabel.text = text
        
        var height:CGFloat = 0
        
        switch Section(rawValue: section) {
        case .words:
            height = 60
            
        case .passphrase:
            height = 60
            
        case .cosigner:
            height = 80
            
        case .singleSig:
            height = 80
            
        case .rootXpub:
            height = 80
            
        case .signableWallets:
            height = 60
            
        case .label:
            height = 40
            
        default:
            titleLabel.text  = ""
        }
        
        titleLabel.frame = CGRect(x:0, y: 8, width: tableView.frame.width - 32, height: height)
        
        titleLabel.sizeToFit()
        
        vw.addSubview(titleLabel)
        return vw
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch Section(rawValue: section) {
        case .label:
            return 40
        case .words:
            return 70
        case .signableWallets, .passphrase:
            return 60
        case .cosigner, .singleSig, .rootXpub:
            return 80
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let dict = tableDict[indexPath.section]
        let selectedSegment = dict["selectedSegmentIndex"] as? Int ?? 0
                
        switch indexPath.section {
        case 0:
            editLabel(dict["text"] as? String ?? "")
            
        case 1:
            switch selectedSegment {
            default:
                break
            }
            
        case 2:
            setClipBoard(dict["text"] as? String ?? "")
        
        case 3:
            promptToEditPassphrase()
            
        case 6, 7:
            switch selectedSegment {
            case 0:
                setClipBoard(dict["text"] as? String ?? "")
            case 1:
                setClipBoard(dict["ur"] as? String ?? "")
            default:
                break
            }
            
        case 8:
            setClipBoard(dict["text"] as? String ?? "")
            
        default:
            break
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 9
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "defaultCell", for: indexPath)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.textColor = .lightGray
        cell.textLabel?.sizeToFit()
        cell.sizeToFit()
        cell.selectionStyle = .none
        
        configureField(cell)
        
        let dict = self.tableDict[indexPath.section]
        let selectedSegment = dict["selectedSegmentIndex"] as? Int ?? 0
        
        switch Section(rawValue: indexPath.section) {
        case .label:
            cell.textLabel?.text = dict["text"] as? String ?? "no label"
            
        case .words:
            switch selectedSegment {
            case 0:
                cell.textLabel?.text = dict["censoredText"] as? String ?? "no seed words"
            case 1:
                cell.textLabel?.text = dict["censoredUr"] as? String ?? "no seed words"
            default:
                break
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
            switch selectedSegment {
            case 0:
                cell.textLabel?.text = dict["text"] as? String ?? "no multi-sig cosigner"
            case 1:
                cell.textLabel?.text = dict["ur"] as? String ?? "no multi-sig cosigner"
            default:
                break
            }
            
        case .singleSig:
            switch selectedSegment {
            case 0:
                cell.textLabel?.text = dict["text"] as? String ?? "no descriptor"
            case 1:
                cell.textLabel?.text = dict["ur"] as? String ?? "no descriptor"
            default:
                break
            }
            
        case .rootXpub:
            switch selectedSegment {
            case 0:
                cell.textLabel?.text = dict["text"] as? String ?? "no root xpub"
            case 1:
                cell.textLabel?.text = dict["ur"] as? String ?? "no root xpub hdkey"
            default:
                break
            }
            
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
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .white
        textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
        
        let selectedSegmentIndex = tableDict[section]["selectedSegmentIndex"] as? Int ?? 0
                
        let exportQrButtonGeneric = exportQrButton(header.frame.maxX - 46)
        exportQrButtonGeneric.tag = section
                
        let segmentedControl = segmentedControll(exportQrButtonGeneric.frame.minX - 108, selectedSegmentIndex)
        segmentedControl.tag = section
        
        if let section = Section(rawValue: section) {
            switch section {
            case .signableWallets:
                header.addSubview(createWalletButton(header.frame.maxX - 46))
                textLabel.text = headerName(for: section)
                
            case .words:
                let deleteButtonSeed = deleteButton(segmentedControl.frame.minX - 46)
                deleteButtonSeed.addTarget(self, action: #selector(promptToDeleteSeed), for: .touchUpInside)
                header.addSubview(segmentedControl)
                header.addSubview(exportQrButtonGeneric)
                header.addSubview(deleteButtonSeed)
                
                if selectedSegmentIndex == 0 {
                    textLabel.text = headerName(for: section)
                } else {
                    textLabel.text = "Seed"
                }
                
            case .passphrase:
                let deleteButtonPassphrase = deleteButton(header.frame.maxX - 46)
                textLabel.text = headerName(for: section)
                deleteButtonPassphrase.addTarget(self, action: #selector(promptToDeletePassphrase), for: .touchUpInside)
                header.addSubview(deleteButtonPassphrase)
                
            case .cosigner:
                header.addSubview(segmentedControl)
                header.addSubview(exportQrButtonGeneric)
                textLabel.text = headerName(for: section)
                
            case .singleSig:
                header.addSubview(segmentedControl)
                header.addSubview(exportQrButtonGeneric)
                textLabel.text = headerName(for: section)
                
            case .rootXpub:
                header.addSubview(segmentedControl)
                header.addSubview(exportQrButtonGeneric)
                textLabel.text = headerName(for: section)
                
            default:
                textLabel.text = headerName(for: section)
            }
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
}

extension SignerDetailViewController: UITableViewDataSource {}
