//
//  NodesViewController.swift
//  BitSense
//
//  Created by Peter on 29/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class NodesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var nodeArray = [[String:Any]]()
    var selectedIndex = Int()
    let cd = CoreDataService()
    let ud = UserDefaults.standard
    @IBOutlet var nodeTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        nodeTable.tableFooterView = UIView(frame: .zero)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        nodeArray.removeAll()
        getNodes()
        
    }
    
    func getNodes() {
        
        cd.retrieveEntity(entityName: .nodes) {
            
            if !self.cd.errorBool {
                
                self.nodeArray = self.cd.entities
                
                if self.nodeArray.count == 0 {
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "No nodes added yet, tap the + sign to add one")
                    
                }
                
                DispatchQueue.main.async {
                    self.nodeTable.reloadData()
                }
                
            } else {
                
               displayAlert(viewController: self,
                            isError: true,
                            message: "error getting nodes from core data")
                
            }
            
        }
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return nodeArray.count
        
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "node", for: indexPath)
        let label = cell.viewWithTag(1) as! UILabel
        let isActive = cell.viewWithTag(2) as! UISwitch
        
        if nodeArray[indexPath.row]["label"] != nil {
            
            let aes = AESService()
            let enc = (nodeArray[indexPath.row]["label"] as! String)
            label.text = aes.decryptKey(keyToDecrypt: enc)
            
        } else {
            
            label.text = "Tap to edit node label"
            
        }
        
        isActive.isOn = nodeArray[indexPath.row]["isActive"] as? Bool ?? false
        isActive.restorationIdentifier = "\(indexPath.row)"
        isActive.addTarget(self, action: #selector(setActiveNow(_:)), for: .touchUpInside)
        
        if !isActive.isOn {
            
            label.textColor = UIColor.lightText
            
        } else {
            
            label.textColor = UIColor.white
            
        }
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        selectedIndex = indexPath.row
        
        guard let cell = nodeTable.cellForRow(at: IndexPath.init(row: indexPath.row, section: 0)) else {
            return
        }
        
        DispatchQueue.main.async {
            
            impact()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell.alpha = 0
                
            }, completion: { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell.alpha = 1
                    
                }, completion: { _ in
                    
                    if self.selectedIndex < self.nodeArray.count {
                        
                        let node = self.nodeArray[self.selectedIndex]
                        let str = NodeStruct(dictionary: node)
                        
                        if !str.isDefault {
                            
                            DispatchQueue.main.async {
                                
                                self.performSegue(withIdentifier: "updateNode", sender: self)
                                
                            }
                            
                        } else {
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "You can not edit the testing node")
                            
                        }
                        
                    }
                    
                })
                
            })
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "updateNode" {
            
            if let vc = segue.destination as? NodeDetailViewController {
                
                vc.selectedNode = self.nodeArray[selectedIndex]
                vc.createNew = false
                
            }
            
        }
        
        if segue.identifier == "addNewNode" {
            
            if let vc = segue.destination as? ChooseConnectionTypeViewController {
                
                vc.isUpdating = false
                
            }
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == UITableViewCell.EditingStyle.delete {
            
            let node = NodeStruct(dictionary: nodeArray[indexPath.row])
            
            cd.deleteEntity(id: node.id, entityName: .nodes) {
                
                if !self.cd.errorBool {
                    
                    let success = self.cd.boolToReturn
                    
                    if success {
                        
                        DispatchQueue.main.async {
                            
                            self.nodeArray.remove(at: indexPath.row)
                            self.nodeTable.deleteRows(at: [indexPath], with: .fade)
                            self.nodeTable.reloadData()
                            
                        }
                        
                    } else {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "We had an error trying to delete that node: \(self.cd.errorDescription)")
                        
                    }
                    
                } else {
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "We had an error trying to delete that node: \(self.cd.errorDescription)")
                    
                }
                
            }
            
        }
        
    }
    
    @objc func setActiveNow(_ sender: UISwitch) {
        print("setactivenow")
        
        if TorClient.sharedInstance.isOperational {
            
            TorClient.sharedInstance.resign()
            
        }
        
        impact()
        
        let restId = sender.restorationIdentifier ?? ""
        let index = Int(restId) ?? 10000
        
        guard let selectedCell = nodeTable.cellForRow(at: IndexPath.init(row: index, section: 0)) else {
            return
        }
        
        let selectedSwitch = selectedCell.viewWithTag(2) as! UISwitch
        
        if index < nodeArray.count {
            
            let str = NodeStruct(dictionary: nodeArray[index])
            
            if !selectedSwitch.isOn {
                
                let d:[String:Any] = ["id":str.id,"newValue":false,"keyToEdit":"isActive","entityName":ENTITY.nodes]
                cd.updateEntity(dictsToUpdate: [d]) {
                    
                    if !self.cd.errorBool {
                        
                        let success = self.cd.boolToReturn
                        
                        if success {
                            
                            self.removeWalletReloadTable()
                            
                        } else {
                            
                            displayAlert(viewController: self, isError: true, message: "error updating node")
                            
                        }
                        
                    } else {
                        
                        displayAlert(viewController: self, isError: true, message: self.cd.errorDescription)
                        
                    }
                    
                }
                
            } else {
                
                let d:[String:Any] = ["id":str.id,"newValue":true,"keyToEdit":"isActive","entityName":ENTITY.nodes]
                cd.updateEntity(dictsToUpdate: [d]) {
                    
                    if !self.cd.errorBool {
                        
                        let success = self.cd.boolToReturn
                        
                        if success {
                            
                            self.removeWalletReloadTable()
                            
                        } else {
                            
                            displayAlert(viewController: self, isError: true, message: "error updating node")
                            
                        }
                        
                    } else {
                        
                        displayAlert(viewController: self, isError: true, message: self.cd.errorDescription)
                        
                    }
                    
                }
                
            }
            
            if nodeArray.count > 1 {
                
                for (i, node) in nodeArray.enumerated() {
                    
                    if i != index {
                        
                        let str = NodeStruct(dictionary: node)
                        let d:[String:Any] = ["id":str.id,"newValue":false,"keyToEdit":"isActive","entityName":ENTITY.nodes]
                        cd.updateEntity(dictsToUpdate: [d]) {
                            
                            if !self.cd.errorBool {
                                
                                let success = self.cd.boolToReturn
                                
                                if success {
                                    
                                    self.cd.retrieveEntity(entityName: .nodes) {
                                        
                                        if !self.cd.errorBool {
                                            
                                            DispatchQueue.main.async {
                                                self.nodeArray = self.cd.entities
                                                self.nodeTable.reloadData()
                                            }
                                            
                                        } else {
                                            
                                            displayAlert(viewController: self, isError: true, message: self.cd.errorDescription)
                                            
                                        }
                                        
                                    }
                                    
                                } else {
                                    
                                    displayAlert(viewController: self, isError: true, message: "error getting nodes form core data")
                                    
                                }
                                
                            } else {
                                
                                displayAlert(viewController: self, isError: true, message: self.cd.errorDescription)
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            }
            
        } else {
            
            print("node count is wrong")
            
        }
        
    }
    
    func removeWalletReloadTable() {
        print("removeWalletReloadTable")
        
        ud.removeObject(forKey: "walletName")
        
        cd.retrieveEntity(entityName: .nodes) {
            
            if !self.cd.errorBool {
                
                DispatchQueue.main.async {
                    self.nodeArray = self.cd.entities
                    self.nodeTable.reloadData()
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "error getting nodes from core data")
                
            }
            
        }
        
    }
    
    private func deActivateNodes(nodes: [[String:Any]], completion: @escaping () -> Void) {
        
        if nodes.count > 0 {
            
            for node in nodes {
                
                let str = NodeStruct(dictionary: node)
                let id = str.id
                let isActive = str.isActive
                
                if isActive {
                    
                    let d1:[String:Any] = ["id":id,"newValue":false,"keyToEdit":"isActive","entityName":ENTITY.nodes]
                    
                    cd.updateEntity(dictsToUpdate: [d1]) {
                        
                        if !self.cd.errorBool {
                            
                            let success = self.cd.boolToReturn
                            
                            if success {
                                
                                //completion()
                                
                            } else {
                                
                                displayAlert(viewController: self, isError: true, message: "Error deactivating nodes")
                                //completion()
                                
                            }
                            
                        } else {
                            
                            displayAlert(viewController: self, isError: true, message: self.cd.errorDescription)
                            //completion()
                            
                        }
                        
                    }
                    
                }
                
            }
            
            completion()
                        
        } else {
            
            completion()
            
        }
                
    }
    
    @IBAction func addNode(_ sender: Any) {
        
        // Deactivate nodes here when adding a node to simplify QR scanning issues
        
        deActivateNodes(nodes: self.nodeArray) {
            
            DispatchQueue.main.async {
                
                self.performSegue(withIdentifier: "addNewNode", sender: self)
                
            }
            
        }
        
    }
    

}
