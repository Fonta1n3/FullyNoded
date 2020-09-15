//
//  RescanViewController.swift
//  BitSense
//
//  Created by Peter on 01/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class RescanViewController: UIViewController {
    
    var dict = [String:Any]()
    let dateFormatter = DateFormatter()
    var isSingleKey = Bool()
    var isMultisig = Bool()
    var isDescriptor = Bool()
    @IBOutlet var datePicker: UIDatePicker!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        #if targetEnvironment(macCatalyst)
        #else
        datePicker.setValue(UIColor.white, forKey: "textColor")
        #endif
        
        dateFormatter.dateFormat = "dd/MM/yyyy"
        let genesis = dateFormatter.date(from: "09/01/2009")
        datePicker.minimumDate = genesis
        datePicker.maximumDate = Date()
        datePicker.date = Date()
        
    }
    
    @IBAction func nextAction(_ sender: Any) {
        
        var segueString = "addFingerprint"
        
        if isSingleKey || isDescriptor {
            
            segueString = "goScanKey"
            
        }
        
        if isMultisig {
            
            segueString = "importMusig"
            
        }
        
        if let derivation = dict["derivation"] as? String {
            
            if derivation == "BIP32Legacy" || derivation == "BIP32Segwit" || derivation == "BIP32P2SH" {
                
                segueString = "scanBIP32"
                
            }
            
        }
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: segueString, sender: self)
            
        }
        
    }
    
    func dateToUnix(string: String) -> Int {
        
        let date = dateFormatter.date(from: string)
        let unixTime = date?.timeIntervalSince1970 ?? 0.0
        return Int(unixTime)
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        let dateString = dateFormatter.string(from: datePicker.date)
        dict["rescanDate"] = dateToUnix(string: dateString)
        
        switch segue.identifier {
            
        case "scanBIP32":
            
            if let vc = segue.destination as? ScanExtendedKeyViewController {
                
                vc.dict = dict
                
            }
            
        case "addFingerprint":
            
            if let vc = segue.destination as? AddFingerprintViewController  {
                
                vc.dict = dict
                
            }
            
        case "goScanKey":
            
            if let vc = segue.destination as? ImportPrivKeyViewController  {
                
                vc.dict = dict
                vc.isDescriptor = isDescriptor
                
            }
            
        default:
            
            break
            
        }
        
    }

}
