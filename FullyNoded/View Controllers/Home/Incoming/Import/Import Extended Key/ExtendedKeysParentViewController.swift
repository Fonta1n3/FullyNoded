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
    @IBOutlet var bip49switch: UISwitch!
    @IBOutlet var bip32SegwitWrappedSwitch: UISwitch!
    @IBOutlet var bip32LegacySwitch: UISwitch!
    @IBOutlet var bip32Segwit: UISwitch!
    @IBOutlet var bip44Label: UILabel!
    @IBOutlet var bip84Label: UILabel!
    @IBOutlet var bip32LegacyLabel: UILabel!
    @IBOutlet var bip32SegwitLabel: UILabel!
    @IBOutlet var bip49Label: UILabel!
    @IBOutlet var bip32WrappedLabel: UILabel!
    
    var dict = [String:Any]()

    override func viewDidLoad() {
        super.viewDidLoad()
        bip49switch.isOn = false
        bip32SegwitWrappedSwitch.isOn = false
        bip44Switch.isOn = false
        bip84switch.isOn = false
        bip32LegacySwitch.isOn = false
        bip32Segwit.isOn = true
        turnOn(labels: [bip32SegwitLabel])
        
    }
    
    func turnOn(labels: [UILabel]) {
        
        DispatchQueue.main.async {
            
            let allLabels = [self.bip44Label, self.bip84Label, self.bip32LegacyLabel, self.bip32SegwitLabel, self.bip32WrappedLabel, self.bip49Label]
            
            let labelsToTurnOn = labels
            
            for label in allLabels {
                
                if labelsToTurnOn.contains(label!) {
                    
                    label?.textColor = UIColor.white
                    
                } else {
                    
                    label?.textColor = UIColor.darkGray
                    
                }
                
            }
            
        }
        
    }
    
    @IBAction func nextAction(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: "addRange", sender: self)
            
        }
        
    }
    
    @IBAction func bip32LegacyAction(_ sender: Any) {
        
        if bip32LegacySwitch.isOn {
            
            turnOn(labels: [bip32LegacyLabel])
            bip32Segwit.isOn = false
            bip84switch.isOn = false
            bip44Switch.isOn = false
            bip32SegwitWrappedSwitch.isOn = false
            bip49switch.isOn = false
            
        }
        
    }
    
    @IBAction func bip32SegwitAction(_ sender: Any) {
        
        if bip32Segwit.isOn {
            
            turnOn(labels: [bip32SegwitLabel])
            bip32LegacySwitch.isOn = false
            bip44Switch.isOn = false
            bip84switch.isOn = false
            bip32SegwitWrappedSwitch.isOn = false
            bip49switch.isOn = false
            
        }
        
    }
    
    @IBAction func bip44Action(_ sender: Any) {
        
        if bip44Switch.isOn {
            
            turnOn(labels: [bip44Label])
            bip84switch.isOn = false
            bip32LegacySwitch.isOn = false
            bip32Segwit.isOn = false
            bip32SegwitWrappedSwitch.isOn = false
            bip49switch.isOn = false
            
        }
        
    }
    
    @IBAction func bip84Action(_ sender: Any) {
        
        if bip84switch.isOn {
            
            turnOn(labels: [bip84Label])
            bip44Switch.isOn = false
            bip32Segwit.isOn = false
            bip32LegacySwitch.isOn = false
            bip32SegwitWrappedSwitch.isOn = false
            bip49switch.isOn = false
            
        }
        
    }
    
    @IBAction func bip49Action(_ sender: Any) {
        
        if bip49switch.isOn {
            
            turnOn(labels: [bip49Label])
            bip44Switch.isOn = false
            bip32Segwit.isOn = false
            bip32LegacySwitch.isOn = false
            bip32SegwitWrappedSwitch.isOn = false
            bip84switch.isOn = false
            
        }
        
    }
    
    @IBAction func segwitWrappedAction(_ sender: Any) {
        
        if bip32SegwitWrappedSwitch.isOn {
            
            turnOn(labels: [bip32WrappedLabel])
            bip44Switch.isOn = false
            bip32Segwit.isOn = false
            bip32LegacySwitch.isOn = false
            bip49switch.isOn = false
            bip84switch.isOn = false
            
        }
        
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "addRange":
            
            if let vc = segue.destination as? ChooseRangeViewController  {
                
                if bip49switch.isOn {
                    
                    dict["derivation"] = "BIP49"
                    
                }
                
                if bip32SegwitWrappedSwitch.isOn {
                    
                    dict["derivation"] = "BIP32P2SH"
                }
                
                if bip84switch.isOn {
                    
                    dict["derivation"] = "BIP84"
                    
                }
                
                if bip44Switch.isOn {
                    
                    dict["derivation"] = "BIP44"
                    
                }
                
                if bip32Segwit.isOn {
                    
                    dict["derivation"] = "BIP32Segwit"
                    
                }
                
                if bip32LegacySwitch.isOn {
                    
                    dict["derivation"] = "BIP32Legacy"
                    
                }
                
                vc.dict = dict
                
            }
            
        default:
            
            break
            
        }
        
    }

}
