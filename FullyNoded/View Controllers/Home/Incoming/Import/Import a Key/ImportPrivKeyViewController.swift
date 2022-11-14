//
//  ImportPrivKeyViewController.swift
//  BitSense
//
//  Created by Peter on 23/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ImportPrivKeyViewController: UIViewController, UITextFieldDelegate {
    
    var isPruned = Bool()
    let connectingView = ConnectingView()
    var isAddress = false
    var importedKey = ""
    var label = ""
    var dict = [String:Any]()
    var alertMessage = ""
    var isWatchOnly = Bool()
    @IBOutlet weak var nextButtonOutlet: UIButton!
    @IBOutlet weak var textField: UITextField!
    
   func addBlurView(frame: CGRect, button: UIButton) {
        
        button.removeFromSuperview()
        let blur = UIVisualEffectView()
        blur.effect = UIBlurEffect(style: UIBlurEffect.Style.dark)
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        view.addSubview(blur)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textField.delegate = self
        nextButtonOutlet.layer.cornerRadius = 8
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    
    @IBAction func scanQrAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToScanPrivKey", sender: self)
        }
    }
    
    @IBAction func nextAction(_ sender: Any) {
        guard let key = textField.text, key != "" else { return }
        
        parseKey(key: key)
    }
    
    @objc func dismissKeyboard(_ sender: Any) {
        textField.resignFirstResponder()
    }
    
    func parseKey(key: String) {
        
        importedKey = key
        
        func showError() {
            DispatchQueue.main.async {
                self.connectingView.removeConnectingView()
                displayAlert(viewController: self,
                             isError: true,
                             message: "Invalid key.")
            }
        }
        
        if key != "" {
            var prefix = key.lowercased()
            
            prefix = prefix.replacingOccurrences(of: "bitcoin:", with: "")
            
            switch prefix {
            case _ where prefix.hasPrefix("l"),
                 _ where prefix.hasPrefix("5"),
                 _ where prefix.hasPrefix("9"),
                 _ where prefix.hasPrefix("c"),
                 _ where prefix.hasPrefix("k"):
                
                DispatchQueue.main.async {
                    self.connectingView.addConnectingView(vc: self, description: "Importing Private Key")
                }
                
                let param = "\"\(key)\", \"\(label)\", false"
                self.importPrivKey(param: param)
                
            case _ where prefix.hasPrefix("1"),
                 _ where prefix.hasPrefix("3"),
                 _ where prefix.hasPrefix("tb1"),
                 _ where prefix.hasPrefix("bc1"),
                 _ where prefix.hasPrefix("2"),
                 _ where prefix.hasPrefix("n"),
                 _ where prefix.hasPrefix("bcr"),
                 _ where prefix.hasPrefix("m"):
                
                DispatchQueue.main.async {
                    self.connectingView.addConnectingView(vc: self, description: "Importing Address")
                }
                
                OnchainUtils.getWalletInfo { (walletInfo, message) in
                    guard let walletInfo = walletInfo else {
                        showAlert(vc: self, title: "Error", message: message ?? "Unknown error getting wallet info.")
                        return
                    }
                    
                    if walletInfo.descriptors != 0 {
                        self.importDescriptor(key: key)
                    }// else {
                        //self.importmulti(key: key)
                    //}
                }

            default:
                showError()
            }
            
        } else {
            showError()
        }
    }
    
//    private func importmulti(key: String) {
//        let param = "[{ \"scriptPubKey\": { \"address\": \"\(key)\" }, \"label\": \"\(self.label)\", \"timestamp\": \"now\", \"watchonly\": true, \"keypool\": false, \"internal\": false }], ''{\"rescan\": false}''"
//        
//        OnchainUtils.importMulti(param) { (imported, message) in
//            if imported {
//                self.triggerRescan()
//            } else {
//                self.connectingView.removeConnectingView()
//                showAlert(vc: self, title: "", message: message ?? "unknown error importmulti")
//            }
//        }
//    }
    
    private func importDescriptor(key: String) {
        let param:Get_Descriptor_Info = .init(["descriptor": "addr(\(key))"])
        OnchainUtils.getDescriptorInfo(param) { (descriptorInfo, message) in
            if let message = message, message != "" {
                self.connectingView.removeConnectingView()
                showAlert(vc: self, title: "", message: message)
            }
            
            guard let descriptorInfo = descriptorInfo else {
                self.connectingView.removeConnectingView()
                showAlert(vc: self, title: "", message: "Missing values.")
                
                return
            }
            
            let param:Import_Descriptors = .init([
                "requests":
                [
                    "desc": descriptorInfo.descriptor,
                    "active": false,
                    "timestamp": "now",
                    "internal": false,
                    "label": self.label
                ]
            ] as [String:Any])
            
            OnchainUtils.importDescriptors(param) { (imported, message) in
                self.connectingView.removeConnectingView()
                
                if imported {
                    showAlert(vc: self, title: "Imported ✓", message: message ?? "")
                } else {
                    showAlert(vc: self, title: "Import failed.", message: message ?? "")
                }
            }
        }
    }
    
    private func triggerRescan() {
        connectingView.addConnectingView(vc: self, description: "starting rescan...")
                
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Private key imported successfully ✓", message: "Tap Done to start a rescan and go back to the Active Wallet view, once the rescan completes your balances and transactions from the private key will show up.", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                OnchainUtils.rescan { (started, message) in
                    self.connectingView.removeConnectingView()
                    
                    if !started {
                        showAlert(vc: self, title: "", message: message ?? "Rescan failed...")
                    }
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.navigationController?.popToRootViewController(animated: true)
                    }
                }
            }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }
    
    private func importPrivKey(param: String) {
        Reducer.sharedInstance.makeCommand(command: .importprivkey) { (response, errorMessage) in
            self.connectingView.removeConnectingView()
            if errorMessage == nil {
                self.triggerRescan()
            } else {
                DispatchQueue.main.async {
                    guard var errorMess = errorMessage else { return }
                    
                    if errorMess.contains("private keys disabled") {
                        errorMess = "You are better of using your nodes default wallet for sweeping private keys:\n\nadvanced > bitcoin core wallets > toggle on the default wallet and try again\n\nIt is recommended to send all funds from swept private keys to a FN wallet"
                        self.navigationController?.popToRootViewController(animated: true)
                    }
                    
                    showAlert(vc: self, title: "", message: errorMess)
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToScanPrivKey" {
            if #available(macCatalyst 14.0, *) {
                guard let vc = segue.destination as? QRScannerViewController else { return }
                
                vc.isScanningAddress = true
                vc.onDoneBlock = { [weak self] key in
                    guard let self = self, let key = key else { return }
                    
                    self.parseKey(key: key)
                }
            } else {
                // Fallback on earlier versions
            }            
        }
    }
}
