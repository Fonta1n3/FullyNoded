//
//  ChooseConnectionTypeViewController.swift
//  BitSense
//
//  Created by Peter on 13/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ChooseConnectionTypeViewController: UIViewController {
    
    let cd = CoreDataService()
    var selectedNode = [String:Any]()
    var isUpdating = Bool()
    var successes = [Bool]()
    var scannerShowing = false
    var isFirstTime = Bool()
    
    @IBOutlet var sshSwitchOutlet: UISwitch!
    @IBOutlet var torSwitchOutlet: UISwitch!
    @IBOutlet var imageView: UIImageView!
    
    let qrScanner = QRScanner()
    var isTorchOn = Bool()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let connectingView = ConnectingView()
    
    @IBAction func nextAction(_ sender: Any) {
        
        if torSwitchOutlet.isOn || sshSwitchOutlet.isOn {
            
            self.performSegue(withIdentifier: "goToNodeDetails", sender: self)
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "You need to either choose Tor or SSH")
            
        }
        
    }
    
    @IBAction func sshSwitchAction(_ sender: Any) {
        
        if sshSwitchOutlet.isOn {
            
            torSwitchOutlet.isOn = false
            
        } else {
            
            torSwitchOutlet.isOn = true
            
        }
        
        if isUpdating {
            
            let node = NodeStruct(dictionary: selectedNode)
            
            let id = node.id
            
//            let success = cd.updateNode(viewController: self,
//                                        id: id,
//                                        newValue: sshSwitchOutlet.isOn,
//                                        keyToEdit: "usingSSH")
            
            let success = cd.updateEntity(viewController: self,
                                          id: id,
                                          newValue: sshSwitchOutlet.isOn,
                                          keyToEdit: "usingSSH",
                                          entityName: ENTITY.nodes)
            
            successes.append(success)
            
        }
        
    }
    
    
    @IBAction func torSwitchAction(_ sender: Any) {
        
        if torSwitchOutlet.isOn {
            
            sshSwitchOutlet.isOn = false
            
        } else {
            
            sshSwitchOutlet.isOn = true
            
        }
        
        if isUpdating {
            
            let node = NodeStruct(dictionary: selectedNode)
            let id = node.id
            
//            let success = cd.updateNode(viewController: self,
//                                        id: id,
//                                        newValue: torSwitchOutlet.isOn,
//                                        keyToEdit: "usingTor")
            
            let success = cd.updateEntity(viewController: self,
                                          id: id,
                                          newValue: torSwitchOutlet.isOn,
                                          keyToEdit: "usingTor",
                                          entityName: ENTITY.nodes)
            
            successes.append(success)
            
        }
        
    }
    
    @IBAction func scanQR(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.scanNow()
            
        }
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureScanner()

        if isUpdating {
            
            let node = NodeStruct(dictionary: selectedNode)
            
            sshSwitchOutlet.isOn = node.usingSSH
            torSwitchOutlet.isOn = node.usingTor
            
        } else {
            
            sshSwitchOutlet.isOn = false
            torSwitchOutlet.isOn = false
            
        }
        
    }
    
    func configureScanner() {
        
        isFirstTime = true
        
        imageView.alpha = 0
        imageView.frame = view.frame
        imageView.isUserInteractionEnabled = true
        
        qrScanner.keepRunning = false
        qrScanner.vc = self
        qrScanner.imageView = imageView
        
        qrScanner.completion = { self.getQRCode() }
        qrScanner.downSwipeAction = { self.back() }
        
        qrScanner.closeButton.addTarget(self,
                                        action: #selector(back),
                                        for: .touchUpInside)
        
    }
        
        @objc func back() {
            
            DispatchQueue.main.async {
                
                self.qrScanner.textField.removeFromSuperview()
                self.blurView.removeFromSuperview()
                self.imageView.alpha = 0
                self.scannerShowing = false
                
            }
            
        }
        
        @objc func toggleTorch() {
            
            if isTorchOn {
                
                qrScanner.toggleTorch(on: false)
                isTorchOn = false
                
            } else {
                
                qrScanner.toggleTorch(on: true)
                isTorchOn = true
                
            }
        
    }
    
    func scanNow() {
        print("scanNow")
        
        scannerShowing = true
        
        if isFirstTime {
            
            DispatchQueue.main.async {
                
                self.qrScanner.scanQRCode()
                self.imageView.addSubview(self.qrScanner.closeButton)
                self.isFirstTime = false
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                })
                
            }
            
        } else {
            
            self.qrScanner.startScanner()
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                })
                
            }
            
        }
        
    }
    
    func getQRCode() {
        
        let stringURL = qrScanner.stringToReturn
        addBtcRpcQr(url: stringURL)
        
    }
    
    func addBtcRpcQr(url: String) {
        
        let aes = AESService()
        let cd = CoreDataService()
        let nodes = cd.retrieveEntity(entityName: .nodes)
        
        let arr1 = url.components(separatedBy: "?")
        let onion = arr1[0].replacingOccurrences(of: "btcrpc://", with: "")
        
        if arr1.count > 1 {
            
            let arr2 = arr1[1].components(separatedBy: "&")
            let rpcuser = arr2[0].replacingOccurrences(of: "user=", with: "")
            let rpcpassword = arr2[1].replacingOccurrences(of: "password=", with: "")
            
            var label = "Nodl - Tor"
            var v2password = ""
            
            if arr1.count > 2 {
                
                if arr1[2].contains("label=") {
                    
                    label = arr1[2].replacingOccurrences(of: "label=", with: "")
                    
                } else {
                    
                    v2password = arr1[2].replacingOccurrences(of: "v2password=", with: "")
                    
                }
                
                
                if arr1.count > 3 {
                    
                    v2password = arr1[3].replacingOccurrences(of: "v2password=", with: "")
                    
                }
                
            }
            
            var node = [String:Any]()
            let torNodeId = randomString(length: 23)
            let torNodeHost = aes.encryptKey(keyToEncrypt: onion)
            let torNodeRPCPass = aes.encryptKey(keyToEncrypt: rpcpassword)
            let torNodeRPCUser = aes.encryptKey(keyToEncrypt: rpcuser)
            var torNodeLabel = aes.encryptKey(keyToEncrypt: label)
            let torNodeV2Password = aes.encryptKey(keyToEncrypt: v2password)
            
            if label != "" {
                
                torNodeLabel = aes.encryptKey(keyToEncrypt: label)
                
            }
            
            node["id"] = torNodeId
            node["onionAddress"] = torNodeHost
            node["label"] = torNodeLabel
            node["rpcuser"] = torNodeRPCUser
            node["rpcpassword"] = torNodeRPCPass
            node["usingSSH"] = false
            node["isDefault"] = false
            node["usingTor"] = true
            node["isActive"] = true
            
            if v2password != "" {
                
                node["v2password"] = torNodeV2Password
                
            }
                    
            let success = cd.saveEntity(vc: self,
                                        dict: node,
                                        entityName: .nodes)
            
            if success {
                
                print("nodl node added")
                deActivateOtherNodes(nodes: nodes,
                                     nodlID: torNodeId,
                                     cd: cd,
                                     vc: self)
                
                DispatchQueue.main.async {
                    
                    self.back()
                    self.tabBarController?.selectedIndex = 0
                    
                }
                
                
                
            } else {
                
                print("error adding nodl node")
                
            }
            
        } else {
            
            back()
            displayAlert(viewController: self, isError: true, message: "incompatible uri")
        }
        
    }
    
    func deActivateOtherNodes(nodes: [[String:Any]], nodlID: String, cd: CoreDataService, vc: UIViewController) {
        
        if SSHService.sharedInstance.session != nil {
            
            if SSHService.sharedInstance.session.isConnected {
                
                SSHService.sharedInstance.disconnect()
                SSHService.sharedInstance.commandExecuting = false
                
            }
            
        }
        
        for node in nodes {
            
            let str = NodeStruct(dictionary: node)
            let id = str.id
            let isActive = str.isActive
            
            if id != nodlID && isActive {
                
                let success = cd.updateEntity(viewController: vc,
                                              id: id,
                                              newValue: false,
                                              keyToEdit: "isActive",
                                              entityName: .nodes)
                
                if success {
                    
                    print("nodes deactivated")
                    
                }
                
            }
            
        }
        
    }

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "goToNodeDetails":
            
            if let vc = segue.destination as? NodeDetailViewController  {
                
                vc.newNode["usingSSH"] = sshSwitchOutlet.isOn
                vc.newNode["usingTor"] = torSwitchOutlet.isOn
                vc.selectedNode = self.selectedNode
                
                if !isUpdating {
                    
                    vc.createNew = true
                    
                } else {
                    
                    vc.createNew = false
                    
                }
                
            }
            
        default:
            
            break
            
        }
        
    }

}
