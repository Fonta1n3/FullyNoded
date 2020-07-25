//
//  LockedViewController.swift
//  BitSense
//
//  Created by Peter on 27/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class LockedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var lockedArray = [[String:Any]]()
    let creatingView = ConnectingView()
    var selectedVout = Int()
    var selectedTxid = ""
    @IBOutlet var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView(frame: .zero)
        
        DispatchQueue.main.async {
            
            self.creatingView.addConnectingView(vc: self,
                                                description: "Getting Locked UTXOs")
            
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        executeNodeCommand(method: .listlockunspent, param: "")
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return lockedArray.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "lockedCell", for: indexPath)
        
        let voutLabel = cell.viewWithTag(2) as! UILabel
        let txidLabel = cell.viewWithTag(3) as! UILabel
        
        let dict = lockedArray[indexPath.row]
        let txid = dict["txid"] as! String
        let vout = dict["vout"] as! Int
        
        voutLabel.text = "vout #\(vout)"
        txidLabel.text = "txid" + " " + txid
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return 50
        
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let utxo = lockedArray[indexPath.row]
        let txid = utxo["txid"] as! String
        let vout = utxo["vout"] as! Int
        
        let unlock = UIContextualAction(style: .destructive, title: "Unlock") {  (contextualAction, view, boolValue) in
            self.unlockUTXO(txid: txid, vout: vout)
        }
        unlock.backgroundColor = .blue
        let swipeActions = UISwipeActionsConfiguration(actions: [unlock])

        return swipeActions
    }
    
    func unlockUTXO(txid: String, vout: Int) {
        creatingView.addConnectingView(vc: self, description: "unlocking...")
        let param = "true, ''[{\"txid\":\"\(txid)\",\"vout\":\(vout)}]''"
        executeNodeCommand(method: .lockunspent, param: param)
        
    }
    
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                case .listlockunspent:
                    vc.lockedArray.removeAll()
                    if let lockedutxos = response as? NSArray {
                        if lockedutxos.count > 0 {
                            for (i, locked) in lockedutxos.enumerated() {
                                let dict = locked as! [String:Any]
                                vc.lockedArray.append(dict)
                                if i + 1 == lockedutxos.count {
                                    DispatchQueue.main.async { [unowned vc = self] in
                                        vc.tableView.reloadData()
                                        vc.creatingView.removeConnectingView()
                                    }
                                }
                            }
                        } else {
                            DispatchQueue.main.async { [unowned vc = self] in
                                vc.tableView.reloadData()
                                vc.creatingView.removeConnectingView()
                                showAlert(vc: vc, title: "No Locked UTXO's", message: "")
                            }
                        }
                    }
                    
                case .lockunspent:
                    if let result = response as? Double {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.creatingView.label.text = "refreshing..."
                        }
                        if result == 1 {
                            displayAlert(viewController: self, isError: false, message: "UTXO is unlocked and can be selected for spends")
                        } else {
                            displayAlert(viewController: self, isError: true, message: "Unable to unlock that UTXO")
                        }
                        vc.executeNodeCommand(method: .listlockunspent, param: "")
                    }
                default:
                    break
                    
                }
            } else {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.creatingView.removeConnectingView()
                    displayAlert(viewController: vc, isError: true, message: errorMessage!)
                }
            }
        }
    }
    
}
