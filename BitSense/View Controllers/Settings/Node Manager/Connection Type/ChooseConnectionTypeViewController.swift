//
//  ChooseConnectionTypeViewController.swift
//  BitSense
//
//  Created by Peter on 13/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ChooseConnectionTypeViewController: UIViewController {
    
    let cd = CoreDataService()
    var selectedNode = [String:Any]()
    var isUpdating = Bool()
    var successes = [Bool]()
    
    @IBOutlet var sshSwitchOutlet: UISwitch!
    @IBOutlet var torSwitchOutlet: UISwitch!
    
    @IBAction func nextAction(_ sender: Any) {
        
        if torSwitchOutlet.isOn || sshSwitchOutlet.isOn {
            
            self.performSegue(withIdentifier: "goToNodeDetails", sender: self)
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "You need to either choose Tor or SSH")
            
        }
        
    }
    
    @IBAction func sshSwitchAction(_ sender: Any) {
        
        if sshSwitchOutlet.isOn {
            
            torSwitchOutlet.isOn = false
            
        } else {
            
            torSwitchOutlet.isOn = true
            
        }
        
        if isUpdating {
            
            let node = NodeStruct(dictionary: selectedNode)
            
            let id = node.id
            
//            let success = cd.updateNode(viewController: self,
//                                        id: id,
//                                        newValue: sshSwitchOutlet.isOn,
//                                        keyToEdit: "usingSSH")
            
            let success = cd.updateEntity(viewController: self,
                                          id: id,
                                          newValue: sshSwitchOutlet.isOn,
                                          keyToEdit: "usingSSH",
                                          entityName: ENTITY.nodes)
            
            successes.append(success)
            
        }
        
    }
    
    
    @IBAction func torSwitchAction(_ sender: Any) {
        
        if torSwitchOutlet.isOn {
            
            sshSwitchOutlet.isOn = false
            
            DispatchQueue.main.async {
                
                let alert = UIAlertController(title: "Alert", message: "Connecting via Tor hidden service may not work depending on your device, it will work if you build the app from source", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { (action) in
                    
                    
                    
                }))
                
                self.present(alert, animated: true, completion: nil)
                
            }
            
        } else {
            
            sshSwitchOutlet.isOn = true
            
        }
        
        if isUpdating {
            
            let node = NodeStruct(dictionary: selectedNode)
            let id = node.id
            
//            let success = cd.updateNode(viewController: self,
//                                        id: id,
//                                        newValue: torSwitchOutlet.isOn,
//                                        keyToEdit: "usingTor")
            
            let success = cd.updateEntity(viewController: self,
                                          id: id,
                                          newValue: torSwitchOutlet.isOn,
                                          keyToEdit: "usingTor",
                                          entityName: ENTITY.nodes)
            
            successes.append(success)
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if isUpdating {
            
            let node = NodeStruct(dictionary: selectedNode)
            
            sshSwitchOutlet.isOn = node.usingSSH
            torSwitchOutlet.isOn = node.usingTor
            
        } else {
            
            sshSwitchOutlet.isOn = false
            torSwitchOutlet.isOn = false
            
        }
        
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "goToNodeDetails":
            
            if let vc = segue.destination as? NodeDetailViewController  {
                
                vc.newNode["usingSSH"] = sshSwitchOutlet.isOn
                vc.newNode["usingTor"] = torSwitchOutlet.isOn
                vc.selectedNode = self.selectedNode
                
                if !isUpdating {
                    
                    vc.createNew = true
                    
                } else {
                    
                    vc.createNew = false
                    
                }
                
            }
            
        default:
            
            break
            
        }
        
    }

}
