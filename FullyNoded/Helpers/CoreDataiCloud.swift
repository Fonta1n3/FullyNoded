//
//  CoreDataiCloud.swift
//  FullyNoded
//
//  Created by Peter Denton on 8/5/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation
import CoreData

class CoreDataiCloud {
    
    static var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "Backup")
        
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Could not retrieve a persistent store description.")
        }
        
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.fullynoded.backup")
        
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                //fatalError("Unresolved error \(error), \(error.userInfo)")
                print("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    static var viewContext: NSManagedObjectContext {
        let viewContext = CoreDataiCloud.persistentContainer.viewContext
        viewContext.automaticallyMergesChangesFromParent = true
        return viewContext
    }
        
    class func saveContext() {
        DispatchQueue.main.async {
            let context = CoreDataiCloud.viewContext
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    let nserror = error as NSError
                    print("Unresolved error \(nserror), \(nserror.userInfo)")
                    //fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
                }
            }
        }
    }
    
    class func saveEntity(entity: ENTITY_BACKUP, dict: [String:Any], completion: @escaping ((Bool)) -> Void) {
        DispatchQueue.main.async {
            let context = CoreDataiCloud.viewContext
            
            guard let entity = NSEntityDescription.entity(forEntityName: entity.rawValue, in: context) else {
                completion((false))
                return
            }

            let credential = NSManagedObject(entity: entity, insertInto: context)
            var success = false

            for (key, value) in dict {
                credential.setValue(value, forKey: key)
                do {
                    try context.save()
                    success = true
                } catch {
                }
            }
            completion(success)
        }
    }
    
    class func deleteEntity(entity: ENTITY_BACKUP, completion: @escaping ((Bool)) -> Void) {
        DispatchQueue.main.async {
            let context = CoreDataiCloud.viewContext
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity.rawValue)
            fetchRequest.returnsObjectsAsFaults = false
            do {
                let stuff = try context.fetch(fetchRequest)
                for thing in stuff as! [NSManagedObject] {
                    context.delete(thing)
                }
                try context.save()
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
    
    class func retrieveEntity(entity: ENTITY_BACKUP, completion: @escaping (([[String:Any]]?)) -> Void) {
        DispatchQueue.main.async {
            let context = CoreDataiCloud.viewContext
            var fetchRequest:NSFetchRequest<NSFetchRequestResult>? = NSFetchRequest<NSFetchRequestResult>(entityName: entity.rawValue)
            fetchRequest?.returnsObjectsAsFaults = false
            fetchRequest?.resultType = .dictionaryResultType
            
            do {
                if fetchRequest != nil {
                    if let results = try context.fetch(fetchRequest!) as? [[String:Any]] {
                        fetchRequest = nil
                        completion((results))
                    } else {
                        fetchRequest = nil
                        completion((nil))
                    }
                }
            } catch {
                fetchRequest = nil
                completion((nil))
            }
        }
    }
    
}
