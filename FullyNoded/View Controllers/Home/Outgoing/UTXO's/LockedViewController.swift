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
            self.creatingView.addConnectingView(vc: self, description: "Getting Locked UTXOs")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        executeNodeCommand(method: .listlockunspent, param: "")
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return lockedArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 1
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "lockedCell", for: indexPath)
        
        let voutLabel = cell.viewWithTag(2) as! UILabel
        let txidLabel = cell.viewWithTag(3) as! UILabel
        
        let dict = lockedArray[indexPath.section]
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
        
        let utxo = lockedArray[indexPath.section]
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
        
        Reducer.makeCommand(command: method, param: param) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            if errorMessage == nil {
                switch method {
                case .listlockunspent:
                    self.lockedArray.removeAll()
                    if let lockedutxos = response as? NSArray {
                        if lockedutxos.count > 0 {
                            for (i, locked) in lockedutxos.enumerated() {
                                let dict = locked as! [String:Any]
                                self.lockedArray.append(dict)
                                if i + 1 == lockedutxos.count {
                                    DispatchQueue.main.async {
                                        self.tableView.reloadData()
                                        self.creatingView.removeConnectingView()
                                    }
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.tableView.reloadData()
                                self.creatingView.removeConnectingView()
                                showAlert(vc: self, title: "No Locked UTXO's", message: "")
                            }
                        }
                    }
                    
                case .lockunspent:
                    if let result = response as? Double {
                        DispatchQueue.main.async {
                            self.creatingView.label.text = "refreshing..."
                        }
                        if result == 1 {
                            displayAlert(viewController: self, isError: false, message: "UTXO is unlocked and can be selected for spends")
                        } else {
                            displayAlert(viewController: self, isError: true, message: "Unable to unlock that UTXO")
                        }
                        self.executeNodeCommand(method: .listlockunspent, param: "")
                    }
                default:
                    break
                    
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.creatingView.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorMessage!)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
                
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        
        let lockButton = UIButton()
        let lockImage = UIImage(systemName: "lock.open")!
        lockButton.tag = section
        lockButton.tintColor = .systemTeal
        lockButton.setImage(lockImage, for: .normal)
        lockButton.addTarget(self, action: #selector(unlockViaButton(_:)), for: .touchUpInside)
        lockButton.frame = CGRect(x: header.frame.maxX - 60, y: 0, width: 50, height: 50)
        lockButton.center.y = header.center.y
        header.addSubview(lockButton)
        
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    @objc func unlockViaButton(_ sender: UIButton) {
        let utxo = lockedArray[sender.tag]
        let txid = utxo["txid"] as! String
        let vout = utxo["vout"] as! Int
        unlockUTXO(txid: txid, vout: vout)
    }
    
}
