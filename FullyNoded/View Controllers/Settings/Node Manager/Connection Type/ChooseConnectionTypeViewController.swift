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
    
    func addBtcRpcQr(url: String) {
        QuickConnect.addNode(url: url) { [unowned vc = self] (success, errorMessage) in
            if success {
                if vc.cameFromHome {
                    DispatchQueue.main.async { [unowned vc = self] in
                        NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                        vc.navigationController?.popToRootViewController(animated: true)
                    }
                } else {
                    DispatchQueue.main.async { [unowned vc = self] in
                        NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                        vc.navigationController?.popViewController(animated: true)
                    }
                }
            } else {
                displayAlert(viewController: vc, isError: true, message: "Error adding that node: \(errorMessage ?? "unknown")")
            }
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
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
