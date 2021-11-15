//
//  WalletRecoveryViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 3/7/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import UIKit

class WalletRecoveryViewController: UIViewController, UIDocumentPickerDelegate {
    
    let spinner = ConnectingView()
    var index = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    @IBAction func uploadFileAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if #available(iOS 14.0, *) {
                let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
                documentPicker.delegate = self
                documentPicker.modalPresentationStyle = .formSheet
                self.present(documentPicker, animated: true, completion: nil)
            } else {
                // Fallback on earlier versions
                let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
                documentPicker.delegate = self
                documentPicker.modalPresentationStyle = .formSheet
                self.present(documentPicker, animated: true, completion: nil)
            }
            
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let data = try? Data(contentsOf: urls[0].absoluteURL),
              let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
            showAlert(vc: self, title: "", message: "That does not appear to be a recognized wallet backup file. This is only compatible with Fully Noded wallet backup files.")
            return
        }
        
        if let wallets = dict["wallets"] as? [[String:Any]], let transactions = dict["transactions"] as? [[String:Any]] {
            var mainnetWallets = [[String:Any]]()
            var testnetWallets = [[String:Any]]()
            
            for (i, wallet) in wallets.enumerated() {
                for (_, value) in wallet {
                    guard let string = value as? String else { return }
                    
                    let data = string.dataUsingUTF8StringEncoding
                    
                    guard let walletDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
                        showAlert(vc: self, title: "", message: "That does not appear to be a recognized wallet backup file. This is only compatible with Fully Noded wallet backup files.")
                        
                        return
                    }
                    
                    guard let desc = walletDict["descriptor"] as? String else { return }
                    
                    let descStr = Descriptor(desc)
                    if descStr.chain == "Mainnet" {
                        mainnetWallets.append(walletDict)
                    } else if descStr.chain == "Testnet" {
                        testnetWallets.append(walletDict)
                    }
                }
                
                if i + 1 == wallets.count {
                    if let utxos = dict["utxos"] as? String {
                        let utxosData = utxos.dataUsingUTF8StringEncoding
                        
                        guard let utxoArray = try? JSONSerialization.jsonObject(with: utxosData, options: []) as? [[String:Any]] else {
                            alertToRecoverWalletsTransactions(mainnetWallets, testnetWallets, transactions, [[:]])
                            
                            return
                        }
                        
                        alertToRecoverWalletsTransactions(mainnetWallets, testnetWallets, transactions, utxoArray)
                    } else {
                        alertToRecoverWalletsTransactions(mainnetWallets, testnetWallets, transactions, nil)
                    }
                }
            }
        }
    }
    
    private func alertToRecoverWalletsTransactions(_ mainnetWallets: [[String:Any]], _ testnetWallets: [[String:Any]], _ transactions: [[String:Any]], _ utxos: [[String:Any]]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let chain = UserDefaults.standard.object(forKey: "chain") as? String else {
                showAlert(vc: self, title: "", message: "Could not determine which chain the node is using. Please reload the home screen and try again.")
                return
            }
            
            var wallets = mainnetWallets
            
            if chain == "test" {
                wallets = testnetWallets
            }
            
            let mess = "This will recover \(wallets.count) wallets, \(transactions.count) transactions (labels, memos, and capital gains info)."
            
            let tit = "Recover Now?"
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Recover", style: .default, handler: { action in
                self.recover(wallets, transactions, utxos)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func recover(_ wallets: [[String:Any]], _ transactions: [[String:Any]], _ utxos: [[String:Any]]?) {
        spinner.addConnectingView(vc: self, description: "recovering transaction metadata...")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
        
        CoreDataService.retrieveEntity(entityName: .transactions) { [weak self] existingTxs in
            guard let self = self else { return }
            
            for (i, tx) in transactions.enumerated() {
                
                func saveNew() {
                    if let date = dateFormatter.date(from: tx["date"] as! String) {
                        let dict = [
                            "txid":tx["txid"] as! String,
                            "id":UUID(),
                            "memo":tx["memo"] as! String,
                            "date":date as Date,
                            "label":tx["label"] as! String,
                            "originFxRate":tx["originFxRate"] as? Double ?? 0.0
                        ] as [String:Any]
                        
                        CoreDataService.saveEntity(dict: dict, entityName: .transactions) { [weak self] success in
                            guard let self = self else { return }
                            
                            guard success else {
                                self.spinner.removeConnectingView()
                                showAlert(vc: self, title: "", message: "Error saving your transaction.")
                                return
                            }
                            
                            if i + 1 == transactions.count {
                                self.recoverUtxos(wallets, utxos)
                            }
                        }
                    }
                }
                
                if let existingTxs = existingTxs, existingTxs.count > 0 {
                    var alreadySaved = false
                    var idToUpdate:UUID!
                    
                    for (e, existingTx) in existingTxs.enumerated() {
                        let existingTxStruct = TransactionStruct(dictionary: existingTx)
                        
                        func update() {
                            CoreDataService.update(id: idToUpdate, keyToUpdate: "memo", newValue: tx["memo"] as! String, entity: .transactions) { [weak self] success in
                                guard let self = self else { return }
                                
                                guard success else {
                                    self.spinner.removeConnectingView()
                                    showAlert(vc: self, title: "", message: "Error updating existing transaction memo.")
                                    return
                                }
                                CoreDataService.update(id: idToUpdate, keyToUpdate: "label", newValue: tx["label"] as! String, entity: .transactions) { [weak self] success in
                                    guard let self = self else { return }
                                    
                                    guard success else {
                                        self.spinner.removeConnectingView()
                                        showAlert(vc: self, title: "", message: "Error updating existing transaction label.")
                                        return
                                    }
                                    CoreDataService.update(id: idToUpdate, keyToUpdate: "originFxRate", newValue: tx["originFxRate"] as? Double ?? 0.0, entity: .transactions) { [weak self] success in
                                        guard let self = self else { return }
                                        
                                        guard success else {
                                            self.spinner.removeConnectingView()
                                            showAlert(vc: self, title: "", message: "Error updating existing transaction origin rate.")
                                            return
                                        }
                                        
                                        if i + 1 == transactions.count {
                                            self.recoverUtxos(wallets, utxos)
                                        }
                                    }
                                }
                            }
                        }
                        
                        if existingTxStruct.txid == tx["txid"] as! String {
                            alreadySaved = true
                            idToUpdate = existingTxStruct.id
                        }
                        
                        if e + 1 == existingTxs.count {
                            if !alreadySaved {
                                saveNew()
                            } else {
                                update()
                            }
                        }
                    }
                } else {
                    saveNew()
                }
            }
        }
    }
    
    private func recoverUtxos(_ wallets: [[String:Any]], _ utxos: [[String:Any]]?) {
        guard var utxos = utxos, utxos.count > 0 else {
            self.recoverWallet(wallets)
            
            return
        }
        
        //var utxosToSave = utxos
        
        for (i, utxo) in utxos.enumerated() {
            for (key, value) in utxo {
                print("\(key): \(value)")
                switch key {
                case "id":
                    utxos[i]["id"] = UUID(uuidString: (value as! String))
                case "walletId":
                    utxos[i]["walletId"] = UUID(uuidString: (value as! String))
                default:
                    break
                }
            }
            
            CoreDataService.saveEntity(dict: utxos[i], entityName: .utxos) { saved in
                if !saved {
                    showAlert(vc: self, title: "", message: "There was an issue recovering your utxos, please let us know about it!")
                }
                
                if i + 1 == utxos.count {
                    self.recoverWallet(wallets)
                }
            }
        }
    }
    
    private func recoverWallet(_ wallets: [[String:Any]]) {
        if index < wallets.count {
            ImportWallet.accountMap(wallets[index]) { [weak self] (success, errorDescription) in
                guard let self = self else { return }
                
                guard success else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "", message: "There was an issue recovering that wallet: \(errorDescription ?? "unknown error")")
                    return
                }
                
                self.index += 1
                self.recoverWallet(wallets)
            }
        } else {
            spinner.removeConnectingView()
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let mess = "Your wallets were recovered. When recovering wallets this way you *may* need to manually rescan each one to see balances and historical transactions: home screen > tools > rescan blockchain."
    
                let tit = "Success ✓"
    
                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
    
                alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.navigationController?.popViewController(animated: true)
                    }
                }))
                self.present(alert, animated: true, completion: nil)
            }
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
