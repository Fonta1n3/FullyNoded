//
//  SignerViewController.swift
//  BitSense
//
//  Created by Peter on 03/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit
import LibWally

class SignerViewController: UIViewController, UIDocumentPickerDelegate {
    
    @IBOutlet weak var fxRateLabel: UILabel!
    @IBOutlet weak var analyzeOutlet: UIButton!
    @IBOutlet weak var decodeOutlet: UIButton!
    var fxRate = Double()
    var outputsString = ""
    var inputsString = ""
    var inputArray = [[String:Any]]()
    var index = Int()
    var inputTotal = Double()
    var outputTotal = Double()
    var spinner = ConnectingView()
    var psbt = ""
    var txn = ""
    var txnUnsigned = ""
    var broadcast = false
    var export = false
    var alertStyle = UIAlertController.Style.actionSheet
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var signOutlet: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        if psbt != "" {
            psbt = (psbt.replacingOccurrences(of: "\n", with: "")).condenseWhitespace()
            textView.text = psbt
            if export {
                DispatchQueue.main.async { [weak self] in
                    self?.performSegue(withIdentifier: "segueToBroadcaster", sender: self)
                }
            } else {
                spinner.addConnectingView(vc: self, description: "checking which network the node is on...")
            }
        } else if txn != "" {
            txn = (txn.replacingOccurrences(of: "\n", with: "")).condenseWhitespace()
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "segueToBroadcaster", sender: self)
            }
        } else if txnUnsigned != "" {
            txnUnsigned = (txnUnsigned.replacingOccurrences(of: "\n", with: "")).condenseWhitespace()
            analyzeOutlet.setTitle("verify", for: .normal)
            analyzeOutlet.alpha = 1
            textView.text = txnUnsigned
            titleLabel.text = "Export Unsigned Tx"
            signOutlet.setTitle("export", for: .normal)
            decodeOutlet.alpha = 1
        }
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !export && txnUnsigned == "" {
            Reducer.makeCommand(command: .getblockchaininfo, param: "") { [weak self] (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    if let network = dict["chain"] as? String {
                        var chain:Network!
                        if network == "main" {
                            chain = .mainnet
                        } else {
                            chain = .testnet
                        }
                        self?.getPsbt(chain: chain)
                    } else {
                        self?.showError(error: "error getting network type: \(errorMessage ?? "unknown")")
                    }
                }
            }
        }
    }
    
    @IBAction func addSignerAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "showSignersSegue", sender: self)
        }
    }
    
    
    
    @IBAction func pasteAction(_ sender: Any) {
        let contents = UIPasteboard.general.string ?? ""
        if contents != "" {
            Reducer.makeCommand(command: .getblockchaininfo, param: "") { [weak self] (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    if let network = dict["chain"] as? String {
                        var chain:Network!
                        if network == "main" {
                            chain = .mainnet
                        } else {
                            chain = .testnet
                        }
                        do {
                            let psbtTocheck = try PSBT(contents, chain)
                            DispatchQueue.main.async { [weak self] in
                                var alertStyle = UIAlertController.Style.actionSheet
                                if (UIDevice.current.userInterfaceIdiom == .pad) {
                                  alertStyle = UIAlertController.Style.alert
                                }
                                let alert = UIAlertController(title: "You have a valid psbt on your clipboard", message: "Would you like to process it? This will *not* broadcast the transaction we simply check if it is completed yet and add any missing info to the psbt that may not be there.", preferredStyle: alertStyle)
                                alert.addAction(UIAlertAction(title: "Process", style: .default, handler: { [weak self] action in
                                    if psbtTocheck.complete {
                                        self?.finalizePsbt()
                                    } else {
                                        self?.process()
                                    }
                                }))
                                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                                alert.popoverPresentationController?.sourceView = self?.view
                                self?.present(alert, animated: true) {}
                            }
                        } catch {
                            self?.showError(error: "This button is for pasting the contents of your clipboard, make sure you copied a valid psbt in base64 format.  Whatever you have copied is not a psbt!")
                        }
                    } else {
                        self?.showError(error: "error getting network type: \(errorMessage ?? "unknown")")
                    }
                }
            }
        } else {
            showError(error: "Ooops, no text on your clipboard.")
        }
    }
    
    @IBAction func uploadFileAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            if self != nil {
                let alert = UIAlertController(title: "Upload a .psbt file?", message: "You may upload a .psbt file to sign or just to inspect", preferredStyle: self!.alertStyle)
                
                alert.addAction(UIAlertAction(title: "Upload", style: .default, handler: { [weak self] action in
                    let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)//public.item in iOS and .import
                    documentPicker.delegate = self
                    documentPicker.modalPresentationStyle = .formSheet
                    self?.present(documentPicker, animated: true, completion: nil)
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self?.view
                self?.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if controller.documentPickerMode == .import {
            do {
                let data = try Data(contentsOf: urls[0].absoluteURL)
                psbt = data.base64EncodedString()
                DispatchQueue.main.async { [weak self] in
                    self?.textView.text = self?.psbt
                }
            } catch {
                spinner.removeConnectingView()
                showAlert(vc: self, title: "Ooops", message: "That is not a recognized format, generally it will be a .json file.")
            }
        }
    }
    
    private func updateLabel(text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.spinner.label.text = text
        }
    }
    
    private func getPsbt(chain: Network) {
        if psbt != "" {
            do {
                let psbtTocheck = try PSBT(psbt, chain)
                if psbtTocheck.complete {
                    finalizePsbt()
                } else {
                    process()
                }
            } catch {
                showError(error: "error processing psbt")
            }
        } else {
            spinner.removeConnectingView()
        }
    }
    
    private func showError(error: String) {
        DispatchQueue.main.async { [weak self] in
            self?.spinner.removeConnectingView()
            showAlert(vc: self, title: "Uh oh", message: error)
        }
    }
    
    private func finalizePsbt() {
        updateLabel(text: "finalizing psbt...")
        Reducer.makeCommand(command: .finalizepsbt, param: "\"\(psbt)\"") { [weak self] (object, errorDescription) in
            if let result = object as? NSDictionary {
                if let complete = result["complete"] as? Bool {
                    if complete {
                        let hex = result["hex"] as! String
                        self?.txn = hex
                    }
                } else {
                    self?.showError(error: errorDescription ?? "")
                }
            } else {
                self?.showError(error: errorDescription ?? "")
            }
        }
    }
    
    private func process() {
        updateLabel(text: "processing psbt with active wallet...")
        Reducer.makeCommand(command: .walletprocesspsbt, param: "\"\(psbt)\", true, \"ALL\", true") { [weak self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let processedPsbt = dict["psbt"] as? String {
                    DispatchQueue.main.async { [weak self] in
                        self?.psbt = processedPsbt
                        self?.textView.text = "\(processedPsbt)"
                        self?.spinner.removeConnectingView()
                    }
                } else {
                    self?.showError(error: "error processing psbt: \(errorMessage ?? "unknown")")
                }
            } else {
                self?.showError(error: "error processing psbt: \(errorMessage ?? "unknown")")
            }
        }
    }
    
    @IBAction func signNow(_ sender: Any) {
        if !broadcast {
            spinner.addConnectingView(vc: self, description: "signing psbt...")
            Signer.sign(psbt: psbt) { [weak self] (psbt, rawTx, errorMessage) in
                if psbt != nil {
                    self?.spinner.removeConnectingView()
                    DispatchQueue.main.async { [weak self] in
                        self?.psbt = psbt!
                        self?.performSegue(withIdentifier: "segueToBroadcaster", sender: self)
                    }
                } else if rawTx != nil {
                    self?.spinner.removeConnectingView()
                    DispatchQueue.main.async { [weak self] in
                        self?.psbt = ""
                        self?.txn = rawTx!
                        self?.performSegue(withIdentifier: "segueToBroadcaster", sender: self)
                    }
                } else {
                    self?.spinner.removeConnectingView()
                    self?.showError(error: "Error signing psbt: \(errorMessage ?? "unknown error")")
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                if self != nil {
                    self!.txn = self!.txn.replacingOccurrences(of: "\n", with: "").condenseWhitespace()
                    self?.performSegue(withIdentifier: "segueToBroadcaster", sender: self)
                }
            }
        }
        
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToBroadcaster" {
            if let vc = segue.destination as? VerifyTransactionViewController {
                vc.signedRawTx = txn
                vc.unsignedPsbt = psbt
            }
        }
    }
}
