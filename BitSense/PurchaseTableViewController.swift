//
//  PurchaseTableViewController.swift
//  BitSense
//
//  Created by Peter on 14/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import StoreKit

class PurchaseTableViewController: UITableViewController {
        
    var products: [SKProduct] = []
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showDetail" {
            guard let indexPath = tableView.indexPathForSelectedRow else {
                return false
            }
            
            let product = products[indexPath.row]
            
            return FullyNodedProducts.store.isProductPurchased(product.productIdentifier)
        }
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            guard let indexPath = tableView.indexPathForSelectedRow else { return }
            
            let product = products[indexPath.row]
            
            if let name = resourceNameForProductIdentifier(product.productIdentifier),
                let detailViewController = segue.destination as? DetailViewController {
                let image = UIImage(named: name)
                detailViewController.image = image
                
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Node Subscription"
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(PurchaseTableViewController.reload), for: .valueChanged)
        
        let restoreButton = UIBarButtonItem(title: "Restore",
                                            style: .plain,
                                            target: self,
                                            action: #selector(PurchaseTableViewController.restoreTapped(_:)))
        navigationItem.rightBarButtonItem = restoreButton
        
        NotificationCenter.default.addObserver(self, selector: #selector(PurchaseTableViewController.handlePurchaseNotification(_:)),
                                               name: .IAPHelperPurchaseNotification,
                                               object: nil)
        
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reload()
    }
    
    @objc func reload() {
        products = []
        
        tableView.reloadData()
        
        FullyNodedProducts.store.requestProducts{ [self] success, products in
            /*guard
                
                let self = self
                
            else { return }*/
            
            
            if success {
                print("success = \(success)")
                self.products = products!
                self.tableView.reloadData()
            }
            self.refreshControl?.endRefreshing()
        }
    }
    
    @objc func restoreTapped(_ sender: AnyObject) {
        FullyNodedProducts.store.restorePurchases()
    }
    
    @objc func handlePurchaseNotification(_ notification: Notification) {
        guard
            let productID = notification.object as? String,
            let index = products.index(where: { product -> Bool in
                product.productIdentifier == productID
            })
        else { return }
        
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        
    }

}

extension PurchaseTableViewController {
    
   override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ProductCell
        
        let product = products[indexPath.row]
        
        cell.product = product
        cell.buyButtonHandler = { product in
            FullyNodedProducts.store.buyProduct(product)
        }
        
        return cell
    }
    
}
