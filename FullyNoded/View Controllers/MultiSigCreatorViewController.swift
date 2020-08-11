//
//  MultiSigCreatorViewController.swift
//  BitSense
//
//  Created by Peter on 19/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class MultiSigCreatorViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UITextFieldDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var createOutlet: UIButton!
    @IBOutlet weak var derivLabel: UILabel!
    @IBOutlet weak var editButtonOutlet: UIButton!
    @IBOutlet weak var table: UITableView!
    var signers:[[String:Any]] = []
    var spinner = ConnectingView()
    var cointType = "0"
    var blockheight = 0
    var m = Int()
    var n = Int()
    var keysString = ""
    var isDone = Bool()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        table.delegate = self
        table.dataSource = self
        addTapGesture()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        spinner.addConnectingView(vc: self, description: "fetching chain type...")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { [unowned vc = self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let blocks = dict["blocks"] as? Int {
                    vc.blockheight = blocks
                }
                if let chain = dict["chain"] as? String {
                    if chain != "main" {
                        vc.cointType = "1"
                    }
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.derivLabel.text = "m/48'/\(vc.cointType)'/0'/2' - segwit (bc1)"
                    }
                    vc.loadData()
                    vc.spinner.removeConnectingView()
                } else {
                    vc.spinner.removeConnectingView()
                    showAlert(vc: vc, title: "Error", message: "error fetching chain type: \(errorMessage ?? "")")
                }
            } else {
                vc.spinner.removeConnectingView()
                showAlert(vc: vc, title: "Error", message: "error fetching chain type: \(errorMessage ?? "")")
            }
        }
    }
    
    private func export() {
        let text = """
        Name: Fully Noded
        Policy: \(m) of \(n)
        Derivation: m/48'/\(cointType)'/0'/2'
        Format: P2WSH
        
        \(keysString)
        """
        if let url = exportMultisigWalletToURL(data: text.dataUsingUTF8StringEncoding) {
            DispatchQueue.main.async { [unowned vc = self] in
                let activityViewController = UIActivityViewController(activityItems: ["Multisig Export", url], applicationActivities: nil)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    activityViewController.popoverPresentationController?.sourceView = self.view
                    activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
                }
                vc.present(activityViewController, animated: true) {}
            }
        }
    }
    
    @IBAction func help(_ sender: Any) {
        showAlert(vc: self, title: "MultiSig Creator", message: "Here you can add as many signers you like, by default we create a bip39 12 word seed for you (without a passphrase) and derive its account xpub/Zpub and fingerprint. All fields are editable, ensure you add valid words only. If you add valid words the app will derive the new fingerprint/xpub/Zpub for you. You may also delete the words and add a custom xpub or Zpub. If you do not want the device to be able to sign for certain seed words simply delete them and they will never get saved.")
    }
    
    @IBAction func createAction(_ sender: Any) {
        if !isDone {
            promptToCreate()
        } else {
            walletSuccessfullyCreated(m: m)
        }
    }
    
    private func promptToCreate() {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "How many signers are required to spend funds?", message: "", preferredStyle: alertStyle)
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
        spinner.addConnectingView(vc: self, description: "creating multisig wallet...")
        var keys = ""
        for (i, signer) in signers.enumerated() {
            let fingerprint = signer["fingerprint"] as? String ?? ""
            let xpub = signer["xpub"] as? String ?? ""
            let words = signer["signer"] as? String ?? ""
            if fingerprint != "" {
                if xpub != "" {
                    keys += "[\(fingerprint)/48'/\(cointType)'/0'/2']\(xpub)/0/*"
                    keysString += "\(fingerprint):\(xpub)\n"
                    if i < signers.count - 1 {
                        keys += ","
                    }
                    if words != "" {
                        if let _ = Keys.masterKey(words: words, coinType: cointType, passphrase: "") {
                            Crypto.encryptData(dataToEncrypt: words.dataUsingUTF8StringEncoding) { (encryptedWords) in
                                if encryptedWords != nil {
                                    let dict = ["id":UUID(), "words":encryptedWords!] as [String:Any]
                                    CoreDataService.saveEntity(dict: dict, entityName: .signers) { [unowned vc = self] success in
                                        if success {
                                            if i + 1 == vc.signers.count {
                                                vc.m = m
                                                vc.n = vc.signers.count
                                                let rawPrimDesc = "wsh(sortedmulti(\(m),\(keys)))"
                                                let accountMap = ["descriptor":rawPrimDesc,"label":"MultiSig - \(m) of \(vc.signers.count)", "blockheight": vc.blockheight] as [String:Any]
                                                ImportWallet.accountMap(accountMap) { (success, errorDescription) in
                                                    if success {
                                                        vc.walletSuccessfullyCreated(m: m)
                                                    } else {
                                                        vc.spinner.removeConnectingView()
                                                        showAlert(vc: self, title: "There was an error!", message: "Something went wrong during the wallet creation process: \(errorDescription ?? "unknown error")")
                                                    }
                                                }
                                            }
                                        } else {
                                            vc.spinner.removeConnectingView()
                                            showAlert(vc: vc, title: "Error saving signer", message: "There was an error encrypting and saving your signer.")
                                        }
                                    }
                                }
                            }
                        } else {
                            self.spinner.removeConnectingView()
                            showAlert(vc: self, title: "Invalid BIP39 words", message: "")
                        }
                    } else {
                        if i + 1 == signers.count {
                            let rawPrimDesc = "wsh(sortedmulti(\(m),\(keys)))"
                            let accountMap = ["descriptor":rawPrimDesc,"label":"MultiSig - \(m) of \(signers.count)", "blockheight": blockheight] as [String:Any]
                            ImportWallet.accountMap(accountMap) { [unowned vc = self] (success, errorDescription) in
                                if success {
                                    vc.walletSuccessfullyCreated(m: m)
                                } else {
                                    vc.spinner.removeConnectingView()
                                    showAlert(vc: vc, title: "There was an error!", message: "Something went wrong during the wallet creation process: \(errorDescription ?? "unknown error")")
                                }
                            }
                        }
                    }
                } else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "xpub missing!", message: "We can not create a multisig wallet wiouth a set of bip39 words and xpub, we need one or the other.")
                }
            } else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Fingerprint missing!", message: "Please add the correct fingerprint for the master key so offline signers will be able to sign.")
            }
        }
    }
    
    private func walletSuccessfullyCreated(m: Int) {
        isDone = true
        DispatchQueue.main.async { [unowned vc = self] in
            vc.spinner.removeConnectingView()
            vc.createOutlet.setTitle("Done", for: .normal)
            NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "\(m) of \(vc.signers.count) successfully created ✓", message: "Your active wallet tab is refreshing, tap done to go back, tap export to get a text file which holds all necessary info to export your multisig wallet to other apps, this txt file can be directly imported to a Coldcard via the SD card to import it.", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Export", style: .default, handler: { [unowned vc = self] action in
                vc.export()
            }))
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { action in
                DispatchQueue.main.async {
                    if vc.navigationController != nil {
                        vc.navigationController?.popToRootViewController(animated: true)
                    } else {
                        vc.dismiss(animated: true, completion: nil)
                    }
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
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
            if let mk = Keys.masterKey(words: words, coinType: cointType, passphrase: "") {
                if let fingerprint = Keys.fingerprint(masterKey: mk) {
                    if let xpub = Keys.xpub(path: "m/48'/\(cointType)'/0'/2'", masterKey: mk) {
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
        if signers.count > 0 {
            return 245
        } else {
            return 44
        }
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
            fingerprint.restorationIdentifier = "\(indexPath.section)"
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
        if signers.count > 0 {
            textLabel.text = "#\(section + 1)"
            let clearButton = UIButton()
            clearButton.tintColor = .white
            clearButton.tag = section
            clearButton.setTitle("clear", for: .normal)
            clearButton.addTarget(self, action: #selector(clearSection(_:)), for: .touchUpInside)
            let clearButtonX = header.frame.maxX - 100
            clearButton.frame = CGRect(x: clearButtonX, y: 0, width: 80, height: 18)
            clearButton.center.y = textLabel.center.y
            
            header.addSubview(textLabel)
            header.addSubview(clearButton)
        }
        return header
    }
    
    @objc func clearSection(_ sender: UIButton) {
        let section = sender.tag
        signers[section]["fingerprint"] = ""
        signers[section]["xpub"] = ""
        signers[section]["zpub"] = ""
        signers[section]["signer"] = ""
        reloadIndex(index: section)
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
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
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        print("shouldChangeCharactersIn: \(string)")
        if textField.restorationIdentifier != nil {
            if let index = Int(textField.restorationIdentifier!) {
                signers[index]["fingerprint"] = textField.text ?? ""
            }
        }
        return true
    }
    
    private func updateWords(words: String, index: Int) {
        if words != "" {
            if let mk = Keys.masterKey(words: words, coinType: cointType, passphrase: "") {
                if let fingerprint = Keys.fingerprint(masterKey: mk) {
                    if let xpub = Keys.xpub(path: "m/48'/\(cointType)'/0'/2'", masterKey: mk) {
                        if let zpub = XpubConverter.zpub(xpub: xpub) {
                            signers[index]["signer"] = words
                            signers[index]["fingerprint"] = fingerprint
                            signers[index]["xpub"] = xpub
                            signers[index]["zpub"] = zpub
                            reloadIndex(index: index)
                            showAlert(vc: self, title: "Signer updated", message: "The fingerprint, xpub and Zpub have all been updated to be derived from the new bip39 words.")
                        } else {
                            signers[index]["signer"] = ""
                            signers[index]["fingerprint"] = ""
                            signers[index]["xpub"] = ""
                            signers[index]["zpub"] = ""
                            reloadIndex(index: index)
                            showAlert(vc: self, title: "Error", message: "Error deriving Zpub")
                        }
                    } else {
                        signers[index]["signer"] = ""
                        signers[index]["fingerprint"] = ""
                        signers[index]["xpub"] = ""
                        signers[index]["zpub"] = ""
                        reloadIndex(index: index)
                        showAlert(vc: self, title: "Error", message: "Error deriving xpub")
                    }
                } else {
                    signers[index]["signer"] = ""
                    signers[index]["fingerprint"] = ""
                    signers[index]["xpub"] = ""
                    signers[index]["zpub"] = ""
                    reloadIndex(index: index)
                    showAlert(vc: self, title: "Error", message: "Error deriving fingerprint")
                }
            } else {
                signers[index]["signer"] = ""
                signers[index]["fingerprint"] = ""
                signers[index]["xpub"] = ""
                signers[index]["zpub"] = ""
                reloadIndex(index: index)
                showAlert(vc: self, title: "Error", message: "Invalid bip39 seed words")
            }
        } else {
            signers[index]["signer"] = ""
        }
    }
    
    private func updateXpub(xpub: String, index: Int) {
        if xpub != "" {
            if let zpub = XpubConverter.zpub(xpub: xpub) {
                signers[index]["signer"] = ""
                signers[index]["xpub"] = xpub
                signers[index]["zpub"] = zpub
                reloadIndex(index: index)
                showAlert(vc: self, title: "Signer updated", message: "You added a custom xpub, ensure the fingerprint is correct as this is important for offline signers to function properly.")
            }
        }
    }
    
    private func updateZpub(zpub: String, index: Int) {
        if zpub != "" {
            if let xpub = XpubConverter.convert(extendedKey: zpub) {
                signers[index]["signer"] = ""
                signers[index]["xpub"] = xpub
                signers[index]["zpub"] = zpub
                reloadIndex(index: index)
                showAlert(vc: self, title: "Signer updated", message: "You added a custom Zpub, ensure the fingerprint is correct as this is important for offline signers to function properly.")
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
