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
    var memoText = ""
    var doneBlock:(([String]) -> Void)?

    @IBOutlet weak var labelField: UITextField!
    @IBOutlet weak var memoField: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTapGesture()
        
        memoField.delegate = self
        labelField.delegate = self

        // Do any additional setup after loading the view.
        memoField.clipsToBounds = true
        memoField.layer.cornerRadius = 8
        memoField.layer.borderWidth = 0.5
        memoField.layer.borderColor = UIColor.lightGray.cgColor
        memoField.textColor = .white
        
        labelField.layer.borderColor = UIColor.lightGray.cgColor
        labelField.layer.borderWidth = 0.5
        labelField.clipsToBounds = true
        labelField.layer.cornerRadius = 8
        
        labelField.text = labelText
        memoField.text = memoText
    }
    
    @IBAction func saveAction(_ sender: Any) {
        guard let newLabel = labelField.text, let newMemo = memoField.text else { return }
        
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
                        
                        CoreDataService.update(id: txStuct.id!, keyToUpdate: "memo", newValue: newMemo, entity: .transactions) { success in
                            guard success else {
                                showAlert(vc: self, title: "", message: "Memo not updated! Please let us know about this issue.")
                                return
                            }
                        }
                    }
                }
                
                if i + 1 == transactions.count {
                    self.doneBlock!([newLabel, newMemo])
                    
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
        memoField.resignFirstResponder()
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
