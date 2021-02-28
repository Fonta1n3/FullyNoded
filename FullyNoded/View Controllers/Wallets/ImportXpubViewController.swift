//
//  ImportXpubViewController.swift
//  FullyNoded
//
//  Created by Peter on 9/19/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class ImportXpubViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var importOutlet: UIButton!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var labelField: UITextField!
    @IBOutlet weak var headerLabel: UILabel!
    
    var xpub = ""
    var fingerprint = ""
    var coinType = "0"
    var spinner = ConnectingView()
    var onDoneBlock:(((Bool)) -> Void)?
    var isDescriptor = false
    
    var bip44primAccount: String {
        return "pkh([\(fingerprint)/44h/\(coinType)h/0h]\(xpub)/0/*)"
    }
    
    var bip44changeAccount: String {
        return "pkh([\(fingerprint)/44h/\(coinType)h/0h]\(xpub)/1/*)"
    }
    
    var bip49primAccount: String {
        return "sh(wpkh([\(fingerprint)/49h/\(coinType)h/0h]\(xpub)/0/*))"
    }
    
    var bip49changeAccount: String {
        return "sh(wpkh([\(fingerprint)/49h/\(coinType)h/0h]\(xpub)/1/*))"
    }
    
    var bip84primAccount: String {
        return "wpkh([\(fingerprint)/84h/\(coinType)h/0h]\(xpub)/0/*)"
    }
    
    var bip84changeAccount: String {
        return "wpkh([\(fingerprint)/84h/\(coinType)h/0h]\(xpub)/1/*)"
    }
    
    var bip44primbip32: String {
        return "pkh([\(fingerprint)/44h/\(coinType)h/0h/0]\(xpub)/*)"
    }
    
    var bip44changebip32: String {
        return "pkh([\(fingerprint)/44h/\(coinType)h/0h/1]\(xpub)/*)"
    }
    
    var bip49primbip32: String {
        return "sh(wpkh([\(fingerprint)/49h/\(coinType)h/0h/0]\(xpub)/*))"
    }
    
    var bip49changebip32: String {
        return "sh(wpkh([\(fingerprint)/49h/\(coinType)h/0h/1]\(xpub)/*))"
    }
    
    var bip84primbip32: String {
        return "wpkh([\(fingerprint)/84h/\(coinType)h/0h/0]\(xpub)/*)"
    }
    
    var bip84changebip32: String {
        return "wpkh([\(fingerprint)/84h/\(coinType)h/0h/1]\(xpub)/*)"
    }
    
    var plainPrim: String {
        return "pkh([\(fingerprint)/0h]\(xpub)/0/*)"
    }
    
    var plainChange: String {
        return "pkh([\(fingerprint)/0h]\(xpub)/1/*)"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        importOutlet.clipsToBounds = true
        importOutlet.layer.cornerRadius = 8
        textField.delegate = self
        labelField.delegate = self
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        textField.removeGestureRecognizer(tapGesture)
        labelField.removeGestureRecognizer(tapGesture)
        
        if isDescriptor {
            textField.placeholder = "descriptor"
            headerLabel.text = "Descriptor import"
            showAlert(vc: self, title: "", message: "Fully Noded currently supports extended key (xpub/xprv) based descriptors to create wallets. Creating wallets with other descriptor types will not work.")
        } else {
            setCoinType()
        }        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        textField.resignFirstResponder()
        labelField.resignFirstResponder()
    }
    
    private func showError(_ error: String) {
        showAlert(vc: self, title: "Something went wrong", message: error)
    }
    
    private func setCoinType() {
        spinner.addConnectingView(vc: self, description: "fetching chain type...")
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { [weak self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let chain = dict["chain"] as? String {
                    if chain == "test" {
                        self?.coinType = "1"
                    }
                    self?.spinner.removeConnectingView()
                }
            } else {
                self?.showError("Error getting blockchain info, please chack your connection to your node.")
                DispatchQueue.main.async {
                    self?.navigationController?.popToRootViewController(animated: true)
                }
            }
        }
    }
    
    @IBAction func importAction(_ sender: Any) {
        if !isDescriptor {
            importXpubNow()
        } else {
            importDescriptor()
        }
    }
    
    @IBAction func scanQrAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToScanXpub", sender: self)
        }
    }
    
    private func importXpubNow() {
        xpub = textField.text ?? ""
        
        if !xpub.hasPrefix("xpub") && !xpub.hasPrefix("tpub") {
            xpub = XpubConverter.convert(extendedKey: xpub) ?? ""
        }
        
        guard xpub != "" else {
            showError("Paste in an extended public key")
            return
        }
        
        fingerprint = Keys.fingerprint(masterKey: xpub) ?? "00000000"
        spinner.addConnectingView(vc: self, description: "importing xpub, this can take a minute...")
        importXpub()
    }
    
    var watchingArray: [String] {
        return [bip44primAccount,
                bip44changeAccount,
                bip49primAccount,
                bip49changeAccount,
                bip44primbip32,
                bip44changebip32,
                bip49primbip32,
                bip49changebip32,
                bip84primbip32,
                bip84changebip32,
                plainPrim,
                plainChange]
    }
    
    private func importXpub() {
        let defaultLabel = "xpub import"
        
        var label = labelField.text ?? defaultLabel
        
        if label == "" {
            label = defaultLabel
        }
        
        let accountMap = ["descriptor": bip84primAccount, "blockheight": 0, "watching": watchingArray, "label": label] as [String : Any]
        
        ImportWallet.accountMap(accountMap) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            if success {
                self.doneAlert("xpub wallet created ✓", "Tap done to go back and the home screen will refresh, your wallet is rescanning the blockchain, this can take awhile, to monitor rescan progress tap the refresh button on the \"Active Wallet\" tab. You will not see your balances or transaction history until the rescan completes.")
            } else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "", message: errorDescription ?? "unknown error")
            }
        }
    }
    
    private func importDescriptor() {
        guard let descriptor = textField.text else {
            showAlert(vc: self, title: "", message: "Paste or scan a descriptor first.")
            return
        }
        
        guard !descriptor.contains("xprv"), !descriptor.contains("tprv") else {
            showAlert(vc: self, title: "", message: "Fully Noded wallets do not allow you to import private keys onto your node. To do that you can create a Bitcoin Core Hot wallet and then import the xprv descriptor via the advanced button on the active wallet tab.")
            return
        }
        
        spinner.addConnectingView(vc: self, description: "importing descriptor wallet, this can take a minute...")
        
        let defaultLabel = "Descriptor import"
        
        var label = labelField.text ?? defaultLabel
        
        if label == "" {
            label = defaultLabel
        }
        
        let accountMap = ["descriptor": descriptor, "blockheight": 0, "watching": [], "label": label] as [String : Any]
        
        ImportWallet.accountMap(accountMap) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            if success {
                self.doneAlert("Descriptor wallet created ✓", "Tap done to go back and the home screen will refresh, your wallet is rescanning the blockchain, this can take awhile, to monitor rescan progress tap the refresh button on the \"Active Wallet\" tab. You will not see your balances or transaction history until the rescan completes.")
            } else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "", message: errorDescription ?? "unknown error")
            }
        }
    }
    
    private func addXpubToTextField(_ xpub: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textField.text = xpub
        }
    }
    
    private func doneAlert(_ title: String, _ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
            
            self.spinner.removeConnectingView()
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                DispatchQueue.main.async {
                    self.navigationController?.popToRootViewController(animated: true)
                }
            }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToScanXpub" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isScanningAddress = true
                vc.onAddressDoneBlock = { [unowned thisVc = self] xpub in
                    if xpub != nil {
                        thisVc.addXpubToTextField(xpub!)
                    }
                }
            }
        }
    }
}
