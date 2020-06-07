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
        
        cd.retrieveEntity(entityName: .newNodes) { [unowned vc = self] in
            
            if !vc.cd.errorBool {
                
                vc.nodeArray.removeAll()
                for node in vc.cd.entities {
                    if node["id"] != nil {
                        vc.nodeArray.append(node)
                    }
                }
                
                if vc.nodeArray.count == 0 {
                    
                    displayAlert(viewController: vc,
                                 isError: true,
                                 message: "No nodes added yet, tap the + sign to add one")
                    
                }
                
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.nodeTable.reloadData()
                }
                
            } else {
                
               displayAlert(viewController: vc,
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
            
            label.text = nodeArray[indexPath.row]["label"] as? String ?? ""
            
        } else {
            
            label.text = "Tap to edit node label"
            
        }
        
        isActive.isOn = nodeArray[indexPath.row]["isActive"] as? Bool ?? false
        isActive.restorationIdentifier = "\(indexPath.row)"
        isActive.addTarget(self, action: #selector(setActiveNow(_:)), for: .touchUpInside)
        
        if !isActive.isOn {
            
            label.textColor = .darkGray
            
        } else {
            
            label.textColor = .lightGray
            
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
                                                
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "updateNode", sender: self)
                            
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
    
    private func deleteNode(nodeId: UUID, indexPath: IndexPath) {
        cd.deleteNode(id: nodeId, entityName: .newNodes) { [unowned vc = self] success in
            if success {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.nodeArray.remove(at: indexPath.row)
                    vc.nodeTable.deleteRows(at: [indexPath], with: .fade)
                    vc.nodeTable.reloadData()
                }
            } else {
                displayAlert(viewController: vc,
                             isError: true,
                             message: "We had an error trying to delete that node")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            let node = NodeStruct(dictionary: nodeArray[indexPath.row])
            if node.id != nil {
                deleteNode(nodeId: node.id!, indexPath: indexPath)
            }
        }
    }
    
    @objc func setActiveNow(_ sender: UISwitch) {
        print("setactivenow")
        
        impact()
        
        let restId = sender.restorationIdentifier ?? ""
        let index = Int(restId) ?? 10000
        
        guard let selectedCell = nodeTable.cellForRow(at: IndexPath.init(row: index, section: 0)) else {
            return
        }
        
        let selectedSwitch = selectedCell.viewWithTag(2) as! UISwitch
        
        if index < nodeArray.count {
            
            let str = NodeStruct(dictionary: nodeArray[index])
            
            cd.update(id: str.id!, keyToUpdate: "isActive", newValue: selectedSwitch.isOn, entity: .newNodes) { [unowned vc = self] success in
                if success {
                    
                    vc.ud.removeObject(forKey: "walletName")
                    if vc.nodeArray.count == 1 {
                        vc.reloadTable()
                    }
                    
                } else {
                    
                    displayAlert(viewController: vc, isError: true, message: "error updating node")
                    
                }
            }
            
            if nodeArray.count > 1 {
                
                for (i, node) in nodeArray.enumerated() {
                    
                    if i != index {
                        
                        let str = NodeStruct(dictionary: node)
                        
                        cd.update(id: str.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { [unowned vc = self] success in
                            if success {
                                
                                vc.cd.retrieveEntity(entityName: .newNodes) { [unowned vc = self] in
                                    
                                    if !vc.cd.errorBool {
                                        
                                        DispatchQueue.main.async { [unowned vc = self] in
                                            vc.nodeArray.removeAll()
                                            for node in vc.cd.entities {
                                                if node["id"] != nil {
                                                    vc.nodeArray.append(node)
                                                }
                                            }
                                            vc.nodeTable.reloadData()
                                            NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                                        }
                                        
                                    } else {
                                        
                                        displayAlert(viewController: vc, isError: true, message: vc.cd.errorDescription)
                                        
                                    }
                                    
                                }
                                
                            } else {
                                
                                displayAlert(viewController: vc, isError: true, message: "error updating node")
                                
                            }
                        }
                        
                    }
                    
                }
                
            }
            
        } else {
            
            print("node count is wrong")
            
        }
        
    }
    
    func reloadTable() {
        
        cd.retrieveEntity(entityName: .newNodes) {
            
            if !self.cd.errorBool {
                
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.nodeArray.removeAll()
                    for node in vc.cd.entities {
                        if node["id"] != nil {
                            vc.nodeArray.append(node)
                        }
                    }
                    vc.nodeTable.reloadData()
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
                let isActive = str.isActive
                if isActive {
                    cd.update(id: str.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { [unowned vc = self] success in
                        if !success {
                            displayAlert(viewController: vc, isError: true, message: vc.cd.errorDescription)
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
        
        deActivateNodes(nodes: nodeArray) {
            
            DispatchQueue.main.async {
                
                self.performSegue(withIdentifier: "addNewNode", sender: self)
                
            }
            
        }
        
    }
    

}
