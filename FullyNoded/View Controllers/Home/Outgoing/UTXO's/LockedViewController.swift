//
//  LockedViewController.swift
//  BitSense
//
//  Created by Peter on 27/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class LockedViewController: UIViewController {
    
    private var lockedUtxos = [UtxosStruct]()
    let spinner = ConnectingView()
    var selectedVout = Int()
    var selectedTxid = ""
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
        
        Reducer.makeCommand(command: .listlockunspent, param: "") { [weak self] (response, errorMessage) in
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
                
                let utxoStruct = UtxosStruct(dictionary: utxoDict)
                self.lockedUtxos.append(utxoStruct)
            }
            
            CoreDataService.retrieveEntity(entityName: .utxos) { savedLockedUtxos in
                guard let savedLockedUtxos = savedLockedUtxos, savedLockedUtxos.count > 0 else {
                    self.finishedLoading()
                    return
                }
                
                for savedLockedUtxo in savedLockedUtxos {
                    let savedUtxoStruct = UtxosStruct(dictionary: savedLockedUtxo)
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
    
    private func deleteLocalUtxo(_ utxo: UtxosStruct) {
        CoreDataService.retrieveEntity(entityName: .utxos) { (utxos) in
            guard let utxos = utxos else { return }
            
            let outpoint = utxo.txid + "\(utxo.vout)"
            
            for existingUtxo in utxos {
                let existingUtxoStruct = UtxosStruct(dictionary: existingUtxo)
                let existingUtxoOutpoint = existingUtxoStruct.txid + "\(existingUtxoStruct.vout)"
                
                if outpoint == existingUtxoOutpoint {
                    guard let id = existingUtxoStruct.id else { return }
                    
                    CoreDataService.deleteEntity(id: id, entityName: .utxos) { success in
                        #if DEBUG
                            print("deleted utxo from local storage: \(success)")
                        #endif
                    }
                }
            }
        }
    }
    
    private func unlock(_ utxo: UtxosStruct) {
        spinner.addConnectingView(vc: self, description: "unlocking...")
        let param = "true, [{\"txid\":\"\(utxo.txid)\",\"vout\":\(utxo.vout)}]"
        
        Reducer.makeCommand(command: .lockunspent, param: param) { (response, errorMessage) in
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
                    // Delete them from storage when they get unlocked.
                    self.deleteLocalUtxo(utxo)
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
    
    func didTapToLock(_ utxo: UtxosStruct) {
        unlock(utxo)
    }
    
//    func didTapInfoFor(_ utxo: UtxosStruct) {
//        performSegue(withIdentifier: "getUTXOinfo", sender: utxo)
//    }
    
}

// Mark: UITableViewDataSource

extension LockedViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: UTXOCell.identifier, for: indexPath) as! UTXOCell
        let utxo = lockedUtxos[indexPath.section]
        
        cell.configure(utxo: utxo, isLocked: true, delegate: self)
        
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
