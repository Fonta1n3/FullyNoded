//
//  ExtendedKeysParentViewController.swift
//  BitSense
//
//  Created by Peter on 01/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ExtendedKeysParentViewController: UIViewController {
    
    @IBOutlet var bip44Switch: UISwitch!
    @IBOutlet var bip84switch: UISwitch!
    
    var dict = [String:Any]()

    override func viewDidLoad() {
        super.viewDidLoad()

        bip44Switch.isOn = false
        bip84switch.isOn = true
        
    }
    
    @IBAction func nextAction(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: "addRange", sender: self)
            
        }
        
    }
    
    @IBAction func bip44Action(_ sender: Any) {
        
        if bip44Switch.isOn {
            
            bip84switch.isOn = false
            
        } else {
            
            bip84switch.isOn = true
            
        }
        
    }
    
    @IBAction func bip84Action(_ sender: Any) {
        
        if bip84switch.isOn {
            
            bip44Switch.isOn = false
            
        } else {
            
            bip44Switch.isOn = true
            
        }
        
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "addRange":
            
            if let vc = segue.destination as? ChooseRangeViewController  {
                
                if bip84switch.isOn {
                    
                    dict["derivation"] = "BIP84"
                    
                }
                
                if bip44Switch.isOn {
                    
                    dict["derivation"] = "BIP44"
                    
                }
                
                vc.dict = dict
                
            }
            
        default:
            
            break
            
        }
    }
    

}
