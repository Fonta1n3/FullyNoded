//
//  SignerDetailViewController.swift
//  BitSense
//
//  Created by Peter on 05/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class SignerDetailViewController: UIViewController, UINavigationControllerDelegate {
    
    var id:UUID!
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
        case casaCosigner
    }
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self
        navigationController?.delegate = self
        segmentedControl.setEnabled(true, forSegmentAt: network)
        
        tableDict = [
            ["text":"", "footerText": "Tap the label to edit it."],// label 0
            ["text": "", "ur": "", "selectedSegmentIndex": 0, "censoredText": "", "censoredUr": "", "footerText": "UR for exporting this signer to iOS Seed Tool, Gordian Wallet, Gordian Signer and any other wallet which supports UR crypto-seed. Tap to copy the text."],// words 1
            ["text": "", "footerText": ""],// xfp 2
            ["text": "", "footerText": ""],// passphrase 3
            ["text": "", "footerText": ""],// dateAdded 4
            ["text": "", "footerText": "The wallets which this signer can sign for. Tap the + button to create a wallet with this signer."],// wallets 5
            ["text": "", "ur": "", "selectedSegmentIndex": 1, "footerText": "UR for exporting the segwit mutli-sig cosigner to Blue Wallet, Keystone HWW, Passport HWW, Sparrow and any other wallet which supports UR crypto-account. Tap to copy the text."],// cosigner 6
            ["text": "", "ur": "", "selectedSegmentIndex": 1, "footerText": "UR for exporting the segwit single-sig watch-only wallet to Blue Wallet, Keystone HWW, Passport HWW, Sparrow and any other wallet which supports UR crypto-account. Tap to copy the text."],// singlesig 7
            ["text": "", "footerText": "Export your segwit multi-sig cosigner to Casa App by selecting the Keystone option when adding a HWW key to Casa App. Also compatible with Gordian Wallet and Gordian Cosigner. Tap to copy the text."]// casa hdkey 8
        ]
        
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
        case .casaCosigner:
            return "Casa App Cosigner"
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
        
        let selectedSegmentIndex = tableDict[1]["selectedSegmentIndex"] as? Int ?? 0
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch selectedSegmentIndex {
            case 0:
                self.tableDict[1]["censoredText"] = self.tableDict[1]["text"] as? String ?? "no seed words"
                
            case 1:
                self.tableDict[1]["censoredSeed"] = self.tableDict[1]["ur"] as? String ?? "no crypto-seed"
                
            default:
                break
            }
            
            self.tableView.reloadSections(IndexSet(arrayLiteral: 1), with: .fade)
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
                        let string = decryptedPassphrase.utf8 else { return }
                
                passphrase = string
                self.tableDict[3]["text"] = "  " + passphrase
            } else {
                self.tableDict[3]["text"] = "  ** no passphrase **"
            }
            
            guard let encryptedXfp = signer.xfp,
                let decryptedXfp = Crypto.decrypt(encryptedXfp),
                let xfp = decryptedXfp.utf8 else {
                    showAlert(vc: self, title: "", message: "Error getting your xfp.")
                return
            }
            
            self.tableDict[2]["text"] = "  " + xfp
            
            if self.network == 0 {
                if let encryptedbip84xpub = signer.bip84xpub,
                    let decryptedbip84xpub = Crypto.decrypt(encryptedbip84xpub),
                    let xpub = decryptedbip84xpub.utf8 {
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
                    let xpub = decryptedbip48xpub.utf8 {
                    let cosigner = "wsh([\(xfp)/48h/0h/0h/2h]\(xpub)/0/*)"
                    
                    guard let cosignerAccount = URHelper.descriptorToUrAccount(Descriptor(cosigner)) else {
                        showAlert(vc: self, title: "UR error.", message: "Unable to convert your cosigner to crypto-account.")
                        return
                    }
                    
                    self.tableDict[6]["text"] = cosigner
                    self.tableDict[6]["ur"] = cosignerAccount
                    
                    guard let casaHdkey = URHelper.descriptorToUrHdkey(Descriptor(cosigner)) else {
                        showAlert(vc: self, title: "UR error.", message: "Unable to convert your cosigner to crypto-hdkey.")
                        return
                    }
                    
                    self.tableDict[8]["text"] = casaHdkey
                }
                
            } else {
                if let encryptedbip84tpub = signer.bip84tpub,
                    let decryptedbip84tpub = Crypto.decrypt(encryptedbip84tpub),
                    let tpub = decryptedbip84tpub.utf8 {
                    let descriptor = "wpkh([\(xfp)/84h/0h/0h]\(tpub)/0/*)"
                    
                    guard let singleSigCryptoAccount = URHelper.descriptorToUrAccount(Descriptor(descriptor)) else {
                        showAlert(vc: self, title: "UR error.", message: "Unable to convert your descriptor to crypto-account.")
                        return
                    }
                    
                    self.tableDict[7]["text"] = descriptor
                    self.tableDict[7]["ur"] = singleSigCryptoAccount
                }
                
                if let encryptedbip48tpub = signer.bip48tpub,
                    let decryptedbip48tpub = Crypto.decrypt(encryptedbip48tpub),
                    let tpub = decryptedbip48tpub.utf8 {
                    let cosigner = "wsh([\(xfp)/48h/0h/0h/2h]\(tpub)/0/*)"
                    
                    guard let cosignerAccount = URHelper.descriptorToUrAccount(Descriptor(cosigner)) else {
                        showAlert(vc: self, title: "UR error.", message: "Unable to convert your cosigner to crypto-account.")
                        return
                    }
                    
                    self.tableDict[6]["text"] = cosigner
                    self.tableDict[6]["ur"] = cosignerAccount
                    
                    guard let casaHdkey = URHelper.descriptorToUrHdkey(Descriptor(cosigner)) else {
                        showAlert(vc: self, title: "UR error.", message: "Unable to convert your cosigner to crypto-hdkey.")
                        return
                    }
                    
                    self.tableDict[8]["text"] = casaHdkey
                }
            }
            
            if let encryptedWords = signer.words {
                guard let decrypted = Crypto.decrypt(encryptedWords),
                        let words = decrypted.utf8 else { return }
                
                guard let masterKey = Keys.masterKey(words: words, coinType: "\(self.network)", passphrase: passphrase) else {
                    showAlert(vc: self, title: "", message: "Unable to derive your master key.")
                    return
                }
                                            
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
                self.tableDict[1]["censoredSeed"] = displaySeed
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
    
    @objc func export(_ sender: UIButton) {
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
    
    private func setClipBoard(_ string: String) {
        let clipBoard = UIPasteboard.general
        clipBoard.string = string
        showAlert(vc: self, title: "", message: "Copied to clipboard ✓")
    }
    
    @objc func segmentedControlValueDidChange(_ sender: UISegmentedControl) {
        tableDict[sender.tag]["selectedSegmentIndex"] = sender.selectedSegmentIndex
        tableView.reloadSections(IndexSet(arrayLiteral: sender.tag), with: .fade)
    }
    
    private func importAccountMap(_ descriptor: String, _ label: String) {
        let accountMap = ["descriptor": descriptor, "blockheight": 0, "watching": [], "label": label] as [String : Any]
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.navigationController?.popViewController(animated: true)
            self.tabBarController?.selectedIndex = 1
            NotificationCenter.default.post(name: .importWallet, object: nil, userInfo: accountMap)
        }
    }
    
    @objc func createWallet() {
        // MARK: If no words then only use saved accounts
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let fingerprint = Keys.fingerprint(masterKey: self.masterKey) else { return }
            
            let title = "Create a single sig wallet using this signer?"
            let message = "Choose an address type."
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let p2wpkh = UIAlertAction(title: "Segwit BIP84", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                guard let singleSigKey = Keys.xpub(path: "m/84'/\(self.network)'/0'", masterKey: self.masterKey) else { return }
                
                let descriptor = "wpkh([\(fingerprint)/84h/\(self.network)h/0h]\(singleSigKey)/0/*)"
                self.importAccountMap(descriptor, self.signer.label + " segwit")
            }
            
            let p2pkh = UIAlertAction(title: "Legacy BIP44", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                guard let singleSigKey = Keys.xpub(path: "m/44'/\(self.network)'/0'", masterKey: self.masterKey) else { return }
                
                let descriptor = "pkh([\(fingerprint)/44h/\(self.network)h/0h]\(singleSigKey)/0/*)"
                self.importAccountMap(descriptor, self.signer.label + " Legacy single-sig")
            }
            
            let p2shp2wpkh = UIAlertAction(title: "Nested BIP49", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                guard let singleSigKey = Keys.xpub(path: "m/49'/\(self.network)'/0'", masterKey: self.masterKey) else { return }
                
                let descriptor = "sh(wpkh([\(fingerprint)/49h/\(self.network)h/0h]\(singleSigKey)/0/*))"
                self.importAccountMap(descriptor, self.signer.label + " Nested single-sig")
            }
            
            alert.addAction(p2wpkh)
            alert.addAction(p2pkh)
            alert.addAction(p2shp2wpkh)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            
            self.present(alert, animated:true, completion: nil)
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
                headerText = "Descriptor BIP84"
                descriptionText = "This can be shared with other wallets to create watch-only segwit single-sig wallets."
                
            case 1:
                stringToExport = dict["ur"] as? String ?? ""
                headerText = "Descriptor BIP84"
                descriptionText = "This can be shared with other wallets like Blue Wallet, Passport, Sparrow, Keystone to create watch-only segwit single-sig wallets."
                
            default:
                break
            }
            
            segueToQr()
            
        case 8:
            stringToExport = dict["text"] as? String ?? ""
            headerText = "Casa App Cosigner"
            descriptionText = "You can scan this with your Casa App to add a multi-sig cosigner from Fully Noded.\n\n⚠️ Currently Casa App does not display Fully Noded as an option, select Keystone instead."
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
        guard let vc = segue.destination as? QRDisplayerViewController else { return }
        
        vc.descriptionText = descriptionText
        vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
        vc.headerText = headerText
        vc.text = stringToExport.uppercased()
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
            
        case .cosigner:
            height = 80
            
        case .singleSig:
            height = 80
            
        case .casaCosigner:
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
        case .words, .signableWallets:
            return 60
        case .cosigner, .singleSig, .casaCosigner:
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
            case 0:
                setClipBoard(dict["text"] as? String ?? "")
            case 1:
                setClipBoard(dict["ur"] as? String ?? "")
            default:
                break
            }
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
                cell.textLabel?.text = dict["censoredSeed"] as? String ?? "no seed words"
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
            
        case .casaCosigner:
            cell.textLabel?.text = dict["text"] as? String ?? "no hdkey"
            
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
                header.addSubview(segmentedControl)
                header.addSubview(exportQrButtonGeneric)
                
                if selectedSegmentIndex == 0 {
                    textLabel.text = headerName(for: section)
                } else {
                    textLabel.text = "Seed"
                }
                
            case .cosigner:
                header.addSubview(segmentedControl)
                header.addSubview(exportQrButtonGeneric)
                textLabel.text = headerName(for: section)
                
            case .singleSig:
                header.addSubview(segmentedControl)
                header.addSubview(exportQrButtonGeneric)
                textLabel.text = headerName(for: section)
                
            case .casaCosigner:
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
