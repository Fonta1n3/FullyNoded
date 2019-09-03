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
    
    @IBOutlet var datePicker: UIDatePicker!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        datePicker.setValue(UIColor.white, forKey: "textColor")
        dateFormatter.dateFormat = "dd/MM/yyyy"
        let genesis = dateFormatter.date(from: "09/01/2009")
        datePicker.minimumDate = genesis
        datePicker.maximumDate = Date()
        datePicker.date = Date()
        
    }
    
    @IBAction func nextAction(_ sender: Any) {
        
        var segueString = "addFingerprint"
        
        if isSingleKey {
            
            segueString = "goScanKey"
            
        }
        
        if isMultisig {
            
            segueString = "importMusig"
            
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
            
        case "addFingerprint":
            
            if let vc = segue.destination as? AddFingerprintViewController  {
                
                vc.dict = dict
                
            }
            
        case "goScanKey":
            
            if let vc = segue.destination as? ImportPrivKeyViewController  {
                
                vc.dict = dict
                
            }
            
        case "importMusig":
            
            if let vc = segue.destination as? ImportMultiSigViewController {
                
                vc.dict = dict
                
            }
            
        default:
            
            break
            
        }
        
    }

}
