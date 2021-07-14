//
//  NodesViewController.swift
//  BitSense
//
//  Created by Peter on 29/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class NodesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UINavigationControllerDelegate {
    
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
        addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNode))
        editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editNodes))
        addButton.tintColor = .systemTeal
        editButton.tintColor = .systemTeal
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        nodeArray.removeAll()
        getNodes()
    }
    
    func getNodes() {
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { [unowned vc = self] nodes in
            if nodes != nil {
                vc.nodeArray.removeAll()
                for node in nodes! {
                    let nodeStr = NodeStruct(dictionary: node)
                    if nodeStr.id != nil {
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
        guard let decrypted = Crypto.decrypt(encryptedValue) else { return "" }
        
        return decrypted.utf8 ?? ""
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
        
        let nodeStruct = NodeStruct(dictionary: nodeArray[indexPath.section])
        
        if !nodeStruct.uncleJim {
            label.text = nodeStruct.label
        } else {
            label.text = "***shared node***"
        }
        
        isActive.isOn = nodeArray[indexPath.section]["isActive"] as? Bool ?? false
        isActive.restorationIdentifier = "\(indexPath.section)"
        isActive.addTarget(self, action: #selector(setActiveNow(_:)), for: .touchUpInside)
        
        if !isActive.isOn {
            label.textColor = .darkGray
        } else {
            label.textColor = .white
        }
        
        icon.tintColor = .white
        
        if nodeStruct.isLightning {
            icon.image = UIImage(systemName: "bolt")
            background.backgroundColor = .systemOrange
        } else {
            icon.image = UIImage(systemName: "link")
            background.backgroundColor = .systemBlue
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    @objc func editNode(_ sender: UIButton) {
        guard let id = sender.restorationIdentifier, let section = Int(id) else { return }
        
        let nodeStruct = NodeStruct(dictionary: nodeArray[section])
        
        if !nodeStruct.uncleJim {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.selectedIndex = section
                vc.performSegue(withIdentifier: "updateNode", sender: vc)
            }
        } else {
            showAlert(vc: self, title: "Restricted", message: "You can not view node credentials for nodes shared to you.")
        }
    }
    
    @objc func editNodes() {
        nodeTable.setEditing(!nodeTable.isEditing, animated: true)
        
        if nodeTable.isEditing {
            editButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(editNodes))
        } else {
            editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editNodes))
        }
        
        addButton.tintColor = .systemTeal
        editButton.tintColor = .systemTeal
        
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
        
        let nodeStr = NodeStruct(dictionary: nodeArray[index])
        
        if index < nodeArray.count {
            
            CoreDataService.update(id: nodeStr.id!, keyToUpdate: "isActive", newValue: selectedSwitch.isOn, entity: .newNodes) { [unowned vc = self] success in
                if success {
                    if !nodeStr.isLightning {
                        vc.ud.removeObject(forKey: "walletName")
                    }
                    
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
                        
                        if str.id != nodeStr.id {
                            if !nodeStr.isLightning && !str.isLightning {
                                CoreDataService.update(id: str.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                            }
                            
                            if nodeStr.isLightning && str.isLightning {
                                CoreDataService.update(id: str.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                            }
                        }
                    }
                    
                    if i + 1 == nodeArray.count {
                        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
                            if nodes != nil {
                                DispatchQueue.main.async { [unowned vc = self] in
                                    vc.nodeArray.removeAll()
                                    for node in nodes! {
                                        let str = NodeStruct(dictionary: node)
                                        if str.id != nil {
                                            vc.nodeArray.append(node)
                                        }
                                    }
                                    vc.nodeTable.reloadData()
                                    
                                    if !nodeStr.isLightning {
                                        NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                                    }
                                    
                                    NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
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
        var first = String(label.prefix(25))
        if label.count > 25 {
            first += "..."
        }
        return "\(first)"
    }
    
    @IBAction func addNode(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alertStyle = UIAlertController.Style.alert
            
            let alert = UIAlertController(title: "Scan QR or add manually?", message: "You can add the node credentials manually or scan a QR code.", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Add manually", style: .default, handler: { [weak self] action in
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
        QuickConnect.addNode(uncleJim: false, url: url) { [weak self] (success, errorMessage) in
            if success {
                if !url.hasPrefix("clightning-rpc") && !url.hasPrefix("lndconnect:") {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.navigationController?.popViewController(animated: true)
                        NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                    }
                } else {
                    self?.reloadTable()
                }
            } else {
                displayAlert(viewController: self, isError: true, message: "Error adding that node: \(errorMessage ?? "unknown")")
            }
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
        
        if segue.identifier == "segueToAddBitcoinCoreNode" {
            if let vc = segue.destination as? NodeDetailViewController {
                vc.createNew = true
                vc.isLightning = false
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
        
        if segue.identifier == "segueToScanAddNode" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isQuickConnect = true
                vc.onQuickConnectDoneBlock = { [unowned thisVc = self] url in
                    if url != nil {
                        thisVc.addBtcRpcQr(url: url!)
                    }
                }
            }
        }
        
    }
}
