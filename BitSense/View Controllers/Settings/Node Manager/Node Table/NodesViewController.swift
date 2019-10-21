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
        nodeTable.reloadData()
        
    }
    
    func getNodes() {
        
        nodeArray = cd.retrieveEntity(entityName: ENTITY.nodes)
        
        if nodeArray.count == 0 {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "No nodes added yet, tap the + sign to add one")
            
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
        let cell = nodeTable.cellForRow(at: IndexPath.init(row: indexPath.row, section: 0))!
        
        DispatchQueue.main.async {
            
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell.alpha = 0
                
            }, completion: { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell.alpha = 1
                    
                }, completion: { _ in
                    
                    if !(self.nodeArray[self.selectedIndex]["isDefault"] as! Bool) {
                        
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "updateNode", sender: self)
                            
                        }
                        
                    } else {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "You can not edit the testing node")
                        
                    }
                    
                })
                
            })
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "updateNode" {
            
            if let vc = segue.destination as? ChooseConnectionTypeViewController {
                
                vc.selectedNode = self.nodeArray[selectedIndex]
                vc.isUpdating = true
                
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
            
            //let success = cd.deleteNode(viewController: self, id: nodeArray[indexPath.row]["id"] as! String)
            let success = cd.deleteEntity(viewController: self,
                                          id: node.id,
                                          entityName: .nodes)
            
            if success {
                
                nodeArray.remove(at: indexPath.row)
                nodeTable.deleteRows(at: [indexPath], with: .fade)
                nodeTable.reloadData()
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "We had an error trying to delete that node")
                
            }
            
        }
        
    }
    
    @objc func setActiveNow(_ sender: UISwitch) {
        
        if SSHService.sharedInstance.session != nil {
            
            if SSHService.sharedInstance.session.isConnected {
                
                SSHService.sharedInstance.disconnect()
                SSHService.sharedInstance.commandExecuting = false
                
            }
            
        }
        
        DispatchQueue.main.async {
            
            UIImpactFeedbackGenerator().impactOccurred()
            
        }
        
        let index = Int(sender.restorationIdentifier!)!
        
        let selectedCell = nodeTable.cellForRow(at: IndexPath.init(row: index, section: 0))!
        let selectedSwitch = selectedCell.viewWithTag(2) as! UISwitch
        let id = nodeArray[index]["id"] as! String
        
        if !selectedSwitch.isOn {
            
            //turned off
            //let success = cd.updateNode(viewController: self, id: id, newValue: false, keyToEdit: "isActive")
            let success = cd.updateEntity(viewController: self,
                                          id: id,
                                          newValue: false,
                                          keyToEdit: "isActive",
                                          entityName: ENTITY.nodes)
            
            if success {
                
                ud.removeObject(forKey: "walletName")//removes active wallet name
                nodeArray = cd.retrieveEntity(entityName: ENTITY.nodes)
                nodeTable.reloadData()
                
            }
            
        } else {
            
            //turned on
            //let success = cd.updateNode(viewController: self, id: id, newValue: true, keyToEdit: "isActive")
            let success = cd.updateEntity(viewController: self,
                                          id: id,
                                          newValue: true,
                                          keyToEdit: "isActive",
                                          entityName: ENTITY.nodes)
            
            if success {
                
                ud.removeObject(forKey: "walletName")//removes active wallet name
                nodeArray = cd.retrieveEntity(entityName: ENTITY.nodes)
                nodeTable.reloadData()
                
            }
            
        }
        
        if nodeArray.count > 1 {
            
            for (i, node) in nodeArray.enumerated() {
                
                if i != index {
                    
                    let id = node["id"] as! String
                    
                    let success = cd.updateEntity(viewController: self,
                                                  id: id,
                                                  newValue: false,
                                                  keyToEdit: "isActive",
                                                  entityName: .nodes)
                    
                    if success {
                        
                        nodeArray = cd.retrieveEntity(entityName: .nodes)
                        nodeTable.reloadData()
                        
                    }
                    
                }
                
            }
            
        }
        
    }


}
