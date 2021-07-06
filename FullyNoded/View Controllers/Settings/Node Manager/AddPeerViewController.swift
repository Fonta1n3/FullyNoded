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
        
        guard let amountText = amountField.text, let int = Int(amountText) else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "Invalid committment amount", message: "")
            return
        }
        
        Lightning.connect(amount: int, id: id, ip: ip, port: port ?? "9735") { [weak self] (result, errorMessage) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let result = result, let success = result["commitments_secured"] as? Bool else {
                showAlert(vc: self, title: "Ooops something did not go quite right", message: errorMessage ?? "unknown error connecting and funding that peer/channel")
                return
            }
            
            if success {
                showAlert(vc: self, title: "⚡️⚡️⚡️⚡️⚡️⚡️", message: "Peer connected, channel created, channel started, channel funded and channel commitment secured! That wasn't hard now was it?")
            } else {
                showAlert(vc: self, title: "Uh oh", message: "So close yet so far! The channel is connected yet we did not seem to get our commitment secured...")
            }
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
                
                vc.onAddressDoneBlock = { [weak self] url in
                    guard let self = self else { return }
                    
                    guard let url = url else { return }
                    
                    let arr = url.split(separator: "@")
                    
                    guard arr.count > 0 else { return }
                    
                    let arr1 = "\(arr[1])".split(separator: ":")
                    let id = "\(arr[0])"
                    let ip = "\(arr1[0])"
                    
                    guard arr1.count > 0 else { return }
                    
                    let port = "\(arr1[1])"
                    
                    self.addChannel(id: id, ip: ip, port: port)
                }
            }
        }
    }
}
