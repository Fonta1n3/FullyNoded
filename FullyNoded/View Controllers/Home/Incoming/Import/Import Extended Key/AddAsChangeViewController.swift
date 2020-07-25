//
//  AddAsChangeViewController.swift
//  BitSense
//
//  Created by Peter on 01/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class AddAsChangeViewController: UIViewController {
    
    var dict = [String:Any]()
    @IBOutlet var yesSwitch: UISwitch!
    @IBOutlet var yesLabel: UILabel!
    var isSingleKey = Bool()
    var isMultisig = Bool()
    var isDescriptor = Bool()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        yesLabel.text = "NO"
        yesSwitch.isOn = false
        
    }
    
    @IBAction func yesAction(_ sender: Any) {
        
        if yesSwitch.isOn {
            
            yesLabel.text = "YES"
            
        } else {
            
            yesLabel.text = "NO"
            
        }
        
    }
    
    @IBAction func nextAction(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: "goToRescan", sender: self)
            
        }
        
    }
    

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "goToRescan":
            
            if let vc = segue.destination as? RescanViewController  {
                
                dict["addAsChange"] = yesSwitch.isOn
                vc.dict = dict
                vc.isSingleKey = isSingleKey
                vc.isMultisig = isMultisig
                vc.isDescriptor = isDescriptor
                
            }
            
        default:
            
            break
            
        }
    }

}
