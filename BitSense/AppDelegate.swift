//
//  AppDelegate.swift
//  BitSense
//
//  Created by Peter on 8/1/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import CoreData
import KeychainSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        UIApplication.shared.statusBarStyle = .lightContent
            
        return true
        
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        
        
        
    }
    
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        addNode(url: "\(url)")
        return true
        
    }
    
    func addNode(url: String) {
        
        //btcrpc://kjhfefe.onion:8332?user=rpcuser&password=rpcpassword?label=nodeName?v2password=uenfieufnuf4
        
        let aes = AESService()
        let cd = CoreDataService()
        let nodes = cd.retrieveEntity(entityName: .nodes)
        let arr1 = url.components(separatedBy: "?")
        let onion = arr1[0].replacingOccurrences(of: "btcrpc://", with: "")
        let arr2 = arr1[1].components(separatedBy: "&")
        let rpcuser = arr2[0].replacingOccurrences(of: "user=", with: "")
        let rpcpassword = arr2[1].replacingOccurrences(of: "password=", with: "")
        
        var label = "Nodl - Tor"
        var v2password = ""
        
        if arr1.count > 2 {
            
            if arr1[2].contains("label=") {
                
                label = arr1[2].replacingOccurrences(of: "label=", with: "")
                
            } else {
                
                v2password = arr1[2].replacingOccurrences(of: "v2password=", with: "")
                
            }
            
            
            if arr1.count > 3 {
                
                v2password = arr1[3].replacingOccurrences(of: "v2password=", with: "")
                
            }
            
        }
        
        var node = [String:Any]()
        let torNodeId = randomString(length: 23)
        let torNodeHost = aes.encryptKey(keyToEncrypt: onion)
        let torNodeRPCPass = aes.encryptKey(keyToEncrypt: rpcpassword)
        let torNodeRPCUser = aes.encryptKey(keyToEncrypt: rpcuser)
        var torNodeLabel = aes.encryptKey(keyToEncrypt: label)
        let torNodeV2Password = aes.encryptKey(keyToEncrypt: v2password)
        
        if label != "" {
            
            torNodeLabel = aes.encryptKey(keyToEncrypt: label)
            
        }
        
        node["id"] = torNodeId
        node["onionAddress"] = torNodeHost
        node["label"] = torNodeLabel
        node["rpcuser"] = torNodeRPCUser
        node["rpcpassword"] = torNodeRPCPass
        node["usingSSH"] = false
        node["isDefault"] = false
        node["usingTor"] = true
        node["isActive"] = true
        
        if v2password != "" {
            
            node["v2password"] = torNodeV2Password
            
        }
        
        let vc = MainMenuViewController()
        
        let success = cd.saveEntity(vc: vc,
                                    dict: node,
                                    entityName: .nodes)
        
        if success {
            
            print("btcrpc node added")
            deActivateOtherNodes(nodes: nodes,
                                 nodeID: torNodeId,
                                 cd: cd,
                                 vc: vc)
            
        } else {
            
            print("error adding btcrpc node")
            
        }
        
    }
    
    func deActivateOtherNodes(nodes: [[String:Any]], nodeID: String, cd: CoreDataService, vc: UIViewController) {
        
        if SSHService.sharedInstance.session != nil {
            
            if SSHService.sharedInstance.session.isConnected {
                
                SSHService.sharedInstance.disconnect()
                SSHService.sharedInstance.commandExecuting = false
                
            }
            
        }
        
        for node in nodes {
            
            let str = NodeStruct(dictionary: node)
            let id = str.id
            let isActive = str.isActive
            
            if id != nodeID && isActive {
                
                let success = cd.updateEntity(viewController: vc,
                                              id: id,
                                              newValue: false,
                                              keyToEdit: "isActive",
                                              entityName: .nodes)
                
                if success {
                    
                    print("nodes deactivated")
                    
                }
                
            }
            
        }
        
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        
        let keychain = KeychainSwift()
        
        if keychain.get("UnlockPassword") != nil {
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let loginVC = storyboard.instantiateViewController(withIdentifier: "LogIn")
            let topVC = self.window?.rootViewController?.topViewController()
            
            if topVC!.restorationIdentifier != "LogIn" {
                
                topVC!.present(loginVC, animated: true, completion: nil)
                
            }
            
        }
        
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "BitSense")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

