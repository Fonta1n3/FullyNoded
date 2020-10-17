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
    
    var spinner = ConnectingView()
    var psbt = ""
    var txn = ""
    var broadcast = false
    var alertStyle = UIAlertController.Style.actionSheet
    
    @IBOutlet weak private var textView: UITextView!
    @IBOutlet weak private var signOutlet: UIButton!
    @IBOutlet weak private var titleLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        signOutlet.clipsToBounds = true
        signOutlet.layer.cornerRadius = 8
        
        configureTextView()
        
        if psbt != "" {
            psbt = processedText(psbt)
            textView.text = psbt
            
        } else if txn != "" {
            txn = processedText(txn)
            segueToBroadcast()
        }
        
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if psbt != "" {
            getChain()
        }
    }
    
    private func getChain() {
        spinner.addConnectingView(vc: self, description: "checking which network the node is on...")
        
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary, let network = dict["chain"] as? String else {
                self.showError(error: "error getting network type: \(errorMessage ?? "unknown")")
                return
            }
            
            var chain:Network!
            
            if network == "main" {
                chain = .mainnet
            } else {
                chain = .testnet
            }
            
            self.getPsbt(chain: chain)
        }
    }
    
    @IBAction func scanQrAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToScanPsbtUr", sender: self)
        }
    }
    
    
    private func processedText(_ text: String) -> String {
        return (text.replacingOccurrences(of: "\n", with: "")).condenseWhitespace()
    }
    
    private func segueToBroadcast() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToBroadcaster", sender: self)
        }
    }
    
    private func configureTextView() {
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
    }
    
    @IBAction func addSignerAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
             guard let self = self else { return }
            
            self.performSegue(withIdentifier: "showSignersSegue", sender: self)
        }
    }
    
    private func processPastedString(_ string: String) {
        spinner.addConnectingView(vc: self, description: "checking which network the node is on...")
        
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary, let network = dict["chain"] as? String else {
                self.spinner.removeConnectingView()
                self.showError(error: "We did not get a valid response from your node: \(errorMessage ?? "unknown error")")
                return
            }
            
            var chain:Network!
            
            if network == "main" {
                chain = .mainnet
            } else {
                chain = .testnet
            }
            
            guard let psbtTocheck = try? PSBT(string, chain) else {
                self.spinner.removeConnectingView()
                self.showError(error: "This button is for pasting the contents of your clipboard, make sure you copied a valid psbt in base64 format.  Whatever you have copied is not a psbt!")
                return
            }
            
            self.psbt = string
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.spinner.removeConnectingView()
                
                let alert = UIAlertController(title: "You have a valid psbt on your clipboard", message: "Would you like to process it? This will *not* broadcast the transaction we simply check if it is completed yet and add any missing info to the psbt that may not be there.", preferredStyle: self.alertStyle)
                
                alert.addAction(UIAlertAction(title: "Process", style: .default, handler: { action in
                                        
                    if psbtTocheck.complete {
                        self.finalizePsbt()
                    } else {
                        self.process()
                    }
                    
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true) {}
            }
        }
    }
    
    @IBAction func pasteAction(_ sender: Any) {
        if let data = UIPasteboard.general.data(forPasteboardType: "com.apple.traditional-mac-plain-text") {
            guard let string = String(bytes: data, encoding: .utf8) else { return }
            
            processPastedString(string)
        } else if let string = UIPasteboard.general.string {
           processPastedString(string)
        }
    }
    
    @IBAction func uploadFileAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Upload a .psbt file?", message: "You may upload a .psbt file to sign or just to inspect", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Upload", style: .default, handler: { action in
                self.presentUploader()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func presentUploader() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = .formSheet
            self.present(documentPicker, animated: true, completion: nil)
        }
    }
    
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard controller.documentPickerMode == .import, let data = try? Data(contentsOf: urls[0].absoluteURL) else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "Ooops", message: "That is not a recognized format, generally it will be a .json file.")
            return
        }
        
        psbt = data.base64EncodedString()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textView.text = self.psbt
        }
    }
    
    private func updateLabel(text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.label.text = text
        }
    }
    
    private func getPsbt(chain: Network) {
        guard psbt != "", let psbtTocheck = try? PSBT(psbt, chain) else {
            showError(error: "error processing psbt")
            return
        }
        
        if psbtTocheck.complete {
            finalizePsbt()
        } else {
            process()
        }
    }
    
    private func showError(error: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "Uh oh", message: error)
        }
    }
    
    private func finalizePsbt() {
        updateLabel(text: "finalizing psbt...")
        
        Reducer.makeCommand(command: .finalizepsbt, param: "\"\(psbt)\"") { [weak self] (object, errorDescription) in
            guard let self = self else { return }
            
            guard let result = object as? NSDictionary,
                let complete = result["complete"] as? Bool,
                complete,
                let hex = result["hex"] as? String else {
                    self.showError(error: errorDescription ?? "")
                    return
            }
            
            self.txn = hex
            self.segueToBroadcast()
        }
    }
    
    private func process() {
        updateLabel(text: "processing psbt with active wallet...")
        
        Reducer.makeCommand(command: .walletprocesspsbt, param: "\"\(psbt)\", true, \"ALL\", true") { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary, let processedPsbt = dict["psbt"] as? String else {
                self.showError(error: "error processing psbt: \(errorMessage ?? "unknown")")
                return
            }
            
            DispatchQueue.main.async {
                self.psbt = processedPsbt
                self.textView.text = "\(processedPsbt)"
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "PSBT processed ✅", message: "You can tap \"sign psbt\" to proceed")
            }
        }
    }
    
    @IBAction func signNow(_ sender: Any) {
        if !broadcast {
            sign()
        } else {
            broadcastTxn()
        }
    }
    
    private func broadcastTxn() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.txn = self.processedText(self.txn)
            self.segueToBroadcast()
        }
    }
    
    private func sign() {
        spinner.addConnectingView(vc: self, description: "signing psbt...")
        
        Signer.sign(psbt: psbt) { [weak self] (psbt, rawTx, errorMessage) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            if psbt != nil {
                self.psbt = psbt!
                self.segueToBroadcast()
                
            } else if rawTx != nil {
                self.psbt = ""
                self.txn = rawTx!
                self.segueToBroadcast()
                
            } else {
                self.showError(error: "Error signing psbt: \(errorMessage ?? "unknown error")")
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
        
        if segue.identifier == "segueToScanPsbtUr" {
            guard let vc = segue.destination as? QRScannerViewController else { return }
            
            vc.isUrPsbt = true
            vc.onAddressDoneBlock = { [weak self] psbt in
                guard let self = self, let psbt = psbt else { return }
                
                self.psbt = psbt
                self.getChain()
            }
        }
    }
}
