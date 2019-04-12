//
//  NodesTableViewController.swift
//  BitSense
//
//  Created by Peter on 04/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class NodesTableViewController: UITableViewController, UITabBarControllerDelegate {
    
    var nodeArray = [[String:Any]]()
    var selectedIndex = Int()
    @IBOutlet var nodeTable: UITableView!
    let cd = CoreDataService.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBarController!.delegate = self
        nodeTable.tableFooterView = UIView(frame: .zero)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        nodeArray.removeAll()
        getNodes()
        nodeTable.reloadData()
        
    }
    
    func getNodes() {
        
        nodeArray = cd.retrieveCredentials()
        print("nodearray = \(nodeArray)")
        
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
        
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return nodeArray.count
        
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "node", for: indexPath)
        let label = cell.viewWithTag(1) as! UILabel
        let isActive = cell.viewWithTag(2) as! UISwitch
        
        if nodeArray[indexPath.row]["label"] != nil {
            
            label.text = (nodeArray[indexPath.row]["label"] as! String)
            
        } else {
            
            label.text = "Tap to edit node label"
            
        }
        
        isActive.isOn = nodeArray[indexPath.row]["isActive"] as! Bool
        isActive.restorationIdentifier = "\(indexPath.row)"
        isActive.addTarget(self, action: #selector(setActiveNow(_:)), for: .touchUpInside)
        
        if !isActive.isOn {
            
            label.textColor = UIColor.lightText
            
        } else {
            
            label.textColor = UIColor.white
            
        }
        
        return cell
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
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
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "showCredentials", sender: self)
                        
                    }
                    
                })
                
            })
            
        }
        
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showCredentials" {
            
            if let vc = segue.destination as? NodeDetailTableViewController {
                
                vc.node = self.nodeArray[selectedIndex]
                vc.createNew = false
                
            }
            
        }
        
        if segue.identifier == "createNew" {
            
            if let vc = segue.destination as? NodeDetailTableViewController {
                
                vc.createNew = true
                
            }
            
        }
        
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == UITableViewCellEditingStyle.delete {
            
            let success = cd.deleteNode(viewController: self, id: nodeArray[indexPath.row]["id"] as! String)
                
            if success {
                
                nodeArray.remove(at: indexPath.row)
                nodeTable.deleteRows(at: [indexPath], with: .fade)
                
            } else {
                
                displayAlert(viewController: self, title: "Error", message: "We had an error trying to delete that node")
                
            }
            
        }
        
    }
    
    func updateActiveState(indexpath: IndexPath) {
        print("updateActiveState \(indexpath)")
        
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator().impactOccurred()
        }
        
        /*let selectedCell = nodeTable.cellForRow(at: IndexPath.init(row: index, section: 0))!
        let selectedSwitch = selectedCell.viewWithTag(2) as! UISwitch
        print("selectedSwitch = \(selectedSwitch.isOn)")
        let id = nodeArray[index]["id"] as! String
        
        if !selectedSwitch.isOn {
            
            //turned off
            let success = cd.updateNode(viewController: self, id: id, newValue: false, keyToEdit: "isActive")
            
            if success {
                
                nodeArray = cd.retrieveCredentials()
                nodeTable.reloadData()
                
            }
            
            
        } else {
            
            //turned on
            let success = cd.updateNode(viewController: self, id: id, newValue: true, keyToEdit: "isActive")
            
            if success {
                
                nodeArray = cd.retrieveCredentials()
                nodeTable.reloadData()
                
            }
            
        }*/
        
        
        
        /*for row in 0 ..< nodeTable.numberOfRows(inSection: 0) {
            
            if let cell = self.nodeTable.cellForRow(at: IndexPath(row: row, section: 0)) {
                
                let label = cell.viewWithTag(1) as! UILabel
                let isActive = cell.viewWithTag(2) as! UISwitch
                let tappedId = nodeArray[index]["id"] as! String
                let id = nodeArray[row]["id"] as! String
                
                
                
                if index == row && isActive.isOn {
                    
                    //cell.isSelected = true
                    label.textColor = UIColor.white
                    cd.updateNode(viewController: self, id: tappedId, newValue: true, keyToEdit: "isActive")
                    
                } else if row != index {
                    
                    //cell.isSelected = false
                    isActive.isOn = false
                    label.textColor = UIColor.lightText
                    cd.updateNode(viewController: self, id: id, newValue: false, keyToEdit: "isActive")
                    
                }
                
            }
            
        }
        
        self.nodeArray = self.cd.retrieveCredentials()*/
        //nodeTable.reloadData()
        
        /*if success {
            
            if isActive.isOn {
                
                DispatchQueue.main.async {
                    
                    label.textColor = UIColor.white
                    
                }
                
            }
            
            //disables the other active node
            if nodeArray.count > 1 {
                
                if isActive.isOn {
                    
                    for (index, nodeToTurnOff) in nodeArray.enumerated() {
                        
                        let activeNode = nodeToTurnOff["isActive"] as! Bool
                        
                        if activeNode {
                            
                            let activeID = nodeToTurnOff["id"] as! String
                            let success1 = cd.updateNode(viewController: self, id: activeID, newValue: false, keyToEdit: "isActive")
                            
                            if success1 {
                                
                                DispatchQueue.main.async {
                                    
                                    let cellToDisable = self.nodeTable.cellForRow(at: IndexPath.init(row: index, section: 0))!
                                    let labelToDisable = cellToDisable.viewWithTag(1) as! UILabel
                                    let isActiveToDisable = cellToDisable.viewWithTag(2) as! UISwitch
                                    labelToDisable.textColor = UIColor.lightText
                                    isActiveToDisable.isOn = false
                                    
                                    self.nodeArray = self.cd.retrieveCredentials()
                                    
                                }
                                
                            }
                            
                        }
                        
                    }
                    
                } else {
                    
                    
                }
                
            }
            
        }*/
        
    }
    
    @objc func setActiveNow(_ sender: UISwitch) {
        
        DispatchQueue.main.async {
            
            UIImpactFeedbackGenerator().impactOccurred()
            
        }
        
        let index = Int(sender.restorationIdentifier!)!
        
        let selectedCell = nodeTable.cellForRow(at: IndexPath.init(row: index, section: 0))!
        let selectedSwitch = selectedCell.viewWithTag(2) as! UISwitch
        let id = nodeArray[index]["id"] as! String
        
        if !selectedSwitch.isOn {
            
            //turned off
            let success = cd.updateNode(viewController: self, id: id, newValue: false, keyToEdit: "isActive")
            
            if success {
                
                nodeArray = cd.retrieveCredentials()
                nodeTable.reloadData()
                
            }
            
            
        } else {
            
            //turned on
            let success = cd.updateNode(viewController: self, id: id, newValue: true, keyToEdit: "isActive")
            
            if success {
                
                nodeArray = cd.retrieveCredentials()
                nodeTable.reloadData()
                
            }
            
        }
        
        if nodeArray.count > 1 {
            
            for (i, node) in nodeArray.enumerated() {
                
                if i != index {
                    
                    let id = node["id"] as! String
                    
                    let success = cd.updateNode(viewController: self, id: id, newValue: false, keyToEdit: "isActive")
                    
                    if success {
                        
                        nodeArray = cd.retrieveCredentials()
                        nodeTable.reloadData()
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    

}

extension NodesTableViewController  {
    func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return MyTransition(viewControllers: tabBarController.viewControllers)
    }
}
