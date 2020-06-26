//
//  LockedViewController.swift
//  BitSense
//
//  Created by Peter on 27/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class LockedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var lockedArray = NSArray()
    var helperArray = [[String:Any]]()
    let creatingView = ConnectingView()
    var selectedVout = Int()
    var selectedTxid = ""
    var ind = 0
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
        
        getHelperArray()
        
    }
    
    func getHelperArray() {
        
        helperArray.removeAll()
        
        ind = 0
        
        if lockedArray.count > 0 {
            
            for utxo in lockedArray {
                
                let dict = utxo as! NSDictionary
                let txid = dict["txid"] as! String
                let vout = dict["vout"] as! Int
                
                let helperDict = ["txid":txid,
                                  "vout":vout,
                                  "amount":0.0] as [String : Any]
                
                helperArray.append(helperDict)
                
            }
            
            getAmounts(i: ind)
            
        } else {
            
            DispatchQueue.main.async {
                
                self.tableView.reloadData()
                
                self.creatingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "No locked UTXO's")
                
            }
            
        }
        
    }
    
    func getAmounts(i: Int) {
        if i <= helperArray.count - 1 {
            selectedTxid = helperArray[i]["txid"] as! String
            selectedVout = helperArray[i]["vout"] as! Int
            executeNodeCommand(method: .gettransaction, param: "\"\(selectedTxid)\", true")
        }
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return helperArray.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "lockedCell", for: indexPath)
        
        let amountLabel = cell.viewWithTag(1) as! UILabel
        let voutLabel = cell.viewWithTag(2) as! UILabel
        let txidLabel = cell.viewWithTag(3) as! UILabel
        
        let dict = helperArray[indexPath.row]
        let txid = dict["txid"] as! String
        let vout = dict["vout"] as! Int
        let amount = dict["amount"] as! Double
        
        amountLabel.text = "\(amount)"
        voutLabel.text = "vout #\(vout)"
        txidLabel.text = "txid" + " " + txid
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return 113
        
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
        
        let utxo = helperArray[editActionsForRowAt.row]
        let txid = utxo["txid"] as! String
        let vout = utxo["vout"] as! Int
        
        let unlock = UITableViewRowAction(style: .destructive, title: "Unlock") { action, index in
            
            self.unlockUTXO(txid: txid, vout: vout)
            
        }
        
        unlock.backgroundColor = .blue
        
        return [unlock]
        
    }
    
    func unlockUTXO(txid: String, vout: Int) {
        
        let param = "true, ''[{\"txid\":\"\(txid)\",\"vout\":\(vout)}]''"
        
        executeNodeCommand(method: BTC_CLI_COMMAND.lockunspent,
                           param: param)
        
    }
    
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                case .gettransaction:
                    if let dict = response as? NSDictionary {
                        if let details = dict["details"] as? NSArray {
                            for (i, output) in details.enumerated() {
                                if let outputDict = output as? NSDictionary {
                                    let value = outputDict["amount"] as! Double
                                    let vout = outputDict["vout"] as! Int
                                    if vout == vc.selectedVout {
                                        vc.helperArray[vc.ind]["amount"] = value
                                        vc.ind += 1
                                    }
                                    if i + 1 == details.count {
                                        if vc.ind <= vc.helperArray.count - 1 {
                                            vc.getAmounts(i: vc.ind)
                                        } else {
                                            DispatchQueue.main.async { [unowned vc = self] in
                                                vc.tableView.reloadData()
                                                vc.creatingView.removeConnectingView()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                case BTC_CLI_COMMAND.listlockunspent:
                    if let lockedutxos = response as? NSArray {
                        vc.lockedArray = lockedutxos
                        vc.getHelperArray()
                    }
                    
                case BTC_CLI_COMMAND.lockunspent:
                    if let result = response as? Double {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.creatingView.addConnectingView(vc: self, description: "Refreshing")
                        }
                        if result == 1 {
                            displayAlert(viewController: self, isError: false, message: "UTXO is unlocked and can be selected for spends")
                        } else {
                            displayAlert(viewController: self, isError: true, message: "Unable to unlock that UTXO")
                        }
                        vc.helperArray.removeAll()
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
