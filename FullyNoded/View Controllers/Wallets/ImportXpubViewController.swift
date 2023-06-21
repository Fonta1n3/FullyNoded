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
    @IBOutlet weak var labelField: UITextField!
    @IBOutlet weak var descriptorField: UILabel!
    
    var spinner = ConnectingView()
    var onDoneBlock:(((Bool)) -> Void)?
    var descriptor = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        
        importOutlet.clipsToBounds = true
        importOutlet.layer.cornerRadius = 8
        labelField.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        labelField.removeGestureRecognizer(tapGesture)
        
        addDescriptorToLabel(descriptor)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        labelField.resignFirstResponder()
    }
    
    @IBAction func importAction(_ sender: Any) {
        importDescriptor()
    }
    
    @IBAction func scanQrAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToScanDescriptor", sender: self)
        }
    }
        
    private func importDescriptor() {
        guard descriptor != "" else {
            showAlert(vc: self, title: "", message: "Scan a descriptor first.")
            return
        }
        
        spinner.addConnectingView(vc: self, description: "importing descriptor wallet, this can take a minute...")
        
        let defaultLabel = "Descriptor import"
        
        var label = labelField.text ?? defaultLabel
        
        if label == "" {
            label = defaultLabel
        }
        
        let accountMap = ["descriptor": descriptor, "blockheight": 0, "watching": [] as [String], "label": label] as [String : Any]
        
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
    
    private func addDescriptorToLabel(_ descriptor: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            descriptorField.text = descriptor
            descriptorField.translatesAutoresizingMaskIntoConstraints = true
            descriptorField.sizeToFit()
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
        if segue.identifier == "segueToScanDescriptor" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isScanningAddress = true
                vc.onDoneBlock = { [weak self] descriptor in
                    guard let self = self else { return }
                    
                    guard let desc = descriptor else { return }
                    
                    addDescriptorToLabel(desc)
                }
            }
        }
    }
}
