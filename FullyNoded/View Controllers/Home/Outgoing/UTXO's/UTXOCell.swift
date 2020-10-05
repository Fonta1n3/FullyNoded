//
//  UTXOCell.swift
//  FullyNoded
//
//  Created by FeedMyTummy on 9/16/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

protocol UTXOCellDelegate: class {
    func didTapToLock(_ utxo: UtxosStruct)
    //func didTapInfoFor(_ utxo: UtxosStruct)
}

class UTXOCell: UITableViewCell {
    
    static let identifier = "UTXOCell"
    private var utxo: UtxosStruct!
    private var isLocked: Bool!
    private unowned var delegate: UTXOCellDelegate!
    
    @IBOutlet public weak var roundeBackgroundView: UIView!
    @IBOutlet private weak var walletLabel: UILabel!// an address label
    @IBOutlet public weak var checkMarkImageView: UIImageView!
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
    @IBOutlet private weak var lockButtonOutlet: UIButton!
    @IBOutlet private weak var infoButtonOutlet: UIButton!
    
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
        
        infoButtonOutlet.alpha = 0
        
        selectionStyle = .none
    }
    
    func configure(utxo: UtxosStruct, isLocked: Bool, delegate: UTXOCellDelegate) {
        self.utxo = utxo
        self.isLocked = isLocked
        self.delegate = delegate
        
        txidLabel.text = utxo.txid
        walletLabel.text = utxo.label
        addressLabel.text = "Address: \(utxo.address ?? "unknown")"
        txidLabel.text = "TXID: \(utxo.txid)"
        voutLabel.text = "vout #\(utxo.vout)"
        
        if isLocked {
            lockButtonOutlet.setImage(UIImage(systemName: "lock"), for: .normal)
            lockButtonOutlet.tintColor = .systemPink
            //infoButtonOutlet.alpha = 0
        } else {
            lockButtonOutlet.setImage(UIImage(systemName: "lock.open"), for: .normal)
            lockButtonOutlet.tintColor = .systemTeal
            //infoButtonOutlet.alpha = 1
        }
        
        if utxo.desc != nil {
            if utxo.desc!.contains("/1/") {
                isChangeImageView.image = UIImage(systemName: "arrow.2.circlepath")
                isChangeBackground.backgroundColor = .systemPurple
            } else {
                isChangeImageView.image = UIImage(systemName: "arrow.down.left")
                isChangeBackground.backgroundColor = .systemBlue
            }
        } else {
            isChangeImageView.image = UIImage(systemName: "questionmark")
            isChangeBackground.backgroundColor = .clear
        }
        
        if utxo.amount != nil {
            let roundedAmount = rounded(number: utxo.amount!)
            amountLabel.text = "\(roundedAmount.avoidNotation)"
            
            if utxo.amount! <= 0.00010000 {
                isDustImageView.image = UIImage(systemName: "exclamationmark.triangle")
                isDustBackground.backgroundColor = .systemRed
            } else {
                isDustImageView.image = UIImage(systemName: "checkmark")
                isDustBackground.backgroundColor = .darkGray
            }
        }  else {
            isDustImageView.image = UIImage(systemName: "questionmark")
            isDustBackground.backgroundColor = .clear
            amountLabel.text = "?"
        }

        if utxo.isSelected {
            checkMarkImageView.alpha = 1
            self.roundeBackgroundView.backgroundColor = .darkGray
        } else {
            checkMarkImageView.alpha = 0
            self.roundeBackgroundView.backgroundColor = #colorLiteral(red: 0.07831101865, green: 0.08237650245, blue: 0.08238270134, alpha: 1)
        }
        
        if utxo.solvable != nil {
            if utxo.solvable! {
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
        } else {
            solvableLabel.text = "?"
            solvableLabel.textColor = .lightGray
            isSolvableImageView.image = UIImage(systemName: "questionmark")
            isSolvableBackground.backgroundColor = .clear
        }
        
        if utxo.confs != nil {
            if Int(utxo.confs!) == 0 {
                confirmationsLabel.textColor = .systemRed
            } else {
                confirmationsLabel.textColor = .systemGreen
            }
            
            confirmationsLabel.text = "\(utxo.confs!) confs"
        } else {
            confirmationsLabel.text = "?"
            confirmationsLabel.textColor = .lightGray
        }
        
        if utxo.spendable != nil {
            if utxo.spendable! {
                spendableLabel.text = "Node hot"
                spendableLabel.textColor = .systemGreen
            } else {
                spendableLabel.text = "Node cold"
                spendableLabel.textColor = .systemBlue

            }
        } else {
            spendableLabel.text = "?"
            spendableLabel.textColor = .lightGray
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
        //delegate.didTapInfoFor(utxo)
    }
}
