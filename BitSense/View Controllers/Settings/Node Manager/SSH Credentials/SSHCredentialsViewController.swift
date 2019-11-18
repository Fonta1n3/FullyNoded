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
    @IBOutlet var portField: UITextField!
    @IBOutlet var privKeyField: UITextField!
    @IBOutlet var pubKeyField: UITextField!
    @IBOutlet var saveButton: UIButton!
    
    @IBAction func saveAction(_ sender: Any) {
        
//        if createNew {
//
//            if hostField.text != "" && ipField.text != "" && portField.text != "" && passwordField.text != "" {
//
//                let id = randomString(length: 23)
//                let encHost = aes.encryptKey(keyToEncrypt: hostField.text!)
//                let encIP = aes.encryptKey(keyToEncrypt: ipField.text!)
//                let encPort = aes.encryptKey(keyToEncrypt: portField.text!)
//                let encPassword = aes.encryptKey(keyToEncrypt: passwordField.text!)
//
//                if privKeyField.text != "" && pubKeyField.text != "" {
//
//                    let encPrivKey = aes.encryptKey(keyToEncrypt: privKeyField.text!)
//                    let encPubKey = aes.encryptKey(keyToEncrypt: pubKeyField.text!)
//
//                    newNode["privateKey"] = encPrivKey
//                    newNode["publicKey"] = encPubKey
//
//                }
//
//                newNode["id"] = id
//                newNode["username"] = encHost
//                newNode["ip"] = encIP
//                newNode["port"] = encPort
//                newNode["password"] = encPassword
//
//                let success = cd.saveEntity(vc: navigationController!,
//                                            dict: newNode,
//                                            entityName: ENTITY.nodes)
//
//                if success {
//
//                    displayAlert(viewController: self,
//                                 isError: false,
//                                 message: "Node added")
//
//                } else {
//
//                    displayAlert(viewController: self,
//                                 isError: true,
//                                 message: "Error saving node")
//
//                }
//
//            } else {
//
//                displayAlert(viewController: self,
//                             isError: true,
//                             message: "Fill out all required fields")
//
//            }
//
//        } else {
//
//            let id = selectedNode["id"] as! String
//            let encHost = aes.encryptKey(keyToEncrypt: hostField.text!)
//            let encIP = aes.encryptKey(keyToEncrypt: ipField.text!)
//            let encPort = aes.encryptKey(keyToEncrypt: portField.text!)
//            let encPassword = aes.encryptKey(keyToEncrypt: passwordField.text!)
//
//            if privKeyField.text != "" {
//
//                let processedPrivKey = privKeyField.text!.replacingOccurrences(of: " ", with: "")
//                let encPrivKey = aes.encryptKey(keyToEncrypt: processedPrivKey)
//                selectedNode["privateKey"] = encPrivKey
//
//            } else {
//
//                selectedNode["privateKey"] = ""
//
//            }
//
//            if pubKeyField.text != "" {
//
//                let encPubKey = aes.encryptKey(keyToEncrypt: pubKeyField.text!)
//                selectedNode["publicKey"] = encPubKey
//
//            } else {
//
//                selectedNode["publicKey"] = ""
//            }
//
//
//            selectedNode["username"] = encHost
//            selectedNode["ip"] = encIP
//            selectedNode["port"] = encPort
//            selectedNode["password"] = encPassword
//
//            var successes = [Bool]()
//
//            for (key, value) in selectedNode {
//
//                let success = cd.updateEntity(viewController: navigationController!,
//                                              id: id,
//                                              newValue: value,
//                                              keyToEdit: key,
//                                              entityName: ENTITY.nodes)
//
//                successes.append(success)
//
//            }
//
//            var succeed = true
//
//            for success in successes {
//
//                if !success {
//
//                    succeed = false
//
//                }
//
//            }
//
//            if succeed {
//
//                displayAlert(viewController: self,
//                             isError: false,
//                             message: "Node updated")
//
//                loadValues()
//
//            } else {
//
//                displayAlert(viewController: self,
//                             isError: true,
//                             message: "Error updating node")
//
//            }
//
//        }
        
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
        privKeyField.delegate = self
        pubKeyField.delegate = self
        passwordField.isSecureTextEntry = true
        privKeyField.isSecureTextEntry = true
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        passwordField.text = ""
        privKeyField.text = ""
        pubKeyField.text = ""
        
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        
        hostField.resignFirstResponder()
        passwordField.resignFirstResponder()
        ipField.resignFirstResponder()
        portField.resignFirstResponder()
        privKeyField.resignFirstResponder()
        pubKeyField.resignFirstResponder()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
//        loadValues()
//
//        if !createNew {
//
//            DispatchQueue.main.async {
//
//                self.saveButton.setTitle("Update", for: .normal)
//
//            }
//
//        }
        
    }

    func loadValues() {
        
//        if !createNew {
//
//            let node = NodeStruct(dictionary: selectedNode)
//            let nodeId = node.id
//
//            cd.retrieveEntity(entityName: .nodes) {
//
//                if !self.cd.errorBool {
//
//                    let nodes = self.cd.entities
//                    for n in nodes {
//
//                        let str = NodeStruct(dictionary: n)
//
//                        if str.id == nodeId {
//
//                            //load this node to prevent showing old selected node values when user navigates back and forth
//                            let encIP = str.ip
//                            let encPort = str.port
//                            let encPassword = str.password
//                            let encHost = str.username
//                            self.hostField.text = self.aes.decryptKey(keyToDecrypt: encHost)
//                            self.ipField.text = self.aes.decryptKey(keyToDecrypt: encIP)
//                            self.portField.text = self.aes.decryptKey(keyToDecrypt: encPort)
//                            self.passwordField.text = self.aes.decryptKey(keyToDecrypt: encPassword)
//
//                            if str.privateKey != "" {
//
//                                self.privKeyField.text = self.aes.decryptKey(keyToDecrypt: str.privateKey)
//
//                            }
//
//                            if str.publicKey != "" {
//
//                                self.pubKeyField.text = self.aes.decryptKey(keyToDecrypt: str.publicKey)
//
//                            }
//
//                        }
//
//                    }
//
//                } else {
//
//                    displayAlert(viewController: self, isError: true, message: "error gettings nodes from core data")
//
//                }
//
//            }
//
//        }
        
    }
    
    override func willMove(toParent parent: UIViewController?) {
        
//        if let vc = parent as? NodeDetailViewController {
//            
//            vc.selectedNode = selectedNode
//            vc.createNew = createNew
//        }
        
    }

}
