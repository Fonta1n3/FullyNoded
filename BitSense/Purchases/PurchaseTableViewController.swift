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
    
    let infoView = UIView()
    var products: [SKProduct] = []
    let masterKey = "u0pzk5re5x7fc2m0fypgzgw6l5vmqf9c"
    
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
        
        
        
        infoView.backgroundColor = UIColor.darkGray
        
        
        
        let text = "Sets up a personal remote full node for a monthly fee of $9.42. This is an automatically renewing fee. We will keep your node running unless you cancel making the monthly payments. The node is an instance of a pruned Bitcoin Core version 0.17.0 node running on mainnet. It allows you to utilize Bitcoins core software. Features include full Bech32 compatibility, RBF, broadcast/decode/sign raw transactions. After succesfully purchasing the node you will get a display of your balance, pending balance, and your 10 most recent transactions. Just pull to refresh the table on the home screen. You can take a note of your customer ID by tapping \"Customer Support\" (see below) and email us at bitsenseapp@gmail.com if you have any questions.\n\nPayment will be charged to iTunes Account at confirmation of purchase. Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period.  Account will be charged for renewal within 24-hours prior to the end of the current period, and identify the cost of the renewal. Subscriptions may be managed by the user and auto-renewal may be turned off by going to the user's Account Settings after purchase. \n\nTerms of use: THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.\n\nPrivacy Policy: We collect no data from you and share with no third parties."
        
    }
    
    
    
    override func viewDidLayoutSubviews() {
        infoView.frame = CGRect(x: self.tableView.frame.maxX - 200, y: 0, width: self.tableView.frame.width, height: 200)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reload()
        tableView.addSubview(infoView)
        //view.bringSubview(toFront: infoView)
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
        
        let alert = UIAlertController(title: "Warning!", message: "This will overwrite your current node and create a new one.", preferredStyle: UIAlertControllerStyle.actionSheet)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Create new node", comment: ""), style: .default, handler: { (action) in
            FullyNodedProducts.store.restorePurchases()
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in }))
        
        alert.popoverPresentationController?.sourceView = self.view
        self.present(alert, animated: true) {}
        
    }
    
    @objc func handlePurchaseNotification(_ notification: Notification) {
        guard
            let productID = notification.object as? String,
            let index = products.index(where: { product -> Bool in
                product.productIdentifier == productID
            })
        else { return }
        
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        displayAlert(viewController: self, title: "Success", message: "Purchase restored!")
        
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
            FullyNodedProducts.store.buyProduct(product, viewController: self)
        }
        
        return cell
        
    }
    
}
