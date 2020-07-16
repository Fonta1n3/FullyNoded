//
//  CreateFullyNodedWalletViewController.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class CreateFullyNodedWalletViewController: UIViewController, UINavigationControllerDelegate {
    
    @IBOutlet weak var singleSigOutlet: UIButton!
    @IBOutlet weak var recoveryOutlet: UIButton!
    @IBOutlet weak var importOutlet: UIButton!
    var onDoneBlock:(((Bool)) -> Void)?
    var spinner = ConnectingView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        singleSigOutlet.layer.cornerRadius = 8
        recoveryOutlet.layer.cornerRadius = 8
        importOutlet.layer.cornerRadius = 8
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
    
    @IBAction func howHelp(_ sender: Any) {
        let message = "You have the option to either create a Fully Noded Wallet or a Recovery Wallet, to read more about recovery tap it and then tap the help button in the recovery view. Fully Noded single sig wallets are BIP84 but watch for and can sign for all address types, you may create invoices in any address format and still spend your funds. You will get a 12 word BIP39 recovery phrase to backup, these seed words are encrypted and stored using your devices secure enclave (no passphrase). Your node ONLY holds public keys. Your device will be able to sign for any derivation path and the encrypted seed is stored independently of your wallet. With Fully Noded your node will build an unsigned psbt then the device will sign it locally, acting like a hardware wallet, we then pass it back to your node as a fully signed raw transaction for broadcasting."
        showAlert(vc: self, title: "Fully Noded Wallet", message: message)
    }
    
    @IBAction func importAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToScanner", sender: vc)
        }
    }
    
    private func importAccountMap(_ accountMap: [String:Any]) {
        spinner.addConnectingView(vc: self, description: "importing...")
        if let _ = accountMap["descriptor"] as? String {
            if let _ = accountMap["blockheight"] as? Int {
                /// It is an Account Map.
                ImportWallet.accountMap(accountMap) { [unowned vc = self] (success, errorDescription) in
                    if success {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.spinner.removeConnectingView()
                            vc.onDoneBlock!(true)
                            vc.navigationController?.popViewController(animated: true)
                        }
                    } else {
                        vc.spinner.removeConnectingView()
                        showAlert(vc: vc, title: "Error", message: "There was an error importing your wallet")
                    }
                }
            }
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
    }
}
