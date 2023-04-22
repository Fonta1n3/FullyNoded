//
//  ConfirmLightningPaymentViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/11/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import UIKit

class ConfirmLightningPaymentViewController: UIViewController {
    
    var doneBlock:(((Bool)) -> Void)?
    var fxRate:Double?
    var invoice:[String:Any]?
    var spinner = ConnectingView()
    
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var recipientLabel: UILabel!
    @IBOutlet weak var expiryLabel: UILabel!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var sendButton: UIButton!
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        spinner.addConnectingView(vc: self, description: "")
        amountLabel.alpha = 0
        recipientLabel.alpha = 0
        expiryLabel.alpha = 0
        textView.alpha = 0
        sendButton.alpha = 0
        
        sendButton.layer.cornerRadius = 8
        sendButton.clipsToBounds = true
        textView.layer.cornerRadius = 8
        textView.clipsToBounds = true
        textView.layer.borderWidth = 0.5
        textView.layer.borderColor = UIColor.lightGray.cgColor
        
        load()
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        close(confirmed: false)
    }
    
    @IBAction func closeAction(_ sender: Any) {
        close(confirmed: false)
    }
    
    @IBAction func sendAction(_ sender: Any) {
        close(confirmed: true)
    }
    
    private func close(confirmed: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.doneBlock!(confirmed)
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func load() {
        guard let invoice = invoice else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "No invoice...", message: "There was an issue and no invoice was included.")
            return
        }
        
        let str = InvoiceStruct(invoice)
        
        fetchLocalPeers(recipient: str.recipient) { [weak self] displayName in
            guard let self = self else { return }
            
            self.setDisplay(invoice: str, displayName: displayName)
        }
    }
    
    private func setDisplay(invoice: InvoiceStruct, displayName: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var invoiceDoubleAmount = Double(invoice.amount)!
            
            var amountText = invoice.amount + " sats"
            
            if let customAmount = invoice.userSpecifiedAmount {
                invoiceDoubleAmount = (Double(customAmount)! / 1000.0)
                amountText = "\(invoiceDoubleAmount)" + " sats"
            }            
            
            if let fxRate = self.fxRate {
                let fiat = (invoiceDoubleAmount / 100000000.0) * fxRate
                
                amountText += "\n\(fiat.fiatString)"
            }
            
            self.amountLabel.text = amountText
            self.expiryLabel.text = "Expires " + invoice.expiry
            self.textView.text = invoice.memo
            self.recipientLabel.text = "To: " + displayName
            
            self.sendButton.alpha = 1
            self.amountLabel.alpha = 1
            self.recipientLabel.alpha = 1
            self.expiryLabel.alpha = 1
            self.textView.alpha = 1
            
            self.spinner.removeConnectingView()
        }
    }
    
    private func fetchLocalPeers(recipient: String, completion: @escaping ((String)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .peers) { peers in
            guard let peers = peers, peers.count > 0 else {
                completion(recipient)
                return
            }
            
            for (i, peer) in peers.enumerated() {
                let peerStruct = PeersStruct(dictionary: peer)
                
                var string = recipient
                
                if recipient == peerStruct.pubkey {
                    if peerStruct.label == "" {
                        string = peerStruct.alias
                    } else {
                        string = peerStruct.label
                    }
                }
                
                if i + 1 == peers.count {
                    completion(string)
                }
            }
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
