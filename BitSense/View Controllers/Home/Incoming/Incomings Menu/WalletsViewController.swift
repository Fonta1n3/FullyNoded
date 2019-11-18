//
//  WalletsViewController.swift
//  BitSense
//
//  Created by Peter on 09/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class WalletsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var wallets = [[String:Any]]()
    var wallet = [String:Any]()
    var isHDInvoice = Bool()
    let aes = AESService()
    
    var tableArray = [[String:Any]]()

    @IBOutlet var walletTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        loadArray()
        
    }
    
    func loadArray() {
        
        for w in wallets {
            
            let wallet = Wallet(dictionary: w)
            let walletLabel = wallet.label
            let decLabel = aes.decryptKey(keyToDecrypt: walletLabel)
            let dict = ["label":decLabel]
            tableArray.append(dict)
            walletTable.reloadData()
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return tableArray.count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "walletCell", for: indexPath)
        cell.selectionStyle = .none
        cell.textLabel?.textColor = UIColor.white
        let dict = tableArray[indexPath.row]
        let label = dict["label"] as! String
        cell.textLabel?.text = label
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: indexPath)!
        
        wallet = wallets[indexPath.row]
        
        DispatchQueue.main.async {
            
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell.alpha = 0
                
            }, completion: { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell.alpha = 1
                    
                }, completion: { _ in
                    
                    self.performSegue(withIdentifier: "getColdStorageAddress", sender: self)
                    
                })
                
            })
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == UITableViewCell.EditingStyle.delete {
            
            let row = indexPath.row
            let cd = CoreDataService()
            let wallet = Wallet(dictionary: wallets[row])
            
            cd.deleteEntity(id: wallet.id, entityName: .hdWallets) {
                
                if !cd.errorBool {
                    
                    let success = cd.boolToReturn
                    
                    if success {
                        
                        DispatchQueue.main.async {
                            
                            self.tableArray.remove(at: row)
                            self.wallets.remove(at: row)
                            self.walletTable.deleteRows(at: [indexPath], with: .fade)
                            
                        }
                        
                    } else {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "We had an error trying to delete that wallet: \(cd.errorDescription)")
                        
                    }
                    
                    
                } else {
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "We had an error trying to delete that wallet: \(cd.errorDescription)")
                    
                }
                
            }
            
        }
        
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "getColdStorageAddress" {
            
            if let vc = segue.destination as? InvoiceViewController {
                
                vc.wallet = wallet
                vc.isHDInvoice = true
                
            }
            
        }
        
    }
    

}
