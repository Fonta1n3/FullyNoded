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
    
    @IBOutlet var nodeLabel: UITextField!
    @IBOutlet var rpcUserField: UITextField!
    @IBOutlet var rpcPassword: UITextField!
    @IBOutlet var rpcPort: UITextField!
    
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
            
            if rpcPort.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: rpcPort.text!)
                newNode["rpcport"] = enc
                
            }
            
            if !(newNode["usingSSH"] as! Bool) {
                
                if nodeLabel.text != "" && rpcPort.text != "" && rpcPassword.text != "" && rpcUserField.text != "" {
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "goToTorDetails", sender: self)
                        
                    }
                    
                } else {
                    
                    displayAlert(viewController: navigationController!,
                                 isError: true,
                                 message: "Fill out all fields first")
                    
                }
                
            } else {
                
                if nodeLabel.text != "" && rpcPort.text != "" && rpcPassword.text != "" && rpcUserField.text != "" {
                    
                    //segue to ssh node
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "sshCredentials",
                                          sender: self)
                        
                    }
                    
                } else {
                    
                    displayAlert(viewController: navigationController!,
                                 isError: true,
                                 message: "You need to fill out all fields")
                    
                }
                
            }
            
        } else {
            
            //updating
            
            let id = selectedNode["id"] as! String
            
            if nodeLabel.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: nodeLabel.text!)
                selectedNode["label"] = enc
                
                let _ = cd.updateNode(viewController: self,
                                      id: id,
                                      newValue: enc,
                                      keyToEdit: "label")
                
            }
            
            if rpcUserField.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: rpcUserField.text!)
                selectedNode["rpcuser"] = enc
                
                let _ = cd.updateNode(viewController: self,
                                      id: id,
                                      newValue: enc,
                                      keyToEdit: "rpcuser")
                
            }
            
            if rpcPassword.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: rpcPassword.text!)
                selectedNode["rpcpassword"] = enc
                
                let _ = cd.updateNode(viewController: self,
                                      id: id,
                                      newValue: enc,
                                      keyToEdit: "rpcpassword")
                
            }
            
            if rpcPort.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: rpcPort.text!)
                selectedNode["rpcport"] = enc
                
                let _ = cd.updateNode(viewController: self,
                                      id: id,
                                      newValue: enc,
                                      keyToEdit: "rpcport")
                
            }
            
            if (selectedNode["usingSSH"] as! Bool) {
                
                let _ = cd.updateNode(viewController: self,
                                      id: id,
                                      newValue: true,
                                      keyToEdit: "usingSSH")
                
                let _ = cd.updateNode(viewController: self,
                                      id: id,
                                      newValue: false,
                                      keyToEdit: "usingTor")
                
                DispatchQueue.main.async {
                    
                    self.performSegue(withIdentifier: "sshCredentials", sender: self)
                    
                }
                
            }
            
            if (selectedNode["usingTor"] as! Bool) {
                
                let _ = cd.updateNode(viewController: self,
                                      id: id,
                                      newValue: false,
                                      keyToEdit: "usingSSH")
                
                let _ = cd.updateNode(viewController: self,
                                      id: id,
                                      newValue: true,
                                      keyToEdit: "usingTor")
                
                DispatchQueue.main.async {
                    
                    self.performSegue(withIdentifier: "goToTorDetails", sender: self)
                    
                }
                
            }
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTapGesture()
        
        nodeLabel.delegate = self
        rpcPort.delegate = self
        rpcPassword.delegate = self
        rpcUserField.delegate = self
        
        rpcPassword.isSecureTextEntry = true
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        loadValues()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        nodeLabel.text = ""
        rpcUserField.text = ""
        rpcPassword.text = ""
        rpcPort.text = ""
        
    }
    
    func configureTapGesture() {
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        
    }
    
    func loadValues() {
        
        if selectedNode["id"] != nil {
            
            if selectedNode["rpcport"] != nil {
                
                rpcPort.text = aes.decryptKey(keyToDecrypt: (selectedNode["rpcport"] as! String))
                
            } else {
                
                rpcPort.attributedPlaceholder = NSAttributedString(string: "8332 or 18332 for testnet",
                                                                   attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
            if selectedNode["label"] != nil {
                
                nodeLabel.text = aes.decryptKey(keyToDecrypt: (selectedNode["label"] as! String))
                
            } else {
                
                nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                     attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
            if selectedNode["rpcuser"] != nil {
                
                rpcUserField.text = aes.decryptKey(keyToDecrypt: (selectedNode["rpcuser"] as! String))
                
            } else {
                
                rpcUserField.attributedPlaceholder = NSAttributedString(string: "rpcuser",
                                                                        attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
            if selectedNode["rpcpassword"] != nil {
                
                rpcPassword.text = aes.decryptKey(keyToDecrypt: (selectedNode["rpcpassword"] as! String))
                
            } else {
                
                rpcPassword.attributedPlaceholder = NSAttributedString(string: "rpcpassword",
                                                                       attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
        } else {
            
            rpcPassword.attributedPlaceholder = NSAttributedString(string: "rpcpassword",
                                                                   attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            rpcUserField.attributedPlaceholder = NSAttributedString(string: "rpcuser",
                                                                    attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            rpcPort.attributedPlaceholder = NSAttributedString(string: "8332 or 18332 for testnet",
                                                               attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
            nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                 attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
        }
        
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        
        nodeLabel.resignFirstResponder()
        rpcUserField.resignFirstResponder()
        rpcPassword.resignFirstResponder()
        rpcPort.resignFirstResponder()
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        self.view.endEditing(true)
        
        return true
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "sshCredentials":
            
            if let vc = segue.destination as? SSHCredentialsViewController {
                
                vc.selectedNode = self.selectedNode
                vc.newNode = self.newNode
                vc.createNew = self.createNew
                
            }
            
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
