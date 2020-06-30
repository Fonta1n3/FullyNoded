//
//  WalletDetailViewController.swift
//  BitSense
//
//  Created by Peter on 29/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class WalletDetailViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate {
    
    @IBOutlet weak var detailTable: UITableView!
    var walletId:UUID!
    var wallet:Wallet!
    var signer = ""
    var spinner = ConnectingView()
    var coinType = "0"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addTapGesture()
        setCoinType()
    }
    
    private func setCoinType() {
        spinner.addConnectingView(vc: self, description: "fetching chain type...")
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { [unowned vc = self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let chain = dict["chain"] as? String {
                    if chain == "test" {
                        vc.coinType = "1"
                    }
                    vc.load()
                    vc.spinner.removeConnectingView()
                }
            } else {
                vc.showError(error: "Error getting blockchain info, please chack your connection to your node.")
                DispatchQueue.main.async {
                    vc.navigationController?.popToRootViewController(animated: true)
                }
            }
        }
    }
    
    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        self.detailTable.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            view.endEditing(true)
        }
        sender.cancelsTouchesInView = false
    }
    
    @IBAction func deleteWallet(_ sender: Any) {
        promptToDeleteWallet()
    }
    
    
    private func load() {
        CoreDataService.retrieveEntity(entityName: .wallets) { [unowned vc = self] wallets in
            if wallets != nil {
                if wallets!.count > 0 {
                    for w in wallets! {
                        let walletStruct = Wallet(dictionary: w)
                        if walletStruct.id == vc.walletId {
                            vc.wallet = walletStruct
                            vc.findSigner()
                        }
                    }
                }
            }
        }
    }
    
    private func findSigner() {
        CoreDataService.retrieveEntity(entityName: .signers) { signers in
            if signers != nil {
                if signers!.count > 0 {
                    for signer in signers! {
                        Crypto.decryptData(dataToDecrypt: (signer["words"] as! Data)) { [unowned vc = self] decryptedData in
                            if decryptedData != nil {
                                if let words = String(bytes: decryptedData!, encoding: .utf8) {
                                    if let mk = CreateFullyNodedWallet.masterKey(words: words, coinType: vc.coinType) {
                                        if let xpub = CreateFullyNodedWallet.bip84AccountXpub(masterKey: mk, coinType: vc.coinType) {
                                            if xpub == vc.accountXpub() {
                                                DispatchQueue.main.async { [unowned vc = self] in
                                                    vc.signer = words
                                                    vc.detailTable.reloadData()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func accountXpub() -> String {
        let desc = wallet.receiveDescriptor
        let arr = desc.split(separator: "]")
        let xpubWithPath = "\(arr[1])"
        let arr2 = xpubWithPath.split(separator: "/")
        return "\(arr2[0])"
    }
    
    private func promptToDeleteWallet() {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Remove this wallet?", message: "Removing the wallet hides it from your \"Fully Noded Wallets\". The wallet will still exist on your node and be accessed via the \"Wallet Manager\" or via bitcoin-cli and bitcoin-qt. In order to completely delete the wallet you need to find the \"Filename\" as listed above on your nodes machine in the .bitcoin directory and manually delete it there.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { [unowned vc = self] action in
                vc.deleteNow()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func deleteNow() {
        CoreDataService.deleteEntity(id: walletId, entityName: .wallets) { [unowned vc = self] success in
            if success {
                DispatchQueue.main.async { [unowned vc = self] in
                    if vc.wallet.name == UserDefaults.standard.object(forKey: "walletName") as! String {
                        UserDefaults.standard.removeObject(forKey: "walletName")
                        NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    }
                    vc.walletDeleted()
                }
            } else {
                showAlert(vc: vc, title: "Error", message: "We had an error deleting your wallet.")
            }
        }
    }
    
    private func walletDeleted() {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Fully Noded wallet removed", message: "It will no longer appear in your list of \"Fully Noded Wallets\".", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.navigationController?.popToRootViewController(animated: true)
                }
            }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToEditLabel(newLabel: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Update wallet label?", message: "Selecting yes will update this wallets label.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
                vc.updateLabel(newLabel: newLabel)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func updateLabel(newLabel: String) {
        CoreDataService.update(id: walletId, keyToUpdate: "label", newValue: newLabel, entity: .wallets) { [unowned vc = self] success in
            if success {
                vc.load()
                if UserDefaults.standard.object(forKey: "walletName") as? String == vc.wallet.name {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    }
                }
                showAlert(vc: vc, title: "Success", message: "Wallet label updated ✓")
            } else {
                showAlert(vc: vc, title: "Error", message: "There was an error saving your new wallet label.")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 1417
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "walletDetailCell", for: indexPath)
        cell.selectionStyle = .none
        let labelField = cell.viewWithTag(1) as! UITextField
        let fileNameLabel = cell.viewWithTag(2) as! UILabel
        let receiveDescTextView = cell.viewWithTag(3) as! UITextView
        let changeDescTextView = cell.viewWithTag(4) as! UITextView
        let currentIndexField = cell.viewWithTag(5) as! UITextField
        let maxIndexField = cell.viewWithTag(6) as! UITextField
        let signerTextField = cell.viewWithTag(7) as! UITextView
        let watchingTextView = cell.viewWithTag(8) as! UITextView
        labelField.delegate = self
        maxIndexField.delegate = self
        receiveDescTextView.layer.cornerRadius = 8
        receiveDescTextView.layer.borderWidth = 0.5
        receiveDescTextView.layer.borderColor = UIColor.darkGray.cgColor
        changeDescTextView.layer.cornerRadius = 8
        changeDescTextView.layer.borderWidth = 0.5
        changeDescTextView.layer.borderColor = UIColor.darkGray.cgColor
        fileNameLabel.layer.cornerRadius = 8
        fileNameLabel.layer.borderWidth = 0.5
        fileNameLabel.layer.borderColor = UIColor.darkGray.cgColor
        signerTextField.layer.cornerRadius = 8
        signerTextField.layer.borderWidth = 0.5
        signerTextField.layer.borderColor = UIColor.darkGray.cgColor
        watchingTextView.layer.cornerRadius = 8
        watchingTextView.layer.borderWidth = 0.5
        watchingTextView.layer.borderColor = UIColor.darkGray.cgColor
                
        maxIndexField.addTarget(self, action: #selector(indexDidChange(_:)), for: .editingDidEnd)
        labelField.addTarget(self, action: #selector(labelDidChange(_:)), for: .editingDidEnd)
        
        if wallet != nil {
            labelField.text = wallet.label
            fileNameLabel.text = "  " + wallet.name + ".dat"
            receiveDescTextView.text = wallet.receiveDescriptor
            changeDescTextView.text = wallet.changeDescriptor
            maxIndexField.text = "\(wallet.maxIndex)"
            currentIndexField.text = "\(wallet.index)"
            signerTextField.text = signer
            if wallet.watching != nil {
                var watching = ""
                for watch in wallet.watching! {
                    watching += watch + "\n\n"
                }
                watchingTextView.text = watching
            }
        }
        return cell
    }
    
    @objc func indexDidChange(_ sender: UITextField) {
        if sender.text != "" {
            if let updatedIndex = Int(sender.text!) {
                if updatedIndex > wallet.maxIndex {
                    promptToUpdateMaxIndex(max: updatedIndex)
                }
            }
        }
    }
    
    @objc func labelDidChange(_ sender: UITextField) {
        promptToEditLabel(newLabel: sender.text!)
    }
    
    private func promptToUpdateMaxIndex(max: Int) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Import index \(vc.wallet.maxIndex + 1) to \(max) public keys?", message: "Selecting yes will trigger a series of calls to your node to import \(max - (Int(vc.wallet.maxIndex) + 1)) additional keys for each descriptor your wallet holds. This can take a bit of time so please be patient and wait for the spinner to dismiss.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
                vc.importUpdatedIndex(maxRange: max)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func updateSpinnerText(text: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.spinner.label.text = text
        }
    }
    
    private func importUpdatedIndex(maxRange: Int) {
        spinner.addConnectingView(vc: self, description: "importing \(maxRange - Int(wallet.maxIndex) + 1) public keys...")
        var descriptorsToImport = [String]()
        descriptorsToImport.append(wallet.receiveDescriptor)
        descriptorsToImport.append(wallet.changeDescriptor)
        if wallet.watching != nil {
            if wallet.watching!.count > 0 {
                for watcher in wallet.watching! {
                    descriptorsToImport.append(watcher)
                }
            }
        }
        importDescriptors(index: 0, maxRange: maxRange, descriptorsToImport: descriptorsToImport)
    }
    
    private func importDescriptors(index: Int, maxRange: Int, descriptorsToImport: [String]) {
        if index < descriptorsToImport.count {
            updateSpinnerText(text: "importing descriptor #\(index + 1), \(maxRange - Int(wallet.maxIndex) + 1) public keys...")
            let descriptor = descriptorsToImport[index]
            var params = "[{ \"desc\": \"\(descriptor)\", \"timestamp\": \"now\", \"range\": [\(wallet.maxIndex),\(maxRange)], \"watchonly\": true, \"label\": \"Fully Noded Recovery\", \"keypool\": false, \"internal\": false }], {\"rescan\": false}"
            if descriptor.contains(wallet.receiveDescriptor) {
                if descriptor.contains("/0/*") {
                    params = "[{ \"desc\": \"\(descriptor)\", \"timestamp\": \"now\", \"range\": [\(wallet.maxIndex),\(maxRange)], \"watchonly\": true, \"label\": \"Fully Noded Recovery\", \"keypool\": true, \"internal\": false }], {\"rescan\": false}"
                } else if descriptor.contains(wallet.changeDescriptor) {
                    params = "[{ \"desc\": \"\(descriptor)\", \"timestamp\": \"now\", \"range\": [\(wallet.maxIndex),\(maxRange)], \"watchonly\": true, \"keypool\": true, \"internal\": true }], {\"rescan\": false}"
                }
            }
            importMulti(params: params) { [unowned vc = self] success in
                if success {
                    vc.importDescriptors(index: index + 1, maxRange: maxRange, descriptorsToImport: descriptorsToImport)
                } else {
                    vc.showError(error: "Error importing a recovery descriptor.")
                }
            }
        } else {
            updateSpinnerText(text: "starting a rescan...")
            Reducer.makeCommand(command: .getblockchaininfo, param: "") { [unowned vc = self] (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    if let pruned = dict["pruned"] as? Bool {
                        if pruned {
                            if let pruneHeight = dict["pruneheight"] as? Int {
                                Reducer.makeCommand(command: .rescanblockchain, param: "\(pruneHeight)") { [unowned vc = self] (response, errorMessage) in
                                    vc.updateMaxIndex(max: maxRange)
                                }
                            }
                        } else {
                            Reducer.makeCommand(command: .rescanblockchain, param: "") { [unowned vc = self] (response, errorMessage) in
                                vc.updateMaxIndex(max: maxRange)
                            }
                        }
                    }
                } else {
                    vc.showError(error: "Error starting a rescan, your wallet has not been saved. Please check your connection to your node and try again.")
                }
            }
        }
    }
    
    private func importMulti(params: String, completion: @escaping ((Bool)) -> Void) {
        Reducer.makeCommand(command: .importmulti, param: params) { (response, errorDescription) in
            if let result = response as? NSArray {
                if result.count > 0 {
                    if let dict = result[0] as? NSDictionary {
                        if let success = dict["success"] as? Bool {
                            completion((success))
                        } else {
                            completion((false))
                        }
                    }
                } else {
                    completion((false))
                }
            } else {
                completion((false))
            }
        }
    }
    
    private func updateMaxIndex(max: Int) {
        CoreDataService.update(id: walletId, keyToUpdate: "maxIndex", newValue: Int16(max), entity: .wallets) { [unowned vc = self] success in
            if success {
                vc.spinner.removeConnectingView()
                showAlert(vc: vc, title: "Success, you have imported up to \(max) public keys.", message: "Your wallet is now rescanning, you can check the progress at Tools > Get Wallet Info, if you want to abort the rescan you can do that from Tools as well. In order to see balances for all your addresses you'll need to wait for the rescan to complete.")
            } else {
                vc.showError(error: "There was an error updating the wallets maximum index.")
            }
        }
    }
    
    private func showError(error:String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.spinner.removeConnectingView()
            showAlert(vc: vc, title: "Error", message: error)
        }
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
