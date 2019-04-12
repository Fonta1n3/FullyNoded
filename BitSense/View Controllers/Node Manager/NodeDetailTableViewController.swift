//
//  NodeDetailTableViewController.swift
//  BitSense
//
//  Created by Peter on 04/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class NodeDetailTableViewController: UITableViewController, UITextFieldDelegate {
    
    var node = [String:Any]()
    let aes = AESService.sharedInstance
    let cd = CoreDataService.sharedInstance
    var createNew = Bool()
    @IBOutlet var detailTable: UITableView!
    var newNode = [String:Any]()
    
    @IBAction func save(_ sender: UIButton) {
        
        if createNew {
            
            let cell = detailTable.cellForRow(at: IndexPath.init(row: 0, section: 0))!
            let rpc = cell.viewWithTag(6) as! UISwitch
            let ssh = cell.viewWithTag(7) as! UISwitch
            let label = cell.viewWithTag(1) as! UITextField
            let username = cell.viewWithTag(2) as! UITextField
            let password = cell.viewWithTag(3) as! UITextField
            let ip = cell.viewWithTag(4) as! UITextField
            let port = cell.viewWithTag(5) as! UITextField
            newNode["isSSH"] = ssh.isOn
            newNode["isRPC"] = rpc.isOn
            newNode["id"] = randomString(length: 7)
            newNode["isDefault"] = false
            
            if label.text != "" {
                
                newNode["label"] = label.text!
                
            }
            
            if username.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: username.text!)
                newNode["username"] = enc
                
            }
            
            if password.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: password.text!)
                newNode["password"] = enc
                
            }
            
            if ip.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: ip.text!)
                newNode["ip"] = enc
                
            }
            
            if port.text != "" {
                
                let enc = aes.encryptKey(keyToEncrypt: port.text!)
                newNode["port"] = enc
                
            }
            
            if label.text != "" && username.text != "" && password.text != "" && ip.text != "" && port.text != "" {
                
                print("newnode = \(newNode)")
                
                let success = cd.saveCredentialsToCoreData(vc: self, credentials: newNode)
                
                if success {
                    
                    displayAlert(viewController: self, title: "Success", message: "Node added succesfully")
                    
                } else {
                    
                    displayAlert(viewController: self, title: "Error", message: "Could not save")
                    
                }
                
            } else {
                
                displayAlert(viewController: self, title: "Error", message: "You need to fill out all fields")
                
            }
            
        }
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        detailTable.tableFooterView = UIView(frame: .zero)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        
        let cell = detailTable.cellForRow(at: IndexPath.init(row: 0, section: 0))!
        let label = cell.viewWithTag(1) as! UITextField
        let username = cell.viewWithTag(2) as! UITextField
        let password = cell.viewWithTag(3) as! UITextField
        let ip = cell.viewWithTag(4) as! UITextField
        let port = cell.viewWithTag(5) as! UITextField
        label.resignFirstResponder()
        username.resignFirstResponder()
        password.resignFirstResponder()
        ip.resignFirstResponder()
        port.resignFirstResponder()
        
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
        
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return 1
        
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "nodeDetail", for: indexPath)
        
        let label = cell.viewWithTag(1) as! UITextField
        label.delegate = self
        
        let username = cell.viewWithTag(2) as! UITextField
        username.delegate = self
        
        let password = cell.viewWithTag(3) as! UITextField
        password.delegate = self
        
        let ip = cell.viewWithTag(4) as! UITextField
        ip.delegate = self
        
        let port = cell.viewWithTag(5) as! UITextField
        port.delegate = self
        
        let rpc = cell.viewWithTag(6) as! UISwitch
        let ssh = cell.viewWithTag(7) as! UISwitch
        
        rpc.addTarget(self, action: #selector(switchRPC), for: .touchUpInside)
        ssh.addTarget(self, action: #selector(switchSSH), for: .touchUpInside)
        
        let button = cell.viewWithTag(8) as! UIButton
        
        if !createNew {
            
            button.alpha = 0
            
        }
        
        if node["id"] != nil {
            
            username.text = aes.decryptKey(keyToDecrypt: (node["username"] as! String))
            password.text = aes.decryptKey(keyToDecrypt: (node["password"] as! String))
            ip.text = aes.decryptKey(keyToDecrypt: (node["ip"] as! String))
            port.text = aes.decryptKey(keyToDecrypt: (node["port"] as! String))
            rpc.isOn = node["isRPC"] as! Bool
            ssh.isOn = node["isSSH"] as! Bool
            
            if node["label"] != nil {
                
                label.text = (node["label"] as! String)
                
            } else {
                
                label.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                 attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
        } else {
            
            username.attributedPlaceholder = NSAttributedString(string: "Enter SSH user",
                                                                attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            password.attributedPlaceholder = NSAttributedString(string: "Enter SSH password",
                                                                attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            ip.attributedPlaceholder = NSAttributedString(string: "Enter SSH host IP",
                                                          attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            port.attributedPlaceholder = NSAttributedString(string: "Enter SSH port",
                                                            attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            label.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                             attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            rpc.isOn = false
            ssh.isOn = true
            
        }
        
        return cell
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        let cell = detailTable.cellForRow(at: IndexPath.init(row: 0, section: 0))!
        let label = cell.viewWithTag(1) as! UITextField
        let username = cell.viewWithTag(2) as! UITextField
        let password = cell.viewWithTag(3) as! UITextField
        let ip = cell.viewWithTag(4) as! UITextField
        let port = cell.viewWithTag(5) as! UITextField
        
        if let id = node["id"] as? String {
            
            if !createNew {
                
                if textField.text != "" {
                    
                    switch textField {
                        
                    case label:
                        
                        if label.text != "" {
                            
                            let success = cd.updateNode(viewController: self, id: id, newValue: label.text!, keyToEdit: "label")
                            print("success = \(success)")
                            
                            if success {
                                
                                displayAlert(viewController: self, title: "Success", message: "Node updated")
                                
                            } else {
                                
                                displayAlert(viewController: self, title: "Error", message: "Error updating node")
                            }
                            
                        }
                        
                    case username:
                        
                        if username.text != "" {
                            
                            let enc = aes.encryptKey(keyToEncrypt: username.text!)
                            let success = cd.updateNode(viewController: self, id: id, newValue: enc, keyToEdit: "username")
                            
                            if success {
                                
                                displayAlert(viewController: self, title: "Success", message: "Node updated")
                                
                            } else {
                                
                                displayAlert(viewController: self, title: "Error", message: "Error updating node")
                            }
                            
                        }
                        
                    case password:
                        
                        if password.text != "" {
                            
                            let enc = aes.encryptKey(keyToEncrypt: password.text!)
                            let success = cd.updateNode(viewController: self, id: id, newValue: enc, keyToEdit: "password")
                            
                            if success {
                                
                                displayAlert(viewController: self, title: "Success", message: "Node updated")
                                
                            } else {
                                
                                displayAlert(viewController: self, title: "Error", message: "Error updating node")
                            }
                            
                        }
                        
                    case ip:
                        
                        if ip.text != "" {
                            
                            let enc = aes.encryptKey(keyToEncrypt: ip.text!)
                            let success = cd.updateNode(viewController: self, id: id, newValue: enc, keyToEdit: "ip")
                            
                            if success {
                                
                                displayAlert(viewController: self, title: "Success", message: "Node updated")
                                
                            } else {
                                
                                displayAlert(viewController: self, title: "Error", message: "Error updating node")
                            }
                            
                        }
                        
                    case port:
                        
                        if port.text != "" {
                            
                            let enc = aes.encryptKey(keyToEncrypt: port.text!)
                            let success = cd.updateNode(viewController: self, id: id, newValue: enc, keyToEdit: "port")
                            
                            if success {
                                
                                displayAlert(viewController: self, title: "Success", message: "Node updated")
                                
                            } else {
                                
                                displayAlert(viewController: self, title: "Error", message: "Error updating node")
                            }
                            
                        }
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    displayAlert(viewController: self, title: "Error", message: "You need to enter a value in the text field.")
                    
                }
                
            }
            
        }
            
        self.view.endEditing(true)
        
        return true
        
     }
    
    @objc func switchSSH() {
        
        let cell = detailTable.cellForRow(at: IndexPath.init(row: 0, section: 0))!
        let rpc = cell.viewWithTag(6) as! UISwitch
        let ssh = cell.viewWithTag(7) as! UISwitch
        
        if !createNew {
            
            if let id = node["id"] as? String {
                
                if !ssh.isOn {
                    
                    rpc.isOn = true
                    ssh.isOn = false
                    let success1 = cd.updateNode(viewController: self, id: id, newValue: true, keyToEdit: "isRPC")
                    let success2 = cd.updateNode(viewController: self, id: id, newValue: false, keyToEdit: "isSSH")
                    
                    if success1 && success2 {
                        
                        self.updatePlaceHolders(cell: cell, ssh: ssh.isOn)
                        displayAlert(viewController: self, title: "Success", message: "Node updated")
                        
                    } else {
                        
                        displayAlert(viewController: self, title: "Error", message: "Error updating node")
                        
                    }
                    
                    
                } else {
                    
                    rpc.isOn = false
                    ssh.isOn = true
                    let success1 = cd.updateNode(viewController: self, id: id, newValue: true, keyToEdit: "isSSH")
                    let success2 = cd.updateNode(viewController: self, id: id, newValue: false, keyToEdit: "isRPC")
                    
                    if success1 && success2 {
                        
                        self.updatePlaceHolders(cell: cell, ssh: ssh.isOn)
                        displayAlert(viewController: self, title: "Success", message: "Node updated")
                        
                    } else {
                        
                        displayAlert(viewController: self, title: "Error", message: "Error updating node")
                        
                    }
                    
                }
                
            }
            
        } else {
            
            if !ssh.isOn {
                
                rpc.isOn = true
                ssh.isOn = false
                self.updatePlaceHolders(cell: cell, ssh: ssh.isOn)
                
            } else if ssh.isOn {
                
                rpc.isOn = false
                ssh.isOn = true
                self.updatePlaceHolders(cell: cell, ssh: ssh.isOn)
                
            }
            
        }
        
    }
    
    @objc func switchRPC() {
        
        let cell = detailTable.cellForRow(at: IndexPath.init(row: 0, section: 0))!
        let rpc = cell.viewWithTag(6) as! UISwitch
        let ssh = cell.viewWithTag(7) as! UISwitch
        
        if !createNew {
            
            if let id = node["id"] as? String {
                
                if !rpc.isOn {
                    
                    rpc.isOn = false
                    ssh.isOn = true
                    let success1 = cd.updateNode(viewController: self, id: id, newValue: false, keyToEdit: "isRPC")
                    let success2 = cd.updateNode(viewController: self, id: id, newValue: true, keyToEdit: "isSSH")
                    
                    if success1 && success2 {
                        
                        self.updatePlaceHolders(cell: cell, ssh: ssh.isOn)
                        displayAlert(viewController: self, title: "Success", message: "Node updated")
                        
                    } else {
                        
                        displayAlert(viewController: self, title: "Error", message: "Error updating node")
                        
                    }
                    
                } else {
                    
                    rpc.isOn = true
                    ssh.isOn = false
                    let success1 = cd.updateNode(viewController: self, id: id, newValue: false, keyToEdit: "isSSH")
                    let success2 = cd.updateNode(viewController: self, id: id, newValue: true, keyToEdit: "isRPC")
                    
                    if success1 && success2 {
                        
                        self.updatePlaceHolders(cell: cell, ssh: ssh.isOn)
                        displayAlert(viewController: self, title: "Success", message: "Node updated")
                        
                    } else {
                        
                        displayAlert(viewController: self, title: "Error", message: "Error updating node")
                        
                    }
                    
                }
                
            }
            
        } else {
            
            if !rpc.isOn {
                
                rpc.isOn = false
                ssh.isOn = true
                self.updatePlaceHolders(cell: cell, ssh: ssh.isOn)
                
            } else if rpc.isOn {
                
                rpc.isOn = true
                ssh.isOn = false
                self.updatePlaceHolders(cell: cell, ssh: ssh.isOn)
                
            }
            
        }
        
    }
    
    func updatePlaceHolders(cell: UITableViewCell, ssh: Bool) {
        
        let username = cell.viewWithTag(2) as! UITextField
        let password = cell.viewWithTag(3) as! UITextField
        let ip = cell.viewWithTag(4) as! UITextField
        let port = cell.viewWithTag(5) as! UITextField
        
        if ssh {
            
            DispatchQueue.main.async {
                
                username.attributedPlaceholder = NSAttributedString(string: "Enter SSH user",
                                                                    attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                password.attributedPlaceholder = NSAttributedString(string: "Enter SSH password",
                                                                    attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                ip.attributedPlaceholder = NSAttributedString(string: "Enter SSH host IP",
                                                              attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                port.attributedPlaceholder = NSAttributedString(string: "Enter SSH port",
                                                                attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
        } else {
            
            DispatchQueue.main.async {
                
                username.attributedPlaceholder = NSAttributedString(string: "Enter rpcusername",
                                                                    attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                password.attributedPlaceholder = NSAttributedString(string: "Enter rpcpassword",
                                                                    attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                ip.attributedPlaceholder = NSAttributedString(string: "Enter Nodes IP",
                                                              attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                port.attributedPlaceholder = NSAttributedString(string: "18332/testnet or 8332/mainnet",
                                                                attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
        }
        
    }

}
