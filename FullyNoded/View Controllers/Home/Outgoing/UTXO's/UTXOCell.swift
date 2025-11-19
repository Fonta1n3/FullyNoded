//
//  UTXOCell.swift
//  FullyNoded
//
//  Created by FeedMyTummy on 9/16/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

protocol UTXOCellDelegate: AnyObject {
    func didTapToLock(_ utxo: UTXO)
    func didTapToSpendUtxo(_ utxo: UTXO)
    func copyAddress(_ utxo: UTXO)
    func copyTxid(_ utxo: UTXO)
    func copyDesc(_ utxo: UTXO)
    func editLabel(_ utxo: UTXO)
    func getAddressInfo(_ utxo: UTXO)
    func getTxInfo(_ utxo: UTXO)
    func getDescriptorInfo(_ utxo: UTXO)
    func showUtxoRawData(_ utxo: UTXO)
}

class UTXOCell: UITableViewCell {
    
    static let identifier = "UTXOCell"
    private var utxo: UTXO!
    private var isLocked: Bool!
    private unowned var delegate: UTXOCellDelegate!
    
    
    @IBOutlet weak var spendUtxoButtonOutlet: UIButton!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var checkMarkImageView: UIImageView!
    @IBOutlet weak var confirmationsLabel: UILabel!
    @IBOutlet weak var solvableLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var labelOutlet: UILabel!
    @IBOutlet weak var reusedLabel: UILabel!
    @IBOutlet weak var reusedImageView: UIImageView!
    @IBOutlet weak var changeLabel: UILabel!
    @IBOutlet weak var dustLabel: UILabel!
    @IBOutlet weak var confsIcon: UIImageView!
    @IBOutlet weak var descriptorLabel: UILabel!
    @IBOutlet weak var txidLabel: UILabel!
    @IBOutlet weak var voutLabel: UILabel!
    @IBOutlet weak var isChangeImageView: UIImageView!
    @IBOutlet weak var lockButtonOutlet: UIButton!
    @IBOutlet weak var isDustImageView: UIImageView!
    @IBOutlet weak var isSolvableImageView: UIImageView!
    @IBOutlet weak var fiatAmount: UILabel!
    
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        selectionStyle = .none
    }
    
    func configure(wallet: Wallet?, utxo: UTXO, isLocked: Bool, fxRate: Double?, delegate: UTXOCellDelegate) {
        self.utxo = utxo
        self.isLocked = isLocked
        self.delegate = delegate
                
        labelOutlet.text = utxo.label?.isEmpty ?? true ? "No label" : utxo.label!
        
        if isLocked {
            lockButtonOutlet.setImage(UIImage(systemName: "lock"), for: .normal)
        } else {
            lockButtonOutlet.setImage(UIImage(systemName: "lock.open"), for: .normal)
        }
        
        if let reused = utxo.reused {
            if reused {
                reusedImageView.image = UIImage(systemName: "shield.slash")
                reusedImageView.tintColor = .systemOrange
                reusedLabel.text = "Address reused!"
            } else {
                reusedImageView.image = UIImage(systemName: "shield")
                reusedImageView.tintColor = .none
                reusedLabel.text = "Used once"
            }
        } else {
            reusedImageView.image = UIImage(systemName: "questionmark")
        }
        
        if let desc = utxo.desc {
            if desc.contains("/1/") {
                isChangeImageView.image = UIImage(systemName: "arrow.2.circlepath")
                isChangeImageView.tintColor = .none
                changeLabel.text = "Change address"
            } else {
                isChangeImageView.image = UIImage(systemName: "arrow.down.left")
                isChangeImageView.tintColor = .none
                changeLabel.text = "Receive address"
            }
            
        } else {
            isChangeImageView.image = UIImage(systemName: "questionmark")
            changeLabel.text = "Unknown address type"
        }
        
        amountLabel.text = utxo.btcAmount
        
        if let fxRate = fxRate {
            let doubleValue = NSDecimalNumber(decimal: utxo.amount).doubleValue
            fiatAmount.text = (doubleValue * fxRate).fiatString
        }
            
        if utxo.amount <= 0.00010000 {
            isDustImageView.image = UIImage(systemName: "exclamationmark.triangle")
            isDustImageView.tintColor = .systemRed
            dustLabel.text = "Dust amount!"
        } else {
            isDustImageView.image = UIImage(systemName: "checkmark")
            isDustImageView.tintColor = .none
            dustLabel.text = "Not dust"
        }
        
        var walletLabel = UserDefaults.standard.object(forKey: "walletName") as! String
        
        if let wallet = wallet {
            walletLabel = wallet.label
        }
                
        if utxo.solvable {
            solvableLabel.text = "Owned by \(walletLabel)"
            isSolvableImageView.tintColor = .none
            isSolvableImageView.image = UIImage(systemName: "person.crop.circle.fill.badge.checkmark")
        } else {
            solvableLabel.text = "Not owned by \(walletLabel)!"
            isSolvableImageView.tintColor = .systemRed
            isSolvableImageView.image = UIImage(systemName: "person.crop.circle.badge.xmark")
        }
        
        if Int(utxo.confirmations) == 0 {
            confsIcon.tintColor = .systemRed
        } else {
            confsIcon.tintColor = .none
        }
            
        confirmationsLabel.text = "\(utxo.confirmations) confirmations"
        
        if let desc = utxo.desc {
            descriptorLabel.text = desc
        }
        
        if let address = utxo.address {
            addressLabel.text = address
        }
        
        txidLabel.text = utxo.txid
        voutLabel.text = "\(utxo.vout)"
        
        self.translatesAutoresizingMaskIntoConstraints = true
        self.sizeToFit()
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
    
    @IBAction func showUtxoRawData(_ sender: Any) {
        delegate.showUtxoRawData(utxo)
    }
    
    
}
