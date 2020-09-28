//
//  LockedViewController.swift
//  BitSense
//
//  Created by Peter on 27/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class LockedViewController: UIViewController {
    
    private var lockedUtxos = [UTXO]()
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
    
    private func loadLockedUTxos() {
        lockedUtxos.removeAll()
        
        Reducer.listLockedUTXOs { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(var utxos):
                
                CoreDataService.retrieveEntity(entityName: .utxos) { savedLockedUtxos in
                    guard let savedLockedUtxos = savedLockedUtxos, savedLockedUtxos.count > 0 else {
                        
                        self.lockedUtxos = utxos.sorted { $0.confirmations ?? 0 < $1.confirmations ?? 0 }
                        
                        if self.lockedUtxos.isEmpty {
                            displayAlert(viewController: self, isError: true, message: "No locked UTXO's")
                        }
                        
                        return
                    }
                    
                    var updatedUtxos = [UTXO]()
                    
                    for savedLockedUtxo in savedLockedUtxos {
                        let savedUtxoStruct = UtxosStruct(dictionary: savedLockedUtxo)
                        let savedUtxoOutpoint = savedUtxoStruct.txid + "\(savedUtxoStruct.vout)"
                        var isSaved = false
                        
                        for (i, utxo) in utxos.enumerated() {
                            let outpoint = utxo.txid + "\(utxo.vout)"
                            isSaved = outpoint == savedUtxoOutpoint
                            
                            if isSaved {
                                utxos.remove(at: i)
                                let utxoToAdd:UTXO = UTXO(txid: savedUtxoStruct.txid,
                                                          vout: Int(savedUtxoStruct.vout),
                                                          address: savedUtxoStruct.address,
                                                          addressLabel: savedUtxoStruct.label,
                                                          pubKey: "",
                                                          amount: savedUtxoStruct.amount,
                                                          confirmations: Int(savedUtxoStruct.confs),
                                                          spendable: savedUtxoStruct.spendable,
                                                          solvable: savedUtxoStruct.solvable,
                                                          safe: savedUtxoStruct.safe,
                                                          desc: savedUtxoStruct.desc)
                                
                                updatedUtxos.append(utxoToAdd)
                                
                            } else if i + 1 == utxos.count {
                                updatedUtxos.append(utxo)
                            }
                        }
                    }
                    
                    self.lockedUtxos = updatedUtxos.sorted { $0.confirmations ?? 0 < $1.confirmations ?? 0 }
                    
                    if self.lockedUtxos.isEmpty {
                        displayAlert(viewController: self, isError: true, message: "No locked UTXO's")
                    }
                }
                
            case .failure(let error):
                switch error {
                case .description(let description):
                    displayAlert(viewController: self, isError: true, message: description)
                }
            }
            
            DispatchQueue.main.async {
                self.spinner.removeConnectingView()
                self.tableView.reloadData()
                self.tableView.isUserInteractionEnabled = true
            }
        }
    }
    
    private func deleteLocalUtxo(_ utxo: UTXO) {
        CoreDataService.retrieveEntity(entityName: .utxos) { (utxos) in
            guard let utxos = utxos else { return }
            
            let outpoint = utxo.txid + "\(utxo.vout)"
            
            for existingUtxo in utxos {
                let existingUtxoStruct = UtxosStruct(dictionary: existingUtxo)
                let existingUtxoOutpoint = existingUtxoStruct.txid + "\(existingUtxoStruct.vout)"
                
                if outpoint == existingUtxoOutpoint {
                    
                    CoreDataService.deleteEntity(id: existingUtxoStruct.id, entityName: .utxos) { success in
                        #if DEBUG
                            print("deleted utxo from local storage: \(success)")
                        #endif
                    }
                }
            }
        }
    }
    
    private func unLock(_ utxo: UTXO, completion: ((Result<Void, MakeRPCCallError>) -> Void)? = nil) {
        guard let index = lockedUtxos.firstIndex(of: utxo) else { return }
        
        lockedUtxos.remove(at: index)
        
        spinner.addConnectingView(vc: self, description: "unlocking...")
        
        Reducer.unlock(utxo) { [weak self] result in
            guard let self = self else { return }
            
            if case .failure(let error) = result {
                self.loadLockedUTxos()
                
                switch error {
                case .description(let errorMessage):
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.spinner.removeConnectingView()
                        self.tableView.reloadData()
                    }
                    displayAlert(viewController: self, isError: true, message: errorMessage)
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Only save UTXO's when they get locked, delete them from storage when they get unlocked.
                    self.deleteLocalUtxo(utxo)
                    self.spinner.removeConnectingView()
                    self.tableView.reloadData()
                }
                showAlert(vc: self, title: "UTXO Unlocked 🔓", message: "")
            }
            
            completion?(result)
        }
    }
}

// MARK: UTXOCellDelegate

extension LockedViewController: UTXOCellDelegate {
    
    func didTapToLock(_ utxo: UTXO) {
        unLock(utxo)
    }
    
    func didTapInfoFor(_ utxo: UTXO) {
        performSegue(withIdentifier: "getUTXOinfo", sender: utxo)
    }
    
}

// Mark: UITableViewDataSource

extension LockedViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: UTXOCell.identifier, for: indexPath) as! UTXOCell
        let utxo = lockedUtxos[indexPath.section]
        cell.locked = true
        
        cell.configure(utxo: utxo, isSelected: false, delegate: self)
        
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
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let unlock = UIContextualAction(style: .destructive, title: "Unlock") { [weak self] (contextualAction, view, boolValue) in
            guard let self = self else { return }
            
            tableView.isUserInteractionEnabled = false
            
            let utxo = self.lockedUtxos[indexPath.section]
            self.unLock(utxo) { result in
                
                DispatchQueue.main.async {
                    tableView.isUserInteractionEnabled = true
                    self.tableView.reloadData()
                }
            }
        }
        
        unlock.backgroundColor = .systemRed
        let swipeActions = UISwipeActionsConfiguration(actions: [unlock])
        return swipeActions
    }
    
}
