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
    
    var entities = [[String:Any]]()
    var boolToReturn = Bool()
    var errorBool = Bool()
    var errorDescription = ""
    
    func saveEntity(dict: [String:Any], entityName: ENTITY, completion: @escaping () -> Void) {
        print("saveEntityToCoreData")
        
        DispatchQueue.main.async {
            
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                
                let context = appDelegate.persistentContainer.viewContext
                guard let entity = NSEntityDescription.entity(forEntityName: entityName.rawValue, in: context) else {
                    self.errorBool = true
                    self.errorDescription = "unable to access \(entityName.rawValue)"
                    completion()
                    return
                }
                
                let credential = NSManagedObject(entity: entity, insertInto: context)
                
                for (key, value) in dict {
                    
                    credential.setValue(value, forKey: key)
                    
                    do {
                        
                        try context.save()
                        self.boolToReturn = true
                        print("Saved credential \(key) = \(value)")
                        
                    } catch {
                        
                        self.errorBool = true
                        self.errorDescription = "Failed saving credential \(key) = \(value)"
                        
                    }
                    
                }
                
                completion()
                
            } else {
                
                self.errorBool = true
                self.errorDescription = "Unable to access app delegate for core data"
                completion()
                
            }
            
        }
        
    }
    
    func retrieveEntity(entityName: ENTITY, completion: @escaping () -> Void) {
        print("retrieveEntity")
        
        DispatchQueue.main.async {

            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                print("got app delegate")

                let context = appDelegate.persistentContainer.viewContext
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName.rawValue)
                fetchRequest.returnsObjectsAsFaults = false
                fetchRequest.resultType = .dictionaryResultType
                
                do {
                    
                    if let results = try context.fetch(fetchRequest) as? [[String:Any]] {
                            
                        self.entities = results
                        self.errorBool = false
                        completion()
                                                
                    }
                    
                } catch {
                    
                    print("Failed getting nodes")
                    self.errorBool = true
                    self.errorDescription = "failed getting nodes"
                    completion()
                    
                }

            } else {

                print("error can't access app delegate")
                self.errorBool = true
                self.errorDescription = "error can't access app delegate"
                completion()
                
            }

        }
        
    }
    
    func updateEntity(dictsToUpdate: [[String:Any]], completion: @escaping () -> Void) {
        print("updateEntity")
        
        for (i, d) in dictsToUpdate.enumerated() {
            
            var newValue:Any!
            
            let id = d["id"] as! String
            
            if let newValueCheck = d["newValue"] as? String {
                
                newValue = newValueCheck
                
            } else if let newValueCheck = d["newValue"] as? Bool {
                
                newValue = newValueCheck
                
            }
            
            let keyToEdit = d["keyToEdit"] as! String
            let entityName = d["entityName"] as! ENTITY
            
            DispatchQueue.main.async {
                
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    
                    let context = appDelegate.persistentContainer.viewContext
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName.rawValue)
                    fetchRequest.returnsObjectsAsFaults = false
                    
                    do {
                        
                        let results = try context.fetch(fetchRequest) as [NSManagedObject]
                        
                        if results.count > 0 {
                            
                            for data in results {
                                
                                if id == data.value(forKey: "id") as? String {
                                    
                                    data.setValue(newValue, forKey: keyToEdit)
                                    
                                    do {
                                        
                                        try context.save()
                                        self.errorBool = false
                                        self.boolToReturn = true
                                        print("updated successfully")
                                        
                                    } catch {
                                        
                                        print("error editing")
                                        self.errorBool = true
                                        self.errorDescription = "error editing"
                                        
                                    }
                                    
                                }
                                
                            }
                            
                            if i == dictsToUpdate.count - 1 {
                                
                                completion()
                                
                            }
                                                        
                        } else {
                            
                            print("no results")
                            self.errorBool = true
                            self.errorDescription = "no results"
                            completion()
                        }
                        
                    } catch {
                        
                        print("Failed")
                        self.errorBool = true
                        self.errorDescription = "failed"
                        completion()
                    }
                    
                } else {
                    
                    self.errorBool = true
                    self.errorDescription = "Something strange has happened and we do not have access to app delegate, please try again."
                    completion()
                    
                }
                
            }
            
        }
        
    }
    
    func update(id: UUID, keyToUpdate: String, newValue: Any, entity: ENTITY, completion: @escaping ((Bool)) -> Void) {
        
        DispatchQueue.main.async {
            
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                
                let context = appDelegate.persistentContainer.viewContext
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entity.rawValue)
                fetchRequest.returnsObjectsAsFaults = false
                
                do {
                    
                    let results = try context.fetch(fetchRequest) as [NSManagedObject]
                    
                    if results.count > 0 {
                        
                        for data in results {
                            
                            if id == data.value(forKey: "id") as? UUID {
                                
                                data.setValue(newValue, forKey: keyToUpdate)
                                
                                do {
                                    
                                    try context.save()
                                    completion(true)
                                    
                                } catch {
                                    
                                    completion(false)
                                    
                                }
                                
                            }
                            
                        }
                        
                    } else {
                        
                        completion(false)
                    }
                    
                } catch {
                    
                    completion(false)
                }
                
            } else {
                
                completion(false)
                
            }
            
        }
        
    }
    
    func deleteEntity(id: String, entityName: ENTITY, completion: @escaping () -> Void) {
        
        DispatchQueue.main.async {
            
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                
                let context = appDelegate.persistentContainer.viewContext
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName.rawValue)
                fetchRequest.returnsObjectsAsFaults = false
                
                do {
                    
                    let results = try context.fetch(fetchRequest) as [NSManagedObject]
                    
                    if results.count > 0 {
                        
                        for (index, data) in results.enumerated() {
                            
                            if id == data.value(forKey: "id") as? String {
                                
                                context.delete(results[index] as NSManagedObject)
                                
                                do {
                                    
                                    try context.save()
                                    print("deleted succesfully")
                                    self.boolToReturn = true
                                    self.errorBool = false
                                    
                                } catch {
                                    
                                    print("error deleting")
                                    self.boolToReturn = false
                                    self.errorBool = true
                                    self.errorDescription = "error deleting"
                                    
                                }
                                
                            }
                            
                        }
                        
                        completion()
                        
                    } else {
                        
                        print("no results")
                        self.errorBool = true
                        self.errorDescription = "no results for that entity to delete"
                        completion()
                        
                    }
                    
                } catch {
                    
                    print("Failed")
                    self.errorBool = true
                    self.errorDescription = "failed trying to delete that entity"
                    completion()
                    
                }
                
            } else {
                
                self.errorBool = true
                self.errorDescription = "failed getting the app delegate"
                completion()
                
            }
            
        }
                
    }
    
    func deleteNode(id: UUID, entityName: ENTITY, completion: @escaping ((Bool)) -> Void) {
        
        DispatchQueue.main.async {
            
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                
                let context = appDelegate.persistentContainer.viewContext
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName.rawValue)
                fetchRequest.returnsObjectsAsFaults = false
                
                do {
                    
                    let results = try context.fetch(fetchRequest) as [NSManagedObject]
                    
                    if results.count > 0 {
                        
                        for (index, data) in results.enumerated() {
                            
                            if id == data.value(forKey: "id") as? UUID {
                                
                                context.delete(results[index] as NSManagedObject)
                                
                                do {
                                    
                                    try context.save()
                                    completion(true)
                                    
                                } catch {
                                    
                                    completion(false)
                                    
                                }
                                
                            }
                            
                        }
                                                
                    } else {
                        
                        completion(false)
                        
                    }
                    
                } catch {
                    
                    completion(false)
                    
                }
                
            } else {
                
                completion(false)
                
            }
            
        }
                
    }
    
}
