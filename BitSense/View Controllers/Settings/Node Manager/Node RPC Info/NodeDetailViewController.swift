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
        navigationController?.delegate = self
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
                if (rpcUserField.text!).isAlphanumeric {
                    guard let enc = encryptedValue((rpcUserField.text)!.dataUsingUTF8StringEncoding) else { return }
                    newNode["rpcuser"] = enc
                } else {
                    showAlert(vc: self, title: "Only alphanumeric characters allowed in RPC username", message: "")
                    return
                }
            }
            
            if rpcPassword.text != "" {
                if rpcPassword.text!.isAlphanumeric {
                    guard let enc = encryptedValue((rpcPassword.text)!.dataUsingUTF8StringEncoding) else { return }
                    newNode["rpcpassword"] = enc
                } else {
                    showAlert(vc: self, title: "Only alphanumeric characters allowed in RPC password", message: "")
                    return
                }
            }
            
            if onionSane(onion: onionAddressField.text) {
                guard let encryptedOnionAddress = encryptedValue((onionAddressField.text)!.dataUsingUTF8StringEncoding)  else { return }
                newNode["onionAddress"] = encryptedOnionAddress
            } else {
                return
            }
            
            if nodeLabel.text != "" && rpcPassword.text != "" && rpcUserField.text != "" && onionAddressField.text != "" {
                CoreDataService.retrieveEntity(entityName: .newNodes) { [unowned vc = self] nodes in
                    if nodes != nil {
                        if nodes!.count == 0 {
                            vc.newNode["isActive"] = true
                        } else {
                            vc.newNode["isActive"] = false
                        }
                        CoreDataService.saveEntity(dict: vc.newNode, entityName: .newNodes) { [unowned vc = self] success in
                            if success {
                                vc.nodeAddedSuccess()
                            } else {
                                displayAlert(viewController: vc, isError: true, message: "Error saving tor node")
                            }
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
                CoreDataService.update(id: id, keyToUpdate: "label", newValue: nodeLabel.text!, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating label")
                    }
                }
            }
            
            if rpcUserField.text != "" {
                if rpcUserField.text!.isAlphanumeric {
                    guard let enc = encryptedValue((rpcUserField.text)!.dataUsingUTF8StringEncoding) else { return }
                    CoreDataService.update(id: id, keyToUpdate: "rpcuser", newValue: enc, entity: .newNodes) { success in
                        if !success {
                            displayAlert(viewController: self, isError: true, message: "error updating rpc username")
                        }
                    }
                } else {
                    showAlert(vc: self, title: "Only alphanumeric characters allowed in RPC username", message: "")
                }
            }
            
            if rpcPassword.text != "" {
                if rpcPassword.text!.isAlphanumeric {
                    guard let enc = encryptedValue((rpcPassword.text)!.dataUsingUTF8StringEncoding) else { return }
                    CoreDataService.update(id: id, keyToUpdate: "rpcpassword", newValue: enc, entity: .newNodes) { success in
                        if !success {
                            displayAlert(viewController: self, isError: true, message: "error updating rpc password")
                        }
                    }
                } else {
                    showAlert(vc: self, title: "Only alphanumeric characters allowed in RPC password", message: "")
                }
            }
            
            if onionSane(onion: onionAddressField.text) {
                let decryptedAddress = (onionAddressField.text)!.dataUsingUTF8StringEncoding
                guard let encryptedOnionAddress = encryptedValue(decryptedAddress) else { return }
                CoreDataService.update(id: id, keyToUpdate: "onionAddress", newValue: encryptedOnionAddress, entity: .newNodes) { [unowned vc = self] success in
                    if success {
                        vc.nodeAddedSuccess()
                    } else {
                        displayAlert(viewController: vc, isError: true, message: "Error updating node!")
                    }
                }
            }
        }
    }
    
    private func onionSane(onion: String?) -> Bool {
        if onion != "" {
            if onion!.contains(":") {
                let arr = onion!.split(separator: ".")
                if "\(arr[0])".count == 56 && "\(arr[0])".isAlphanumeric {
                    if "\(arr[1])".contains(":") {
                        let arr1 = "\(arr[1])".split(separator: ":")
                        if arr1.count > 1 {
                                if let _ = Int("\(arr1[1])") {
                                    return true
                                } else {
                                    showAlert(vc: self, title: "Not a valid port", message: "")
                                    return false
                                }
                        } else {
                            showAlert(vc: self, title: "No port added", message: "Ensure you add a port to the end of the onion url, for example heuehehe8444.onion:8332")
                            return false
                        }
                    } else {
                       showAlert(vc: self, title: "No port added", message: "Ensure you add a port to the end of the onion url, for example heuehehe8444.onion:8332")
                        return false
                    }
                } else {
                    showAlert(vc: self, title: "Not a valid Tor V3 hostname", message: "")
                    return false
                }
            } else {
               showAlert(vc: self, title: "Not a valid port", message: "")
                return false
            }
        } else {
            showAlert(vc: self, title: "Add an onion hostname", message: "")
            return false
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
    
    private func nodeAddedSuccess() {
        CoreDataService.retrieveEntity(entityName: .newNodes) { [unowned vc = self] nodes in
            if nodes != nil {
                if nodes!.count > 1 {
                    vc.deActivateNodes(nodes: nodes!) {
                        DispatchQueue.main.async { [unowned vc = self] in
                            let alert = UIAlertController(title: "Node saved successfully", message: "Your node has been saved and activated, tap Done to go back. Sometimes its necessary to force quit and reopen FullyNoded to refresh the Tor connection to your new node.", preferredStyle: .actionSheet)
                            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                                DispatchQueue.main.async { [unowned vc = self] in
                                    NotificationCenter.default.post(name: .refreshNode, object: nil)
                                    vc.navigationController?.popToRootViewController(animated: true)
                                }
                            }))
                            alert.popoverPresentationController?.sourceView = vc.view
                            vc.present(alert, animated: true) {}
                        }
                    }
                } else {
                    if !vc.createNew {
                        DispatchQueue.main.async { [unowned vc = self] in
                            let alert = UIAlertController(title: "Node updated successfully", message: "Your node has been updated, tap Done to go back. Sometimes its necessary to force quit and reopen FullyNoded to refresh the Tor connection using your updated node credentials.", preferredStyle: .actionSheet)
                            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                                DispatchQueue.main.async { [unowned vc = self] in
                                    NotificationCenter.default.post(name: .refreshNode, object: nil)
                                    vc.navigationController?.popToRootViewController(animated: true)
                                }
                            }))
                            alert.popoverPresentationController?.sourceView = vc.view
                            vc.present(alert, animated: true) {}
                        }
                    } else {
                       DispatchQueue.main.async { [unowned vc = self] in
                            let alert = UIAlertController(title: "Node added successfully", message: "Your node has been added and activated. The home screen is automatically refreshing. Tap Done to go back.", preferredStyle: .actionSheet)
                            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                                DispatchQueue.main.async { [unowned vc = self] in
                                    NotificationCenter.default.post(name: .refreshNode, object: nil)
                                    vc.navigationController?.popToRootViewController(animated: true)
                                }
                            }))
                            alert.popoverPresentationController?.sourceView = vc.view
                            vc.present(alert, animated: true) {}
                        }
                    }
                }
            }
        }
    }
    
    private func deActivateNodes(nodes: [[String:Any]], completion: @escaping () -> Void) {
        for (i, node) in nodes.enumerated() {
            let str = NodeStruct(dictionary: node)
            let isActive = str.isActive
            if isActive {
                CoreDataService.update(id: str.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
            }
            if i + 1 == nodes.count {
                if createNew {
                    let id = newNode["id"] as! UUID
                    CoreDataService.update(id: id, keyToUpdate: "isActive", newValue: true, entity: .newNodes) { success in
                        completion()
                    }
                } else {
                    let id = selectedNode["id"] as! UUID
                    CoreDataService.update(id: id, keyToUpdate: "isActive", newValue: true, entity: .newNodes) { success in
                        completion()
                    }
                }
            }
        }
    }
}
