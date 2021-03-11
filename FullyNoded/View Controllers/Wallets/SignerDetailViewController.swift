//
//  SignerDetailViewController.swift
//  BitSense
//
//  Created by Peter on 05/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class SignerDetailViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    var isEditingNow = false
    var id:UUID!
    private var signer: SignerStruct!
    private var tableDict = [String:String]()
    private var multisigKeystore = ""
    private var network = 0
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var labelField: UITextField!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self
        navigationController?.delegate = self
        labelField.delegate = self
        addTapGesture()
        configureField(labelField)
        segmentedControl.setEnabled(true, forSegmentAt: network)
        getData()
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
    
    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        self.labelField.removeGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            view.endEditing(true)
        }
        sender.cancelsTouchesInView = false
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
            
            self.labelField.text = signer.label
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
        
        self.multisigKeystore = "[\(fingerprint)/48h/\(self.network)h/0h/2h]\(msigKey)"
        
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets, wallets.count > 0 else {
                self.tableDict["wallets"] = ""
                self.reloadTable()
                return
            }
            
            var signableWallets = ""
            
            for (w, wallet) in wallets.enumerated() {
                let walletStruct = Wallet(dictionary: wallet)
                let p = DescriptorParser()
                let descriptor = p.descriptor(walletStruct.receiveDescriptor)
                
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

extension SignerDetailViewController: UITableViewDelegate { }

extension SignerDetailViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "signerDetailCell", for: indexPath)
        
        let wordsView = cell.viewWithTag(1) as! UITextView
        let fingerprintLabel = cell.viewWithTag(2) as! UILabel
        let passphraseLabel = cell.viewWithTag(3) as! UILabel
        let dateAddedLabel = cell.viewWithTag(4) as! UILabel
        let signableWalletsLabel = cell.viewWithTag(5) as! UILabel
        let exportButton = cell.viewWithTag(6) as! UIButton
        
        configureField(wordsView)
        configureField(passphraseLabel)
        configureField(dateAddedLabel)
        configureField(fingerprintLabel)
        configureField(signableWalletsLabel)
        configureField(exportButton)
        
        wordsView.text = self.tableDict["words"]
        fingerprintLabel.text = self.tableDict["fingerprint"]
        passphraseLabel.text = self.tableDict["passphrase"]
        dateAddedLabel.text = self.tableDict["date"]
        signableWalletsLabel.text = self.tableDict["wallets"]
        
        exportButton.showsTouchWhenHighlighted = true
        exportButton.addTarget(self, action: #selector(export), for: .touchUpInside)
        
        cell.sizeToFit()
        cell.selectionStyle = .none
        
        return cell
    }
    
    
}
