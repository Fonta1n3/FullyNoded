//
//  ChooseWalletViewController.swift
//  BitSense
//
//  Created by Peter on 25/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ChooseWalletViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var wallets = NSArray()
    var tableArray = [String]()
    var doneBlock:((Bool) -> Void)?
    
    func loadTableArray() {
        
        for wallet in wallets {
            
            let walletName = wallet as! String
            
            if walletName != "" {
                
                tableArray.append(walletName)
                
            }
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return tableArray.count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "chooseWalletCell", for: indexPath)
        cell.textLabel?.textColor = UIColor.white
        cell.selectionStyle = .none
        let walletname = tableArray[indexPath.row]
        cell.textLabel?.text = walletname
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let walletName = tableArray[indexPath.row]
        UserDefaults.standard.set(walletName, forKey: "walletName")
        self.doneBlock!(true)
        navigationController?.popToRootViewController(animated: true)
        
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()

        loadTableArray()
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
