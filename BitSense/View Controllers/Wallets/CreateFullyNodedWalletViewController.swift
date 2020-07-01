//
//  CreateFullyNodedWalletViewController.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class CreateFullyNodedWalletViewController: UIViewController {
    
    @IBOutlet weak var singleSigOutlet: UIButton!
    @IBOutlet weak var recoveryOutlet: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        singleSigOutlet.layer.cornerRadius = 8
        recoveryOutlet.layer.cornerRadius = 8
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
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
