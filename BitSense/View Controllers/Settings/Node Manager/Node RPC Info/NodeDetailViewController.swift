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
        
        if createNew {
            
            if nodeLabel.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: nodeLabel.text!)
                newNode["label"] = enc
                
            }
            
            if rpcUserField.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: rpcUserField.text!)
                newNode["rpcuser"] = enc
                
            }
            
            if rpcPassword.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: rpcPassword.text!)
                newNode["rpcpassword"] = enc
                
            }
            
            if rpcPassword.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: rpcPassword.text!)
                newNode["rpcpassword"] = enc
                
            }
            
            if nodeLabel.text != "" && rpcPassword.text != "" && rpcUserField.text != "" {
                
                DispatchQueue.main.async {
                    
                    self.performSegue(withIdentifier: "goToTorDetails", sender: self)
                    
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Fill out all fields first")
                
            }
            
        } else {
            
            //updating
            
            let id = selectedNode["id"] as! String
            
            var arr = [[String:Any]]()
            
            if nodeLabel.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: nodeLabel.text!)
                selectedNode["label"] = enc
                let d:[String:Any] = ["id":id,"newValue":enc,"keyToEdit":"label","entityName":ENTITY.nodes]
                arr.append(d)
                
            }
            
            if rpcUserField.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: rpcUserField.text!)
                selectedNode["rpcuser"] = enc
                let d:[String:Any] = ["id":id,"newValue":enc,"keyToEdit":"rpcuser","entityName":ENTITY.nodes]
                arr.append(d)
                
            }
            
            if rpcPassword.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: rpcPassword.text!)
                selectedNode["rpcpassword"] = enc
                let d:[String:Any] = ["id":id,"newValue":enc,"keyToEdit":"rpcpassword","entityName":ENTITY.nodes]
                arr.append(d)
                
            }
            
            if (selectedNode["usingTor"] as! Bool) {
                
                let d1:[String:Any] = ["id":id,"newValue":false,"keyToEdit":"usingSSH","entityName":ENTITY.nodes]
                let d2:[String:Any] = ["id":id,"newValue":true,"keyToEdit":"usingTor","entityName":ENTITY.nodes]
                arr.append(d1)
                arr.append(d2)
                
            }
            
            cd.updateEntity(dictsToUpdate: arr) {
                
                if !self.cd.errorBool {
                    
                    let success = self.cd.boolToReturn
                    
                    if success {
                        
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "goToTorDetails", sender: self)
                            
                        }
                        
                    }
                    
                } else {
                    
                    displayAlert(viewController: self, isError: true, message: self.cd.errorDescription)
                    
                }
                
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
        
        let node = NodeStruct(dictionary: selectedNode)
        
        if node.id != "" {
            
            if node.label != "" {
                
                nodeLabel.text = aes.decryptKey(keyToDecrypt: node.label)
                
            } else {
                
                nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                     attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
            if node.rpcuser != "" {
                
                rpcUserField.text = aes.decryptKey(keyToDecrypt: node.rpcuser)
                
            } else {
                
                rpcUserField.attributedPlaceholder = NSAttributedString(string: "rpcuser",
                                                                        attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
            if node.rpcpassword != "" {
                
                rpcPassword.text = aes.decryptKey(keyToDecrypt: node.rpcpassword)
                
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
