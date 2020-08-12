//
//  NodesViewController.swift
//  BitSense
//
//  Created by Peter on 29/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class NodesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UINavigationControllerDelegate {
    
    var colors = [UIColor.systemIndigo, UIColor.systemOrange, UIColor.systemGreen, UIColor.systemBlue, UIColor.systemYellow, UIColor.systemPurple, UIColor.systemPink]
    var nodeArray = [[String:Any]]()
    var selectedIndex = Int()
    let ud = UserDefaults.standard
    var addButton = UIBarButtonItem()
    var editButton = UIBarButtonItem()
    @IBOutlet var nodeTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        nodeTable.tableFooterView = UIView(frame: .zero)
        addButton = UIBarButtonItem.init(barButtonSystemItem: .add, target: self, action: #selector(addNode))
        editButton = UIBarButtonItem.init(barButtonSystemItem: .edit, target: self, action: #selector(editNodes))
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        nodeArray.removeAll()
        getNodes()
    }
    
    @IBAction func addLightningNode(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToAddLightningNode", sender: vc)
        }
    }
    
    func getNodes() {
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { [unowned vc = self] nodes in
            if nodes != nil {
                vc.nodeArray.removeAll()
                for node in nodes! {
                    let nodeStr = NodeStruct(dictionary: node)
                    if nodeStr.id != nil && !nodeStr.isLightning {
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
        return nodeArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    private func decryptedValue(_ encryptedValue: Data) -> String {
        var decryptedValue = ""
        Crypto.decryptData(dataToDecrypt: encryptedValue) { decryptedData in
            if decryptedData != nil {
                decryptedValue = decryptedData!.utf8
            }
        }
        return decryptedValue
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "node", for: indexPath)
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        let label = cell.viewWithTag(1) as! UILabel
        let isActive = cell.viewWithTag(2) as! UISwitch
        let background = cell.viewWithTag(3)!
        let icon = cell.viewWithTag(4) as! UIImageView
        let button = cell.viewWithTag(5) as! UIButton
        button.restorationIdentifier = "\(indexPath.section)"
        button.addTarget(self, action: #selector(editNode(_:)), for: .touchUpInside)
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        
        let nodeStruct = NodeStruct.init(dictionary: nodeArray[indexPath.section])
        let dec = decryptedValue(nodeStruct.onionAddress!)
        let abbreviated = reduced(label: dec)
        label.text = abbreviated//nodeArray[indexPath.row]["label"] as? String ?? ""
        isActive.isOn = nodeArray[indexPath.section]["isActive"] as? Bool ?? false
        isActive.restorationIdentifier = "\(indexPath.section)"
        isActive.addTarget(self, action: #selector(setActiveNow(_:)), for: .touchUpInside)
        if !isActive.isOn {
            label.textColor = .darkGray
        } else {
            label.textColor = .white
        }
        icon.tintColor = .white
        icon.image = UIImage(systemName: "desktopcomputer")
        if nodeArray.count < 7 {
            background.backgroundColor = colors[indexPath.section]
        } else {
            background.backgroundColor = colors.randomElement()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .white
        textLabel.frame = CGRect(x: 0, y: 0, width: 400, height: 50)
        textLabel.text =  nodeArray[section]["label"] as? String ?? "No Label"
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    @objc func editNode(_ sender: UIButton) {
        if sender.restorationIdentifier != nil {
            if let section = Int(sender.restorationIdentifier!) {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.selectedIndex = section
                    vc.performSegue(withIdentifier: "updateNode", sender: vc)
                }
            }
        }
    }
    
    @objc func editNodes() {
        
        nodeTable.setEditing(!nodeTable.isEditing, animated: true)
        
        if nodeTable.isEditing {
            
            editButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(editNodes))
            
        } else {
            
            editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editNodes))
            
        }
        
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
        
    }
    
    private func deleteNode(nodeId: UUID, indexPath: IndexPath) {
        CoreDataService.deleteEntity(id: nodeId, entityName: .newNodes) { [unowned vc = self] success in
            if success {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.nodeArray.remove(at: indexPath.section)
                    vc.nodeTable.deleteSections(IndexSet.init(arrayLiteral: indexPath.section), with: .fade)
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
            let node = NodeStruct(dictionary: nodeArray[indexPath.section])
            if node.id != nil {
                deleteNode(nodeId: node.id!, indexPath: indexPath)
            }
        }
    }
    
    @objc func setActiveNow(_ sender: UISwitch) {        
        impact()
        
        let restId = sender.restorationIdentifier ?? ""
        let index = Int(restId) ?? 10000
        
        guard let selectedCell = nodeTable.cellForRow(at: IndexPath.init(row: 0, section: index)) else {
            return
        }
        
        let selectedSwitch = selectedCell.viewWithTag(2) as! UISwitch
        
        if index < nodeArray.count {
            
            let str = NodeStruct(dictionary: nodeArray[index])
            
            CoreDataService.update(id: str.id!, keyToUpdate: "isActive", newValue: selectedSwitch.isOn, entity: .newNodes) { [unowned vc = self] success in
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
                        CoreDataService.update(id: str.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                    }
                    
                    if i + 1 == nodeArray.count {
                        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
                            if nodes != nil {
                                DispatchQueue.main.async { [unowned vc = self] in
                                    vc.nodeArray.removeAll()
                                    for node in nodes! {
                                        if node["id"] != nil {
                                            vc.nodeArray.append(node)
                                        }
                                    }
                                    vc.nodeTable.reloadData()
                                    NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                                }
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
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            
            if nodes != nil {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.nodeArray.removeAll()
                    for node in nodes! {
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
    
    private func reduced(label: String) -> String {
        let first = String(label.prefix(5))
        let last = String(label.suffix(15))
        return "\(first)...\(last)"
    }
    
    @IBAction func addNode(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "addNewNode", sender: vc)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "updateNode" {
            if let vc = segue.destination as? NodeDetailViewController {
                vc.selectedNode = self.nodeArray[selectedIndex]
                vc.createNew = false
                vc.isLightning = false
            }
        }
        
        if segue.identifier == "addNewNode" {
            if let vc = segue.destination as? ChooseConnectionTypeViewController {
                vc.isUpdating = false
            }
        }
        
        if segue.identifier == "segueToAddLightningNode" {
            if let vc = segue.destination as? NodeDetailViewController {
                vc.isLightning = true
                vc.createNew = true
                CoreDataService.retrieveEntity(entityName: .newNodes) { (nodes) in
                    if nodes != nil {
                        for node in nodes! {
                            let str = NodeStruct(dictionary: node)
                            if str.isLightning {
                                vc.createNew = false
                                vc.selectedNode = node
                            }
                        }
                    }
                }
            }
        }
        
    }
}
