//
//  NodeDetailViewController.swift
//  BitSense
//
//  Created by Peter on 16/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class NodeDetailViewController: UIViewController, UITextFieldDelegate {
    
    var node = [String:Any]()
    let aes = AESService()
    let cd = CoreDataService()
    var createNew = Bool()
    var newNode = [String:Any]()
    
    @IBOutlet var nodeUsername: UITextField!
    @IBOutlet var nodeLabel: UITextField!
    @IBOutlet var nodePassword: UITextField!
    @IBOutlet var nodeIp: UITextField!
    @IBOutlet var nodePort: UITextField!
    @IBOutlet var saveButton: UIButton!
    
    
    @IBAction func save(_ sender: Any) {
        
        if createNew {
            
            newNode["id"] = randomString(length: 7)
            newNode["isDefault"] = false
            
            if nodeLabel.text != "" {
                
                newNode["label"] = nodeLabel.text!
                
            }
            
            if nodeUsername.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: nodeUsername.text!)
                newNode["username"] = enc
                
            }
            
            if nodePassword.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: nodePassword.text!)
                newNode["password"] = enc
                
            }
            
            if nodeIp.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: nodeIp.text!)
                newNode["ip"] = enc
                
            }
            
            if nodePort.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: nodePort.text!)
                newNode["port"] = enc
                
            }
            
            if nodeLabel.text != "" && nodeUsername.text != "" && nodePassword.text != "" && nodeIp.text != "" && nodePort.text != "" {
                
                let success = cd.saveCredentialsToCoreData(vc: self,
                                                           credentials: newNode)
                
                if success {
                    
                    displayAlert(viewController: navigationController!,
                                 isError: false,
                                 message: "Added succesfully")
                    
                    self.navigationController!.popToRootViewController(animated: true)
                    
                } else {
                    
                    displayAlert(viewController: navigationController!,
                                 isError: true,
                                 message: "Could not save")
                    
                }
                
            } else {
                
                displayAlert(viewController: navigationController!,
                             isError: true,
                             message: "Fill out all fields")
                
            }
            
        } else {
            
            //updating
            let id = node["id"] as! String
            var success1 = Bool()
            var success2 = Bool()
            var success3 = Bool()
            var success4 = Bool()
            var success5 = Bool()
            
            if nodeLabel.text != "" {
                
                success1 = cd.updateNode(viewController: self,
                                         id: id,
                                         newValue: nodeLabel.text!,
                                         keyToEdit: "label")
                
            }
            
            if nodeUsername.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: nodeUsername.text!)
                
                success2 = cd.updateNode(viewController: self,
                                         id: id,
                                         newValue: enc,
                                         keyToEdit: "username")
                
            }
            
            if nodePassword.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: nodePassword.text!)
                
                success3 = cd.updateNode(viewController: self,
                                         id: id,
                                         newValue: enc,
                                         keyToEdit: "password")
                
            }
            
            if nodeIp.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: nodeIp.text!)
                
                success4 = cd.updateNode(viewController: self,
                                         id: id,
                                         newValue: enc,
                                         keyToEdit: "ip")
                
            }
            
            if nodePort.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: nodePort.text!)
                
                success5 = cd.updateNode(viewController: self,
                                         id: id,
                                         newValue: enc,
                                         keyToEdit: "port")
                
            }
            
            if success1 && success2 && success3 && success4 && success5 {
                
                displayAlert(viewController: navigationController!,
                             isError: false,
                             message: "Node updated")
                
            } else {
                
                displayAlert(viewController: navigationController!,
                             isError: true,
                             message: "Update failed")
                
            }
            
        }
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        
        nodeLabel.delegate = self
        nodePort.delegate = self
        nodeIp.delegate = self
        nodePassword.delegate = self
        nodeUsername.delegate = self
        
        loadValues()
        
        if !createNew {
            
            saveButton.setTitle("Update", for: .normal)
            
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        nodeLabel.text = ""
        nodePort.text = ""
        nodePassword.text = ""
        nodeIp.text = ""
        nodeUsername.text = ""
        
    }
    
    func loadValues() {
        
        if node["id"] != nil {
            
            nodeUsername.text = aes.decryptKey(keyToDecrypt: (node["username"] as! String))
            nodePassword.text = aes.decryptKey(keyToDecrypt: (node["password"] as! String))
            nodeIp.text = aes.decryptKey(keyToDecrypt: (node["ip"] as! String))
            nodePort.text = aes.decryptKey(keyToDecrypt: (node["port"] as! String))
            
            if node["label"] != nil {
                
                nodeLabel.text = (node["label"] as! String)
                
            } else {
                
                nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                 attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
        } else {
            
            nodeUsername.attributedPlaceholder = NSAttributedString(string: "Enter SSH host user",
                                                                attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            nodePassword.attributedPlaceholder = NSAttributedString(string: "Enter SSH host password",
                                                                attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            nodeIp.attributedPlaceholder = NSAttributedString(string: "Enter SSH host IP",
                                                          attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            nodePort.attributedPlaceholder = NSAttributedString(string: "Enter SSH host port",
                                                            attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                             attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
        }
        
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        
        nodeLabel.resignFirstResponder()
        nodeUsername.resignFirstResponder()
        nodePassword.resignFirstResponder()
        nodeIp.resignFirstResponder()
        nodePort.resignFirstResponder()
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        self.view.endEditing(true)
        
        return true
        
    }

}
