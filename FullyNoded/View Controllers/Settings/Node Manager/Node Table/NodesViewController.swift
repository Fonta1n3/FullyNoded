//
//  NodesViewController.swift
//  BitSense
//
//  Created by Peter on 29/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class NodesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UINavigationControllerDelegate {
    
    var nodeArray: [NodeStruct] = []
    var selectedIndex: Int?
    let ud = UserDefaults.standard
    var addButton = UIBarButtonItem()
    var editButton = UIBarButtonItem()
    private var now: Date = .now
    private var firstTap: Date?
    private var lastTap: Date?
    private var authenticated = false
    @IBOutlet var nodeTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.delegate = self
        nodeTable.tableFooterView = UIView(frame: .zero)
        addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNode))
        editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editNodes))
        addButton.tintColor = .systemBlue
        editButton.tintColor = .systemBlue
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        getNodes()
    }
    
    func getNodes() {
        nodeArray.removeAll()
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            
            guard let nodes = nodes else {
                displayAlert(viewController: self,
                             isError: true,
                             message: "error getting nodes from core data")
                return
            }
            
            self.nodeArray.removeAll()
            
            for node in nodes {
                let nodeStr = NodeStruct(dictionary: node)
                if nodeStr.id != nil {
                    self.nodeArray.append(nodeStr)
                }
            }
            
            self.reloadNodeTable()
            
            if self.nodeArray.count == 0 {
                self.addNodePrompt()
            }
        }
    }
    
    private func reloadNodeTable() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.nodeTable.reloadData()
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return nodeArray.count
    }
    
    private func decryptedValue(_ encryptedValue: Data) -> String {
        guard let decrypted = Crypto.decrypt(encryptedValue) else { return "" }
        
        return decrypted.utf8String ?? ""
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "node", for: indexPath)
        cell.tintColor = .systemBlue
        
        let label = cell.viewWithTag(1) as! UILabel
        let icon = cell.viewWithTag(4) as! UIImageView
        let button = cell.viewWithTag(5) as! UIButton
        
        button.restorationIdentifier = "\(indexPath.row)"
        button.addTarget(self, action: #selector(editNode(_:)), for: .touchUpInside)
        
        let nodeStruct = nodeArray[indexPath.row]
        label.text = nodeStruct.label
                
        icon.image = UIImage(systemName: "link")
        icon.tintColor = .systemBlue
        
        if !nodeStruct.isActive {
            label.textColor = .secondaryLabel
            cell.accessoryType = .none
            cell.isSelected = false
        } else {
            label.textColor = .none
            cell.accessoryType = .checkmark
            cell.isSelected = true
            cell.accessoryView?.frame = .init(x: 0, y: 0, width: 35, height: 35)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedNode = nodeArray[indexPath.row]
        
        let isActive = selectedNode.isActive
        
        if !isActive {
            CoreDataService.update(id: selectedNode.id!, keyToUpdate: "isActive", newValue: true, entity: .newNodes) { [weak self] success in
                guard let self = self else { return }
                
                if success {
                    self.ud.removeObject(forKey: "walletName")
                    
                    if self.nodeArray.count == 1 {
                        self.reloadTable()
                    }
                    
                } else {
                    displayAlert(viewController: self, isError: true, message: "Error updating node.")
                }
            }
            
            if nodeArray.count > 1 {
                for (i, node) in nodeArray.enumerated() {
                    guard i != indexPath.row else { return }
                    
                    if node.id != selectedNode.id {
                        CoreDataService.update(id: node.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                    }
                    
                    guard i + 1 == nodeArray.count else { return }
                    
                    CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
                        guard let nodes = nodes else { return }
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            nodeArray.removeAll()
                            
                            for node in nodes {
                                if node["id"] as? UUID != nil {
                                    nodeArray.append(NodeStruct(dictionary: node))
                                }
                            }
                            nodeTable.reloadData()
                            showAlert(vc: self, title: "", message: "Tap the refresh button on the home view to show the current node.")
                        }
                    }
                }
            }
        } else {
            CoreDataService.update(id: selectedNode.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { [weak self] success in
                guard let self = self else { return }
                
                if success {
                    self.ud.removeObject(forKey: "walletName")
                    self.reloadTable()
    
                } else {
                    displayAlert(viewController: self, isError: true, message: "Error updating node.")
                }
            }
        }
        
        
    }
    
    @objc func editNode(_ sender: UIButton) {
        func editNow() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                firstTap = .now
                guard let id = sender.restorationIdentifier, let row = Int(id) else { return }
                selectedIndex = row
                performSegue(withIdentifier: "updateNode", sender: self)
            }
        }
        
        if let firstTap = firstTap {
            if firstTap.timeIntervalSinceNow < -2.0 {
                editNow()
            }
        } else {
            editNow()
        }
    }
    
    @objc func editNodes() {
        nodeTable.setEditing(!nodeTable.isEditing, animated: true)
        
        if nodeTable.isEditing {
            editButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(editNodes))
        } else {
            editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editNodes))
        }
        
        addButton.tintColor = .systemBlue
        editButton.tintColor = .systemBlue
        
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }
    
    private func deleteNode(nodeId: UUID, indexPath: IndexPath) {
        CoreDataService.deleteEntity(id: nodeId, entityName: .newNodes) { [weak self] success in
            guard let self = self else { return }
            if success {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    nodeArray.remove(at: indexPath.row)
                    nodeTable.deleteRows(at: [indexPath], with: .fade)
                    nodeTable.reloadData()
                }
            } else {
                showAlert(vc: self, title: "", message: "We had an error trying to delete that node.")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            let node = nodeArray[indexPath.row]
            if node.id != nil {
                deleteNode(nodeId: node.id!, indexPath: indexPath)
            }
        }
    }
    
    @objc func setActiveNow(_ sender: UISwitch) {        
        impact()
        
        let restId = sender.restorationIdentifier ?? ""
        let index = Int(restId) ?? 10000
        
        guard let selectedCell = nodeTable.cellForRow(at: IndexPath.init(row: index, section: 0)) else {
            return
        }
        
        let selectedSwitch = selectedCell.viewWithTag(2) as! UISwitch
        let nodeToActivate = nodeArray[index]
        
        if index < nodeArray.count {
            
            CoreDataService.update(id: nodeToActivate.id!, keyToUpdate: "isActive", newValue: selectedSwitch.isOn, entity: .newNodes) { [unowned vc = self] success in
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
                        if node.id != nodeToActivate.id {
                            CoreDataService.update(id: nodeToActivate.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                        }
                    }
                    
                    if i + 1 == nodeArray.count {
                        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
                            guard let nodes = nodes else { return }
                            
                            DispatchQueue.main.async { [unowned vc = self] in
                                vc.nodeArray.removeAll()
                                
                                for node in nodes {
                                    if node["id"] as? UUID != nil {
                                        vc.nodeArray.append(NodeStruct(dictionary: node))
                                    }
                                }
                                vc.nodeTable.reloadData()
                                
                                if selectedSwitch.isOn {
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
                        let ns = NodeStruct(dictionary: node)
                        if ns.id != nil {
                            vc.nodeArray.append(ns)
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
        var first = String(label.prefix(25))
        if label.count > 25 {
            first += "..."
        }
        return "\(first)"
    }
    
    private func addNodePrompt() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alertStyle = UIAlertController.Style.alert
            
            let alert = UIAlertController(title: "Scan QR or add manually?", message: "You can add the node credentials manually or scan a QR code.", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Manually", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.segueToAddNodeManually()
            }))
            
            alert.addAction(UIAlertAction(title: "Scan QR", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.segueToScanNode()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func addNode(_ sender: Any) {
        addNodePrompt()
    }
        
    private func segueToAddNodeManually() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToAddBitcoinCoreNode", sender: vc)
        }
    }
    
    private func segueToScanNode() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToScanAddNode", sender: vc)
        }
    }
    
    private func addBtcRpcQr(url: String) {
        selectedIndex = nil
        QuickConnect.addNode(url: url) { [weak self] (success, errorMessage) in
            guard let self = self else { return }
            if success {
                getNodes()
//                showAlert(vc: self, title: "Node added ✓", message: "The new node is automatically activated, you need to go home and tap the refresh button to try and connect.")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    performSegue(withIdentifier: "updateNode", sender: self)
                }
                
                
            } else {
                displayAlert(viewController: self, isError: true, message: "Error adding that node: \(errorMessage ?? "unknown")")
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "updateNode" {
            if let vc = segue.destination as? NodeDetailViewController {
                guard let selectedIndex = selectedIndex else {
                    // If there is no selected node it can only be bc we just added it via scanning a QR in which case it will be the active node.
                    for node in nodeArray {
                        if node.isActive {
                            vc.selectedNode = node
                        }
                    }
                    return
                }
                vc.selectedNode = self.nodeArray[selectedIndex]
            }
        }
        
        if segue.identifier == "segueToAddBitcoinCoreNode" {
            if let vc = segue.destination as? NodeDetailViewController {
                vc.selectedNode = nil
            }
        }
        
        if segue.identifier == "segueToScanAddNode" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isQuickConnect = true
                vc.onDoneBlock = { [unowned thisVc = self] url in
                    if url != nil {
                        thisVc.addBtcRpcQr(url: url!)
                    }
                }
            }
        }
        
    }
}


