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
    @IBOutlet var labelOutlet: UILabel!
    @IBOutlet weak var addLabelOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textField.delegate = self
        addLabelOutlet.clipsToBounds = true
        addLabelOutlet.layer.cornerRadius = 8
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
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
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "importPrivKey", sender: self)
            }
            
        } else {
            shakeAlert(viewToShake: textField)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
        case "importPrivKey":
            if let vc = segue.destination as? ImportPrivKeyViewController {
                vc.dict = dict
                vc.label = textField.text ?? ""
            }
        default:
            break
        }
    }

}
