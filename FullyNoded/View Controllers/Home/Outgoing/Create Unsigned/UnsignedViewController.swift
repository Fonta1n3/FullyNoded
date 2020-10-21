//
//  UnsignedViewController.swift
//  BitSense
//
//  Created by Peter on 30/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class UnsignedViewController: UIViewController, UITextFieldDelegate {
    
    let addressParser = AddressParser()
    let creatingView = ConnectingView()
    let createUnsigned = CreateUnsigned()
    var unsignedTx = ""
    var amount = Double()
    var isSpendingFrom = Bool()
    var isReceiving = Bool()
    var isChange = Bool()
    
    @IBOutlet var changeField: UITextField!
    @IBOutlet var amountField: UITextField!
    @IBOutlet var spendingField: UITextField!
    @IBOutlet var receivingField: UITextField!
    @IBOutlet var amountOutlet: UILabel!
    @IBOutlet var recOutlet: UILabel!
    @IBOutlet var recButtonOutlet: UIButton!
    @IBOutlet var addressOutlet: UILabel!
    @IBOutlet var addressButtOutlet: UIButton!
    @IBOutlet var changeOutlet: UILabel!
    @IBOutlet var changeButtOutlet: UIButton!
    @IBOutlet var imageView: UIImageView!
    
    @IBAction func scanChange(_ sender: Any) {
        
        print("scanChange")
        isSpendingFrom = false
        isReceiving = false
        isChange = true
        scanNow()
        
    }
    
    @IBAction func scanSpendingFrom(_ sender: Any) {
        
        print("scanSpendingFrom")
        isSpendingFrom = true
        isReceiving = false
        isChange = false
        scanNow()
        
    }
    
    @IBAction func scanReceiving(_ sender: Any) {
        
        print("scanReceiving")
        isReceiving = true
        isSpendingFrom = false
        isChange = false
        scanNow()
        
    }
    
    @IBAction func createRaw(_ sender: Any) {
        
        print("createRaw")
        
        hideKeyboards()
        
        if receivingField.text != "" && amountField.text != "" && changeField.text != "" && spendingField.text != ""{
            
            self.creatingView.addConnectingView(vc: self, description: "creating unsigned...")
            
            createUnsigned.amount = Double(amountField.text!)!
            createUnsigned.changeAddress = changeField.text!
            createUnsigned.addressToPay = receivingField.text!
            createUnsigned.spendingAddress = spendingField.text!
            
            func getResult() {
                
                if !createUnsigned.errorBool {
                    
                    DispatchQueue.main.async {
                        
                        self.receivingField.removeFromSuperview()
                        self.spendingField.removeFromSuperview()
                        self.changeField.removeFromSuperview()
                        self.amountField.removeFromSuperview()
                        self.amountOutlet.removeFromSuperview()
                        self.recOutlet.removeFromSuperview()
                        self.recButtonOutlet.removeFromSuperview()
                        self.addressOutlet.removeFromSuperview()
                        self.addressButtOutlet.removeFromSuperview()
                        self.changeOutlet.removeFromSuperview()
                        self.changeButtOutlet.removeFromSuperview()
                        
                    }
                    
                    displayRaw(raw: createUnsigned.unsignedRawTx)
                    
                } else {
                    
                    creatingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: createUnsigned.errorDescription)
                    
                }
                
            }
            
            createUnsigned.createRawTransaction(completion: getResult)
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Ooops, you need to fill out an amount and recipient address")
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        amountField.delegate = self
        changeField.delegate = self
        receivingField.delegate = self
        spendingField.delegate = self

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            self.amountField.resignFirstResponder()
            self.spendingField.resignFirstResponder()
            self.receivingField.resignFirstResponder()
            self.changeField.resignFirstResponder()
            
        }
        
    }
    
    func removeSpinner() {
        
        DispatchQueue.main.async {
            
            self.creatingView.removeConnectingView()
            
        }
        
    }
    
    // MARK: QR SCANNER METHODS
    
    private func scanNow() {
        print("scanNow")
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToScannerFromUnsigned", sender: vc)
        }
    }
    
    func parseAddress(address: String) {
        
        addressParser.url = address
        let address = addressParser.parseAddress(url: address).address
        let errorBool = addressParser.parseAddress(url: address).errorBool
        let errorDescription = addressParser.parseAddress(url: address).errorDescription
        
        if !errorBool {
            
            if isSpendingFrom {
                
                DispatchQueue.main.async {
                    
                    //self.back()
                    self.spendingField.text = address
                    print("update spending")
                    
                }
                
            }
            
            if isReceiving {
                
                DispatchQueue.main.async {
                    
                    self.receivingField.text = address
                    
                }
                
            }
            
            if isChange {
                
                DispatchQueue.main.async {
                    
                    self.changeField.text = address
                    
                }
                
            }
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: errorDescription)
            
        }
        
    }
    
    func displayRaw(raw: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToExporterFromUnsigned", sender: vc)
        }
    }
    
    // MARK: TEXTFIELD METHODS
    
    func hideKeyboards() {
        
        receivingField.resignFirstResponder()
        spendingField.resignFirstResponder()
        amountField.resignFirstResponder()
        changeField.resignFirstResponder()
        
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        if textField == receivingField  {
            
            isReceiving = true
            isSpendingFrom = false
            isChange = false
            
        } else if textField == spendingField {
            
            isSpendingFrom = true
            isReceiving = false
            isChange = false
            
        } else if textField == changeField {
            
            isChange = true
            isReceiving = false
            isSpendingFrom = false
            
        }
        
        if textField.text != "" {
            
            textField.becomeFirstResponder()
            
        } else {
            
            if let string = UIPasteboard.general.string {
                
                textField.becomeFirstResponder()
                textField.text = string
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textField.resignFirstResponder()
                }
                
            } else {
                
                textField.becomeFirstResponder()
                
            }
            
        }
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        textField.endEditing(true)
        return true
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        print("textFieldDidEndEditing")
        
        if textField == receivingField && receivingField.text != "" && isReceiving {
            
            let address = receivingField.text!
            addressParser.url = address
            parseAddress(address: address)
            
        } else if textField == spendingField && spendingField.text != "" && isSpendingFrom {
            
            let address = spendingField.text!
            addressParser.url = address
            parseAddress(address: address)
            
        } else if textField == changeField && changeField.text != "" && isChange {
            
            let address = changeField.text!
            addressParser.url = address
            parseAddress(address: address)
            
        } else if textField == amountField && amountField.text != "" {
            
            if let amountCheck = Double(amountField.text!) {
                
                self.amount = amountCheck
                
            } else {
                
                amountField.text = ""
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Only valid numbers allowed")
                
            }
            
        }
        
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        if textView.text != "" {
            
            textView.becomeFirstResponder()
            
        } else {
            
            if let string = UIPasteboard.general.string {
                
                textView.becomeFirstResponder()
                textView.text = string
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textView.resignFirstResponder()
                }
                
            } else {
                
                textView.becomeFirstResponder()
                
            }
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "segueToScannerFromUnsigned" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isScanningAddress = true
                vc.onAddressDoneBlock = { text in
                    if text != nil {
                        self.parseAddress(address: text!)
                    }
                }
            }
            
        } else if segue.identifier == "segueToExporterFromUnsigned" {
            if let vc = segue.destination as? VerifyTransactionViewController {
                vc.signedRawTx = self.unsignedTx
            }
        }
    }

}
