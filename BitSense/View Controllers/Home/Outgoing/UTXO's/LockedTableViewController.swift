//
//  LockedTableViewController.swift
//  BitSense
//
//  Created by Peter on 02/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class LockedTableViewController: UITableViewController {
    
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var isUsingSSH = IsUsingSSH.sharedInstance
    
    var lockedArray = NSArray()
    var helperArray = [[String:Any]]()
    
    let creatingView = ConnectingView()
    
    var selectedVout = Int()
    var selectedTxid = ""
    
    var ind = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView(frame: .zero)

        DispatchQueue.main.async {
            
            self.creatingView.addConnectingView(vc: self,
                                                description: "Getting Locked UTXOs")
            
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        isUsingSSH = IsUsingSSH.sharedInstance
        
        if isUsingSSH {
            
            ssh = SSHService.sharedInstance
            makeSSHCall = SSHelper.sharedInstance
            
        } else {
            
            torRPC = MakeRPCCall.sharedInstance
            torClient = TorClient.sharedInstance
            
        }
        
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
                
                displayAlert(viewController: self.navigationController!,
                             isError: true,
                             message: "No locked UTXO's")
                
            }
            
        }
        
    }
    
    func getAmounts(i: Int) {
        
        if i <= helperArray.count - 1 {
            
            selectedTxid = helperArray[i]["txid"] as! String
            selectedVout = helperArray[i]["vout"] as! Int
            
            executeNodeCommandSSH(method: BTC_CLI_COMMAND.getrawtransaction,
                                  param: "\"\(selectedTxid)\", true")
            
        }
        
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return helperArray.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
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
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return 113
        
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
        
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
        
        executeNodeCommandSSH(method: BTC_CLI_COMMAND.lockunspent,
                              param: param)
        
    }
    

    func executeNodeCommandSSH(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.getrawtransaction:
                    
                    let dict = makeSSHCall.dictToReturn
                    let outputs = dict["vout"] as! NSArray
                    
                    for (i, outputDict) in outputs.enumerated() {
                        
                        let output = outputDict as! NSDictionary
                        let value = output["value"] as! Double
                        let vout = output["n"] as! Int
                        
                        if vout == selectedVout {
                            
                            helperArray[ind]["amount"] = value
                            ind = ind + 1
                            
                        }
                        
                        if i + 1 == outputs.count {
                         
                            if ind <= helperArray.count - 1 {
                                
                                getAmounts(i: ind)
                                
                            } else {
                                
                                DispatchQueue.main.async {
                                    
                                    self.tableView.reloadData()
                                    self.creatingView.removeConnectingView()
                                    
                                }
                                
                            }
                            
                        }
                        
                    }
                    
                case BTC_CLI_COMMAND.listlockunspent:
                    
                    lockedArray = makeSSHCall.arrayToReturn
                    getHelperArray()
                    
                case BTC_CLI_COMMAND.lockunspent:
                    
                    let result = makeSSHCall.doubleToReturn
                    
                    if result == 1 {
                        
                        displayAlert(viewController: self.navigationController!,
                                     isError: false,
                                     message: "UTXO is unlocked and can be selected for spends")
                        
                    } else {
                        
                        displayAlert(viewController: self.navigationController!,
                                     isError: true,
                                     message: "Unable to unlock that UTXO")
                        
                    }
                    
                    helperArray.removeAll()
                    
                    executeNodeCommandSSH(method: BTC_CLI_COMMAND.listlockunspent,
                                          param: "")
                    
                    DispatchQueue.main.async {
                        
                        self.creatingView.addConnectingView(vc: self,
                                                            description: "Refreshing")
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.creatingView.removeConnectingView()
                    
                    displayAlert(viewController: self.navigationController!,
                                 isError: true,
                                 message: self.makeSSHCall.errorDescription)
                    
                }
                
            }
            
        }
        
        if self.ssh != nil {
         
            if self.ssh.session.isConnected {
                
                makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                              method: method,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                self.creatingView.removeConnectingView()
                
                displayAlert(viewController: self.navigationController!,
                             isError: true,
                             message: "Not connected")
                
            }
            
        } else {
         
            self.creatingView.removeConnectingView()
            
            displayAlert(viewController: self.navigationController!,
                         isError: true,
                         message: "Not connected")
            
        }
        
    }

}
