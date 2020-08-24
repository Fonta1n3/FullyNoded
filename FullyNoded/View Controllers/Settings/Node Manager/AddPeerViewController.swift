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

    override func viewDidLoad() {
        super.viewDidLoad()
        amountField.delegate = self
        configureTapGesture()
    }
    
    @IBAction func scanNowAction(_ sender: Any) {
        if amountField.text != nil {
            if let _ = Int(amountField.text!) {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.performSegue(withIdentifier: "segueToScannerFromLightningManager", sender: vc)
                }
            } else {
                spinner.removeConnectingView()
                showAlert(vc: self, title: "Invalid commitment amount", message: "")
            }
        } else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "Add a valid commitment amount", message: "")
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
        if amountField.text != nil {
            if let int = Int(amountField.text!) {
                Lightning.connect(amount: int, id: id, ip: ip, port: port ?? "9735") { [weak self] (result, errorMessage) in
                    if result != nil {
                        self?.spinner.removeConnectingView()
                        if let success = result!["commitments_secured"] as? Bool {
                            if success {
                                showAlert(vc: self, title: "⚡️⚡️⚡️⚡️⚡️⚡️", message: "Peer connected, channel created, channel started, channel funded and channel commitment secured! That wasn't hard now was it?")
                            } else {
                                showAlert(vc: self, title: "Uh oh", message: "So close yet so far! The channel is connected yet we did not seem to get our commitment secured...")
                            }
                        }
                    } else {
                        self?.spinner.removeConnectingView()
                        showAlert(vc: self, title: "Ooops something did not go quite right", message: errorMessage ?? "unknown error connecting and funding that peer/channel")
                    }
                }
            } else {
                spinner.removeConnectingView()
                showAlert(vc: self, title: "Invalid committment amount", message: "")
            }
        } else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "Add a valid committment amount", message: "")
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
            if let vc = segue.destination as? QRScannerViewController {
                vc.isScanningAddress = true
                vc.onAddressDoneBlock = { url in
                    if url != nil {
                        let arr = url!.split(separator: "@")
                        if arr.count > 0 {
                            let arr1 = "\(arr[1])".split(separator: ":")
                            let id = "\(arr[0])"
                            let ip = "\(arr1[0])"
                            if arr1.count > 0 {
                                let port = "\(arr1[1])"
                                self.addChannel(id: id, ip: ip, port: port)
                            }
                        }
                    }
                }
            }
        }
    }
}
