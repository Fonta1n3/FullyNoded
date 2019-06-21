//
//  SSHCredentialsViewController.swift
//  BitSense
//
//  Created by Peter on 13/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class SSHCredentialsViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    var selectedNode = [String:Any]()
    var newNode = [String:Any]()
    let aes = AESService()
    let cd = CoreDataService()
    var createNew = Bool()
    
    @IBOutlet var hostField: UITextField!
    @IBOutlet var passwordField: UITextField!
    @IBOutlet var ipField: UITextField!
    @IBOutlet var pathField: UITextField!
    @IBOutlet var portField: UITextField!
    
    @IBOutlet var saveButton: UIButton!
    
    @IBAction func saveAction(_ sender: Any) {
        
        if createNew {
            
            if hostField.text != "" && ipField.text != "" && portField.text != "" && passwordField.text != "" {
                
                let id = randomString(length: 23)
                let encHost = aes.encryptKey(keyToEncrypt: hostField.text!)
                let encIP = aes.encryptKey(keyToEncrypt: ipField.text!)
                let encPort = aes.encryptKey(keyToEncrypt: portField.text!)
                let encPassword = aes.encryptKey(keyToEncrypt: passwordField.text!)
                var encPath = aes.encryptKey(keyToEncrypt: "bitcoin-cli")
                
                if pathField.text != "" {
                    
                    encPath = aes.encryptKey(keyToEncrypt: pathField.text!)
                    
                }
                
                newNode["id"] = id
                newNode["username"] = encHost
                newNode["ip"] = encIP
                newNode["port"] = encPort
                newNode["password"] = encPassword
                newNode["path"] = encPath
                
                let success = cd.saveCredentialsToCoreData(vc: navigationController!,
                                                           credentials: newNode)
                
                if success {
                    
                    displayAlert(viewController: navigationController!,
                                 isError: false,
                                 message: "Node added")
                    
                    self.navigationController!.popToRootViewController(animated: true)
                    
                } else {
                    
                    displayAlert(viewController: navigationController!,
                                 isError: true,
                                 message: "Error saving node")
                    
                }
                
            } else {
                
                displayAlert(viewController: navigationController!,
                             isError: true,
                             message: "Fill out all required fields")
                
            }
            
        } else {
            
            let id = selectedNode["id"] as! String
            let encHost = aes.encryptKey(keyToEncrypt: hostField.text!)
            let encIP = aes.encryptKey(keyToEncrypt: ipField.text!)
            let encPort = aes.encryptKey(keyToEncrypt: portField.text!)
            let encPassword = aes.encryptKey(keyToEncrypt: passwordField.text!)
            var encPath = aes.encryptKey(keyToEncrypt: "bitcoin-cli")
            
            if pathField.text != "" {
                
                encPath = aes.encryptKey(keyToEncrypt: pathField.text!)
                
            }
            
            selectedNode["username"] = encHost
            selectedNode["ip"] = encIP
            selectedNode["port"] = encPort
            selectedNode["password"] = encPassword
            selectedNode["path"] = encPath
            
            var successes = [Bool]()
            
            for (key, value) in selectedNode {
                
                let success = cd.updateNode(viewController: navigationController!,
                                            id: id,
                                            newValue: value,
                                            keyToEdit: key)
                
                successes.append(success)
                
            }
            
            var succeed = true
            
            for success in successes {
                
                if !success {
                    
                    succeed = false
                    
                }
                
            }
            
            if succeed {
                
                displayAlert(viewController: navigationController!,
                             isError: false,
                             message: "Node updated")
                
                self.navigationController!.popToRootViewController(animated: true)
                
            } else {
                
                displayAlert(viewController: navigationController!,
                             isError: true,
                             message: "Error updating node")
                
            }
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)

        hostField.delegate = self
        passwordField.delegate = self
        ipField.delegate = self
        portField.delegate = self
        pathField.delegate = self
        
        passwordField.isSecureTextEntry = true
        
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        
        hostField.resignFirstResponder()
        passwordField.resignFirstResponder()
        ipField.resignFirstResponder()
        portField.resignFirstResponder()
        pathField.resignFirstResponder()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        loadValues()
        
        if !createNew {
            
            DispatchQueue.main.async {
                
                self.saveButton.setTitle("Update", for: .normal)
                
            }
            
        }
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        hostField.text = ""
        passwordField.text = ""
        ipField.text = ""
        portField.text = ""
        pathField.text = ""
        
    }
    

    func loadValues() {
        
        if !createNew {
            
            let encIP = selectedNode["ip"] as! String
            let encPort = selectedNode["port"] as! String
            let encPassword = selectedNode["password"] as! String
            let encHost = selectedNode["username"] as! String
            
            if let encPath = selectedNode["path"] as? String {
                
                pathField.text = aes.decryptKey(keyToDecrypt: encPath)
                
            }
            
            hostField.text = aes.decryptKey(keyToDecrypt: encHost)
            ipField.text = aes.decryptKey(keyToDecrypt: encIP)
            portField.text = aes.decryptKey(keyToDecrypt: encPort)
            passwordField.text = aes.decryptKey(keyToDecrypt: encPassword)
            
        }
        
    }

}
