//
//  AddFingerprintViewController.swift
//  BitSense
//
//  Created by Peter on 01/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class AddFingerprintViewController: UIViewController, UITextFieldDelegate {
    
    var dict = [String:Any]()
    @IBOutlet var fingerprintInput: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        print("dict = \(dict)")
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        
        fingerprintInput.resignFirstResponder()
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        fingerprintInput.resignFirstResponder()
        return true
        
    }
    
    @IBAction func nextAction(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: "goScanExtendedKey", sender: self)
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "goScanExtendedKey":
            
            if let vc = segue.destination as? ScanExtendedKeyViewController  {
                
                dict["fingerprint"] = fingerprintInput.text ?? ""
                vc.dict = dict
                
            }
            
        default:
            
            break
            
        }
    }

}
