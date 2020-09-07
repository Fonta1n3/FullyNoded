//
//  CreateFullyNodedWalletViewController.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class CreateFullyNodedWalletViewController: UIViewController, UINavigationControllerDelegate, UIDocumentPickerDelegate {
    
    @IBOutlet weak var uploadOutlet: UIButton!
    @IBOutlet weak var multiSigOutlet: UIButton!
    @IBOutlet weak var singleSigOutlet: UIButton!
    @IBOutlet weak var recoveryOutlet: UIButton!
    @IBOutlet weak var importOutlet: UIButton!
    var onDoneBlock:(((Bool)) -> Void)?
    var spinner = ConnectingView()
    var alertStyle = UIAlertController.Style.actionSheet
    var ccXfp = ""
    var xpub = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        singleSigOutlet.layer.cornerRadius = 8
        recoveryOutlet.layer.cornerRadius = 8
        importOutlet.layer.cornerRadius = 8
        multiSigOutlet.layer.cornerRadius = 8
        uploadOutlet.layer.cornerRadius = 8
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
        checkPasteboard()
    }
    
    @IBAction func uploadFileAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Upload a file?", message: "Here you can upload files from your Hardware Wallets to easily create Fully Noded Wallet's", preferredStyle: vc.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Upload", style: .default, handler: { [unowned vc = self] action in
                let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)//public.item in iOS and .import
                documentPicker.delegate = vc
                documentPicker.modalPresentationStyle = .formSheet
                vc.present(documentPicker, animated: true, completion: nil)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    
    @IBAction func automaticAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToSeedWords", sender: vc)
        }
    }
    
    @IBAction func manualAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "seguToManualCreation", sender: vc)
        }
    }
    
    @IBAction func createMultiSigAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToCreateMultiSig", sender: vc)
        }
    }
    
    @IBAction func howHelp(_ sender: Any) {
        let message = "You have the option to either create a Fully Noded Wallet or a Recovery Wallet, to read more about recovery tap it and then tap the help button in the recovery view. Fully Noded single sig wallets are BIP84 but watch for and can sign for all address types, you may create invoices in any address format and still spend your funds. You will get a 12 word BIP39 recovery phrase to backup, these seed words are encrypted and stored using your devices secure enclave (no passphrase). Your node ONLY holds public keys. Your device will be able to sign for any derivation path and the encrypted seed is stored independently of your wallet. With Fully Noded your node will build an unsigned psbt then the device will sign it locally, acting like a hardware wallet, we then pass it back to your node as a fully signed raw transaction for broadcasting."
        showAlert(vc: self, title: "Fully Noded Wallet", message: message)
    }
    
    @IBAction func importAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToScanner", sender: vc)
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if controller.documentPickerMode == .import {
            do {
                let data = try Data(contentsOf: urls[0].absoluteURL)
                let dict = try JSONSerialization.jsonObject(with: data, options: []) as! [String:Any]
                if let _ = dict["chain"] as? String {
                    /// We know its a coldcard skeleton import
                    promptToImportColdcardSingleSig(dict)
                } else if let _ = dict["p2wsh_deriv"] as? String, let xfp = dict["xfp"] as? String, let p2wsh = dict["p2wsh"] as? String {
                    /// It is most likely a multi-sig wallet export
                    promptToImportColdcardMsig(xfp, p2wsh)
                } else if let _ = dict["descriptor"] as? String {
                    promptToImportAccountMap(dict: dict)
                } else {
                    
                }
            } catch {
                spinner.removeConnectingView()
                showAlert(vc: self, title: "Ooops", message: "That is not a recognized format, generally it will be a .json file.")
            }
        }
    }
    
    private func promptToImportColdcardMsig(_ xfp: String, _ xpub: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Create a multisig with your Coldcard?", message: "You have uploaded a Coldcard multisig file, this action allows you to easily create a wallet with your Coldcard and Fully Noded.", preferredStyle: vc.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.ccXfp = xfp
                    vc.xpub = xpub
                    vc.performSegue(withIdentifier: "segueToCreateMultiSig", sender: vc)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToImportColdcardSingleSig(_ coldcard: [String:Any]) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Create a single sig with your Coldcard?", message: "You have uploaded a Coldcard single sig file, this action will recreate your Coldcard wallet on Fully Noded using its xpubs.", preferredStyle: vc.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { action in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .addColdCard, object: nil, userInfo: coldcard)
                    vc.navigationController?.popViewController(animated: true)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func checkPasteboard() {
        let pastboard = UIPasteboard.general
        if let text = pastboard.string {
            if let data = text.data(using: .utf8) {
                do {
                    let accountMap = try JSONSerialization.jsonObject(with: data, options: []) as! [String:Any]
                    promptToImportAccountMap(dict: accountMap)
                } catch {
                    
                }
            }
        }
    }
    
    private func importAccountMap(_ accountMap: [String:Any]) {
        spinner.addConnectingView(vc: self, description: "importing...")
        if let _ = accountMap["descriptor"] as? String {
            if let _ = accountMap["blockheight"] as? Int {
                /// It is an Account Map.
                ImportWallet.accountMap(accountMap) { (success, errorDescription) in
                    if success {
                        DispatchQueue.main.async {
                            self.spinner.removeConnectingView()
                            self.onDoneBlock!(true)
                            self.navigationController?.popViewController(animated: true)
                        }
                    } else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "Error", message: "There was an error importing your wallet: \(errorDescription ?? "unknown")")
                    }
                }
            }
        }
    }
    
    private func promptToImportAccountMap(dict: [String:Any]) {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Import wallet?", message: "Looks like you have selected a valid wallet format ✅", preferredStyle: vc.alertStyle)
            alert.addAction(UIAlertAction(title: "Import", style: .default, handler: { [unowned vc = self] action in
                vc.importAccountMap(dict)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToScanner" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isAccountMap = true
                vc.onImportDoneBlock = { [unowned thisVc = self] accountMap in
                    if accountMap != nil {
                        thisVc.importAccountMap(accountMap!)
                    }
                }
            }
        }
        if segue.identifier == "segueToCreateMultiSig" {
            if let vc = segue.destination as? CreateMultisigViewController {
                vc.ccXfp = ccXfp
                vc.ccXpub = xpub
            }
        }
    }
}
