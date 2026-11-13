//
//  AppDelegate.swift
//  BitSense
//
//  Created by Fontaine on 8/1/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        builder.remove(menu: .help)
        let helpCommand = UIKeyCommand(input: "H", modifierFlags: [.command], action: #selector(openHelp))
        helpCommand.title = "Fully Noded FAQ"
        let helpMenu = UIMenu(title: "Fully Noded FAQ", image: nil, identifier: UIMenu.Identifier("guide"), options: .displayInline, children: [helpCommand])
        builder.insertChild(helpMenu, atStartOfMenu: .application)
    }
    
    @objc func openHelp() {
        UIApplication.shared.open(URL(string: "https://www.fullynoded.app/faq")!)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Remove the temporary BDK database and old exports that earlier versions left in
        // Documents, which is visible in the Files app / Finder.
        WalletLogic.shared.cleanUpLegacyDocuments()
        // Save each signer's silent payment address and scan key while its seed words exist.
        SignerSilentPayment.backfillAll()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        self.saveContext()
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "BitSense")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
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
                #if DEBUG
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
                #endif
            }
        }
    }
}

