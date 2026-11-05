//
//  CoreDataService.swift
//  BitSense
//
//  Created by Peter on 04/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class CoreDataService {
    
    /// The app's Core Data context. Only used on the main queue.
    private static var context: NSManagedObjectContext? {
        (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
    }
    
    private static func save(_ context: NSManagedObjectContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }
    
    /// The saved objects of `entity` whose "id" is `id`.
    private static func objects(id: UUID, entity: ENTITY, in context: NSManagedObjectContext) -> [NSManagedObject] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entity.rawValue)
        fetchRequest.returnsObjectsAsFaults = false
        let results = (try? context.fetch(fetchRequest)) ?? []
        return results.filter { $0.value(forKey: "id") as? UUID == id }
    }
    
    class func saveEntity(dict: [String:Any], entityName: ENTITY, completion: @escaping ((Bool)) -> Void) {
        DispatchQueue.main.async {
            guard !dict.isEmpty, let context = context,
                  let entity = NSEntityDescription.entity(forEntityName: entityName.rawValue, in: context) else {
                completion(false)
                return
            }

            let object = NSManagedObject(entity: entity, insertInto: context)
            for (key, value) in dict {
                object.setValue(value, forKey: key)
            }
            completion(save(context))
        }
    }
    
    class func retrieveEntity(entityName: ENTITY, completion: @escaping (([[String:Any]]?)) -> Void) {
        DispatchQueue.main.async {
            guard let context = context else {
                completion(nil)
                return
            }
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName.rawValue)
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.resultType = .dictionaryResultType
            completion((try? context.fetch(fetchRequest)) as? [[String:Any]])
        }
    }
    
    class func deleteAllData(entity: ENTITY, completion: @escaping ((Bool)) -> Void) {
        DispatchQueue.main.async {
            guard let context = context else {
                completion(false)
                return
            }
            
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entity.rawValue)
            guard let objects = try? context.fetch(fetchRequest) else {
                completion(false)
                return
            }
            objects.forEach(context.delete)
            completion(save(context))
        }
    }
    
    /// Sets `keyToUpdate` on the object with this id; nil clears it.
    /// `completion(false)` if there's no such object.
    class func update(id: UUID, keyToUpdate: String, newValue: Any?, entity: ENTITY, completion: @escaping ((Bool)) -> Void) {
        DispatchQueue.main.async {
            guard let context = context else {
                completion(false)
                return
            }
            
            let matches = objects(id: id, entity: entity, in: context)
            guard !matches.isEmpty else {
                completion(false)
                return
            }
            matches.forEach { $0.setValue(newValue, forKey: keyToUpdate) }
            completion(save(context))
        }
    }
    
    class func deleteValue(id: UUID, keyToDelete: String, entity: ENTITY, completion: @escaping ((Bool)) -> Void) {
        update(id: id, keyToUpdate: keyToDelete, newValue: nil, entity: entity, completion: completion)
    }
    
    /// `completion(false)` if there's no object with this id.
    class func deleteEntity(id: UUID, entityName: ENTITY, completion: @escaping ((Bool)) -> Void) {
        DispatchQueue.main.async {
            guard let context = context else {
                completion(false)
                return
            }
            
            let matches = objects(id: id, entity: entityName, in: context)
            guard !matches.isEmpty else {
                completion(false)
                return
            }
            matches.forEach(context.delete)
            completion(save(context))
        }
    }
}
