//
//  UTXOCell.swift
//  FullyNoded
//
//  Created by FeedMyTummy on 9/16/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

protocol UTXOCellDelegate: class {
    func didTapToLock(_ utxo: UTXO)
}

class UTXOCell: UITableViewCell {
    
    static let identifier = "UTXOCell"
    private var utxo: UTXO!
    private unowned var delegate: UTXOCellDelegate!
    
    @IBOutlet private weak var roundeBackgroundView: UIView!
    @IBOutlet private weak var walletLabel: UILabel!
    @IBOutlet private weak var checkMarkImageView: UIImageView!
    @IBOutlet private weak var confirmationsLabel: UILabel!
    @IBOutlet private weak var spendableLabel: UILabel!
    @IBOutlet private weak var solvableLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var txidLabel: UILabel!
    @IBOutlet private weak var voutLabel: UILabel!
    @IBOutlet private weak var addressLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 8
        
        selectionStyle = .none
    }
    
    func configure(utxo: UTXO, isSelected: Bool, delegate: UTXOCellDelegate) {
        self.utxo = utxo
        self.delegate = delegate
        
        txidLabel.text = utxo.txid
        walletLabel.text = utxo.walletLabel
        addressLabel.text = "Address: \(utxo.address)"
        txidLabel.text = "TXID: \(utxo.txid)"
        voutLabel.text = "vout #\(utxo.vout)"
        
        
        let roundedAmount = rounded(number: utxo.amount)
        amountLabel.text = "\(roundedAmount)"

        if isSelected {
            checkMarkImageView.alpha = 1
            backgroundColor = UIColor.black
        } else {
            checkMarkImageView.alpha = 0
            backgroundColor = #colorLiteral(red: 0.07831101865, green: 0.08237650245, blue: 0.08238270134, alpha: 1)
        }

        if utxo.solvable {
            solvableLabel.text = "Solvable"
            solvableLabel.textColor = .systemGreen
        } else {
            solvableLabel.text = "Not Solvable"
            solvableLabel.textColor = .systemBlue
        }

        if utxo.confirmations == 0 {
            confirmationsLabel.textColor = .systemRed
        } else {
            confirmationsLabel.textColor = .systemGreen
        }
        confirmationsLabel.text = "\(utxo.confirmations) confs"

        if utxo.spendable {
            spendableLabel.text = "Spendable"
            spendableLabel.textColor = .systemGreen
        } else {
            spendableLabel.text = "COLD"
            spendableLabel.textColor = .systemBlue

        }
    }
    
    func selectedAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            UIView.animate(withDuration: 0.2, animations: {
                self.alpha = 0
            }) { _ in
                UIView.animate(withDuration: 0.2, animations: {
                    self.alpha = 1
                    self.checkMarkImageView.alpha = 1
                    self.backgroundColor = UIColor.black
                    
                })
                
            }
            
        }
    }
    
    func deselectedAnimation() {
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                guard let self = self else { return }
                
                self.checkMarkImageView.alpha = 0
                self.alpha = 0
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    self.alpha = 1
                    self.backgroundColor = #colorLiteral(red: 0.07831101865, green: 0.08237650245, blue: 0.08238270134, alpha: 1)
                    
                })
                
            }
            
        }
    }
    
    @IBAction func lockTapped(_ sender: Any) {
        
        delegate.didTapToLock(utxo)
    }
    
}

// TODO: Move to its own file
struct UTXO: Equatable, Hashable, Codable {
    
    let txid: String
    let vout: Int
    let address: String
    let walletLabel: String
    let pubKey: String
    let amount: Double
    let confirmations: Int
    let spendable: Bool
    let solvable: Bool
    let safe: Bool
    
    enum CodingKeys: String, CodingKey {
        case txid
        case vout
        case address
        case walletLabel = "label"
        case pubKey = "scriptPubKey"
        case amount
        case confirmations
        case spendable
        case solvable
        case safe
    }
}

// MARK: Equatable
extension UTXO {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.txid == rhs.txid && lhs.vout == rhs.vout
    }
    
}
