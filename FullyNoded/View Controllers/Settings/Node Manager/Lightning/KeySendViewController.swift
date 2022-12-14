//
//  KeySendViewController.swift
//  FullyNoded
//
//  Created by Peter on 21/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class KeySendViewController: UIViewController, UITextFieldDelegate {
    
    let spinner = ConnectingView()
    var id = ""
    var peer:PeersStruct?
    var peerName = ""
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var iconBackground: UIView!
    @IBOutlet weak var aliasLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textField.delegate = self
        textField.keyboardType = .decimalPad
        textField.keyboardAppearance = .dark
        iconBackground.clipsToBounds = true
        iconBackground.layer.cornerRadius = 5
        
        addTapGesture()
        if peer != nil {
            idLabel.text = peer!.label
            iconBackground.backgroundColor = hexStringToUIColor(hex: peer!.color)
            aliasLabel.text = peer!.alias
            peerName = peer!.label
            if peer!.label == "" {
                peerName = peer!.alias
            }
        } else {
            peerName = id
            idLabel.text = id
            aliasLabel.text = "Key Send"
        }
        
    }
    
    @IBAction func sendAction(_ sender: Any) {
        textField.resignFirstResponder()
        if textField.text != "" {
            if let sats = Double(textField.text!) {
                promptToSend(sats: sats)
            }
        }
    }
    
    private func promptToSend(sats: Double) {
        DispatchQueue.main.async { [weak self] in
            if self != nil {
                var alertStyle = UIAlertController.Style.actionSheet
                if (UIDevice.current.userInterfaceIdiom == .pad) {
                  alertStyle = UIAlertController.Style.alert
                }
                let alert = UIAlertController(title: "Send \(sats) sats?", message: "This action uses the keysend command to send these satoshis to the peer id: \(String(describing: self!.id))", preferredStyle: alertStyle)
                alert.addAction(UIAlertAction(title: "Send it", style: .default, handler: { [weak self] action in
                    if self != nil {
                        self?.spinner.addConnectingView(vc: self!, description: "sending...")
                        self?.send(sats: sats)
                    }
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self?.view
                self?.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func send(sats: Double) {
        isLndNode { [weak self] isLnd in
            guard let self = self else { return }
            
            guard isLnd else {
                self.keysendCL(sats: sats)
                return
            }
            
            self.createInvoice(Int(sats))
        }
    }
    
    private func createInvoice(_ sats: Int) {
        guard let preimage = secret() else { return }
        
        let hash = Crypto.sha256hash(preimage)
        let b64 = hash.base64EncodedString()
        let memo = "Fully Noded Keysend: \(sats) sats sent to \(self.peerName) ⚡️"
        
        let param:[String:Any] = ["memo": memo,
                                  "hash":b64,
                                  "value":"\(sats)",
                                  "r_preimage": preimage.base64EncodedString(),
                                  "is_keysend": true]
        
        LndRpc.sharedInstance.command(.addinvoice, param, nil, nil) { [weak self] (response, error) in
            guard let self = self else { return }

            guard let response = response, let payreq = response["payment_request"] as? String, let payment_addr = response["payment_addr"] as? String else {
                return
            }

            self.keysend(hash: b64, sats: sats, payreq: payreq, payment_addr: payment_addr, memo: memo)
        }
    }
    
    private func secret() -> Data? {
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        
        guard result == errSecSuccess else {
            print("Problem generating random bytes")
            return nil
        }
        
        return Data(bytes)
    }
    
    private func keysend(hash: String, sats: Int, payreq: String, payment_addr: String, memo: String) {
        guard let pubkey = (peer?.pubkey ?? idLabel.text), let destData = Data(hexString: pubkey) else {
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "", message: "Pubkey missing!")
            return
        }
        
        let dest = destData.base64EncodedString()
        
        let param:[String:Any] = ["dest":dest,
                                  "amt":"\(sats)",
                                  "payment_hash": hash,
                                  "payment_request": payreq,
                                  "payment_addr": payment_addr,
                                  "allow_self_payment": true]
        
        LndRpc.sharedInstance.command(.keysend, param, nil, nil) { [weak self] (response, error) in
            guard let self = self else { return }

            guard let response = response else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "There was an issue...", message: error ?? "Unknown error.")
                return
            }
            
            if let payment_error = response["payment_error"] as? String, payment_error != "" {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Payment Error", message: payment_error)
            } else if let _ = response["payment_preimage"] as? String {
                self.decodePayreq(memo: memo, payreq: payreq, sats: sats)
            } else if let message = response["message"] as? String {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "There was an issue...", message: message)
            }
        }
    }
    
    private func decodePayreq(memo: String, payreq: String, sats: Int) {
        LndRpc.sharedInstance.command(.decodepayreq, nil, payreq, nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            guard let response = response, let paymentHash = response["payment_hash"] as? String else {
                return
            }
            
            self.saveTx(memo: memo, hash: paymentHash, sats: sats)
        }
    }
    
    private func keysendCL(sats: Double) {
        let msats = Int(sats * 1000.0)
        let commandId = UUID()
        let p:[String:Any] = ["destination":id, "msatoshi": msats, "label": "Fully Noded keysend"]
        LightningRPC.sharedInstance.command(id: commandId, method: .keysend, param: p) { [weak self] (uuid, response, errorDesc) in
            self?.spinner.removeConnectingView()
            if let dict = response as? NSDictionary {
                if let complete = dict["status"] as? String {
                    if complete == "complete" {
                        self?.success(dict: dict)
                    } else {
                        showAlert(vc: self, title: "Error", message: "\(dict)")
                    }
                }
            } else {
                showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown key send error")
            }
        }
    }
    
    private func success(dict: NSDictionary) {
        DispatchQueue.main.async { [weak self] in
            if self != nil {
                var alertStyle = UIAlertController.Style.actionSheet
                if (UIDevice.current.userInterfaceIdiom == .pad) {
                  alertStyle = UIAlertController.Style.alert
                }
                let alert = UIAlertController(title: "⚡️ Payment succeeded ⚡️", message: "The payment was a success, you can copy the payment hash below.", preferredStyle: alertStyle)
                alert.addAction(UIAlertAction(title: "Copy payment hash", style: .default, handler: { [weak self] action in
                    let pasteboard = UIPasteboard.general
                    pasteboard.string = dict["payment_hash"] as? String ?? ""
                    showAlert(vc: self, title: "Payment hash copied", message: "")
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self?.view
                self?.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        textField.resignFirstResponder()
    }
    
    private func saveTx(memo: String, hash: String, sats: Int) {
        FiatConverter.sharedInstance.getFxRate { fxRate in
            self.spinner.removeConnectingView()
            
            let fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
            
            var dict:[String:Any] = [
                "txid":hash,
                "id":UUID(),
                "memo":memo,
                "date":Date(),
                "label":"Fully Noded Keysend",
                "fiatCurrency": fiatCurrency
            ]
            
            guard let originRate = fxRate else {
                CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in }
                showAlert(vc: self, title: "Lightning payment sent ⚡️", message: "\(sats) sats sent to \(self.peerName)")
                return
            }
            
            dict["originFxRate"] = originRate
            
            CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in }
            showAlert(vc: self, title: "Lightning payment sent ⚡️", message: "\(sats) sats sent to \(self.peerName)")
        }        
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
