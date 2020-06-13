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
    let cd = CoreDataService()
    var createNew = Bool()
    var newNode = [String:Any]()
    var isInitialLoad = Bool()
    
    @IBOutlet var nodeLabel: UITextField!
    @IBOutlet var rpcUserField: UITextField!
    @IBOutlet var rpcPassword: UITextField!
    @IBOutlet var rpcLabel: UILabel!
    @IBOutlet var saveButton: UIButton!
    @IBOutlet weak var onionAddressField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTapGesture()
        nodeLabel.delegate = self
        rpcPassword.delegate = self
        rpcUserField.delegate = self
        onionAddressField.delegate = self
        rpcPassword.isSecureTextEntry = true
        onionAddressField.isSecureTextEntry = true
        saveButton.clipsToBounds = true
        saveButton.layer.cornerRadius = 8
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadValues()
    }
    
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
            
            newNode["id"] = UUID()
            
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
            
            if onionAddressField.text != "" {
                guard let encryptedOnionAddress = encryptedValue((onionAddressField.text)!.dataUsingUTF8StringEncoding)  else { return }
                newNode["onionAddress"] = encryptedOnionAddress
            }
            
            if nodeLabel.text != "" && rpcPassword.text != "" && rpcUserField.text != "" && onionAddressField.text != "" {
                var refresh = false
                cd.retrieveEntity(entityName: .newNodes) { [unowned vc = self] in
                    if vc.cd.entities.count == 0 {
                        vc.newNode["isActive"] = true
                        refresh = true
                    } else {
                        vc.newNode["isActive"] = false
                    }
                    vc.cd.saveEntity(dict: vc.newNode, entityName: .newNodes) { [unowned vc = self] in
                        
                        if !vc.cd.errorBool {
                            
                            let success = vc.cd.boolToReturn
                            
                            if success {
                                
                                if refresh {
                                    NotificationCenter.default.post(name: .refreshNode, object: nil)
                                    displayAlert(viewController: vc, isError: false, message: "Tor node saved, we are now refreshing the home screen automatically.")
                                } else {
                                    displayAlert(viewController: vc, isError: false, message: "Tor node saved")
                                }
                                
                            } else {
                                
                                displayAlert(viewController: vc, isError: true, message: "Error saving tor node")
                                
                            }
                            
                        } else {
                            
                            displayAlert(viewController: vc, isError: true, message: vc.cd.errorDescription)
                        }
                        
                    }
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Fill out all fields first")
                
            }
            
        } else {
            
            //updating
            
            let id = selectedNode["id"] as! UUID
            
            if nodeLabel.text != "" {
                cd.update(id: id, keyToUpdate: "label", newValue: nodeLabel.text!, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating label")
                    }
                }
            }
            
            if rpcUserField.text != "" {
                guard let enc = encryptedValue((rpcUserField.text)!.dataUsingUTF8StringEncoding) else { return }
                cd.update(id: id, keyToUpdate: "rpcuser", newValue: enc, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating rpc username")
                    }
                }
            }
            
            if rpcPassword.text != "" {
                guard let enc = encryptedValue((rpcPassword.text)!.dataUsingUTF8StringEncoding) else { return }
                cd.update(id: id, keyToUpdate: "rpcpassword", newValue: enc, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating rpc password")
                    }
                }
            }
            
            if onionAddressField.text != "" {
                let decryptedAddress = (onionAddressField.text)!.dataUsingUTF8StringEncoding
                guard let encryptedOnionAddress = encryptedValue(decryptedAddress) else { return }
                cd.update(id: id, keyToUpdate: "onionAddress", newValue: encryptedOnionAddress, entity: .newNodes) { [unowned vc = self] success in
                    if success {
                        displayAlert(viewController: vc, isError: false, message: "Node updated!")
                    } else {
                        displayAlert(viewController: vc, isError: true, message: "Error updating node!")
                    }
                }
            }
        }
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
            
            if let enc = node.onionAddress {
                onionAddressField.text = decryptedValue(enc)
            } else {
                onionAddressField.attributedPlaceholder = NSAttributedString(string: "83nd8e93djh.onion:8332",
                                                                             attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            }
            
        } else {
                        
            rpcPassword.attributedPlaceholder = NSAttributedString(string: "rpcpassword",
                                                                   attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
            rpcUserField.attributedPlaceholder = NSAttributedString(string: "rpcuser",
                                                                    attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
            nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                 attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
            onionAddressField.attributedPlaceholder = NSAttributedString(string: "83nd8e93djh.onion:8332",
                                                                         attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
        }
        
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        onionAddressField.resignFirstResponder()
        nodeLabel.resignFirstResponder()
        rpcUserField.resignFirstResponder()
        rpcPassword.resignFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }
    
}
