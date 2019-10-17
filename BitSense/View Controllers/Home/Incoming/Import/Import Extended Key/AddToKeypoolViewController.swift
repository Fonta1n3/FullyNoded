//
//  AddToKeypoolViewController.swift
//  BitSense
//
//  Created by Peter on 01/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class AddToKeypoolViewController: UIViewController {
    
    var dict = [String:Any]()
    @IBOutlet var yesLabel: UILabel!
    @IBOutlet var yesSwitch: UISwitch!
    var isSingleKey = Bool()
    var isMultiSig = Bool()
    var isDescriptor = Bool()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        print("dict = \(dict)")
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
            
            self.performSegue(withIdentifier: "addAsChange", sender: self)
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "addAsChange":
            
            if let vc = segue.destination as? AddAsChangeViewController  {
                
                dict["addToKeypool"] = yesSwitch.isOn
                vc.dict = dict
                vc.isSingleKey = isSingleKey
                vc.isMultisig = isMultiSig
                vc.isDescriptor = isDescriptor
                
            }
            
        default:
            
            break
            
        }
    }

}
