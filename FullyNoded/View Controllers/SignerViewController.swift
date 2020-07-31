//
//  SignerViewController.swift
//  BitSense
//
//  Created by Peter on 03/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit
import LibWally

class SignerViewController: UIViewController {
    
    @IBOutlet weak var analyzeOutlet: UIButton!
    @IBOutlet weak var decodeOutlet: UIButton!
    var spinner = ConnectingView()
    var psbt = ""
    var txn = ""
    var broadcast = false
    var export = false
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var signOutlet: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        if psbt != "" {
            textView.text = psbt
            if export {
                titleLabel.text = "Export PSBT"
                signOutlet.setTitle("export", for: .normal)
                analyzeOutlet.alpha = 1
                decodeOutlet.alpha = 1
            } else {
                spinner.addConnectingView(vc: self, description: "checking which network the node is on...")
            }
        } else if txn != "" {
            titleLabel.text = "Broadcaster"
            broadcast = true
            textView.text = (txn.replacingOccurrences(of: "\n", with: "")).condenseWhitespace()
            signOutlet.setTitle("broadcast", for: .normal)
            analyzeOutlet.alpha = 0
            decodeOutlet.alpha = 1
            spinner.addConnectingView(vc: self, description: "checking which network the node is on...")
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !export {
            Reducer.makeCommand(command: .getblockchaininfo, param: "") { [unowned vc = self] (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    if let network = dict["chain"] as? String {
                        var chain:Network!
                        if network == "main" {
                            chain = .mainnet
                        } else {
                            chain = .testnet
                        }
                        vc.getPsbt(chain: chain)
                    } else {
                        vc.showError(error: "error getting network type: \(errorMessage ?? "unknown")")
                    }
                }
            }
        }
    }
    
    private func updateLabel(text: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.spinner.label.text = text
        }
    }
    
    private func getPsbt(chain: Network) {
        if psbt != "" {
            process()
        } else {
            spinner.removeConnectingView()
        }
    }
    
    private func showError(error: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.spinner.removeConnectingView()
            showAlert(vc: vc, title: "Error", message: error)
        }
    }
    
    private func process() {
        updateLabel(text: "processing psbt with active wallet...")
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
        if txn != "" {
            spinner.addConnectingView(vc: self, description: "decoding raw...")
            Reducer.makeCommand(command: .decoderawtransaction, param: "\"\(txn)\"") { [unowned vc = self] (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.textView.text = "\(dict)"
                        vc.spinner.removeConnectingView()
                    }
                } else {
                    vc.showError(error: "error decoding raw: \(errorMessage ?? "unknown")")
                }
            }
        } else if psbt != "" {
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
        if export {
            exportPsbt(psbt: psbt)
        } else if !broadcast {
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
            broadcastNow(tx: (txn.replacingOccurrences(of: "\n", with: "")).condenseWhitespace())
        }
        
    }
    
    private func exportPsbt(psbt: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Share as a .psbt file, text or QR?", message: "Sharing as a .psbt file allows you to send the unsigned psbt directly to your Coldcard or to Electrum 4.0 for signing", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: ".psbt file", style: .default, handler: { [unowned vc = self] action in
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
            alert.addAction(UIAlertAction(title: "QR", style: .default, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.performSegue(withIdentifier: "segueToExportPsbtAsQr", sender: vc)
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true) {}
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
    
    private func broadcastNow(tx: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Broadcast with your node?", message: "You can optionally broadcast this transaction using Blockstream's esplora API over Tor V3 for improved privacy.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Privately", style: .default, handler: { action in
                vc.spinner.addConnectingView(vc: vc, description: "broadcasting...")
                Broadcaster.sharedInstance.send(rawTx: tx) { [unowned vc = self] (txid) in
                    if txid != nil {
                        DispatchQueue.main.async { [unowned vc = self] in
                            NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                            vc.textView.text = "txid: " + txid!
                            vc.decodeOutlet.alpha = 0
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
                            NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                            vc.textView.text = "txid: " + txid
                            vc.spinner.removeConnectingView()
                            vc.decodeOutlet.alpha = 0
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
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToExportPsbtAsQr" {
            if let vc = segue.destination as? QRDisplayerViewController {
                if psbt != "" {
                    vc.text = psbt
                } else if txn != "" {
                    vc.text = txn
                }
            }
        }
    }
}
