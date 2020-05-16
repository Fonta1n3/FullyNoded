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
        
        let cd = CoreDataService()
        
        cd.retrieveEntity(entityName: .newNodes) { [unowned vc = self] in
            
            if !cd.errorBool {
                
                for descriptor in vc.descriptors {
                    
                    DispatchQueue.main.async { [unowned vc = self] in
                        
                        let dict = descriptor
                        let str = DescriptorStruct(dictionary: dict)
                        let label = str.label
                        let range = str.range
                        
                        let d = [
                            "label":label,
                            "range":range
                        ]
                        
                        vc.tableArray.append(d)
                        vc.table.reloadData()
                        
                    }
                    
                }
                
            } else {
               
                displayAlert(viewController: vc, isError: true, message: "error getting nodes from core data")
                
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
        let dict = tableArray[indexPath.row]
        let str = DescriptorStruct(dictionary: dict)
        labelLabel.text = str.label
        rangeLabel.text = str.range
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let impact = UIImpactFeedbackGenerator()
        let dict = descriptors[indexPath.row]
        let str = DescriptorStruct(dictionary: dict)
        Crypto.decryptData(dataToDecrypt: str.descriptor!) { [unowned vc = self] (desc) in
            if desc != nil {
             
                let cell = tableView.cellForRow(at: indexPath)!
                vc.label = vc.tableArray[indexPath.row]["label"] as! String
                vc.descriptor = desc!.utf8
                DispatchQueue.main.async {
                    
                    impact.impactOccurred()
                    
                    UIView.animate(withDuration: 0.2, animations: {
                        
                        cell.alpha = 0
                        
                    }) { _ in
                        
                        UIView.animate(withDuration: 0.2, animations: {
                            
                            cell.alpha = 1
                            
                        }, completion: { [unowned vc = self] _ in
                            
                            vc.performSegue(withIdentifier: "showDescriptor", sender: vc)
                            
                        })
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == UITableViewCell.EditingStyle.delete {
            
            let cd = CoreDataService()
            let dict = descriptors[indexPath.row]
            let descriptor = DescriptorStruct(dictionary: dict)
            
            cd.deleteNode(id: descriptor.id!, entityName: .newDescriptors) { success in
                
                if success {
                    
                    DispatchQueue.main.async { [unowned vc = self] in
                        
                        vc.descriptors.remove(at: indexPath.row)
                        vc.tableArray.remove(at: indexPath.row)
                        tableView.deleteRows(at: [indexPath], with: .fade)
                        
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
