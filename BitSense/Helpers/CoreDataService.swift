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
    
    func saveEntity(vc: UIViewController, dict: [String:Any], entityName: ENTITY) -> Bool {
        print("saveEntityToCoreData")
        
        var success = Bool()
        var appDelegate = AppDelegate()
        
        if let appDelegateCheck = UIApplication.shared.delegate as? AppDelegate {
            
            appDelegate = appDelegateCheck
            let context = appDelegate.persistentContainer.viewContext
            guard let entity = NSEntityDescription.entity(forEntityName: entityName.rawValue, in: context) else {
                success = false
                return success
            }
            let credential = NSManagedObject(entity: entity, insertInto: context)
            
            for (key, value) in dict {
                
                credential.setValue(value, forKey: key)
                
                do {
                    
                    try context.save()
                    success = true
                    print("Saved credential \(key) = \(value)")
                    
                } catch {
                    
                    print("Failed saving credential \(key) = \(value)")
                    success = false
                    
                }
                
            }
            
        } else {
            
            displayAlert(viewController: vc, isError: true, message: "Unable to convert credentials to coredata.")
            success = false
            
        }
        
        return success
        
    }
    
    func retrieveEntity(entityName: ENTITY) -> [[String:Any]] {
        print("retrieveEntity")
        
        var array = [[String:Any]]()
        var appDelegate = AppDelegate()
        
        DispatchQueue.main.async {
            
            if let appDelegateCheck = UIApplication.shared.delegate as? AppDelegate {
                
                appDelegate = appDelegateCheck
                
            } else {
                
                print("error can't access app delegate")
                
            }
            
        }
        
        let context = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName.rawValue)
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.resultType = .dictionaryResultType
        
        do {
            
            if let results = try context.fetch(fetchRequest) as? [[String:Any]] {
                
                if results.count > 0 {
                    
                    for entity in results {
                        
                        array.append(entity)
                        
                    }
                    
                }
                
            }
            
        } catch {
            
            print("Failed")
            
        }
    
        return array
        
    }
    
    func updateEntity(viewController: UIViewController, id: String, newValue: Any, keyToEdit: String, entityName: ENTITY) -> Bool {
        
        var boolToReturn = Bool()
        var appDelegate = AppDelegate()
        
        DispatchQueue.main.async {
            
            if let appDelegateCheck = UIApplication.shared.delegate as? AppDelegate {
                
                appDelegate = appDelegateCheck
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
                                    boolToReturn = true
                                    print("updated successfully")
                                    
                                } catch {
                                    
                                    print("error editing")
                                    boolToReturn = false
                                    
                                }
                                
                            }
                            
                        }
                        
                    } else {
                        
                        print("no results")
                        boolToReturn = false
                        
                    }
                    
                } catch {
                    
                    print("Failed")
                    boolToReturn = false
                    
                }
                
            } else {
                
                boolToReturn = false
                
                displayAlert(viewController: viewController,
                             isError: true,
                             message: "Something strange has happened and we do not have access to app delegate, please try again.")
                
            }
            
        }
        
        return boolToReturn
        
    }
    
    func deleteEntity(viewController: UIViewController, id: String, entityName: ENTITY) -> Bool {
        
        var boolToReturn = Bool()
        var appDelegate = AppDelegate()
        
        DispatchQueue.main.async {
            
            if let appDelegateCheck = UIApplication.shared.delegate as? AppDelegate {
                
                appDelegate = appDelegateCheck
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
                                    boolToReturn = true
                                    
                                } catch {
                                    
                                    print("error deleting")
                                    print("deleted succesfully")
                                    boolToReturn = false
                                    
                                }
                                
                            }
                            
                        }
                        
                    } else {
                        
                        print("no results")
                        boolToReturn = false
                        
                    }
                    
                } catch {
                    
                    print("Failed")
                    boolToReturn = false
                    
                }
                
            } else {
                
                boolToReturn = false
                displayAlert(viewController: viewController, isError: true, message: "Something strange has happened and we do not have access to app delegate, please try again.")
                
            }
            
        }
        
        return boolToReturn
        
    }
    
}
