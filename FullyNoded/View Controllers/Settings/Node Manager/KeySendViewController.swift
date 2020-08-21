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
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textField.delegate = self
        textField.keyboardType = .decimalPad
        textField.keyboardAppearance = .dark
        addTapGesture()
        idLabel.text = id
    }
    
    @IBAction func sendAction(_ sender: Any) {
        if textField.text != "" {
            if let sats = Int(textField.text!) {
                promptToSend(sats: sats)
            }
        }
    }
    
    private func promptToSend(sats: Int) {
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
    
    private func send(sats: Int) {
        let msats = sats * 1000
        LightningRPC.command(method: .keysend, param: "\"\(id)\", \(msats)") { [weak self] (response, errorDesc) in
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
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
