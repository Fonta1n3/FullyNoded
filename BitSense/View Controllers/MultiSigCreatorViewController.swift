//
//  MultiSigCreatorViewController.swift
//  BitSense
//
//  Created by Peter on 19/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class MultiSigCreatorViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UITextFieldDelegate {

    @IBOutlet weak var editButtonOutlet: UIButton!
    @IBOutlet weak var table: UITableView!
    var signers:[[String:Any]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        table.delegate = self
        table.dataSource = self
        addTapGesture()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadData()
    }
    
    @IBAction func createAction(_ sender: Any) {
        promptToCreate()
    }
    
    private func promptToCreate() {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "How many signers are required to spend funds?", message: "", preferredStyle: .actionSheet)
            for (i, _) in vc.signers.enumerated() {
                alert.addAction(UIAlertAction(title: "\(i + 1)", style: .default, handler: { action in
                    vc.create(m: i + 1)
                }))
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func create(m: Int) {
        var keys = ""
        for (i, signer) in signers.enumerated() {
            if let words = signer["signer"] as? String {
                if let _ = Keys.masterKey(words: words, coinType: "0", passphrase: "") {
                    Crypto.encryptData(dataToEncrypt: words.dataUsingUTF8StringEncoding) { [unowned vc = self] (encryptedWords) in
                        if encryptedWords != nil {
                            if vc.saveSigner(encryptedSigner: encryptedWords!) {
                                if let fingerprint = signer["fingerprint"] as? String {
                                    if let xpub = signer["xpub"] as? String {
                                        keys += "[\(fingerprint)/48'/0'/0'/2']\(xpub)/0/*"
                                        if i < vc.signers.count - 1 {
                                            keys += ","
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                if let fingerprint = signer["fingerprint"] as? String {
                    if let xpub = signer["xpub"] as? String {
                        keys += "[\(fingerprint)/48'/0'/0'/2']\(xpub)/0/*"
                        if i < signers.count - 1 {
                            keys += ","
                        }
                    }
                }
            }
            if i + 1 == signers.count {
                let rawPrimDesc = "wsh(sortedmulti(\(m),\(keys)))"
                let rawChangeDesc = rawPrimDesc.replacingOccurrences(of: "/0/*", with: "/1/*")
                
            }
        }
    }
    
    private func saveSigner(encryptedSigner: Data) -> Bool {
        var boolToReturn:Bool!
        let dict = ["id":UUID(), "words":encryptedSigner] as [String:Any]
        CoreDataService.saveEntity(dict: dict, entityName: .signers) { success in
            boolToReturn = success
        }
        return boolToReturn
    }
    
    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        self.table.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            view.endEditing(true)
        }
        sender.cancelsTouchesInView = false
    }
    
    private func loadData() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.table.reloadData()
        }
    }
    
    @IBAction func editAction(_ sender: Any) {
        table.setEditing(!table.isEditing, animated: true)
        if table.isEditing {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.editButtonOutlet.setTitle("Done", for: .normal)
            }
        } else {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.editButtonOutlet.setTitle("Edit", for: .normal)
            }
        }
    }
        
    @IBAction func addSignerAction(_ sender: Any) {
        if let words = Keys.seed() {
            if let mk = Keys.masterKey(words: words, coinType: "0", passphrase: "") {
                if let fingerprint = Keys.fingerprint(masterKey: mk) {
                    if let xpub = Keys.xpub(path: "m/48'/0'/0'/1'", masterKey: mk) {
                        if let zpub = XpubConverter.zpub(xpub: xpub) {
                            let dict = ["signer":words,"fingerprint":fingerprint,"xpub":xpub,"zpub":zpub]
                            signers.append(dict)
                            loadData()
                        }
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            signers.remove(at: indexPath.section)
            loadData()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 245
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if signers.count == 0 {
            return 1
        } else {
            return signers.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if signers.count > 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "signerCell", for: indexPath)
            cell.selectionStyle = .none
            let fingerprint = cell.viewWithTag(1) as! UITextField
            fingerprint.delegate = self
            let signer = cell.viewWithTag(2) as! UITextView
            signer.layer.borderWidth = 0.5
            signer.layer.borderColor = UIColor.darkGray.cgColor
            signer.layer.cornerRadius = 5
            signer.delegate = self
            signer.restorationIdentifier = "\(indexPath.section)"
            let xpub = cell.viewWithTag(3) as! UITextView
            xpub.layer.borderWidth = 0.5
            xpub.layer.borderColor = UIColor.darkGray.cgColor
            xpub.layer.cornerRadius = 5
            xpub.delegate = self
            xpub.restorationIdentifier = "\(indexPath.section)"
            let zpub = cell.viewWithTag(4) as! UITextView
            zpub.layer.borderWidth = 0.5
            zpub.layer.borderColor = UIColor.darkGray.cgColor
            zpub.layer.cornerRadius = 5
            zpub.delegate = self
            zpub.restorationIdentifier = "\(indexPath.section)"
            let dict = signers[indexPath.section]
            fingerprint.text = dict["fingerprint"] as? String ?? ""
            signer.text = dict["signer"] as? String ?? ""
            xpub.text = dict["xpub"] as? String ?? ""
            zpub.text = dict["zpub"] as? String ?? ""
            cell.layer.borderColor = UIColor.lightGray.cgColor
            cell.layer.borderWidth = 0.5
            cell.clipsToBounds = true
            cell.layer.cornerRadius = 8
            return cell
        } else {
            let emptyCell = UITableViewCell()
            emptyCell.selectionStyle = .none
            emptyCell.backgroundColor = .clear
            emptyCell.textLabel?.text = "Tap the + button to add a signer"
            emptyCell.textLabel?.textColor = .white
            return emptyCell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
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
        textLabel.text = "#\(section + 1)"
        header.addSubview(textLabel)
        return header
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        print("did end editing")
        if textView.restorationIdentifier != nil {
            if let index = Int(textView.restorationIdentifier!) {
                let tag = textView.tag
                switch tag {
                case 2:
                    updateWords(words: textView.text ?? "", index: index)
                case 3:
                    updateXpub(xpub: textView.text ?? "", index: index)
                case 4:
                    updateZpub(zpub: textView.text ?? "", index: index)
                default:
                    break
                }
            }
        }
    }
    
    private func updateWords(words: String, index: Int) {
        if words != "" {
            if let mk = Keys.masterKey(words: words, coinType: "0", passphrase: "") {
                if let fingerprint = Keys.fingerprint(masterKey: mk) {
                    if let xpub = Keys.xpub(path: "m/48'/0'/0'/1'", masterKey: mk) {
                        if let zpub = XpubConverter.zpub(xpub: xpub) {
                            signers[index]["signer"] = words
                            signers[index]["fingerprint"] = fingerprint
                            signers[index]["xpub"] = xpub
                            signers[index]["zpub"] = zpub
                            reloadIndex(index: index)
                        }
                    }
                }
            }
        } else {
            signers[index]["signer"] = ""
        }
    }
    
    private func updateXpub(xpub: String, index: Int) {
        if xpub != "" {
            if let zpub = XpubConverter.zpub(xpub: xpub) {
                signers[index]["xpub"] = xpub
                signers[index]["zpub"] = zpub
                reloadIndex(index: index)
            }
        }
    }
    
    private func updateZpub(zpub: String, index: Int) {
        if zpub != "" {
            if let xpub = XpubConverter.convert(extendedKey: zpub) {
                signers[index]["xpub"] = xpub
                signers[index]["zpub"] = zpub
                reloadIndex(index: index)
            }
        }
    }
    
    private func reloadIndex(index: Int) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.table.reloadSections(IndexSet(arrayLiteral: index), with: .none)
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.restorationIdentifier != nil {
            if let index = Int(textField.restorationIdentifier!) {
                signers[index]["fingerprint"] = textField.text ?? ""
                reloadIndex(index: index)
            }
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.restorationIdentifier != nil {
            if let section = Int(textView.restorationIdentifier!) {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.table.scrollToRow(at: IndexPath(row: 0, section: section), at: .bottom, animated: true)
                }
            }
        }
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            table.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        table.contentInset = .zero
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
