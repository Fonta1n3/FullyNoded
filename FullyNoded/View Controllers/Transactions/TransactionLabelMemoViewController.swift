//
//  TransactionLabelMemoViewController.swift
//  FullyNoded
//
//  Created by Peter on 1/12/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import UIKit

class TransactionLabelMemoViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate {
    
    var txid = ""
    var labelText = ""
    var doneBlock:((String) -> Void)?

    @IBOutlet weak var labelField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTapGesture()
        
        labelField.delegate = self
        labelField.layer.borderColor = UIColor.lightGray.cgColor
        labelField.layer.borderWidth = 0.5
        labelField.clipsToBounds = true
        labelField.layer.cornerRadius = 8
        labelField.text = labelText
    }
    
    @IBAction func saveAction(_ sender: Any) {
        guard let newLabel = labelField.text else { return }
        
        CoreDataService.retrieveEntity(entityName: .transactions) { transactions in
            guard let transactions = transactions, transactions.count > 0 else { return }
            for (i, transaction) in transactions.enumerated() {
                let txStuct = TransactionStruct(dictionary: transaction)
                
                if txStuct.txid == self.txid {
                    CoreDataService.update(id: txStuct.id!, keyToUpdate: "label", newValue: newLabel, entity: .transactions) { [weak self] success in
                        guard let self = self else { return }
                        
                        guard success else {
                            showAlert(vc: self, title: "", message: "Label not updated! Please let us know about this issue.")
                            return
                        }
                    }
                }
                
                if i + 1 == transactions.count {
                    self.doneBlock!(newLabel)
                    
                    DispatchQueue.main.async {
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func configureTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        labelField.resignFirstResponder()
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
