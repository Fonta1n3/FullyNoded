//
//  DescriptorsViewController.swift
//  BitSense
//
//  Created by Peter on 22/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class DescriptorsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var descriptors = [[String:Any]]()
    let aes = AESService()
    var descriptor = ""
    var tableArray = [[String:Any]]()
    @IBOutlet var table: UITableView!
    var label = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        table.delegate = self
        table.dataSource = self
        convertToTableArray()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        navigationController?.navigationBar.topItem?.title = "Descriptors"
        
    }
    
    func convertToTableArray() {
        
        let aes = AESService()
        let cd = CoreDataService()
        
        cd.retrieveEntity(entityName: .nodes) {
            
            if !cd.errorBool {
                
                //let nodes = cd.entities
                
                for descriptor in self.descriptors {
                    
                    DispatchQueue.main.async {
                        
                        let dict = descriptor
                        let str = DescriptorStruct(dictionary: dict)
                        let label = aes.decryptKey(keyToDecrypt: str.label)
                        let range = aes.decryptKey(keyToDecrypt: str.range)
                        //var nodeLabel = ""
                        
//                        for n in nodes {
//
//                            let node = NodeStruct(dictionary: n)
//                            let nodeID = node.id
//
//                            if str.nodeID == nodeID {
//
//                                nodeLabel = aes.decryptKey(keyToDecrypt: node.label)
//
//                            }
//
//                        }
                        
                        let d = ["label":label,
                                 "range":range/*,
                                 "nodeID":nodeLabel*/]
                        
                        self.tableArray.append(d)
                        self.table.reloadData()
                        
                    }
                    
                }
                
            } else {
               
                displayAlert(viewController: self, isError: true, message: "error getting nodes from core data")
                
            }
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return tableArray.count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "descriptorsCell", for: indexPath)
        cell.selectionStyle = .none
        let labelLabel = cell.viewWithTag(1) as! UILabel
        let rangeLabel = cell.viewWithTag(2) as! UILabel
        //let nodeLabel = cell.viewWithTag(3) as! UILabel
        let dict = tableArray[indexPath.row]
        let str = DescriptorStruct(dictionary: dict)
        labelLabel.text = str.label
        rangeLabel.text = str.range
        //nodeLabel.text = str.nodeID
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let impact = UIImpactFeedbackGenerator()
        let dict = descriptors[indexPath.row]
        let str = DescriptorStruct(dictionary: dict)
        descriptor = aes.decryptKey(keyToDecrypt: str.descriptor)
        let cell = tableView.cellForRow(at: indexPath)!
        label = tableArray[indexPath.row]["label"] as! String
        
        DispatchQueue.main.async {
            
            impact.impactOccurred()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell.alpha = 1
                    
                }, completion: { _ in
                    
                    self.performSegue(withIdentifier: "showDescriptor", sender: self)
                    
                })
                
            }
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == UITableViewCell.EditingStyle.delete {
            
            let cd = CoreDataService()
            let dict = descriptors[indexPath.row]
            let descriptor = DescriptorStruct(dictionary: dict)
            
            cd.deleteEntity(id: descriptor.id, entityName: .descriptors) {
                
                if !cd.errorBool {
                    
                    let success = cd.boolToReturn
                    
                    if success {
                        
                        DispatchQueue.main.async {
                            
                            self.descriptors.remove(at: indexPath.row)
                            self.tableArray.remove(at: indexPath.row)
                            tableView.deleteRows(at: [indexPath], with: .fade)
                            
                        }
                        
                    } else {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "We had an error trying to delete that descriptor: \(cd.errorDescription)")
                        
                    }
                    
                } else {
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "We had an error trying to delete that descriptor: \(cd.errorDescription)")
                    
                }
                
            }
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "showDescriptor":
            
            if let vc = segue.destination as? DescriptorDisplayerViewController {
                
                vc.descriptor = descriptor
                vc.label = label
                
            }
            
        default:
            
            break
            
        }
        
    }
    
}
