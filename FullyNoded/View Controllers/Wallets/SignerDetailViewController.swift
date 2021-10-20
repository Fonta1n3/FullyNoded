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
    private var tableDict = [String:String]()
    private var multisigKeystore = ""
    private var singleSig = ""
    private var network = 0
    
    private enum Section: Int {
        case label
        case words
        case masterKeyFingerprint
        case passphrase
        case dateAdded
        case signableWallets
        case cosigner
        case singleSig
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
            return "Multi-sig cosigner (BIP48)"
        case .singleSig:
            return "Single sig xpub (BIP84)"
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
        
        tableDict["words"] = words.utf8
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
            
            self.tableDict["label"] = signer.label
            self.tableDict["date"] = "  " +  self.formattedDate(signer.added)
            
            guard var decrypted = Crypto.decrypt(signer.words), var words = decrypted.utf8 else { return }
                        
            var arr = words.split(separator: " ")
            
            for (i, _) in arr.enumerated() {
                if i > 0 && i < arr.count - 1 {
                    arr[i] = "******"
                }
            }
            
            self.tableDict["words"] = arr.joined(separator: " ")
            
            var passphrase = ""
            
            if signer.passphrase != nil {
                guard let decryptedPassphrase = Crypto.decrypt(signer.passphrase!), let string = decryptedPassphrase.utf8 else { return }
                
                passphrase = string
                self.tableDict["passphrase"] = "  " + passphrase
            } else {
                self.tableDict["passphrase"] = "  ** no passphrase **"
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
        
        self.tableDict["fingerprint"] = "  " + fingerprint
        
        guard let msigKey = Keys.xpub(path: "m/48'/\(self.network)'/0'/2'", masterKey: masterKey) else { return }
        
        guard let singleSigKey = Keys.xpub(path: "m/84'/\(self.network)'/0'", masterKey: masterKey) else { return }
        
        self.singleSig = "wpkh([\(fingerprint)/84h/\(self.network)h/0h]\(singleSigKey)/0/*)"
        
        self.multisigKeystore = "wsh([\(fingerprint)/48h/\(self.network)h/0h/2h]\(msigKey)/0/*)"
        
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets, wallets.count > 0 else {
                self.tableDict["wallets"] = ""
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
                        
                        self.tableDict["wallets"] = "  " + signableWallets
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
        
        vc.descriptionText = multisigKeystore
        vc.headerIcon = UIImage(systemName: "person.3")
        vc.headerText = "Multisig Cosigner"
        vc.text = multisigKeystore
    }
    

}

extension SignerDetailViewController: UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 8
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "defaultCell", for: indexPath)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.sizeToFit()
        cell.sizeToFit()
        cell.selectionStyle = .none
        configureField(cell)
        
        switch Section(rawValue: indexPath.section) {
        case .label:
            cell.textLabel?.text = self.tableDict["label"]
        case .words:
            cell.textLabel?.text = self.tableDict["words"]
        case .masterKeyFingerprint:
            cell.textLabel?.text = self.tableDict["fingerprint"]
        case .passphrase:
            cell.textLabel?.text = self.tableDict["passphrase"]
        case .dateAdded:
            cell.textLabel?.text = self.tableDict["date"]
        case .signableWallets:
            cell.textLabel?.text = self.tableDict["wallets"]
        case .cosigner:
            cell.textLabel?.text = self.multisigKeystore
        case .singleSig:
            cell.textLabel?.text = self.singleSig
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
        
        if let section = Section(rawValue: section) {
            textLabel.text = headerName(for: section)
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
}

extension SignerDetailViewController: UITableViewDataSource {}
