//
//  TransactionViewController.swift
//  BitSense
//
//  Created by Peter on 22/07/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class TransactionViewController: UIViewController {
    
    var isBolt11 = Bool()
    var txid = ""
    let spinner = ConnectingView()
    @IBOutlet var textView: UITextView!
    @IBOutlet var bumpButtonOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bumpButtonOutlet.alpha = 0
        bumpButtonOutlet.clipsToBounds = true
        bumpButtonOutlet.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        spinner.addConnectingView(vc: self, description: "getting transaction")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if isBolt11 {
            decodeBolt11(bolt11: txid)
        } else {
            executeNodeCommand(method: .gettransaction, param: "\"\(txid)\", true")
        }
    }
    
    @IBAction func bumpFee(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "bumping")
        executeNodeCommand(method: .bumpfee, param: "\"\(txid)\"")
    }
        
    func bumpFee(result: NSDictionary) {
        let originalFee = result["origfee"] as! Double
        let newFee = result["fee"] as! Double
        if let psbt = result["psbt"] as? String {
            Signer.sign(psbt: psbt) { [unowned vc = self] (psbt, rawTx, errorMessage) in
                if psbt != nil {
                    vc.spinner.removeConnectingView()
                    vc.exportPsbt(psbt: psbt!)
                    
                } else if rawTx != nil {
                    vc.spinner.removeConnectingView()
                    vc.broadcastNow(tx: rawTx!)
                    
                } else if errorMessage != nil {
                    vc.spinner.removeConnectingView()
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
                            vc.spinner.removeConnectingView()
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
                vc.spinner.removeConnectingView()
                displayAlert(viewController: vc, isError: true, message: errorMessage!)
            }
        }
    }
    
    private func broadcastNow(tx: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Broadcast with your node?", message: "You can optionally broadcast this transaction using Blockstream's esplora API over Tor V3 for improved privacy.", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Privately", style: .default, handler: { action in
                vc.spinner.addConnectingView(vc: vc, description: "broadcasting...")
                Broadcaster.sharedInstance.send(rawTx: tx) { [unowned vc = self] (txid) in
                    if txid != nil {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.spinner.removeConnectingView()
                            displayAlert(viewController: vc, isError: false, message: "Fee bumped ✓")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                            }
                        }
                    } else {
                        vc.spinner.removeConnectingView()
                        displayAlert(viewController: vc, isError: true, message: "error broadcasting")
                    }
                }
            }))
            alert.addAction(UIAlertAction(title: "Use my node", style: .default, handler: { [unowned vc = self] action in
                vc.spinner.addConnectingView(vc: vc, description: "broadcasting...")
                Reducer.makeCommand(command: .sendrawtransaction, param: "\"\(tx)\"") { (response, errorMesage) in
                    if let _ = response as? String {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.spinner.removeConnectingView()
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
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Share as raw data or text?", message: "Sharing as raw data allows you to send the unsigned psbt directly to your Coldcard Wallets SD card for signing or to Electrum 4.0", preferredStyle: alertStyle)
            
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
    
    private func convertPSBTtoData(string: String) {
        if let data = Data(base64Encoded: string) {
            if let url = exportPsbtToURL(data: data) {
                DispatchQueue.main.async { [unowned vc = self] in
                    let activityViewController = UIActivityViewController(activityItems: ["Fully Noded PSBT", url], applicationActivities: nil)
                    activityViewController.popoverPresentationController?.sourceView = vc.view
                    vc.present(activityViewController, animated: true) {}
                }
            }
        }
    }
    
    private func decodeBolt11(bolt11: String) {
        LightningRPC.command(id: UUID(), method: .decodepay, param: "\"\(bolt11)\"") { [unowned vc = self] (uuid, response, errorDesc) in
            if let dict = response as? NSDictionary {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.bumpButtonOutlet.alpha = 0
                    vc.textView.text = "\(dict)"
                    vc.spinner.removeConnectingView()
                }
            } else {
                vc.spinner.removeConnectingView()
            }
        }
    }
}
