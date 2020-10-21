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
    @IBOutlet weak var labelField: UITextField!
    @IBOutlet weak var wordsField: UITextView!
    @IBOutlet weak var passphraseLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var passphraseHeader: UILabel!
    @IBOutlet weak var wordsHeader: UILabel!
    @IBOutlet weak var fingerprintField: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        addTapGesture()
        navigationController?.delegate = self
        labelField.clipsToBounds = true
        labelField.layer.cornerRadius = 8
        labelField.layer.borderWidth = 0.5
        labelField.layer.borderColor = UIColor.lightGray.cgColor
        labelField.returnKeyType = .done
        wordsField.clipsToBounds = true
        wordsField.layer.cornerRadius = 8
        wordsField.layer.borderWidth = 0.5
        wordsField.layer.borderColor = UIColor.lightGray.cgColor
        passphraseLabel.clipsToBounds = true
        passphraseLabel.layer.cornerRadius = 8
        passphraseLabel.layer.borderWidth = 0.5
        passphraseLabel.layer.borderColor = UIColor.lightGray.cgColor
        dateLabel.clipsToBounds = true
        dateLabel.layer.cornerRadius = 8
        dateLabel.layer.borderWidth = 0.5
        dateLabel.layer.borderColor = UIColor.lightGray.cgColor
        fingerprintField.clipsToBounds = true
        fingerprintField.layer.cornerRadius = 8
        fingerprintField.layer.borderWidth = 0.5
        fingerprintField.layer.borderColor = UIColor.lightGray.cgColor
        labelField.delegate = self
        getData()
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
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            view.endEditing(true)
        }
        sender.cancelsTouchesInView = false
    }
    
    private func getData() {
        CoreDataService.retrieveEntity(entityName: .signers) { [unowned vc = self] (signers) in
            if signers != nil {
                if signers!.count > 0 {
                    if vc.id != nil {
                        for signer in signers! {
                            let signerStruct = SignerStruct(dictionary: signer)
                            if signerStruct.id == vc.id {
                                vc.setFields(signerStruct)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func setFields(_ signer: SignerStruct) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.labelField.text = signer.label
            self.dateLabel.text = "  " +  self.formattedDate(signer.added)
            
            guard var decrypted = Crypto.decrypt(signer.words),
                var words = String(bytes: decrypted, encoding: .utf8) else {
                    return
            }
            
            var arr = words.split(separator: " ")
            
            for (i, _) in arr.enumerated() {
                if i > 0 && i < arr.count - 1 {
                    arr[i] = "******"
                }
            }
            
            self.wordsField.text = arr.joined(separator: " ")
            
            decrypted = Data()
            words = ""
            
            if signer.passphrase != nil {
                guard let decrypted = Crypto.decrypt(signer.passphrase!),
                    let passphrase = String(bytes: decrypted, encoding: .utf8) else {
                        return
                }
                
                self.passphraseLabel.text = "  " + passphrase
            } else {
                self.passphraseLabel.text = "  ** no passphrase **"
            }
            
            self.setFingerprint(signer.words)
        }
    }
    
    private func setFingerprint(_ encryptedWords: Data) {
        guard var decryptedWords = Crypto.decrypt(encryptedWords),
            var words = String(bytes: decryptedWords, encoding: .utf8),
            var mk = Keys.masterKey(words: words, coinType: "0", passphrase: ""),
            let fingerprint = Keys.fingerprint(masterKey: mk) else {
                return
        }
        
        decryptedWords = Data()
        words = ""
        mk = ""
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.fingerprintField.text = "  " + fingerprint
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
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
