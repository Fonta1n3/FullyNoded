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
        
        self.performSegue(withIdentifier: "goToNodeDetails", sender: self)
        
    }
    
    @IBAction func sshSwitchAction(_ sender: Any) {
        
        if sshSwitchOutlet.isOn {
            
            torSwitchOutlet.isOn = false
            
        } else {
            
            torSwitchOutlet.isOn = true
            
        }
        
        if isUpdating {
            
            let id = selectedNode["id"] as! String
            
            let success = cd.updateNode(viewController: self,
                                        id: id,
                                        newValue: sshSwitchOutlet.isOn,
                                        keyToEdit: "usingSSH")
            
            successes.append(success)
            
        }
        
    }
    
    
    @IBAction func torSwitchAction(_ sender: Any) {
        
        if torSwitchOutlet.isOn {
            
            sshSwitchOutlet.isOn = false
            
        } else {
            
            sshSwitchOutlet.isOn = true
            
        }
        
        if isUpdating {
            
            let id = selectedNode["id"] as! String
            
            let success = cd.updateNode(viewController: self,
                                        id: id,
                                        newValue: torSwitchOutlet.isOn,
                                        keyToEdit: "usingTor")
            
            successes.append(success)
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if isUpdating {
            
            sshSwitchOutlet.isOn = selectedNode["usingSSH"] as! Bool
            torSwitchOutlet.isOn = selectedNode["usingTor"] as! Bool
            
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
