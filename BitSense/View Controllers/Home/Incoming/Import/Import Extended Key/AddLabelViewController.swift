//
//  AddLabelViewController.swift
//  BitSense
//
//  Created by Peter on 02/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class AddLabelViewController: UIViewController, UITextFieldDelegate {

    var dict = [String:Any]()
    @IBOutlet var textField: UITextField!
    var isSingleKey = Bool()
    var isPrivKey = Bool()
    var isMultisig = Bool()
    @IBOutlet var labelOutlet: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        textField.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        labelOutlet.text = "Add a label"
        
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        
        textField.resignFirstResponder()
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        textField.resignFirstResponder()
        return true
        
    }
    
    @IBAction func nextAction(_ sender: Any) {
        
        if textField.text != "" {
            
            var segueString = "goToParent"
            
            if isSingleKey {
                
                segueString = "jumpToKeypool"
                
            }
            
            if isPrivKey {
                
                segueString = "importPrivKey"
                
            }
            
            if isMultisig {
                
                segueString = "goImportMultiSig"
                
            }
            
            DispatchQueue.main.async {
                
                self.performSegue(withIdentifier: segueString, sender: self)
                
            }
            
        } else {
            
            shakeAlert(viewToShake: textField)
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        dict["label"] = textField.text!
        
        switch segue.identifier {
            
        case "goToParent":
            
            if let vc = segue.destination as? ExtendedKeysParentViewController  {
                
                vc.dict = dict
                
            }
            
        case "jumpToKeypool":
            
            if let vc = segue.destination as? AddToKeypoolViewController {
                
                vc.dict = dict
                vc.isSingleKey = isSingleKey
                vc.isMultiSig = false
                
            }
            
        case "goImportMultiSig":
            
            if let vc = segue.destination as? RescanViewController {
                
                vc.dict = dict
                vc.isMultisig = true
                
            }
            
        case "importPrivKey":
            
            if let vc = segue.destination as? ImportPrivKeyViewController {
                
                vc.dict = dict
                
            }
            
        default:
            
            break
            
        }
    }

}
