//
//  AddPeerViewController.swift
//  FullyNoded
//
//  Created by Peter on 06/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class AddPeerViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var amountField: UITextField!
    @IBOutlet weak var acnNowOutlet: UIButton!
    let spinner = ConnectingView()
    var psbt = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        amountField.delegate = self
        configureTapGesture()
    }
    
    @IBAction func pasteAction(_ sender: Any) {
        guard let amountText = amountField.text, let _ = Int(amountText) else {
            showAlert(vc: self, title: "Add a valid commitment amount", message: "")
            return
        }
        
        guard let uri = UIPasteboard.general.string else {
            showAlert(vc: self, title: "", message: "No text on your clipboard.")
            return
        }
        
        var id:String!
        var port:String?
        var ip:String!
        
        if uri.contains("@") {
            let arr = uri.split(separator: "@")
            
            guard arr.count > 0 else { return }
            
            let arr1 = "\(arr[1])".split(separator: ":")
            id = "\(arr[0])"
            ip = "\(arr1[0])"
            
            guard arr1.count > 0 else { return }
            
            if arr1.count >= 2 {
                port = "\(arr1[1])"
            }
            
            self.addChannel(id: id, ip: ip, port: port)
            
        } else {
            showAlert(vc: self, title: "Incomplete URI", message: "The URI must include an address.")
        }
    }
    
    
    @IBAction func scanNowAction(_ sender: Any) {
        guard let amountText = amountField.text, let _ = Int(amountText) else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "Add a valid commitment amount", message: "")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToScannerFromLightningManager", sender: self)
        }
    }
    
    func configureTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        amountField.resignFirstResponder()
    }
    
    private func addChannel(id: String, ip: String, port: String?) {
        spinner.addConnectingView(vc: self, description: "creating a channel...")
        
        guard let amountText = amountField.text, let amount = Int(amountText) else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "Invalid committment amount", message: "")
            return
        }
        
        isLndNode { [weak self] isLnd in
            guard let self = self else { return }
            
            guard isLnd else {
                self.openChannelCL(amount: amount, id: id, ip: ip, port: port)
                return
            }
            
            activeWallet { [weak self] wallet in
                guard let self = self else { return }
                
                guard let wallet = wallet else {
                    self.connect(amount, id, ip, port, nil)
                    return
                }
                
                self.getAddress(amount, id, ip, port, wallet)
            }
        }
    }
    
    private func getAddress(_ amount: Int, _ id: String, _ ip: String, _ port: String?, _ wallet: Wallet) {
        if wallet.type != WalletType.descriptor.stringValue {
            let index = Int(wallet.index) + 1
            let param:Derive_Addresses = .init(["descriptor": wallet.receiveDescriptor, "range": [index,index]])
            
            Reducer.sharedInstance.makeCommand(command: .deriveaddresses(param: param)) { (response, errorMessage) in
                guard let addresses = response as? NSArray, let address = addresses[0] as? String else {
                    showAlert(vc: self, title: "", message: errorMessage ?? "error getting closing address")
                    return
                }
                
                self.promptToUseClosingAddress(amount, id, ip, port, wallet, address)
            }
        }// else {
//            Reducer.sharedInstance.makeCommand(command: .getnewaddress) { (response, errorMessage) in
//                guard let address = response as? String else {
//                    showAlert(vc: self, title: "", message: errorMessage ?? "error getting closing address")
//                    return
//                }
//
//                self.promptToUseClosingAddress(amount, id, ip, port, wallet, address)
//            }
        //}
    }
    
    private func promptToUseClosingAddress(_ amount: Int, _ id: String, _ ip: String, _ port: String?, _ wallet: Wallet, _ address: String?) {
        DispatchQueue.main.async { [weak self] in
            let alertStyle = UIAlertController.Style.actionSheet
            let tit = "Automatically close to \(wallet.label)?"
            let mess = "This means funds will automatically be sent to \(wallet.label) whenever the channel happens to close! This is NOT reversible!"
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Close to \(wallet.label)", style: .default, handler: { action in
                if wallet.type != WalletType.descriptor.stringValue {
                    CoreDataService.update(id: wallet.id, keyToUpdate: "index", newValue: Int64(Int(wallet.index) + 1), entity: .wallets) { _ in }
                }
                
                self?.connect(amount, id, ip, port, address)
            }))
            
            alert.addAction(UIAlertAction(title: "Use LND wallet", style: .default, handler: { action in
                self?.connect(amount, id, ip, port, nil)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self?.view
            self?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func connect(_ amount: Int, _ id: String, _ ip: String, _ port: String?, _ address: String?) {
        let host = "\(ip):\(port ?? "9735")"
        let param = ["addr": ["pubkey":id, "host": host]]
        
        LndRpc.sharedInstance.command(.connect, param, nil, nil) { [weak self] (response, error) in
            guard let self = self else { return }
                        
            guard let response = response else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: error ?? "Unknown error connecting peer.")
                return
            }
            
            if let errorMessage = response["error"] as? String, errorMessage != "", !errorMessage.contains("already connected to peer:") {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: errorMessage)
            } else {
                self.openChannelLND(amount: amount, id: id, address: address)
            }
        }
    }
    
    
    private func openChannelLND(amount: Int, id: String, address: String?) {
        guard let data = Data(hexString: id) else { return }
        
        let param:[String:Any] = ["node_pubkey": data.base64EncodedString(),
                                  "local_funding_amount": amount,
                                  "close_address": address ?? "",
                                  "private":true,
                                  "spend_unconfirmed":true]
        
        LndRpc.sharedInstance.command(.openchannel, param, nil, nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let response = response else {
                showAlert(vc: self, title: "Error", message: error ?? "Unknown error during channel funding.")
                return
            }
            
            guard let _ = response["funding_txid_bytes"] as? String else {
                let errorMess = response["error"] as? String ?? "Unknown channel funding error."
                showAlert(vc: self, title: "Channel created ✓", message: errorMess)
                return
            }
            
            showAlert(vc: self, title: "Channel created ✓", message: "")
        }
    }
    
    private func openChannelCL(amount: Int, id: String, ip: String?, port: String?) {
        Lightning.connect(amount: amount, id: id, ip: ip, port: port) { [weak self] (result, errorMessage) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let result = result else {
                showAlert(vc: self, title: "There was an issue.", message: errorMessage ?? "Unknown error connecting and funding that peer/channel.")
                return
            }
            
            if let success = result["success"] as? Bool {
                if success {
                    showAlert(vc: self, title: "Channel created ⚡️", message: "Channel commitment secured!")
                } else {
                    showAlert(vc: self, title: "There was an issue...", message: errorMessage ?? "Unknown error.")
                }
            } else if let psbt = result["psbt"] as? String {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.psbt = psbt
                    self.promptToExportPsbt(psbt)
                }
                
            } else if let rawTx = result["rawTx"] as? String {
                DispatchQueue.main.async {
                    UIPasteboard.general.string = rawTx
                }
                
                showAlert(vc: self, title: "Channel funding had an issue...", message: "The raw transaction has been copied to your clipboard. Error: \(errorMessage ?? "Unknown error. Try broadcasting the transaction manually. Go to active wallet and tap the send / broadcast button then tap paste.")")
            }
        }
    }
    
    private func promptToExportPsbt(_ psbt: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alertStyle = UIAlertController.Style.alert
            let tit = "Export PSBT"
            let mess = "⚠️ Warning!\n\nYou MUST broadcast the signed transaction with this device using Fully Noded! Otherwise there is a chance of loss of funds and channel funding WILL FAIL!"
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Export", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.exportPsbt()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func exportPsbt() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToExportPsbtForChannelFunding", sender: self)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToScannerFromLightningManager" {
            if #available(macCatalyst 14.0, *) {
                if let vc = segue.destination as? QRScannerViewController {
                    vc.isScanningAddress = true
                    
                    vc.onDoneBlock = { [weak self] url in
                        guard let self = self else { return }
                        
                        guard let url = url else { return }
                        
                        var id:String!
                        var port:String?
                        var ip:String!
                        
                        if url.contains("@") {
                            let arr = url.split(separator: "@")
                            
                            guard arr.count > 0 else { return }
                            
                            let arr1 = "\(arr[1])".split(separator: ":")
                            id = "\(arr[0])"
                            ip = "\(arr1[0])"
                            
                            guard arr1.count > 0 else { return }
                            
                            if arr1.count >= 2 {
                                port = "\(arr1[1])"
                            }
                            
                            self.addChannel(id: id, ip: ip, port: port)
                            
                        } else {
                            self.spinner.removeConnectingView()
                            showAlert(vc: self, title: "Incomplete URI", message: "The URI must include an address.")
                        }
                    }
                }
            } else {
                // Fallback on earlier versions
            }
        }
        
        if segue.identifier == "segueToExportPsbtForChannelFunding" {
            if let vc = segue.destination as? VerifyTransactionViewController {
                vc.unsignedPsbt = self.psbt
            }
        }
    }
}
