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
    func didTapInfoFor(_ utxo: UTXO)
}

class UTXOCell: UITableViewCell {
    
    static let identifier = "UTXOCell"
    private var utxo: UTXO!
    private unowned var delegate: UTXOCellDelegate!
    
    @IBOutlet private weak var roundeBackgroundView: UIView!
    @IBOutlet private weak var walletLabel: UILabel!// an address label
    @IBOutlet private weak var checkMarkImageView: UIImageView!
    @IBOutlet private weak var confirmationsLabel: UILabel!
    @IBOutlet private weak var spendableLabel: UILabel!
    @IBOutlet private weak var solvableLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var txidLabel: UILabel!
    @IBOutlet private weak var voutLabel: UILabel!
    @IBOutlet private weak var addressLabel: UILabel!
    @IBOutlet private weak var isChangeBackground: UIView!
    @IBOutlet private weak var isChangeImageView: UIImageView!
    @IBOutlet private weak var isSolvableBackground: UIView!
    @IBOutlet private weak var isSolvableImageView: UIImageView!
    @IBOutlet private weak var isDustBackground: UIView!
    @IBOutlet private weak var isDustImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 8
        
        isChangeBackground.clipsToBounds = true
        isSolvableBackground.clipsToBounds = true
        isDustBackground.clipsToBounds = true
        
        isChangeBackground.layer.cornerRadius = 5
        isSolvableBackground.layer.cornerRadius = 5
        isDustBackground.layer.cornerRadius = 5
        
        isChangeImageView.tintColor = .white
        isSolvableImageView.tintColor = .white
        isDustImageView.tintColor = .white
        
        selectionStyle = .none
    }
    
    func configure(utxo: UTXO, isSelected: Bool, delegate: UTXOCellDelegate) {
        self.utxo = utxo
        self.delegate = delegate
        
        txidLabel.text = utxo.txid
        walletLabel.text = utxo.addressLabel
        addressLabel.text = "Address: \(utxo.address)"
        txidLabel.text = "TXID: \(utxo.txid)"
        voutLabel.text = "vout #\(utxo.vout)"
        
        if utxo.desc.contains("/1/") {
            isChangeImageView.image = UIImage(systemName: "arrow.2.circlepath")
            isChangeBackground.backgroundColor = .systemPurple
        } else {
            isChangeImageView.image = UIImage(systemName: "arrow.down.left")
            isChangeBackground.backgroundColor = .systemBlue
        }
        
        if utxo.amount <= 0.00010000 {
            isDustImageView.image = UIImage(systemName: "exclamationmark.triangle")
            isDustBackground.backgroundColor = .systemRed
        } else {
            isDustImageView.image = UIImage(systemName: "checkmark")
            isDustBackground.backgroundColor = .darkGray
        }
        
        
        let roundedAmount = rounded(number: utxo.amount)
        amountLabel.text = "\(roundedAmount.avoidNotation)"

        if isSelected {
            checkMarkImageView.alpha = 1
            self.roundeBackgroundView.backgroundColor = .darkGray
        } else {
            checkMarkImageView.alpha = 0
            self.roundeBackgroundView.backgroundColor = #colorLiteral(red: 0.07831101865, green: 0.08237650245, blue: 0.08238270134, alpha: 1)
        }

        if utxo.solvable {
            solvableLabel.text = "Solvable"
            solvableLabel.textColor = .systemGreen
            
            isSolvableBackground.backgroundColor = .systemGreen
            isSolvableImageView.image = UIImage(systemName: "person.crop.circle.fill.badge.checkmark")
        } else {
            solvableLabel.text = "Not Solvable"
            solvableLabel.textColor = .systemBlue
            
            isSolvableBackground.backgroundColor = .systemRed
            isSolvableImageView.image = UIImage(systemName: "person.crop.circle.badge.xmark")
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
                    self.roundeBackgroundView.backgroundColor = .darkGray
                    
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
                    self.roundeBackgroundView.backgroundColor = #colorLiteral(red: 0.07831101865, green: 0.08237650245, blue: 0.08238270134, alpha: 1)
                    
                })
                
            }
            
        }
    }
    
    @IBAction func lockButtonTapped(_ sender: Any) {
        delegate.didTapToLock(utxo)
    }
    
    @IBAction func infoButtonTapped(_ sender: Any) {
        delegate.didTapInfoFor(utxo)
    }
}

// TODO: Move to its own file
struct UTXO: Equatable, Hashable, Codable {
    
    let txid: String
    let vout: Int
    let address: String
    let addressLabel: String?
    let pubKey: String
    let amount: Double
    let confirmations: Int
    let spendable: Bool
    let solvable: Bool
    let safe: Bool
    let desc: String
    
    enum CodingKeys: String, CodingKey {
        case txid
        case vout
        case address
        case addressLabel = "label"
        case pubKey = "scriptPubKey"
        case amount
        case confirmations
        case spendable
        case solvable
        case safe
        case desc
    }
}

// MARK: Equatable
extension UTXO {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.txid == rhs.txid && lhs.vout == rhs.vout
    }
    
}
