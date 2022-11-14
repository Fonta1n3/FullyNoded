//
//  LockedViewController.swift
//  BitSense
//
//  Created by Peter on 27/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class LockedViewController: UIViewController {
    
    private var lockedUtxos = [Utxo]()
    let spinner = ConnectingView()
    var selectedVout = Int()
    var selectedTxid = ""
    var fxRate:Double?
    var isBtc = false
    var isSats = false
    var isFiat = false
    @IBOutlet var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UINib(nibName: UTXOCell.identifier, bundle: nil), forCellReuseIdentifier: UTXOCell.identifier)
        tableView.tableFooterView = UIView(frame: .zero)
        spinner.addConnectingView(vc: self, description: "Getting Locked UTXO's")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadLockedUTxos()
    }
    
    private func finishedLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            self.tableView.reloadData()
            self.tableView.isUserInteractionEnabled = true
        }
    }
    
    private func loadLockedUTxos() {
        lockedUtxos.removeAll()
        
        Reducer.sharedInstance.makeCommand(command: .listlockunspent) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let locked = response as? NSArray else {
                self.finishedLoading()
                displayAlert(viewController: self, isError: true, message: errorMessage ?? "unknown error")
                return
            }
            
            guard locked.count > 0 else {
                self.finishedLoading()
                showAlert(vc: self, title: "No locked UTXO's", message: "")
                return
            }
            
            for lockedUtxo in locked {
                guard let utxoDict = lockedUtxo as? [String:Any] else {
                    displayAlert(viewController: self, isError: true, message: "Error decoding your locked UTXO's")
                    return
                }
                
                let utxoStruct = Utxo(utxoDict)
                self.lockedUtxos.append(utxoStruct)
            }
            
            CoreDataService.retrieveEntity(entityName: .utxos) { savedLockedUtxos in
                guard let savedLockedUtxos = savedLockedUtxos, savedLockedUtxos.count > 0 else {
                    self.finishedLoading()
                    return
                }
                
                for savedLockedUtxo in savedLockedUtxos {
                    let savedUtxoStruct = Utxo(savedLockedUtxo)
                    let savedUtxoOutpoint = savedUtxoStruct.txid + "\(savedUtxoStruct.vout)"
                    var isSaved = false
                    
                    for (i, utxo) in self.lockedUtxos.enumerated() {
                        let outpoint = utxo.txid + "\(utxo.vout)"
                        isSaved = outpoint == savedUtxoOutpoint
                        
                        if isSaved {
                            self.lockedUtxos[i] = savedUtxoStruct
                        }
                    }
                }
                
                self.lockedUtxos = self.lockedUtxos.sorted { $0.confs ?? 0 < $1.confs ?? 0 }
                self.finishedLoading()
            }
        }
    }
    
    private func unlock(_ utxo: Utxo) {
        spinner.addConnectingView(vc: self, description: "unlocking...")
        let param:Lock_Unspent = .init(["unlock": true, "transactions": [["txid":utxo.txid,"vout":utxo.vout]]])
        
        Reducer.sharedInstance.makeCommand(command: .lockunspent(param)) { (response, errorMessage) in
            guard let success = response as? Bool else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.loadLockedUTxos()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "unknown error")
                }
                
                return
            }
            
            if success {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.loadLockedUTxos()
                }
                
                showAlert(vc: self, title: "UTXO Unlocked 🔓", message: "")
                
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.loadLockedUTxos()
                    displayAlert(viewController: self, isError: true, message: "utxo was not locked")
                }
            }
        }
    }
}

// MARK: UTXOCellDelegate

extension LockedViewController: UTXOCellDelegate {
    
    func didTapToLock(_ utxo: Utxo) {
        unlock(utxo)
    }
    
    func didTapToEditLabel(_ utxo: Utxo) {}
    
    func didTapToFetchOrigin(_ utxo: Utxo) {}
    
    func didTapToMix(_ utxo: Utxo) {}
    
    func didTapDonateChange(_ utxo: Utxo) {}
    
    func didTapFidelity(_ utxo: Utxo) {}
    
//    func didTapInfoFor(_ utxo: Utxo) {
//        performSegue(withIdentifier: "getUTXOinfo", sender: utxo)
//    }
    
}

// Mark: UITableViewDataSource

extension LockedViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: UTXOCell.identifier, for: indexPath) as! UTXOCell
        let utxo = lockedUtxos[indexPath.section]
        
        cell.configure(utxo: utxo, isLocked: true, fxRate: fxRate, isSats: isSats, isBtc: isBtc, isFiat: isFiat, delegate: self)
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return lockedUtxos.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
}

// MarK: UITableViewDelegate

extension LockedViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 5 // Spacing between cells
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = .clear
        return headerView
    }
    
}
