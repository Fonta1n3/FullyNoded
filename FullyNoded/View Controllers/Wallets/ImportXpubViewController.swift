//
//  ImportXpubViewController.swift
//  FullyNoded
//
//  Created by Peter on 9/19/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class ImportXpubViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var importOutlet: UIButton!
    @IBOutlet weak var labelField: UITextField!
    @IBOutlet weak var descriptorField: UILabel!
    @IBOutlet var addressTableView: UITableView!
    
    var addresses: [String] = []
    var spinner = ConnectingView()
    var onDoneBlock:(((Bool)) -> Void)?
    var descriptor: Descriptor?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        addressTableView.delegate = self
        addressTableView.dataSource = self
        importOutlet.clipsToBounds = true
        importOutlet.layer.cornerRadius = 8
        labelField.delegate = self
        labelField.spellCheckingType = .no
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        labelField.removeGestureRecognizer(tapGesture)
        
        descriptorField.numberOfLines = 10
        descriptorField.lineBreakMode = .byTruncatingMiddle
        
        if let desc = descriptor {
            addDescriptorToLabel(desc)
            loadAddresses(desc)
        }
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        labelField.resignFirstResponder()
    }
    
    @IBAction func importAction(_ sender: Any) {
        guard let desc = self.descriptor else { return }
        
        importDescriptor(desc.string)
    }
    
    @IBAction func scanQrAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToScanDescriptor", sender: self)
        }
    }
    
    private func loadAddresses(_ desc: Descriptor) {
        let p = Derive_Addresses(["descriptor": desc.string, "range": [0,4]])
        OnchainUtils.deriveAddresses(param: p) { [weak self] (addresses, message) in
            guard let self = self else { return }
            
            guard let addresses = addresses else { return }
                        
            for address in addresses {
                self.addresses.append(address)
            }
            
            DispatchQueue.main.async {
                self.addressTableView.reloadData()
                self.addressTableView.translatesAutoresizingMaskIntoConstraints = true
                self.addressTableView.sizeToFit()
            }
        }
    }
        
    private func importDescriptor(_ desc: String) {
        spinner.addConnectingView(vc: self, description: "importing descriptor wallet, this can take a minute...")
        
        let defaultLabel = "Descriptor import"
        
        var label = labelField.text ?? defaultLabel
        
        if label == "" {
            label = defaultLabel
        }
        
        let accountMap = ["descriptor": desc, "blockheight": 0, "watching": [] as [String], "label": label] as [String : Any]
        
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
    
    private func addDescriptorToLabel(_ descriptor: Descriptor) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            descriptorField.text = descriptor.string
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return addresses.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "addressCell", for: indexPath)
        let label = cell.viewWithTag(1) as! UILabel
        label.text = "#\(indexPath.row) " + addresses[indexPath.row]
        label.numberOfLines = 0
        label.sizeToFit()
        label.translatesAutoresizingMaskIntoConstraints = true
        
        cell.sizeToFit()
        cell.translatesAutoresizingMaskIntoConstraints = true
        
        return cell
        
    }
    
    private func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
//    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        return 40
//    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToScanDescriptor" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isScanningAddress = true
                vc.onDoneBlock = { [weak self] descriptor in
                    guard let self = self else { return }
                    
                    guard let desc = descriptor else { return }
                    
                    self.descriptor = Descriptor(desc)
                    addDescriptorToLabel(self.descriptor!)
                }
            }
        }
    }
}
