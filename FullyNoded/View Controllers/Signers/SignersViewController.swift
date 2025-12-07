//
//  SignersViewController.swift
//  BitSense
//
//  Created by Peter on 04/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class SignersViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var signerTable: UITableView!
    var signers = [[String:Any]]()
    var id:UUID!
    var isCreatingMsig = false
    var signerSelected: ((SignerStruct) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()       
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadData()
    }
    
    @IBAction func addSignerAction(_ sender: Any) {
        guard let _ = KeyChain.getData("UnlockPassword") else {
            showAlert(vc: self, title: "You are not using the app securely...", message: "You can only add signers if the app has a lock/unlock password. Tap the lock button on the home screen to add a password.")
            
            return
        }
        
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "addSignerSegue", sender: vc)
        }
    }
    
    private func loadData() {
        signers.removeAll()
        CoreDataService.retrieveEntity(entityName: .signers) { [weak self] encryptedSigners in
            guard let self = self else { return }
            
            guard let encryptedSigners = encryptedSigners else {
                self.reload()
                return
            }
            
            self.signers = encryptedSigners
            self.reload()
            
            guard encryptedSigners.count > 0 else { return }
            
            for encryptedSigner in encryptedSigners {
                let signerStruct = SignerStruct(dictionary: encryptedSigner)
                
                var passphrase = ""
                
                if let encryptedPassphrase = signerStruct.passphrase,
                   let decryptedPassphrase = Crypto.decrypt(encryptedPassphrase),
                   let string = decryptedPassphrase.utf8String {
                    passphrase = string
                }
                                
                // Only fires off if account xpubs had not been saved before.
                if signerStruct.bip86tpub == nil,
                   var encryptedWords = signerStruct.words,
                   var decryptedSigner = Crypto.decrypt(encryptedWords),
                   var words = decryptedSigner.utf8String,
                   let mkMain = Keys.masterKey(words: words, coinType: "0", passphrase: passphrase),
                   let xfp = Keys.fingerprint(masterKey: mkMain),
                   let encryptedXfp = Crypto.encrypt(xfp.utf8),
                   let mkTest = Keys.masterKey(words: words, coinType: "1", passphrase: passphrase),
                   let bip86xpub = Keys.bip86AccountXpub(masterKey: mkMain, coinType: "0", account: 0),
                   let bip86tpub = Keys.bip86AccountXpub(masterKey: mkTest, coinType: "1", account: 0),
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
                   let encryptedbip86xpub = Crypto.encrypt(bip86xpub.utf8),
                   let encryptedbip86tpub = Crypto.encrypt(bip86tpub.utf8),
                   let encryptedbip48xpub = Crypto.encrypt(bip48xpub.utf8),
                   let encryptedbip48tpub = Crypto.encrypt(bip48tpub.utf8) {
                                        
                    defer {
                        encryptedWords.secureZero()
                        decryptedSigner.secureZero()
                        words.secureWipe()
                        passphrase.secureWipe()
                    }
                    
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "bip84xpub", newValue: encryptedbip84xpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "bip84tpub", newValue: encryptedbip84tpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "bip86xpub", newValue: encryptedbip86xpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "bip86tpub", newValue: encryptedbip86tpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "bip48xpub", newValue: encryptedbip48xpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "bip48tpub", newValue: encryptedbip48tpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "xfp", newValue: encryptedXfp, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "rootTpub", newValue: encryptedRootTpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "rootXpub", newValue: encryptedRootXpub, entity: .signers) { _ in }
                    
                    print("updated signer")
                }
            }
        }
    }
    
    private func reload() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            signerTable.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return signers.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "signerCell", for: indexPath)
        cell.selectionStyle = .none
        let label = cell.viewWithTag(1) as! UILabel
       
        if signers.count > 0 {
            let s = SignerStruct(dictionary: signers[indexPath.row])
            if s.label == "Signer" {
                label.text = "Signer #\(indexPath.row + 1)"
            } else {
                label.text = s.label
            }
        }
        return cell
    }
    
    func seeDetails(_ index: Int) {
        id = SignerStruct(dictionary: signers[index]).id
        segueToDetail()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if !isCreatingMsig {
            seeDetails(indexPath.row)
            
        } else {
            promptToDeriveFromSigner(SignerStruct(dictionary: signers[indexPath.row]))
            
        }
    }
    
    private func promptToDeriveFromSigner(_ signer: SignerStruct) {
        
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            
            guard var encryptedWords = signer.words,
                    var words = Crypto.decrypt(encryptedWords),
                    var arr = words.utf8String?.split(separator: " ") else { return }
            
            defer {
                encryptedWords.secureZero()
                words.secureZero()
                arr.removeAll()
            }
            
            for (i, _) in arr.enumerated() {
                if i > 0 && i < arr.count - 1 {
                    arr[i] = "******"
                }
            }
            
            let alert = UIAlertController(title: "Derive xpub from this signer?", message: arr.joined(separator: " "), preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Derive xpub", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.signerSelected!(signer)
                    self.navigationController?.popViewController(animated: true)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func segueToDetail() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToSignerDetail", sender: vc)
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToSignerDetail" {
            if let vc = segue.destination as? SignerDetailViewController {
                vc.id = id
            }
        }
    }

}
