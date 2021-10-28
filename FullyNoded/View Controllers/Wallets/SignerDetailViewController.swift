//
//  SignerDetailViewController.swift
//  BitSense
//
//  Created by Peter on 05/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class SignerDetailViewController: UIViewController, UINavigationControllerDelegate {
    
    var isEditingNow = false
    var id:UUID!
    private var signer: SignerStruct!
    private var tableDict = [[String:Any]]()
    private var network = 0
    private var stringToExport = ""
    private var descriptionText = ""
    private var headerText = ""
    
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
            ["label": ""],
            ["text": "", "ur": "", "selectedSegmentIndex": 0, "censoredText": "", "censoredUr": ""],
            ["fingerprint": ""],
            ["passphrase": ""],
            ["dateAdded": ""],
            ["wallets": ""],
            ["text": "", "ur": "", "selectedSegmentIndex": 1],
            ["text": "", "ur": "", "selectedSegmentIndex": 1],
            ["text": ""]
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
        
        guard let words = Crypto.decrypt(signer.words) else { return }
        
        tableDict[1]["text"] = words.utf8
        reloadTable()
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
            
            self.tableDict[0]["label"] = signer.label
            self.tableDict[4]["date"] = "  " +  self.formattedDate(signer.added)
            
            guard var decrypted = Crypto.decrypt(signer.words), var words = decrypted.utf8 else { return }
                        
            var arr = words.split(separator: " ")
            
            for (i, _) in arr.enumerated() {
                if i > 0 && i < arr.count - 1 {
                    arr[i] = "******"
                }
            }
                                    
            guard let urSeed = URHelper.mnemonicToCryptoSeed(words) else { return }
            
            var censoredSeed:[String] = []
            
            for (i, c) in urSeed.enumerated() {
                if i > 25 && i < urSeed.count - 7 {
                    censoredSeed.append("*")
                } else {
                    censoredSeed.append("\(c)")
                }
            }
            
            self.tableDict[1]["text"] = words//arr.joined(separator: " ")
            self.tableDict[1]["ur"] = urSeed
            self.tableDict[1]["censoredText"] = arr.joined(separator: " ")
            self.tableDict[1]["censoredSeed"] = censoredSeed.joined()
            
            
            var passphrase = ""
            
            if signer.passphrase != nil {
                guard let decryptedPassphrase = Crypto.decrypt(signer.passphrase!), let string = decryptedPassphrase.utf8 else { return }
                
                passphrase = string
                self.tableDict[3]["passphrase"] = "  " + passphrase
            } else {
                self.tableDict[3]["passphrase"] = "  ** no passphrase **"
            }
            
            guard var mk = Keys.masterKey(words: words, coinType: "\(self.network)", passphrase: passphrase) else { return }
            
            self.setWallets(mk)
            
            decrypted = Data()
            passphrase = ""
            mk = ""
            words = ""
        }
    }
    
    private func setWallets(_ masterKey: String) {
        guard let fingerprint = Keys.fingerprint(masterKey: masterKey) else { return }
        
        self.tableDict[2]["fingerprint"] = "  " + fingerprint
        
        guard let msigKey = Keys.xpub(path: "m/48'/\(self.network)'/0'/2'", masterKey: masterKey) else { return }
        
        guard let singleSigKey = Keys.xpub(path: "m/84'/\(self.network)'/0'", masterKey: masterKey) else { return }
        
        let cosigner = "wsh([\(fingerprint)/48h/\(self.network)h/0h/2h]\(msigKey)/0/*)"
        
        guard let cosignerAccount = URHelper.descriptorToUrAccount(Descriptor(cosigner)) else {
            showAlert(vc: self, title: "UR error.", message: "Unable to convert your cosigner to crypto-account.")
            return
        }
        
        self.tableDict[6]["text"] = cosigner
        self.tableDict[6]["ur"] = cosignerAccount
        
        let descriptor = "wpkh([\(fingerprint)/84h/\(self.network)h/0h]\(singleSigKey)/0/*)"
        
        guard let singleSigCryptoAccount = URHelper.descriptorToUrAccount(Descriptor(descriptor)) else {
            showAlert(vc: self, title: "UR error.", message: "Unable to convert your descriptor to crypto-account.")
            return
        }
        
        self.tableDict[7]["text"] = descriptor
        self.tableDict[7]["ur"] = singleSigCryptoAccount
        
        guard let casaHdkey = URHelper.descriptorToUrHdkey(Descriptor(cosigner)) else {
            showAlert(vc: self, title: "UR error.", message: "Unable to convert your cosigner to crypto-hdkey.")
            return
        }
        
        self.tableDict[8]["text"] = casaHdkey
        
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets, wallets.count > 0 else {
                self.tableDict[5]["wallets"] = ""
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
                        
                        self.tableDict[5]["wallets"] = "  " + signableWallets
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
                self.isEditingNow = false
                showAlert(vc: self, title: "Success ✅", message: "Signer's label updated.")
            } else {
                showAlert(vc: self, title: "Error", message: "Signer's label did not update.")
            }
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.text != "" && isEditingNow {
            updateLabel(textField.text!)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        isEditingNow = true
        return true
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
        
        switch Section(rawValue: section) {
        case .words:
            titleLabel.frame = CGRect(x:0, y: 8, width: tableView.frame.width - 32, height: 50)
            titleLabel.text  = "UR for exporting this signer to iOS Seed Tool, Gordian Wallet, Gordian Signer and any other wallet which supports UR crypto-seed."
        case .cosigner:
            titleLabel.frame = CGRect(x:0, y: 8, width: tableView.frame.width - 32, height: 70)
            titleLabel.text  = "UR for exporting the segwit mutli-sig cosigner to Blue Wallet, Keystone HWW, Passport HWW, Sparrow and any other wallet which supports UR crypto-account."
        case .singleSig:
            titleLabel.frame = CGRect(x:0, y: 8, width: tableView.frame.width - 32, height: 70)
            titleLabel.text  = "UR for exporting the segwit single-sig watch-only wallet to Blue Wallet, Keystone HWW, Passport HWW, Sparrow and any other wallet which supports UR crypto-account."
        case .casaCosigner:
            titleLabel.frame = CGRect(x:0, y: 8, width: tableView.frame.width - 32, height: 70)
            titleLabel.text  = "Export your segwit multi-sig cosigner to Casa App by selecting the Keystone option when adding a HWW key to Casa App. Also compatible with Gordian Wallet and Gordian Cosigner."
            
        default:
            titleLabel.text  = ""
        }
        
        titleLabel.sizeToFit()
        
        vw.addSubview(titleLabel)
        return vw
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch Section(rawValue: section) {
        case .words:
            return 60
        case .cosigner:
            return 70
        case .singleSig:
            return 70
        case .casaCosigner:
            return 70
        default:
            return 0
        }
    }
    
    private func setClipBoard(_ string: String) {
        let clipBoard = UIPasteboard.general
        clipBoard.string = string
        showAlert(vc: self, title: "", message: "Copied to clipboard ✓")
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let dict = tableDict[indexPath.section]
        let selectedSegment = dict["selectedSegmentIndex"] as? Int ?? 0
                
        switch indexPath.section {
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
            cell.textLabel?.text = dict["label"] as? String ?? "no label"
            
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
            cell.textLabel?.text = dict["fingerprint"] as? String ?? "no fingerprint"
            
        case .passphrase:
            cell.textLabel?.text = dict["passphrase"] as? String ?? "*** no passphrase ***"
            
        case .dateAdded:
            cell.textLabel?.text = dict["date"] as? String ?? "no date added"
            
        case .signableWallets:
            cell.textLabel?.text = dict["wallets"] as? String ?? "no signable wallets"
            
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
    
    @objc func segmentedControlValueDidChange(_ sender: UISegmentedControl) {
        tableDict[sender.tag]["selectedSegmentIndex"] = sender.selectedSegmentIndex
        tableView.reloadSections(IndexSet(arrayLiteral: sender.tag), with: .fade)
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
