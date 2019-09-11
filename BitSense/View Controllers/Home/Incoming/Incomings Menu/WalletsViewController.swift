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

    @IBOutlet var walletTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return wallets.count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "walletCell", for: indexPath)
        cell.selectionStyle = .none
        cell.textLabel?.textColor = UIColor.white
        
        let encLabel = wallets[indexPath.row]["label"] as! String
        let decLabel = aes.decryptKey(keyToDecrypt: encLabel)
        
        cell.textLabel?.text = decLabel
        
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
            
            let cd = CoreDataService()
            
            let success = cd.deleteWallet(viewController: self, id: wallets[indexPath.row]["id"] as! String)

            if success {

                wallets.remove(at: indexPath.row)
                walletTable.deleteRows(at: [indexPath], with: .fade)
                
            } else {

                displayAlert(viewController: self.navigationController!,
                             isError: true,
                             message: "We had an error trying to delete that wallet")

            }
            
        }
        
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        
        if segue.identifier == "getColdStorageAddress" {
            
            if let vc = segue.destination as? InvoiceViewController {
                
                vc.wallet = wallet
                vc.isHDInvoice = true
                
            }
            
        }
        
    }
    

}
