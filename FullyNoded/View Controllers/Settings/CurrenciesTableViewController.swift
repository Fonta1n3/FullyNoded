//
//  CurrenciesTableViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/16/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import UIKit

class CurrenciesTableViewController: UITableViewController {
    
    let currencies = Currencies.currenciesWithCircle
    let spinner = ConnectingView.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return currencies.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "currenciesCell", for: indexPath)
        cell.selectionStyle = .none
        let label = cell.viewWithTag(1) as! UILabel
        let icon = cell.viewWithTag(2) as! UIImageView
        let currencyDict = currencies[indexPath.row]
        let existingCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        for (key, value) in currencyDict {
            label.text = key
            icon.image = UIImage(systemName: value)
            
            if key == existingCurrency {
                cell.isSelected = true
                cell.accessoryType = .checkmark
            } else {
                cell.isSelected = false
                cell.accessoryType = .none
            }
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let currencyDict = currencies[indexPath.row]
        
        for (key, value) in currencyDict {
            UserDefaults.standard.set(key, forKey: "currency")
            updateFxRate(currency: key)
        }
    }
    
    func updateFxRate(currency: String) {
        spinner.show(vc: self, description: "fetching fx rate...")
        
        FiatConverter.sharedInstance.getFxRate(currency: currency) { [weak self] fxRate in
            guard let self = self else { return }
            
            spinner.dismiss()
            
            guard let fxRate = fxRate else {
                showAlert(vc: self, title: "", message: "There was an error fetching the exchange rate for \(currency).")
                return
            }
            
            UserDefaults.standard.setValue(fxRate, forKey: "fxRate")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                tableView.reloadData()
                
                showAlert(vc: self, title: "", message: "You need to tap the refresh button on the active wallet view to update the balance currency.")
            }
        }
    }
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
