//
//  NodeDetailViewController.swift
//  BitSense
//
//  Created by Peter on 16/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class NodeDetailViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    var selectedNode = [String:Any]()
    let aes = AESService()
    let cd = CoreDataService()
    var createNew = Bool()
    var newNode = [String:Any]()
    var isInitialLoad = Bool()
    
    @IBOutlet var nodeLabel: UITextField!
    @IBOutlet var rpcUserField: UITextField!
    @IBOutlet var rpcPassword: UITextField!
    @IBOutlet var rpcLabel: UILabel!
    @IBOutlet var saveButton: UIButton!
    
    @IBAction func save(_ sender: Any) {
        
        func encryptedValue(_ decryptedValue: Data) -> Data? {
            var encryptedValue:Data?
            Crypto.encryptData(dataToEncrypt: decryptedValue) { encryptedData in
                if encryptedData != nil {
                    encryptedValue = encryptedData!
                }
            }
            return encryptedValue
        }
        
        if createNew {
            
            if nodeLabel.text != "" {
                newNode["label"] = nodeLabel.text!
                
            }
            
            if rpcUserField.text != "" {
                guard let enc = encryptedValue((rpcUserField.text)!.dataUsingUTF8StringEncoding) else { return }
                newNode["rpcuser"] = enc
            }
            
            if rpcPassword.text != "" {
                guard let enc = encryptedValue((rpcPassword.text)!.dataUsingUTF8StringEncoding) else { return }
                newNode["rpcpassword"] = enc
                
            }
            
            if nodeLabel.text != "" && rpcPassword.text != "" && rpcUserField.text != "" {
                
                DispatchQueue.main.async { [unowned vc = self] in
                    
                    vc.performSegue(withIdentifier: "goToTorDetails", sender: vc)
                    
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Fill out all fields first")
                
            }
            
        } else {
            
            //updating
            
            let id = selectedNode["id"] as! UUID
            
            func update(key: String, value: Data) -> Bool {
                var result = false
                cd.update(id: id, keyToUpdate: key, newValue: value, entity: .newNodes) { success in
                    result = success
                }
                return result
            }
            
            if nodeLabel.text != "" {
                cd.update(id: id, keyToUpdate: "label", newValue: nodeLabel.text!, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating label")
                    }
                }
            }
            
            if rpcUserField.text != "" {
                
                guard let enc = encryptedValue((rpcUserField.text)!.dataUsingUTF8StringEncoding) else { return }
                if !update(key: "rpcuser", value: enc) {
                    displayAlert(viewController: self, isError: true, message: "error updating rpc username")
                }
                
            }
            
            if rpcPassword.text != "" {
                
                guard let enc = encryptedValue((rpcPassword.text)!.dataUsingUTF8StringEncoding) else { return }
                if !update(key: "rpcpassword", value: enc) {
                    displayAlert(viewController: self, isError: true, message: "error updating rpc password")
                }
                
            }
            
            DispatchQueue.main.async { [unowned vc = self] in
                
                vc.performSegue(withIdentifier: "goToTorDetails", sender: vc)
                
            }
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTapGesture()
        nodeLabel.delegate = self
        rpcPassword.delegate = self
        rpcUserField.delegate = self
        rpcPassword.isSecureTextEntry = true
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        loadValues()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {

        rpcPassword.text = ""
        
    }
    
    func configureTapGesture() {
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        
    }
    
    func loadValues() {
        
        func decryptedValue(_ encryptedValue: Data) -> String {
            var decryptedValue = ""
            Crypto.decryptData(dataToDecrypt: encryptedValue) { decryptedData in
                if decryptedData != nil {
                    decryptedValue = decryptedData!.utf8
                }
            }
            return decryptedValue
        }
        
        let node = NodeStruct(dictionary: selectedNode)
        
        if node.id != nil {
            
            if node.label != "" {
                
                nodeLabel.text = node.label
                
            } else {
                
                nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                     attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
            if node.rpcuser != nil {
                
                rpcUserField.text = decryptedValue(node.rpcuser!)
                
            } else {
                
                rpcUserField.attributedPlaceholder = NSAttributedString(string: "rpcuser",
                                                                        attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
            if node.rpcpassword != nil {
                
                rpcPassword.text = decryptedValue(node.rpcpassword!)
                
            } else {
                
                rpcPassword.attributedPlaceholder = NSAttributedString(string: "rpcpassword",
                                                                       attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
        } else {
                        
            rpcPassword.attributedPlaceholder = NSAttributedString(string: "rpcpassword",
                                                                   attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
            rpcUserField.attributedPlaceholder = NSAttributedString(string: "rpcuser",
                                                                    attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
            nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                 attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
        }
        
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        
        nodeLabel.resignFirstResponder()
        rpcUserField.resignFirstResponder()
        rpcPassword.resignFirstResponder()
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        self.view.endEditing(true)
        return true
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "goToTorDetails":
            
            if let vc = segue.destination as? TorCredentialViewController {
                
                vc.newNode = self.newNode
                vc.selectedNode = self.selectedNode
                vc.createNew = self.createNew
                
            }
            
        default:
            
            break
            
        }
        
    }
    
}
