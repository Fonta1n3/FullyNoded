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
    var isFirstTime = Bool()
    var cameFromHome = Bool()
        
    @IBOutlet var scanButtonOutlet: UIButton!
    @IBOutlet var manualButtonOutlet: UIButton!
    
    @IBAction func nextAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "goToNodeDetails", sender: vc)
        }
    }
    
    @IBAction func scanQR(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToScanQuickConnect", sender: vc)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tabBarController?.delegate = self
        scanButtonOutlet.layer.cornerRadius = 35
        manualButtonOutlet.layer.cornerRadius = 35
    }
    
    private func goToNewlyAddedLIghtningNode() {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToLightningNodeView", sender: self)
        }
    }
    
    func addBtcRpcQr(url: String) {
        QuickConnect.addNode(url: url) { [weak self] (success, errorMessage) in
            if success {
                if url.hasPrefix("clightning-rpc") {
                    self?.goToNewlyAddedLIghtningNode()
                } else {
                    if self != nil {
                        if self!.cameFromHome {
                            DispatchQueue.main.async { [weak self] in
                                NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                                self?.navigationController?.popToRootViewController(animated: true)
                            }
                        } else {
                            DispatchQueue.main.async { [weak self] in
                                NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                                self?.navigationController?.popViewController(animated: true)
                            }
                        }
                    }
                }
            } else {
                displayAlert(viewController: self, isError: true, message: "Error adding that node: \(errorMessage ?? "unknown")")
            }
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
        case "segueToLightningNodeView":
            if let vc = segue.destination as? LightningNodeManagerViewController {
                vc.newlyAdded = true
            }
        case "segueToScanQuickConnect":
            if let vc = segue.destination as? QRScannerViewController {
                vc.isQuickConnect = true
                vc.onQuickConnectDoneBlock = { [unowned thisVc = self] url in
                    if url != nil {
                        thisVc.addBtcRpcQr(url: url!)
                    }
                }
            }
            
        case "goToNodeDetails":
            
            if let vc = segue.destination as? NodeDetailViewController  {
                
                vc.selectedNode = self.selectedNode
                vc.isLightning = false
                
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
