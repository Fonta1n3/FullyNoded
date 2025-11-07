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
    func didTapToSpendUtxo(_ utxo: Utxo)
    func copyAddress(_ utxo: Utxo)
    func copyTxid(_ utxo: Utxo)
    func copyDesc(_ utxo: Utxo)
    func editLabel(_ utxo: Utxo)
    func getAddressInfo(_ utxo: Utxo)
    func getTxInfo(_ utxo: Utxo)
    func getDescriptorInfo(_ utxo: Utxo)
}

class UTXOCell: UITableViewCell {
    
    static let identifier = "UTXOCell"
    private var utxo: Utxo!
    private var isLocked: Bool!
    private unowned var delegate: UTXOCellDelegate!
    
    
    @IBOutlet weak var spendUtxoButtonOutlet: UIButton!
    @IBOutlet weak var roundedBackgroundView: UIView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var checkMarkImageView: UIImageView!
    @IBOutlet weak var confirmationsLabel: UILabel!
    @IBOutlet weak var solvableLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var labelOutlet: UILabel!
    @IBOutlet weak var reusedLabel: UILabel!
    @IBOutlet weak var reusedImageView: UIImageView!
    @IBOutlet weak var changeLabel: UILabel!
    @IBOutlet weak var bipLabel: UILabel!
    @IBOutlet weak var dustLabel: UILabel!
    @IBOutlet weak var confsIcon: UIImageView!
    @IBOutlet weak var descriptorLabel: UILabel!
    @IBOutlet weak var txidLabel: UILabel!
    @IBOutlet weak var voutLabel: UILabel!
    @IBOutlet weak var isChangeImageView: UIImageView!
    @IBOutlet weak var lockButtonOutlet: UIButton!
    @IBOutlet weak var derivationLabel: UILabel!
    @IBOutlet weak var isDustImageView: UIImageView!
    @IBOutlet weak var isSolvableImageView: UIImageView!
    
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        selectionStyle = .none
    }
    
    func configure(wallet: Wallet, utxo: Utxo, isLocked: Bool, fxRate: Double?, isSats: Bool, isBtc: Bool, isFiat: Bool, delegate: UTXOCellDelegate) {
        self.utxo = utxo
        self.isLocked = isLocked
        self.delegate = delegate
                
        if let label = utxo.label {
            labelOutlet.text = label == "" ? "No utxo label" : label
        }
        
        if isLocked {
            lockButtonOutlet.setImage(UIImage(systemName: "lock"), for: .normal)
            //lockButtonOutlet.tintColor = .systemPink
        } else {
            lockButtonOutlet.setImage(UIImage(systemName: "lock.open"), for: .normal)
            //lockButtonOutlet.tintColor = .systemTeal
        }
        
        if utxo.reused != nil {
            if utxo.reused! {
                reusedImageView.image = UIImage(systemName: "shield.slash")
                reusedImageView.tintColor = .systemOrange
                reusedLabel.text = "Address reused!"
                //reusedBackground.backgroundColor = .systemOrange
            } else {
                reusedImageView.image = UIImage(systemName: "shield")
                reusedImageView.tintColor = .none
                reusedLabel.text = "Used once"
                //reusedBackground.backgroundColor = .systemIndigo
            }
            //reusedImageView.alpha = 1
        } else {
            reusedImageView.image = UIImage(systemName: "questionmark")
        }
        
        if let desc = utxo.desc ?? utxo.path {
            if desc.contains("/1/") {
                isChangeImageView.image = UIImage(systemName: "arrow.2.circlepath")
                isChangeImageView.tintColor = .none
                changeLabel.text = "Change address"
            } else {
                isChangeImageView.image = UIImage(systemName: "arrow.down.left")
                isChangeImageView.tintColor = .none
                changeLabel.text = "Receive address"
            }
            let descriptor = Descriptor(desc)
            
            if descriptor.isBIP44 {
                bipLabel.text = "BIP44"
            } else if descriptor.isBIP48 {
                bipLabel.text = "BIP48"
            } else if descriptor.isBIP49 {
                bipLabel.text = "BIP49"
            } else if descriptor.isBIP84 {
                bipLabel.text = "BIP84"
            }
            
            derivationLabel.text = descriptor.derivation
            
        } else {
            isChangeImageView.image = UIImage(systemName: "questionmark")
            changeLabel.text = "Unknown address type"
        }
        
        if let path = utxo.path {
            derivationLabel.text = path
        }
        
        
                
        if let amount = utxo.amount {
            if isFiat {
                if let fxRate = fxRate {
                    amountLabel.text = (amount * fxRate).fiatString
                }
                
            } else if isBtc {
                amountLabel.text = amount.btcBalanceWithSpaces
            } else if isSats {
                amountLabel.text = amount.sats
            }
            
            if amount <= 0.00010000 {
                isDustImageView.image = UIImage(systemName: "exclamationmark.triangle")
                isDustImageView.tintColor = .systemRed
                dustLabel.text = "Dust amount!"
            } else {
                isDustImageView.image = UIImage(systemName: "checkmark")
                isDustImageView.tintColor = .none
                dustLabel.text = "Not dust"
            }
            
        }  else {
            isDustImageView.image = UIImage(systemName: "questionmark")
            amountLabel.text = ""
        }

        if utxo.isSelected {
            checkMarkImageView.alpha = 1
            //checkMarkImageView.tintColor = .none
        } else {
            checkMarkImageView.alpha = 0
            //self.roundeBackgroundView.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        }
                
        if utxo.solvable != nil {
            if utxo.solvable! {
                solvableLabel.text = "Owned by \(wallet.label)"
                //solvableLabel.textColor = .systemGreen
                isSolvableImageView.tintColor = .none
                isSolvableImageView.image = UIImage(systemName: "person.crop.circle.fill.badge.checkmark")
            } else {
                solvableLabel.text = "Not owned by \(wallet.label)!"
                //solvableLabel.textColor = .systemBlue
                isSolvableImageView.tintColor = .systemRed
                isSolvableImageView.image = UIImage(systemName: "person.crop.circle.badge.xmark")
            }
        } else {
            solvableLabel.text = "?"
            //solvableLabel.textColor = .lightGray
            isSolvableImageView.image = UIImage(systemName: "questionmark")
            isSolvableImageView.tintColor = .none
        }
        
        if utxo.confs != nil {
            if Int(utxo.confs!) == 0 {
                confsIcon.tintColor = .systemRed
            } else {
                confsIcon.tintColor = .none
            }
            
            confirmationsLabel.text = "\(utxo.confs!) confirmations"
        } else {
            confirmationsLabel.text = "?"
        }
        
        if let desc = utxo.desc {
            descriptorLabel.text = desc
        } else {
            print("no desc")
        }
        
        if let address = utxo.address {
            addressLabel.text = address
        }
        
        txidLabel.text = utxo.txid
        voutLabel.text = "\(utxo.vout)"
        
        self.translatesAutoresizingMaskIntoConstraints = true
        self.sizeToFit()
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
                    //self.roundeBackgroundView.backgroundColor = .darkGray
                    
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
                    //self.roundeBackgroundView.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
                    
                })
            }
        }
    }
    
    @IBAction func lockButtonTapped(_ sender: Any) {
        delegate.didTapToLock(utxo)
    }
    
    @IBAction func sendUtxoTapped(_ sender: Any) {
        delegate.didTapToSpendUtxo(utxo)
    }
    
    @IBAction func copyAddressTapped(_ sender: Any) {
        delegate.copyAddress(utxo)
    }
    
    @IBAction func copyTxidTapped(_ sender: Any) {
        delegate.copyTxid(utxo)
    }
    
    @IBAction func copyDescriptorTapped(_ sender: Any) {
        delegate.copyDesc(utxo)
    }
    
    @IBAction func editLabelTapped(_ sender: Any) {
        delegate.editLabel(utxo)
    }
    
    @IBAction func getAddressInfoTapped(_ sender: Any) {
        delegate.getAddressInfo(utxo)
    }
    
    @IBAction func getTxInfoTapped(_ sender: Any) {
        delegate.getTxInfo(utxo)
    }
    
    @IBAction func getDescInfoTapped(_ sender: Any) {
        delegate.getDescriptorInfo(utxo)
    }
    
    
    
}
