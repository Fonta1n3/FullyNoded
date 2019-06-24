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
            
            DispatchQueue.main.async {
                
                let alert = UIAlertController(title: "Alert", message: "Connecting via Tor hidden service only worked in the simulator for us, please do try it out but do not be suprised if it does not connect. We need help debugging this and are offering a bounty of $200 in BTC to anyone who can solve the issue.\n\nReach out on Twitter @FullyNoded if you want to help.", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { (action) in
                    
                    
                    
                }))
                
                self.present(alert, animated: true, completion: nil)
                
            }
            
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
