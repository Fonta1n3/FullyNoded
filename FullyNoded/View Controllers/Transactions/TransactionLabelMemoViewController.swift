//
//  TransactionLabelMemoViewController.swift
//  FullyNoded
//
//  Created by Peter on 1/12/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import UIKit

class TransactionLabelMemoViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate {
    // Pushed full height, without the tab bar.
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }

    var txid = ""
    var labelText = ""
    var doneBlock:((String) -> Void)?

    let labelField = UITextField()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        
        configureTapGesture()
        
        labelField.delegate = self
        labelField.layer.borderColor = UIColor.lightGray.cgColor
        labelField.layer.borderWidth = 0.5
        labelField.clipsToBounds = true
        labelField.layer.cornerRadius = 8
        labelField.text = labelText
        // Cypherpunk teal look (see WalletTheme in ActiveWalletViewController.swift).
        WalletTheme.apply(to: self, tint: .transaction)
    }
    
    private func buildLayout() {
        let close = UIButton(type: .close)
        close.addTarget(self, action: #selector(closeAction(_:)), for: .touchUpInside)

        let title = UILabel()
        title.text = "Label:"
        title.textColor = .secondaryLabel

        labelField.font = .systemFont(ofSize: 14)
        labelField.backgroundColor = .clear
        labelField.autocorrectionType = .no
        labelField.spellCheckingType = .no
        labelField.smartDashesType = .no
        labelField.smartQuotesType = .no
        labelField.smartInsertDeleteType = .no
        labelField.keyboardAppearance = .dark

        let note = UILabel()
        note.numberOfLines = 0
        note.textColor = .tertiaryLabel
        note.text = "This label is associated with the transaction ID and is saved by Fully Noded, not Bitcoin Core."

        let save = UIButton(type: .system)
        save.setTitle("Save", for: .normal)
        save.backgroundColor = .systemFill
        save.addTarget(self, action: #selector(saveAction(_:)), for: .touchUpInside)

        for subview in [close, title, labelField, note, save] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: guide.topAnchor, constant: 15),
            close.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            title.topAnchor.constraint(equalTo: guide.topAnchor, constant: 68),
            title.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            labelField.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            labelField.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            labelField.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            labelField.heightAnchor.constraint(equalToConstant: 34),
            note.topAnchor.constraint(equalTo: labelField.bottomAnchor, constant: 8),
            note.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            note.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            save.topAnchor.constraint(equalTo: note.bottomAnchor, constant: 8),
            save.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            save.widthAnchor.constraint(equalToConstant: 89),
            save.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    @objc func saveAction(_ sender: Any) {
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
    
    @objc func closeAction(_ sender: Any) {
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
    

}
