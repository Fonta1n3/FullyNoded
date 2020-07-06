//
//  SignerViewController.swift
//  BitSense
//
//  Created by Peter on 03/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class SignerViewController: UIViewController {
    
    @IBOutlet weak var analyzeOutlet: UIButton!
    @IBOutlet weak var decodeOutlet: UIButton!
    var spinner = ConnectingView()
    var psbt = ""
    var broadcast = false
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var signOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        textView.text = psbt
    }
    
    override func viewDidAppear(_ animated: Bool) {
        process()
    }
    
    private func showError(error: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.spinner.removeConnectingView()
            showAlert(vc: vc, title: "Error", message: error)
        }
    }
    
    private func process() {
        spinner.addConnectingView(vc: self, description: "processing psbt with active wallet...")
        Reducer.makeCommand(command: .walletprocesspsbt, param: "\"\(psbt)\", true, \"ALL\", true") { [unowned vc = self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let processedPsbt = dict["psbt"] as? String {
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.psbt = processedPsbt
                        vc.textView.text = "\(processedPsbt)"
                        vc.spinner.removeConnectingView()
                    }
                } else {
                    vc.showError(error: "error processing psbt: \(errorMessage ?? "unknown")")
                }
            } else {
                vc.showError(error: "error processing psbt: \(errorMessage ?? "unknown")")
            }
        }
    }
    
    @IBAction func decodePsbt(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "decoding psbt...")
        Reducer.makeCommand(command: .decodepsbt, param: "\"\(psbt)\"") { [unowned vc = self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.textView.text = "\(dict)"
                    vc.spinner.removeConnectingView()
                }
            } else {
                vc.showError(error: "error decoding psbt: \(errorMessage ?? "unknown")")
            }
        }
    }
    
    @IBAction func analyzePsbt(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "analyzing psbt...")
        Reducer.makeCommand(command: .analyzepsbt, param: "\"\(psbt)\"") { [unowned vc = self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.textView.text = "\(dict)"
                    vc.spinner.removeConnectingView()
                }
            } else {
                vc.showError(error: "error analyzing psbt: \(errorMessage ?? "unknown")")
            }
        }
    }
    
    @IBAction func signNow(_ sender: Any) {
        if !broadcast {
            spinner.addConnectingView(vc: self, description: "signing psbt...")
            Signer.sign(psbt: psbt) { [unowned vc = self] (psbt, rawTx, errorMessage) in
                if psbt != nil {
                    vc.spinner.removeConnectingView()
                    vc.exportPsbt(psbt: psbt!)
                    DispatchQueue.main.async {
                        vc.textView.text = psbt!
                    }
                } else if rawTx != nil {
                    vc.spinner.removeConnectingView()
                    vc.broadcastNow(tx: rawTx!)
                    DispatchQueue.main.async {
                        vc.decodeOutlet.alpha = 0
                        vc.analyzeOutlet.alpha = 0
                        vc.textView.text = rawTx!
                        vc.signOutlet.setTitle("broadcast", for: .normal)
                        vc.broadcast = true
                    }
                } else {
                    vc.spinner.removeConnectingView()
                    vc.showError(error: "Error signing psbt: \(errorMessage ?? "unknown error")")
                }
            }
        } else {
            broadcastNow(tx: textView.text!)
        }
        
    }
    
    private func exportPsbt(psbt: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Share as raw data or text?", message: "Sharing as raw data allows you to send the unsigned psbt directly to your Coldcard Wallets SD card for signing or to Electrum 4.0", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Raw Data", style: .default, handler: { [unowned vc = self] action in
                vc.convertPSBTtoData(string: psbt)
            }))
            alert.addAction(UIAlertAction(title: "Text", style: .default, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    let textToShare = [psbt]
                    let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
                    activityViewController.popoverPresentationController?.sourceView = vc.view
                    vc.present(activityViewController, animated: true) {}
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true) {}
        }
    }
    
    private func convertPSBTtoData(string: String) {
        if let data = Data(base64Encoded: string) {
            DispatchQueue.main.async { [unowned vc = self] in
                let activityViewController = UIActivityViewController(activityItems: [data], applicationActivities: nil)
                activityViewController.popoverPresentationController?.sourceView = vc.view
                vc.present(activityViewController, animated: true) {}
            }
        }
    }
    
    private func broadcastNow(tx: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Broadcast with your node?", message: "You can optionally broadcast this transaction using Blockstream's esplora API over Tor V3 for improved privacy.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Privately", style: .default, handler: { action in
                vc.spinner.addConnectingView(vc: vc, description: "broadcasting...")
                Broadcaster.sharedInstance.send(rawTx: tx) { [unowned vc = self] (txid) in
                    if txid != nil {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.textView.text = "txid: " + txid!
                            vc.spinner.removeConnectingView()
                            showAlert(vc: vc, title: "Success! ✅", message: "Transaction sent.")
                        }
                    } else {
                        vc.showError(error: "Error broadcasting privately, try again and use your node instead.")
                    }
                }
            }))
            alert.addAction(UIAlertAction(title: "Use my node", style: .default, handler: { [unowned vc = self] action in
                vc.spinner.addConnectingView(vc: vc, description: "broadcasting...")
                Reducer.makeCommand(command: .sendrawtransaction, param: "\"\(tx)\"") { [unowned vc = self] (response, errorMesage) in
                    if let txid = response as? String {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.textView.text = "txid: " + txid
                            vc.spinner.removeConnectingView()
                            showAlert(vc: vc, title: "Success! ✅", message: "Transaction sent.")
                        }
                    } else {
                        vc.showError(error: "Error broadcasting: \(errorMesage ?? "")")
                    }
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true) {}
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
