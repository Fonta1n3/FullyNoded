//
//  UtxoTableViewController.swift
//  BitSense
//
//  Created by Peter on 26/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import AES256CBC
import SwiftKeychainWrapper

class UtxoTableViewController: UITableViewController {
    
    var ssh:SSHService!
    var isUsingSSH = Bool()
    var utxoArray = NSArray()
    @IBOutlet var utxoTable: UITableView!
    
    @IBAction func back(_ sender: UIBarButtonItem) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        utxoTable.tableFooterView = UIView(frame: .zero)

        if !isUsingSSH {
            
            executeNodeCommand(method: BTC_CLI_COMMAND.listunspent, param: "")
            
        } else {
            
            listUnspent()
            
        }
        
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
        
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return utxoArray.count
        
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let dict = utxoArray[indexPath.row] as! NSDictionary
        let address = cell.viewWithTag(1) as! UILabel
        let txId = cell.viewWithTag(2) as! UILabel
        let redScript = cell.viewWithTag(3) as! UILabel
        let amount = cell.viewWithTag(4) as! UILabel
        let scriptPubKey = cell.viewWithTag(5) as! UILabel
        let vout = cell.viewWithTag(6) as! UILabel
        let solvable = cell.viewWithTag(7) as! UILabel
        let confs = cell.viewWithTag(8) as! UILabel
        let safe = cell.viewWithTag(9) as! UILabel
        let spendable = cell.viewWithTag(10) as! UILabel
        
        for (key, value) in dict {
            
            let keyString = key as! String
            
            switch keyString {
                
            case "address":
                
                address.text = "\(value)"
                
            case "txid":
                
                txId.text = "\(value)"
                
            case "redeemScript":
                
                redScript.text = "\(value)"
                
            case "amount":
                
                amount.text = "\(value)"
                
            case "scriptPubKey":
                
                scriptPubKey.text = "\(value)"
                
            case "vout":
                
                vout.text = "\(value)"
                
            case "solvable":
                
                if (value as! Int) == 1 {
                    
                    solvable.text = "True"
                    
                } else if (value as! Int) == 0 {
                    
                    solvable.text = "False"

                }
                
            case "confirmations":
                
                confs.text = "\(value)"
                
            case "safe":
                
                if (value as! Int) == 1 {
                    
                    safe.text = "True"
                    
                } else if (value as! Int) == 0 {
                    
                    safe.text = "False"
                    
                }
                
            case "spendable":
                
                if (value as! Int) == 1 {
                    
                    spendable.text = "True"
                    
                } else if (value as! Int) == 0 {
                    
                    spendable.text = "False"
                    
                }
                
            default:
                
                break
                
            }
            
        }
        
        return cell
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: Any) {
        
        func decrypt(item: String) -> String {
            
            var decrypted = ""
            if let password = KeychainWrapper.standard.string(forKey: "AESPassword") {
                if let decryptedCheck = AES256CBC.decryptString(item, password: password) {
                    decrypted = decryptedCheck
                }
            }
            return decrypted
        }
        
        let nodeUsername = decrypt(item: UserDefaults.standard.string(forKey: "NodeUsername")!)
        let nodePassword = decrypt(item: UserDefaults.standard.string(forKey: "NodePassword")!)
        let ip = decrypt(item: UserDefaults.standard.string(forKey: "NodeIPAddress")!)
        let port = decrypt(item: UserDefaults.standard.string(forKey: "NodePort")!)
        let url = URL(string: "http://\(nodeUsername):\(nodePassword)@\(ip):\(port)")
        var request = URLRequest(url: url!)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method.rawValue)\",\"params\":[\(param)]}".data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) -> Void in
            
            do {
                
                if error != nil {
                    
                    displayAlert(viewController: self, title: "Error", message: "\(error.debugDescription)")
                    
                } else {
                    
                    if let urlContent = data {
                        
                        do {
                            
                            let jsonAddressResult = try JSONSerialization.jsonObject(with: urlContent, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                            
                            if let errorCheck = jsonAddressResult["error"] as? NSDictionary {
                                
                                if let error = errorCheck["message"] as? String {
                                    
                                    displayAlert(viewController: self, title: "Error", message: error)
                                    
                                }
                                
                            } else {
                                
                                if let resultCheck = jsonAddressResult["result"] as? Any {
                                    
                                    switch method {
                                        
                                    case BTC_CLI_COMMAND.listunspent:
                                        
                                        if let resultArray = resultCheck as? NSArray {
                                            
                                            if resultArray.count > 0 {
                                                
                                                self.utxoArray = resultArray
                                                
                                                self.getUtxoSize()
                                                
                                                DispatchQueue.main.async {
                                                    
                                                    self.utxoTable.reloadData()
                                                    
                                                }
                                                
                                            }
                                            
                                        }
                                        
                                    default:
                                        
                                        break
                                        
                                    }
                                    
                                }
                                
                            }
                            
                        } catch {
                            
                            print("error processing json")
                            
                        }
                        
                    }
                    
                }
                
            }
            
        }
        
        task.resume()
        
    }
    
    func listUnspent() {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            
            self.ssh.execute(command: BTC_CLI_COMMAND.listunspent, params: "", response: { (result, error) in
                
                if error != nil {
                    
                    print("error listunspent")
                    
                } else {
                    
                    print("result = \(String(describing: result))")
                    
                    if let resultArray = result as? NSArray {
                        
                        if resultArray.count > 0 {
                            
                            self.utxoArray = resultArray
                            
                            self.getUtxoSize()
                            
                            DispatchQueue.main.async {
                                
                                self.utxoTable.reloadData()
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            })
            
        }
        
    }
    
    func getUtxoSize() {
        
        for (index, utxo) in self.utxoArray.enumerated() {
            
            let dict = utxo as! NSDictionary
            let txid = dict["txid"] as! String
            
            if !self.isUsingSSH {
                
                self.executeNodeCommand(method: BTC_CLI_COMMAND.getrawtransaction, param: "\"\(txid)\"")
                
            } else {
                
                self.getRawTx(txid: txid, index: index)
                
            }
        }
    }
    
    func getRawTx(txid: String, index: Int) {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            
            self.ssh.executeStringResponse(command: BTC_CLI_COMMAND.getrawtransaction, params: "\"\(txid)\"", response: { (result, error) in
                
                if error != nil {
                    
                    print("error getRawTx")
                    displayAlert(viewController: self, title: "Error", message: "\(String(describing: error))")
                    
                } else {
                    
                    self.decodeRawTx(rawtx: result!, index: index)
                    
                }
                
            })
            
        }
        
    }
    
    func decodeRawTx(rawtx: String, index: Int) {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            
            self.ssh.execute(command: BTC_CLI_COMMAND.decoderawtransaction, params: "\"\(rawtx)\"", response: { (result, error) in
                
                if error != nil {
                    
                    print("error decodeRawTx")
                    displayAlert(viewController: self, title: "Error", message: "\(String(describing: error))")
                    
                } else {
                    
                    if let dict = result as? NSDictionary {
                        
                        let size = dict["size"] as! Int
                        let vsize = dict["vsize"] as! Int
                        
                        DispatchQueue.main.async {
                            
                            let cell = self.utxoTable.cellForRow(at: IndexPath.init(row: index, section: 0))
                            let sizeLabel = cell?.viewWithTag(11) as! UILabel
                            let vsizeLabel = cell?.viewWithTag(12) as! UILabel
                            sizeLabel.text = "\(size)"
                            vsizeLabel.text = "\(vsize)"
                            
                        }
                        
                    }
                    
                }
                
            })
            
        }
        
    }

}
