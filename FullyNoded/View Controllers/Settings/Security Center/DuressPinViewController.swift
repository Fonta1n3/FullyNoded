//
//  DuressPinViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/15/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import UIKit

class DuressPinViewController: UIViewController, UITextFieldDelegate {
    
    private var pinHash = ""
    
    @IBOutlet weak var duressPinTextField: UITextField!
    @IBOutlet weak var saveButtonOutlet: UIButton!
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        duressPinTextField.delegate = self
        configureTapGesture()
    }
    
    @IBAction func saveDuressPinAction(_ sender: Any) {
        if pinHash == "" {
            guard let originalPIN = duressPinTextField.text else { return }
            
            pinHash = sha256(originalPIN.utf8).hexString
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                duressPinTextField.text = ""
                saveButtonOutlet.setTitle("Confirm Duress PIN", for: .normal)
                showAlert(vc: self, title: "Confirm", message: "Confirm the PIN to save it.")
            }
        } else {
            guard let confirmedPIN = duressPinTextField.text else { return }
            
            let confirmedPINHash = sha256(confirmedPIN.utf8).hexString
            
            if confirmedPINHash == pinHash {
                UserDefaults.standard.set(pinHash, forKey: "DuressPIN")
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    saveButtonOutlet.setTitle("Save Duress PIN", for: .normal)
                    duressPinTextField.text = ""
                    pinHash = ""
                    showAlert(vc: self, title: "Saved ✓", message: "Duress PIN has been saved. Once used there is no going back!")
                }
            }
        }
    }
    
    private func configureTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        duressPinTextField.resignFirstResponder()
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
