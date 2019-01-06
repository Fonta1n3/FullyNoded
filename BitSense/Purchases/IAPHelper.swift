//
//  IAPHelper.swift
//  BitSense
//
//  Created by Peter on 14/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import StoreKit
import Parse
import AES256CBC
import SwiftKeychainWrapper

public typealias ProductIdentifier = String
public typealias ProductsRequestCompletionHandler = (_ success: Bool, _ products: [SKProduct]?) -> Void
public let masterKey = "u0pzk5re5x7fc2m0fypgzgw6l5vmqf9c"

extension Notification.Name {
    static let IAPHelperPurchaseNotification = Notification.Name("IAPHelperPurchaseNotification")
}

open class IAPHelper: NSObject  {
    
    private let productIdentifiers: Set<ProductIdentifier>
    private var purchasedProductIdentifiers: Set<ProductIdentifier> = []
    private var productsRequest: SKProductsRequest?
    private var productsRequestCompletionHandler: ProductsRequestCompletionHandler?
    
    public init(productIds: Set<ProductIdentifier>) {
        productIdentifiers = productIds
        for productIdentifier in productIds {
            let purchased = UserDefaults.standard.bool(forKey: productIdentifier)
            if purchased {
                purchasedProductIdentifiers.insert(productIdentifier)
                print("Previously purchased: \(productIdentifier)")
            } else {
                print("Not purchased: \(productIdentifier)")
            }
        }
        super.init()
        
        SKPaymentQueue.default().add(self)
    }
}

// MARK: - StoreKit API

extension IAPHelper {
    
    public func requestProducts(_ completionHandler: @escaping ProductsRequestCompletionHandler) {
        productsRequest?.cancel()
        productsRequestCompletionHandler = completionHandler
        
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest!.delegate = self
        productsRequest!.start()
    }
    
    public func buyProduct(_ product: SKProduct, viewController: UIViewController) {
        
        print("Buying \(product.productIdentifier)...")
        
        let query = PFQuery(className: "Nodes")
        query.whereKey("Used", equalTo: false)
        query.findObjectsInBackground(block: { (objects, error) in
            
            if error != nil {
                
                print("error = \(error.debugDescription)")
                
            } else {
                
                if objects!.count > 0 {
                    
                    let payment = SKPayment(product: product)
                    SKPaymentQueue.default().add(payment)
                    
                } else {
                    displayAlert(viewController: viewController, title: "Sorry", message: "No available nodes at this time, please contact us at bitsense@gmail.com and we will set one up for you.")
                }
            }
        })
        
    }
    
    public func isProductPurchased(_ productIdentifier: ProductIdentifier) -> Bool {
        return purchasedProductIdentifiers.contains(productIdentifier)
    }
    
    public class func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    public func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
}

// MARK: - SKProductsRequestDelegate

extension IAPHelper: SKProductsRequestDelegate {
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        print("Loaded list of products...")
        let products = response.products
        productsRequestCompletionHandler?(true, products)
        clearRequestAndHandler()
        
        for p in products {
            print("Found product: \(p.productIdentifier) \(p.localizedTitle) \(p.price.floatValue)")
        }
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Failed to load list of products.")
        print("Error: \(error.localizedDescription)")
        productsRequestCompletionHandler?(false, nil)
        clearRequestAndHandler()
    }
    
    private func clearRequestAndHandler() {
        productsRequest = nil
        productsRequestCompletionHandler = nil
    }
}

// MARK: - SKPaymentTransactionObserver

extension IAPHelper: SKPaymentTransactionObserver {
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        //for transaction in transactions {
        let transaction = transactions[0]
            switch (transaction.transactionState) {
            case .purchased:
                complete(transaction: transaction)
                break
            case .failed:
                fail(transaction: transaction)
                break
            case .restored:
                restore(transaction: transaction)
                break
            case .deferred:
                break
            case .purchasing:
                break
            }
        //}
    }
    
    
    
    private func complete(transaction: SKPaymentTransaction) {
        print("complete...")
        
        func encryptKey(keyToEncrypt: String) -> String {
            
            let password = KeychainWrapper.standard.string(forKey: "AESPassword")!
            let encryptedkey = AES256CBC.encryptString(keyToEncrypt, password: password)!
            return encryptedkey
        }
        
        func decryptParsePassword(item: String) -> String {
            
            var decrypted = ""
            if let decryptedCheck = AES256CBC.decryptString(item, password: masterKey) {
                decrypted = decryptedCheck
            }
            return decrypted
        }
        
        func savePassword(password: String) {
            
            let stringToSave = encryptKey(keyToEncrypt: password)
            let saveSuccessful:Bool = KeychainWrapper.standard.set(stringToSave, forKey: "NodePassword")
            
            if saveSuccessful {
                
            } else {
                
                print("error saving string")
            }
        }
        
        func saveSSHPassword(password: String) {
            
            let stringToSave = encryptKey(keyToEncrypt: password)
            let saveSuccess:Bool = KeychainWrapper.standard.set(password, forKey: "sshPassword")
            
            if saveSuccess {
                
                print("saved sshPassword from restore")
                
            } else {
                
                print("error saving string")
            }
            
        }
        
        func saveIPAdress(ipAddress: String) {
            
            let stringToSave = encryptKey(keyToEncrypt: ipAddress)
            let saveSuccessful:Bool = KeychainWrapper.standard.set(stringToSave, forKey: "NodeIPAddress")
            
            if saveSuccessful {
                
                
            } else {
                
                print("error saving string")
            }
            
        }
        
        func savePort(port: String) {
            
            let stringToSave = encryptKey(keyToEncrypt: port)
            let saveSuccessful:Bool = KeychainWrapper.standard.set(stringToSave, forKey: "NodePort")
            
            if saveSuccessful {
                
                
            } else {
                
                print("error saving string")
            }
        }
        
        func saveUsername(username: String) {
            
            let stringToSave = encryptKey(keyToEncrypt: username)
            let saveSuccessful:Bool = KeychainWrapper.standard.set(stringToSave, forKey: "NodeUsername")
            
            if saveSuccessful {
                
                
            } else {
                
                print("error saving string")
            }
            
        }
        
        func getCredentials() {
            
            if let userID = UserDefaults.standard.string(forKey: "userID") {
                
                let queryDuplicatePurchase = PFQuery(className: "Nodes")
                queryDuplicatePurchase.whereKey("UserID", equalTo: userID)
                queryDuplicatePurchase.findObjectsInBackground(block: { (objects, error) in
                    
                    if error != nil {
                        
                        print("error = \(error.debugDescription)")
                        
                    } else {
                        
                        if objects!.count > 0 {
                            
                            DispatchQueue.main.async {
                                //add credentials to keychain
                                displayAlert(viewController: PurchaseTableViewController(), title: "Sorry", message: "You have already purchased a node.")
                            }
                            
                        } else {
                            
                            self.deliverPurchaseNotificationFor(identifier: transaction.payment.productIdentifier)
                            SKPaymentQueue.default().finishTransaction(transaction)
                            
                            var ipAddress = ""
                            let query = PFQuery(className: "Nodes")
                            query.whereKey("Used", equalTo: false)
                            query.whereKey("sshKey", equalTo: "")
                            query.findObjectsInBackground(block: { (objects, error) in
                                
                                if error != nil {
                                    
                                    print("error = \(error.debugDescription)")
                                    
                                } else {
                                    
                                    if objects!.count > 0 {
                                        
                                        let node = objects![0]
                                        let password = node["Password"] as! String
                                        let username = node["Username"] as! String
                                        let port = node["Port"] as! String
                                        ipAddress = node["IPAddress"] as! String
                                        let decrpytedPassword = decryptParsePassword(item: password)
                                        let objectID = node.objectId as! String
                                        let query = PFQuery(className:"Nodes")
                                        query.getObjectInBackground(withId: objectID) { (node: PFObject?, error: Error?) in
                                            if let error = error {
                                                print(error.localizedDescription)
                                            } else if let node = node {
                                                node["Used"] = true
                                                //ensure userid gets created for backwards compatibility
                                                if userID != "" {
                                                    node["UserID"] = userID
                                                } else {
                                                    node["UserID"] = "some user ID"
                                                }
                                                node.saveInBackground()
                                                saveUsername(username: username)
                                                savePort(port: port)
                                                savePassword(password: decrpytedPassword)
                                                saveIPAdress(ipAddress: ipAddress)
                                                DispatchQueue.main.async {
                                                    
                                                    KeychainWrapper.standard.set("", forKey: "sshPassword")
                                                    let query = PFQuery(className: "Users")
                                                    query.whereKey("userID", equalTo: userID)
                                                    query.findObjectsInBackground(block: { (objects, error) in
                                                        
                                                        if error != nil {
                                                            
                                                            print("error = \(error.debugDescription)")
                                                            
                                                        } else {
                                                            
                                                            if objects!.count > 0 {
                                                                
                                                                let user = objects![0]
                                                                user["PurchasedIP"] = ipAddress
                                                                user["didPurchaseNode"] = true
                                                                user.saveInBackground()
                                                            }
                                                        }
                                                    })
                                                }
                                            }
                                        }
                                    } else {
                                        
                                        //displayAlert(viewController: PurchaseTableViewController(), title: "Sorry", message: "No available nodes at this time, please contact us at bitsense@gmail.com and we will set one up for you.")
                                        let query = PFQuery(className: "Nodes")
                                        query.whereKey("Used", equalTo: false)
                                        query.whereKey("sshKey", equalTo: "12ri7dx6KB3Yw9cC9ZVKwggwjatiopRzF5QnYm1KU0Lo8RpNsTfAmBR3YW3yCgPO1N6AuyvLgRRjnHHiniaegU8qSDHHcHuL4Go4xiwtBW/EFsth48N3LAhbs6gHBYfKCw4q03QtsdH0+fub")
                                        query.findObjectsInBackground(block: { (objects, error) in
                                            
                                            if error != nil {
                                                
                                                print("error = \(error.debugDescription)")
                                                
                                            } else {
                                                
                                                if objects!.count > 0 {
                                                    
                                                    let node = objects![0]
                                                    let password = node["sshKey"] as! String
                                                    print("password = \(password)")
                                                    let username = node["Username"] as! String
                                                    //let port = node["Port"] as! String
                                                    ipAddress = node["IPAddress"] as! String
                                                    //let decrpytedPassword = dec
                                                    let objectID = node.objectId as! String
                                                    let query = PFQuery(className:"Nodes")
                                                    query.getObjectInBackground(withId: objectID) { (node: PFObject?, error: Error?) in
                                                        if let error = error {
                                                            print(error.localizedDescription)
                                                        } else if let node = node {
                                                            node["Used"] = true
                                                            //ensure userid gets created for backwards compatibility
                                                            if userID != "" {
                                                                node["UserID"] = userID
                                                            } else {
                                                                node["UserID"] = "some user ID"
                                                            }
                                                            node.saveInBackground()
                                                            saveUsername(username: username)
                                                            saveSSHPassword(password: password)
                                                            saveIPAdress(ipAddress: ipAddress)
                                                            DispatchQueue.main.async {
                                                                
                                                                
                                                                let query = PFQuery(className: "Users")
                                                                query.whereKey("userID", equalTo: userID)
                                                                query.findObjectsInBackground(block: { (objects, error) in
                                                                    
                                                                    if error != nil {
                                                                        
                                                                        print("error = \(error.debugDescription)")
                                                                        
                                                                    } else {
                                                                        
                                                                        if objects!.count > 0 {
                                                                            
                                                                            let user = objects![0]
                                                                            user["PurchasedIP"] = ipAddress
                                                                            user["didPurchaseNode"] = true
                                                                            user.saveInBackground()
                                                                        }
                                                                    }
                                                                })
                                                            }
                                                        }
                                                    }
                                                    
                                                } else {
                                                    
                                                    displayAlert(viewController: PurchaseTableViewController(), title: "Sorry", message: "No available nodes at this time, please contact us at bitsense@gmail.com and we will set one up for you.")
                                                }
                                                
                                            }
                                            
                                        })
                                        
                                        
                                    }
                                }
                            })
                            
                        }
                    }
                })
            }
        }
        
        getCredentials()
    }
    
    private func restore(transaction: SKPaymentTransaction) {
        
        //get userid from parse to find which node is theres and restore it
        guard let productIdentifier = transaction.original?.payment.productIdentifier else { return }
        print("restore... \(productIdentifier)")
        
        func encryptKey(keyToEncrypt: String) -> String {
            
            let password = KeychainWrapper.standard.string(forKey: "AESPassword")!
            let encryptedkey = AES256CBC.encryptString(keyToEncrypt, password: password)!
            return encryptedkey
        }
        
        func decryptParsePassword(item: String) -> String {
            
            var decrypted = ""
            if let decryptedCheck = AES256CBC.decryptString(item, password: masterKey) {
                decrypted = decryptedCheck
            }
            return decrypted
        }
        
        func savePassword(password: String) {
            
            let stringToSave = encryptKey(keyToEncrypt: password)
            let saveSuccessful:Bool = KeychainWrapper.standard.set(stringToSave, forKey: "NodePassword")
            
            if saveSuccessful {
                
            } else {
                
                print("error saving string")
            }
        }
        
        func saveSSHPassword(password: String) {
            
            let stringToSave = encryptKey(keyToEncrypt: password)
            let saveSuccess:Bool = KeychainWrapper.standard.set(password, forKey: "sshPassword")
            
            if saveSuccess {
                
                print("saved sshPassword from restore")
                
            } else {
                
                print("error saving string")
            }
            
        }
        
        func saveIPAdress(ipAddress: String) {
            
            let stringToSave = encryptKey(keyToEncrypt: ipAddress)
            let saveSuccessful:Bool = KeychainWrapper.standard.set(stringToSave, forKey: "NodeIPAddress")
            
            if saveSuccessful {
                
                
            } else {
                
                print("error saving string")
            }
            
        }
        
        func savePort(port: String) {
            
            let stringToSave = encryptKey(keyToEncrypt: port)
            let saveSuccessful:Bool = KeychainWrapper.standard.set(stringToSave, forKey: "NodePort")
            
            if saveSuccessful {
                
                
            } else {
                
                print("error saving string")
            }
        }
        
        func saveUsername(username: String) {
            
            let stringToSave = encryptKey(keyToEncrypt: username)
            let saveSuccessful:Bool = KeychainWrapper.standard.set(stringToSave, forKey: "NodeUsername")
            
            if saveSuccessful {
                
                
            } else {
                
                print("error saving string")
            }
            
        }
        
        func getCredentials() {
            
            if let userID = UserDefaults.standard.string(forKey: "userID") {
                
                let queryDuplicatePurchase = PFQuery(className: "Nodes")
                queryDuplicatePurchase.whereKey("UserID", equalTo: userID)
                queryDuplicatePurchase.findObjectsInBackground(block: { (objects, error) in
                    
                    if error != nil {
                        
                        print("error = \(error.debugDescription)")
                        
                    } else {
                        
                        if objects!.count > 0 {
                            
                            DispatchQueue.main.async {
                                //add credentials to keychain
                                displayAlert(viewController: PurchaseTableViewController(), title: "Sorry", message: "You have already purchased a node.")
                            }
                            
                        } else {
                            
                            self.deliverPurchaseNotificationFor(identifier: transaction.payment.productIdentifier)
                            SKPaymentQueue.default().finishTransaction(transaction)
                            
                            var ipAddress = ""
                            let query = PFQuery(className: "Nodes")
                            query.whereKey("Used", equalTo: false)
                            query.whereKey("sshKey", equalTo: "")
                            query.findObjectsInBackground(block: { (objects, error) in
                                
                                if error != nil {
                                    
                                    print("error = \(error.debugDescription)")
                                    
                                } else {
                                    
                                    if objects!.count > 0 {
                                        
                                        let node = objects![0]
                                        let password = node["Password"] as! String
                                        let username = node["Username"] as! String
                                        let port = node["Port"] as! String
                                        ipAddress = node["IPAddress"] as! String
                                        let decrpytedPassword = decryptParsePassword(item: password)
                                        let objectID = node.objectId as! String
                                        let query = PFQuery(className:"Nodes")
                                        query.getObjectInBackground(withId: objectID) { (node: PFObject?, error: Error?) in
                                            if let error = error {
                                                print(error.localizedDescription)
                                            } else if let node = node {
                                                node["Used"] = true
                                                //ensure userid gets created for backwards compatibility
                                                if userID != "" {
                                                    node["UserID"] = userID
                                                } else {
                                                    node["UserID"] = "some user ID"
                                                }
                                                node.saveInBackground()
                                                saveUsername(username: username)
                                                savePort(port: port)
                                                savePassword(password: decrpytedPassword)
                                                saveIPAdress(ipAddress: ipAddress)
                                                DispatchQueue.main.async {
                                                KeychainWrapper.standard.set("", forKey: "sshPassword")
                                                    
                                                    let query = PFQuery(className: "Users")
                                                    query.whereKey("userID", equalTo: userID)
                                                    query.findObjectsInBackground(block: { (objects, error) in
                                                        
                                                        if error != nil {
                                                            
                                                            print("error = \(error.debugDescription)")
                                                            
                                                        } else {
                                                            
                                                            if objects!.count > 0 {
                                                                
                                                                let user = objects![0]
                                                                user["PurchasedIP"] = ipAddress
                                                                user["didPurchaseNode"] = true
                                                                user.saveInBackground()
                                                            }
                                                        }
                                                    })
                                                }
                                            }
                                        }
                                    } else {
                                        
                                        //displayAlert(viewController: PurchaseTableViewController(), title: "Sorry", message: "No available nodes at this time, please contact us at bitsense@gmail.com and we will set one up for you.")
                                        let query = PFQuery(className: "Nodes")
                                        query.whereKey("Used", equalTo: false)
                                        query.whereKey("sshKey", equalTo: "12ri7dx6KB3Yw9cC9ZVKwggwjatiopRzF5QnYm1KU0Lo8RpNsTfAmBR3YW3yCgPO1N6AuyvLgRRjnHHiniaegU8qSDHHcHuL4Go4xiwtBW/EFsth48N3LAhbs6gHBYfKCw4q03QtsdH0+fub")
                                        query.findObjectsInBackground(block: { (objects, error) in
                                            
                                            if error != nil {
                                                
                                                print("error = \(error.debugDescription)")
                                                
                                            } else {
                                                
                                                if objects!.count > 0 {
                                                    
                                                    let node = objects![0]
                                                    let password = node["sshKey"] as! String
                                                    print("password = \(password)")
                                                    let username = node["Username"] as! String
                                                    //let port = node["Port"] as! String
                                                    ipAddress = node["IPAddress"] as! String
                                                    //let decrpytedPassword = dec
                                                    let objectID = node.objectId as! String
                                                    let query = PFQuery(className:"Nodes")
                                                    query.getObjectInBackground(withId: objectID) { (node: PFObject?, error: Error?) in
                                                        if let error = error {
                                                            print(error.localizedDescription)
                                                        } else if let node = node {
                                                            node["Used"] = true
                                                            //ensure userid gets created for backwards compatibility
                                                            if userID != "" {
                                                                node["UserID"] = userID
                                                            } else {
                                                                node["UserID"] = "some user ID"
                                                            }
                                                            node.saveInBackground()
                                                            saveUsername(username: username)
                                                            saveSSHPassword(password: password)
                                                            saveIPAdress(ipAddress: ipAddress)
                                                            DispatchQueue.main.async {
                                                                
                                                                
                                                                let query = PFQuery(className: "Users")
                                                                query.whereKey("userID", equalTo: userID)
                                                                query.findObjectsInBackground(block: { (objects, error) in
                                                                    
                                                                    if error != nil {
                                                                        
                                                                        print("error = \(error.debugDescription)")
                                                                        
                                                                    } else {
                                                                        
                                                                        if objects!.count > 0 {
                                                                            
                                                                            let user = objects![0]
                                                                            user["PurchasedIP"] = ipAddress
                                                                            user["didPurchaseNode"] = true
                                                                            user.saveInBackground()
                                                                        }
                                                                    }
                                                                })
                                                            }
                                                        }
                                                    }
                                                    
                                                } else {
                                                    
                                                    displayAlert(viewController: PurchaseTableViewController(), title: "Sorry", message: "No available nodes at this time, please contact us at bitsense@gmail.com and we will set one up for you.")
                                                }
                                                
                                            }
                                            
                                        })
                                        
                                        
                                    }
                                }
                            })
                            
                        }
                    }
                })
            }
        }
        
        getCredentials()
    }
    
    private func fail(transaction: SKPaymentTransaction) {
        print("fail...")
        if let transactionError = transaction.error as NSError?,
            let localizedDescription = transaction.error?.localizedDescription,
            transactionError.code != SKError.paymentCancelled.rawValue {
            print("Transaction Error: \(localizedDescription)")
        }
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    private func deliverPurchaseNotificationFor(identifier: String?) {
        guard let identifier = identifier else { return }
        
        purchasedProductIdentifiers.insert(identifier)
        UserDefaults.standard.set(true, forKey: identifier)
        NotificationCenter.default.post(name: .IAPHelperPurchaseNotification, object: identifier)
    }
}


