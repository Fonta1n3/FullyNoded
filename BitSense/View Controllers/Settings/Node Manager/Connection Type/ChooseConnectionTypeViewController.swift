//
//  ChooseConnectionTypeViewController.swift
//  BitSense
//
//  Created by Peter on 13/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ChooseConnectionTypeViewController: UIViewController, UITabBarControllerDelegate {
    
    let cd = CoreDataService()
    var selectedNode = [String:Any]()
    var isUpdating = Bool()
    var scannerShowing = false
    var isFirstTime = Bool()
    var cameFromHome = Bool()
    
    @IBOutlet var imageView: UIImageView!
    
    let qrScanner = QRScanner()
    var isTorchOn = Bool()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    let connectingView = ConnectingView()
    @IBOutlet var scanButtonOutlet: UIButton!
    @IBOutlet var manualButtonOutlet: UIButton!
    
    @IBAction func nextAction(_ sender: Any) {
        
        self.performSegue(withIdentifier: "goToNodeDetails", sender: self)
        
    }
    
    @IBAction func scanQR(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.scanNow()
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBarController?.delegate = self
        scanButtonOutlet.layer.cornerRadius = 35
        manualButtonOutlet.layer.cornerRadius = 35
        configureScanner()
        
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
    
        func nodeAdded() {
                        
            if !qc.errorBool {
                
                back()
                NotificationCenter.default.post(name: .refreshHome, object: nil, userInfo: nil)
                
                if cameFromHome {
                    
                    DispatchQueue.main.async {
                        
                        self.navigationController?.popToRootViewController(animated: true)
                        
                    }
                    
                } else {
                    
                    DispatchQueue.main.async {
                        
                        self.tabBarController?.selectedIndex = 0
                        
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: qc.errorDescription)
                
            }
            
        }
        
        if url.hasPrefix("btcrpc://") || url.hasPrefix("btcstandup://") {
            
            qc.addNode(vc: self, url: url, completion: nodeAdded)
            
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
