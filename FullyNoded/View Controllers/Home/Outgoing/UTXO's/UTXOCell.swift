//
//  UTXOCell.swift
//  FullyNoded
//
//  Created by FeedMyTummy on 9/16/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

protocol UTXOCellDelegate: AnyObject {
    func didTapToLock(_ utxo: Utxo)
    func didTapToEditLabel(_ utxo: Utxo)
    func didTapToFetchOrigin(_ utxo: Utxo)
    func didTapToMix(_ utxo: Utxo)
}

class UTXOCell: UITableViewCell {
    
    static let identifier = "UTXOCell"
    private var utxo: Utxo!
    private var isLocked: Bool!
    private unowned var delegate: UTXOCellDelegate!
    
    @IBOutlet private weak var lifeHashImageView: UIImageView!
    @IBOutlet private weak var fetchOriginOutlet: UIButton!
    @IBOutlet private weak var capGainLabel: UILabel!
    @IBOutlet public weak var roundeBackgroundView: UIView!
    @IBOutlet private weak var walletLabel: UILabel!// an address label
    @IBOutlet public weak var checkMarkImageView: UIImageView!
    @IBOutlet private weak var confirmationsLabel: UILabel!
    @IBOutlet private weak var spendableLabel: UILabel!
    @IBOutlet private weak var solvableLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!
    //@IBOutlet private weak var txidLabel: UILabel!
    //@IBOutlet private weak var voutLabel: UILabel!
    //@IBOutlet private weak var addressLabel: UILabel!
    @IBOutlet private weak var isChangeBackground: UIView!
    @IBOutlet private weak var isChangeImageView: UIImageView!
    @IBOutlet private weak var isSolvableBackground: UIView!
    @IBOutlet private weak var isSolvableImageView: UIImageView!
    @IBOutlet private weak var isDustBackground: UIView!
    @IBOutlet private weak var isDustImageView: UIImageView!
    @IBOutlet private weak var lockButtonOutlet: UIButton!
    @IBOutlet private weak var labelButtonOutlet: UIButton!
    @IBOutlet private weak var fiatLabel: UILabel!
    @IBOutlet private weak var reusedBackground: UIView!
    @IBOutlet private weak var reusedImageView: UIImageView!
    @IBOutlet private weak var mixButtonOutlet: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 8
        
        //mixButtonOutlet.alpha = 0
        
        roundeBackgroundView.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
        isChangeBackground.clipsToBounds = true
        isSolvableBackground.clipsToBounds = true
        isDustBackground.clipsToBounds = true
        reusedBackground.clipsToBounds = true
        
        isChangeBackground.layer.cornerRadius = 5
        isSolvableBackground.layer.cornerRadius = 5
        isDustBackground.layer.cornerRadius = 5
        reusedBackground.layer.cornerRadius = 5
        
        isChangeImageView.tintColor = .white
        isSolvableImageView.tintColor = .white
        isDustImageView.tintColor = .white
        reusedImageView.tintColor = .white
        
        lifeHashImageView.layer.magnificationFilter = .nearest
        
        selectionStyle = .none
    }
    
    func configure(utxo: Utxo, isLocked: Bool, fxRate: Double?, isSats: Bool, isBtc: Bool, isFiat: Bool, delegate: UTXOCellDelegate) {
        self.utxo = utxo
        self.isLocked = isLocked
        self.delegate = delegate
        
        //txidLabel.text = utxo.txid
        walletLabel.text = utxo.label ?? "No label"
        //addressLabel.text = "address: \(utxo.address ?? "unknown")"
        //txidLabel.text = "txid: \(utxo.txid)"
        //voutLabel.text = "vout #: \(utxo.vout)"
        
        if isLocked {
            lockButtonOutlet.setImage(UIImage(systemName: "lock"), for: .normal)
            lockButtonOutlet.tintColor = .systemPink
            labelButtonOutlet.alpha = 0
        } else {
            lockButtonOutlet.setImage(UIImage(systemName: "lock.open"), for: .normal)
            lockButtonOutlet.tintColor = .systemTeal
            labelButtonOutlet.alpha = 1
        }
        
        if utxo.reused != nil {
            if utxo.reused! {
                reusedImageView.image = UIImage(systemName: "shield.slash")
                reusedBackground.backgroundColor = .systemOrange
            } else {
                reusedImageView.image = UIImage(systemName: "shield")
                reusedBackground.backgroundColor = .systemIndigo
            }
            reusedImageView.alpha = 1
            reusedBackground.alpha = 1
        } else {
            reusedImageView.alpha = 0
            reusedBackground.alpha = 0
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
                
        if let amount = utxo.amount {
            //let roundedAmount = rounded(number: amount)
            
            if isFiat {
                amountLabel.text = utxo.amountFiat ?? "missing fx rate"
            } else if isBtc {
                amountLabel.text = amount.btc
            } else if isSats {
                amountLabel.text = amount.sats
            }
            
            if amount <= 0.00010000 {
                isDustImageView.image = UIImage(systemName: "exclamationmark.triangle")
                isDustBackground.backgroundColor = .systemRed
            } else {
                isDustImageView.image = UIImage(systemName: "checkmark")
                isDustBackground.backgroundColor = .darkGray
            }
            
            if let fxRate = fxRate {
                fiatLabel.text = (amount * fxRate).fiatString + " \(utxo.capGain ?? "")"
                capGainLabel.text = utxo.originValue ?? "missing origin rate"
                
                if capGainLabel.text == "missing origin rate" {
                    fetchOriginOutlet.alpha = 1
                } else {
                    fetchOriginOutlet.alpha = 0
                }
            } else {
                fetchOriginOutlet.alpha = 0
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
            self.roundeBackgroundView.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
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
        
//        if utxo.spendable != nil {
//            print("utxo.spendable: \(utxo.spendable)")
//            if utxo.spendable! {
//                spendableLabel.text = "Node hot"
//                spendableLabel.textColor = .systemGreen
//            } else {
//                spendableLabel.text = "Node cold"
//                spendableLabel.textColor = .systemBlue
//
//            }
//        } else {
//            spendableLabel.text = "?"
//            spendableLabel.textColor = .lightGray
//        }
        
        if let lifehash = utxo.lifehash {
            lifeHashImageView.image = lifehash
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
                    self.roundeBackgroundView.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
                    
                })
            }
        }
    }
    
    @IBAction func labelButtonTapped(_ sender: Any) {
        delegate.didTapToEditLabel(utxo)
    }
    
    @IBAction func lockButtonTapped(_ sender: Any) {
        delegate.didTapToLock(utxo)
    }
    
    @IBAction func fetchOriginTapped(_ sender: Any) {
        delegate.didTapToFetchOrigin(utxo)
    }
    
    @IBAction func mixButtonTapped(_ sender: Any) {
        delegate.didTapToMix(utxo)
    }
    
}
