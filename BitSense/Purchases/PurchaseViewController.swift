//
//  PurchaseViewController.swift
//  BitSense
//
//  Created by Peter on 07/12/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import StoreKit

class PurchaseViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var purchaseTable: UITableView!
    var products: [SKProduct] = []
    var refreshControl = UIRefreshControl()
    let textView = UITextView()
    let restoreButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        purchaseTable.delegate = self
        purchaseTable.dataSource = self
        refreshControl.addTarget(self, action: #selector(PurchaseTableViewController.reload), for: .valueChanged)
        
        let backButton = UIButton()
        let modelName = UIDevice.modelName
        if modelName == "iPhone X" {
            backButton.frame = CGRect(x: 15, y: 30, width: 25, height: 25)
        } else {
            backButton.frame = CGRect(x: 15, y: 20, width: 25, height: 25)
        }
        backButton.showsTouchWhenHighlighted = true
        backButton.setImage(#imageLiteral(resourceName: "back.png"), for: .normal)
        backButton.addTarget(self, action: #selector(self.goBack), for: .touchUpInside)
        self.view.addSubview(backButton)
        
        textView.textColor = UIColor.black
        textView.backgroundColor = UIColor.clear
        textView.font = UIFont.init(name: "HelveticaNeue-Light", size: 10)
        textView.text = "Sets up a personal remote full node for a monthly fee of $9.42. This is an automatically renewing fee. We will keep your node running unless you cancel making the monthly payments. The node is an instance of a pruned Bitcoin Core version 0.17.0 node running on mainnet. It allows you to utilize Bitcoins core software. Features include full Bech32 compatibility, RBF, broadcast/decode/sign raw transactions. After succesfully purchasing the node you will get a display of your balance, pending balance, and your 10 most recent transactions. Just pull to refresh the table on the home screen. You can take a note of your customer ID by tapping \"Customer Support\" (see below) and email us at bitsenseapp@gmail.com if you have any questions.\n\nPayment will be charged to iTunes Account at confirmation of purchase. Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period.  Account will be charged for renewal within 24-hours prior to the end of the current period, and identify the cost of the renewal. Subscriptions may be managed by the user and auto-renewal may be turned off by going to the user's Account Settings after purchase. \n\nTerms of use: THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.\n\nPrivacy Policy: We collect no data from you and share with no third parties."
        view.addSubview(textView)
        addRestoreButton()
    }
    
    func addRestoreButton() {
        
        restoreButton.setTitle("Restore", for: .normal)
        restoreButton.setTitleColor(UIColor.black, for: .normal)
        restoreButton.addTarget(self, action: #selector(restoreTapped(_:)), for: .touchUpInside)
        view.addSubview(restoreButton)
        
    }
    
    @objc func goBack() {
        
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewWillLayoutSubviews() {
        
        let textViewHeight = self.view.frame.maxY - self.purchaseTable.frame.maxY
        textView.frame = CGRect(x: 10, y: self.purchaseTable.frame.maxY, width: self.view.frame.width - 20, height: textViewHeight)
        
        restoreButton.frame = CGRect(x: self.view.frame.maxX - 110, y: self.purchaseTable.frame.minY - 25, width: 100, height: 20)
        
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    override func viewDidAppear(_ animated: Bool) {
        reload()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ProductCell
        let product = products[indexPath.row]
        
        cell.product = product
        cell.buyButtonHandler = { product in
            FullyNodedProducts.store.buyProduct(product, viewController: self)
        }
        
        return cell
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
        
        purchaseTable.reloadRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        displayAlert(viewController: self, title: "Success", message: "Purchase restored!")
        
    }
    
    @objc func reload() {
        products = []
        
        purchaseTable.reloadData()
        
        FullyNodedProducts.store.requestProducts{ [self] success, products in
            /*guard
             
             let self = self
             
             else { return }*/
            
            
            if success {
                print("success = \(success)")
                self.products = products!
                self.purchaseTable.reloadData()
            }
            self.refreshControl.endRefreshing()
        }
    }

}
