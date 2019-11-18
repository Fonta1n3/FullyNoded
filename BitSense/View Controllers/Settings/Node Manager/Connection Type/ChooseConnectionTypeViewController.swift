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
        
//        if sshSwitchOutlet.isOn {
//
//            torSwitchOutlet.isOn = false
//
//        } else {
//
//            torSwitchOutlet.isOn = true
//
//        }
//
//        if isUpdating {
//
//            let node = NodeStruct(dictionary: selectedNode)
//
//            let success = cd.updateEntity(viewController: self,
//                                          id: node.id,
//                                          newValue: sshSwitchOutlet.isOn,
//                                          keyToEdit: "usingSSH",
//                                          entityName: .nodes)
//
//            successes.append(success)
//
//        }
        
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
            
            let d:[String:Any] = ["id":id,"newValue":torSwitchOutlet.isOn,"keyToEdit":"usingTor","entityName":ENTITY.nodes]
            
            cd.updateEntity(dictsToUpdate: [d]) {
                
                if !self.cd.errorBool {
                    
                    let success = self.cd.boolToReturn
                    
                    if success {
                        
                        displayAlert(viewController: self, isError: false, message: "updated")
                        
                    } else {
                        
                        displayAlert(viewController: self, isError: true, message: "error updating node")
                        
                    }
                    
                } else {
                    
                    displayAlert(viewController: self, isError: true, message: self.cd.errorDescription)
                    
                }
                
            }            
            
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
        
        let qc = QuickConnect()
    
        func getResult() {
            
            print("result")
            
            if !qc.errorBool {
                
                DispatchQueue.main.async {
                    
                    self.back()
                    
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: qc.errorDescription)
                
            }
            
        }
        
        if url.hasPrefix("btcrpc://") || url.hasPrefix("btcstandup://") {
            
            qc.addNode(vc: self,
                       url: url,
                       completion: getResult)
            
        } else {
            
            back()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Thats not a compatible url!")
            
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
