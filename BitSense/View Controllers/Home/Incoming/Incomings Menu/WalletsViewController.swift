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
    
    var tableArray = [[String:Any]]()

    @IBOutlet var walletTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        loadArray()
        
    }
    
    func loadArray() {
        
        for w in wallets {
            
            let wallet = Wallet(dictionary: w)
            let dict = ["label":wallet.label]
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
            let wallet = WalletOld(dictionary: wallets[row])
            
            CoreDataService.deleteEntity(id: wallet.id!, entityName: .newHdWallets) { [unowned vc = self] success in
                
                if success {
                    
                    DispatchQueue.main.async { [unowned vc = self] in
                        
                        vc.tableArray.remove(at: row)
                        vc.wallets.remove(at: row)
                        vc.walletTable.deleteRows(at: [indexPath], with: .fade)
                        
                    }
                    
                } else {
                    
                    displayAlert(viewController: vc,
                                 isError: true,
                                 message: "We had an error trying to delete that wallet")
                    
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
