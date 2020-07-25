//
//  TransactionViewController.swift
//  BitSense
//
//  Created by Peter on 22/07/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class TransactionViewController: UIViewController {
    
    var txid = ""
    let creatingView = ConnectingView()
    
    @IBOutlet var textView: UITextView!
    
    @IBOutlet var bumpButtonOutlet: UIButton!
    @IBAction func back(_ sender: Any) {
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func bumpFee(_ sender: Any) {
        creatingView.addConnectingView(vc: self, description: "bumping")
        executeNodeCommand(method: .bumpfee, param: "\"\(txid)\"")
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bumpButtonOutlet.alpha = 0
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        creatingView.addConnectingView(vc: self, description: "getting transaction")
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        executeNodeCommand(method: .gettransaction, param: "\"\(txid)\", true")
        
    }
    
    func bumpFee(result: NSDictionary) {
        let originalFee = result["origfee"] as! Double
        let newFee = result["fee"] as! Double
        if let psbt = result["psbt"] as? String {
            Signer.sign(psbt: psbt) { [unowned vc = self] (psbt, rawTx, errorMessage) in
                if psbt != nil {
                    vc.creatingView.removeConnectingView()
                    vc.exportPsbt(psbt: psbt!)
                    
                } else if rawTx != nil {
                    vc.creatingView.removeConnectingView()
                    vc.broadcastNow(tx: rawTx!)
                    
                } else if errorMessage != nil {
                    vc.creatingView.removeConnectingView()
                    showAlert(vc: vc, title: "Error", message: errorMessage!)
                }
            }
        } else {
            displayAlert(viewController: self, isError: false, message: "fee bumped from \(originalFee.avoidNotation) to \(newFee.avoidNotation)")
        }
    }
    

    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                case .bumpfee:
                    if let result = response as? NSDictionary {
                        vc.bumpFee(result: result)
                    }
                case .gettransaction:
                    if let dict = response as? NSDictionary {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.textView.text = "\(dict)"
                            vc.creatingView.removeConnectingView()
                            let replaceable = dict["bip125-replaceable"] as? String ?? ""
                            if replaceable == "yes" {
                                vc.bumpButtonOutlet.alpha = 1
                            }
                        }
                    }
                default:
                    break
                }
            } else {
                vc.creatingView.removeConnectingView()
                displayAlert(viewController: vc, isError: true, message: errorMessage!)
            }
        }
    }
    
    private func broadcastNow(tx: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Broadcast with your node?", message: "You can optionally broadcast this transaction using Blockstream's esplora API over Tor V3 for improved privacy.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Privately", style: .default, handler: { action in
                vc.creatingView.addConnectingView(vc: vc, description: "broadcasting...")
                Broadcaster.sharedInstance.send(rawTx: tx) { [unowned vc = self] (txid) in
                    if txid != nil {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.creatingView.removeConnectingView()
                            displayAlert(viewController: vc, isError: false, message: "Fee bumped ✓")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                            }
                        }
                    } else {
                        vc.creatingView.removeConnectingView()
                        displayAlert(viewController: vc, isError: true, message: "error broadcasting")
                    }
                }
            }))
            alert.addAction(UIAlertAction(title: "Use my node", style: .default, handler: { [unowned vc = self] action in
                vc.creatingView.addConnectingView(vc: vc, description: "broadcasting...")
                Reducer.makeCommand(command: .sendrawtransaction, param: "\"\(tx)\"") { (response, errorMesage) in
                    if let _ = response as? String {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.creatingView.removeConnectingView()
                            displayAlert(viewController: vc, isError: false, message: "Fee bumped ✓")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                            }
                        }
                    } else {
                        displayAlert(viewController: vc, isError: true, message: "Error: \(errorMesage ?? "")")
                    }
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true) {}
        }
    }
    
    private func exportPsbt(psbt: String) {
        DispatchQueue.main.async {
            
            let alert = UIAlertController(title: "Share as raw data or text?", message: "Sharing as raw data allows you to send the unsigned psbt directly to your Coldcard Wallets SD card for signing or to Electrum 4.0", preferredStyle: .actionSheet)
            
            alert.addAction(UIAlertAction(title: "Raw Data", style: .default, handler: { action in
                
                self.convertPSBTtoData(string: psbt)
                
            }))
            
            alert.addAction(UIAlertAction(title: "Text", style: .default, handler: { action in
                
                DispatchQueue.main.async {
                    
                    let textToShare = [psbt]
                    
                    let activityViewController = UIActivityViewController(activityItems: textToShare,
                                                                          applicationActivities: nil)
                    
                    activityViewController.popoverPresentationController?.sourceView = self.view
                    self.present(activityViewController, animated: true) {}
                    
                }
                
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                
            }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
            
        }
    }
    
    func convertPSBTtoData(string: String) {
     
        if let data = Data(base64Encoded: string) {
         
            DispatchQueue.main.async {
                
                let activityViewController = UIActivityViewController(activityItems: [data],
                                                                      applicationActivities: nil)
                
                activityViewController.popoverPresentationController?.sourceView = self.view
                self.present(activityViewController, animated: true) {}
                
            }
            
        }
        
    }
}
