//
//  VerifyTransactionViewController+Cells.swift
//  FullyNoded
//
//  The verifier's table: data source, one builder per row type, and the cell classes.
//

import UIKit

extension VerifyTransactionViewController {

    func defaultCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = verifyTable.dequeueReusableCell(withIdentifier: "defaultCell", for: indexPath)
        configureCell(cell)
        
        let addButton = cell.viewWithTag(2) as! UIButton
        addButton.addTarget(self, action: #selector(tapToAdd(_:)), for: .touchUpInside)
        
        return cell
    }

    func confsCell(_ indexPath: IndexPath) -> UITableViewCell {
        let confsCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        configureCell(confsCell)
        
        let label = confsCell.viewWithTag(1) as! UILabel
        let imageView = confsCell.viewWithTag(2) as! UIImageView
        imageView.tintColor = .tintColor
        label.text = "\(confs) confirmations"
        label.textColor = .label
        
        disableSendButton()
        
        if confs > 0 {
            imageView.tintColor = .systemGreen
            imageView.image = UIImage(systemName: "checkmark.seal")
        } else {
            imageView.tintColor = .systemRed
            imageView.image = UIImage(systemName: "exclamationmark.triangle")
        }
        return confsCell
    }

    func mempoolAcceptCell(_ indexPath: IndexPath) -> UITableViewCell {
        let mempoolAcceptCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        configureCell(mempoolAcceptCell)
        
        let label = mempoolAcceptCell.viewWithTag(1) as! UILabel
        let imageView = mempoolAcceptCell.viewWithTag(2) as! UIImageView
        imageView.tintColor = .tintColor
        
        if txValid != nil {
            if txValid! {
                label.text = "Mempool acception verified ✓"
                imageView.tintColor = .systemGreen
                imageView.image = UIImage(systemName: "checkmark.seal")
                enableSendButton()
            } else {
                label.text = "Transaction invalid! Reason: \(rejectionMessage)."
                imageView.tintColor = .systemRed
                imageView.image = UIImage(systemName: "exclamationmark.triangle")
                disableSendButton()
            }
        } else {
            if unsignedPsbt != "" {
                label.text = "Transaction incomplete."
                disableSendButton()
            } else {
                if signedRawTx != "" {
                    label.text = "Transaction complete."
                    enableSendButton()
                } else {
                    let version = UserDefaults.standard.object(forKey: "version") as? String ?? "0.20"
                    
                    if version.contains("0.1") {
                        label.text = "This feature requires at least Bitcoin Core 0.20.0"
                    } else {
                        label.text = "There was an issue verifying your tx with mempoolaccept."
                    }
                }
            }
            
            imageView.tintColor = .systemOrange
            imageView.image = UIImage(systemName: "exclamationmark.triangle")
        }
        
        mempoolAcceptCell.selectionStyle = .none
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        return mempoolAcceptCell
    }

    func txidCell(_ indexPath: IndexPath) -> UITableViewCell {
        let txidCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        configureCell(txidCell)
        
        let txidLabel = txidCell.viewWithTag(1) as! UILabel
        let imageView = txidCell.viewWithTag(2) as! UIImageView
        imageView.tintColor = .tintColor
        imageView.image = UIImage(systemName: "rectangle.and.paperclip")
        txidLabel.text = txid
        txidCell.selectionStyle = .none
        txidLabel.textColor = .label
        txidLabel.adjustsFontSizeToFitWidth = true
        return txidCell
    }

    func inputCell(_ indexPath: IndexPath) -> UITableViewCell {
        let inputCell = verifyTable.dequeueReusableCell(withIdentifier: "inputCell", for: indexPath)
        configureCell(inputCell)
        
        let inputIndexLabel = inputCell.viewWithTag(1) as! UILabel
        let inputAmountLabel = inputCell.viewWithTag(2) as! UILabel
        let inputAddressLabel = inputCell.viewWithTag(3) as! UILabel
        let inputIsOursImage = inputCell.viewWithTag(4) as! UIImageView
        let inputIsOursLabel = inputCell.viewWithTag(5) as! UILabel
        let inputTypeLabel = inputCell.viewWithTag(6) as! UILabel
        let utxoLabel = inputCell.viewWithTag(7) as! UILabel
        let isChangeImageView = inputCell.viewWithTag(8) as! UIImageView
        let isDustImageView = inputCell.viewWithTag(10) as! UIImageView
        let signaturesLabel = inputCell.viewWithTag(14) as! UILabel
        let descTextView = inputCell.viewWithTag(15) as! UITextView
        let sigsImageView = inputCell.viewWithTag(17) as! UIImageView
        let copyAddressButton = inputCell.viewWithTag(18) as! UIButton
        let copyDescButton = inputCell.viewWithTag(19) as! UIButton
        let addressQrButton = inputCell.viewWithTag(20) as! UIButton
        let getAddressInfoButton = inputCell.viewWithTag(21) as! UIButton
        let signButton = inputCell.viewWithTag(22) as! UIButton
        let dustLabel = inputCell.viewWithTag(VerifyCellTag.dustLabel) as? UILabel
        let signableImageView = inputCell.viewWithTag(VerifyCellTag.inputSignableImage) as? UIImageView
        let signerLabel = inputCell.viewWithTag(VerifyCellTag.inputSignerLabel) as? UILabel

        isDustImageView.tintColor = .tintColor
        isChangeImageView.tintColor = .tintColor
        inputIsOursImage.tintColor = .tintColor
        sigsImageView.tintColor = .tintColor
        descTextView.clipsToBounds = true
        descTextView.layer.cornerRadius = 8
        descTextView.layer.borderWidth = 0.5
        descTextView.layer.borderColor = UIColor.darkGray.cgColor
        utxoLabel.textColor = .label
        descTextView.textColor = .label
        inputAddressLabel.textColor = .label
        
        if indexPath.row < inputTableArray.count {
            let input = inputTableArray[indexPath.row]
            
            let isOurs = input["isOurs"] as? Bool ?? false
            let isChange = input["isChange"] as? Bool ?? false
            let label = input["label"] as? String ?? "No label."
            let isDust = input["isDust"] as? Bool ?? false
            let signatureStatus = input["signatures"] as? String ?? "No signature data."
            let desc = input["desc"] as? String ?? "No descriptor."
            let inputAddress = input["address"] as! String
            let parentDesc = input["parent_desc"] as? String
            
            let sigsRequired = input["sigsRequired"] as? Int ?? 0
            let sigsPresent = input["sigsPresent"] as? Int ?? 0
            let sigsRemaining = input["sigsRemaining"] as? Int ?? 0
            
            if signedRawTx == "" {
                if let parentDesc = parentDesc {
                    if let _ = input["signatures"] as? String {
                        let fnDesc = Descriptor(parentDesc)
                        if fnDesc.isMulti {
                            signButton.alpha = 1
                        } else {
                            signButton.alpha = 0
                        }
                    } else {
                        signButton.alpha = 1
                    }
                } else {
                    signButton.alpha = 0
                }
            } else {
                signButton.alpha = 0
            }
            signButton.isHidden = signButton.alpha < 0.01
            // Disabled only when we know no signer on this device can sign it.
            signButton.isEnabled = (input["canSign"] as? Bool) != false
            
            renderInputSigner(input, imageView: signableImageView, label: signerLabel)
            
            utxoLabel.text = label
            descTextView.text = desc
            sigsImageView.image = UIImage(systemName: "signature")
            
            inputIndexLabel.text = "Input #\(input["index"] as! Int)"
            inputAmountLabel.text = "\((input["amount"] as! String))"
            inputAddressLabel.text = inputAddress.addressExpanded
            
            copyAddressButton.restorationIdentifier = inputAddress
            copyDescButton.restorationIdentifier = desc
            addressQrButton.restorationIdentifier = inputAddress
            getAddressInfoButton.restorationIdentifier = inputAddress
            signButton.restorationIdentifier = parentDesc
            
            
            copyAddressButton.addTarget(self, action: #selector(copyAddress(_:)), for: .touchUpInside)
            copyDescButton.addTarget(self, action: #selector(copyDesc(_:)), for: .touchUpInside)
            addressQrButton.addTarget(self, action: #selector(showAddressQr(_:)), for: .touchUpInside)
            getAddressInfoButton.addTarget(self, action: #selector(showAddressInfo(_:)), for: .touchUpInside)
            signButton.addTarget(self, action: #selector(signInputAction(_:)), for:     .touchUpInside)
            
            if signatureStatus == "Signatures complete" {
                signaturesLabel.text = "Signatures complete."
                sigsImageView.tintColor = .green
                
            } else {
                signaturesLabel.text = "\(sigsPresent)/\(sigsRequired) signatures → \(sigsRemaining) more needed"
                
                if sigsRemaining == 0 {
                    signaturesLabel.text = "Signatures complete."
                    sigsImageView.tintColor = .green
                } else if sigsPresent < sigsRequired {
                    sigsImageView.tintColor = .systemOrange
                } else {
                    sigsImageView.tintColor = .systemRed
                }
            }
            
            Self.renderDust(isDust, kind: "input", imageView: isDustImageView, label: dustLabel)
            
            if isChange {
                isChangeImageView.image = UIImage(systemName: "arrow.triangle.2.circlepath")
                isChangeImageView.tintColor = .systemPurple
                inputTypeLabel.text = "Change input"
            } else {
                isChangeImageView.image = UIImage(systemName: "arrow.down.left")
                isChangeImageView.tintColor = .tintColor
                inputTypeLabel.text = "Receive input"
            }
            
            if isOurs {
                inputIsOursImage.image = UIImage(systemName: "checkmark.circle")
                inputIsOursImage.tintColor = .tintColor
                
                if let walletLabel = wallet?.label {
                    inputIsOursLabel.text = "Owned by \(walletLabel)."
                } else {
                    inputIsOursLabel.text = "Owned by the Active Wallet."
                }
                
            } else {
                inputTypeLabel.text = "Unknown type."
                //backgroundView2.backgroundColor = .systemGray
                //backgroundView1.backgroundColor = .systemGray
                inputIsOursImage.image = UIImage(systemName: "questionmark.circle")
                isChangeImageView.image = UIImage(systemName: "questionmark.circle")
                inputIsOursImage.tintColor = .systemRed
                isChangeImageView.tintColor = .systemRed
                
                if let walletLabel = wallet?.label {
                    inputIsOursLabel.text = "Not owned by \(walletLabel)."
                    
                } else {
                    inputIsOursLabel.text = "Not owned by the Active Wallet."
                }
            }
        }
        
        return inputCell
    }

    func outputCell(_ indexPath: IndexPath) -> UITableViewCell {
        let outputCell = verifyTable.dequeueReusableCell(withIdentifier: "outputCell", for: indexPath)
        configureCell(outputCell)
        
        let outputIndexLabel = outputCell.viewWithTag(1) as! UILabel
        let outputAmountLabel = outputCell.viewWithTag(2) as! UILabel
        let outputAddressLabel = outputCell.viewWithTag(3) as! UILabel
        let outputIsOursImage = outputCell.viewWithTag(4) as! UIImageView
        let verifiedByFnImageView = outputCell.viewWithTag(6) as! UIImageView
        let labelLabel = outputCell.viewWithTag(7) as! UILabel
        let isChangeImageView = outputCell.viewWithTag(8) as! UIImageView
        let verifiedByFnLabel = outputCell.viewWithTag(9) as! UILabel
        let isDustImageView = outputCell.viewWithTag(10) as! UIImageView
        let descTextView = outputCell.viewWithTag(15) as! UITextView
        let signableImageView = outputCell.viewWithTag(17) as! UIImageView
        let signerLabel = outputCell.viewWithTag(18) as! UILabel
        let verifiedByNodeLabel = outputCell.viewWithTag(19) as! UILabel
        let addressTypeLabel = outputCell.viewWithTag(20) as! UILabel
        let copyAddressButton = outputCell.viewWithTag(21) as! UIButton
        let copyDescriptorButton = outputCell.viewWithTag(22) as! UIButton
        let verifyOwnerButton = outputCell.viewWithTag(23) as! UIButton
        let addressQrButton = outputCell.viewWithTag(24) as! UIButton
        let getAddressInfoButton = outputCell.viewWithTag(25) as! UIButton
        let dustLabel = outputCell.viewWithTag(VerifyCellTag.dustLabel) as? UILabel

        descTextView.layer.cornerRadius = 8
        descTextView.layer.borderWidth = 0.5
        descTextView.layer.borderColor = UIColor.darkGray.cgColor
        
        signableImageView.tintColor = .tintColor
        isDustImageView.tintColor = .tintColor
        isChangeImageView.tintColor = .tintColor
        outputIsOursImage.tintColor = .tintColor
        verifiedByFnImageView.tintColor = .tintColor
        
        outputAddressLabel.textColor = .label
                        
        if indexPath.row < outputArray.count {
            let output = outputArray[indexPath.row]
            
            let outputAddress = output["address"] as? String ?? ""
            let signable = output["signable"] as? Bool ?? false
            let signer =  output["signerLabel"] as? String ?? ""
            let walletLabel = output["walletLabel"] as? String ?? ""
            let isOursFullyNoded = output["isOursFullyNoded"] as? Bool ?? false
            let isOursBitcoind = output["isOursBitcoind"] as? Bool ?? false
            let isChange = output["isChange"] as? Bool ?? false
            let label = output["label"] as? String ?? "no label"
            let isDust = output["isDust"] as? Bool ?? false
            let desc = output["desc"] as? String ?? "no descriptor"
            
            labelLabel.text = label
            descTextView.text = desc
            
            outputIndexLabel.text = "Output #\(output["index"] as! Int)"
            outputAmountLabel.text = "\((output["amount"] as! String))"
            outputAddressLabel.text = outputAddress.addressExpanded
            
            copyAddressButton.restorationIdentifier = outputAddress
            verifyOwnerButton.restorationIdentifier = outputAddress + " " + "\(indexPath.row)"
            copyDescriptorButton.restorationIdentifier = desc
            addressQrButton.restorationIdentifier = outputAddress
            getAddressInfoButton.restorationIdentifier = outputAddress
            
            copyAddressButton.addTarget(self, action: #selector(copyAddress(_:)), for: .touchUpInside)
            copyDescriptorButton.addTarget(self, action: #selector(copyDesc(_:)), for: .touchUpInside)
            verifyOwnerButton.addTarget(self, action: #selector(verifyOwner(_:)), for: .touchUpInside)
            addressQrButton.addTarget(self, action: #selector(showAddressQr(_:)), for: .touchUpInside)
            getAddressInfoButton.addTarget(self, action: #selector(showAddressInfo(_:)), for: .touchUpInside)
            
            if isOursFullyNoded {
                verifiedByFnLabel.text = "Owned by \(walletLabel)."
                verifiedByFnImageView.image = UIImage(systemName: "checkmark.circle")
                verifiedByFnImageView.tintColor = .systemGreen
                //verifiedByFnBackgroundView.backgroundColor = .systemGreen
            } else {
                verifyOwnerButton.alpha = 1
                verifiedByFnLabel.text = "Not verified by Fully Noded."
                verifiedByFnImageView.image = UIImage(systemName: "questionmark.circle")
                verifiedByFnImageView.tintColor = .systemRed
                //verifiedByFnBackgroundView.backgroundColor = .systemGray
            }
            
            if signable {
                signableImageView.image = UIImage(systemName: "signature")
                //signableBackgroundView.backgroundColor = .systemGreen
                signerLabel.text = "Signable by \(signer)"
                signableImageView.tintColor = .systemGreen
            } else {
                signableImageView.image = UIImage(systemName: "signature")
                //signableBackgroundView.backgroundColor = .systemRed
                signerLabel.text = "Unable to determine."
                signableImageView.tintColor = .systemOrange
            }
            
            Self.renderDust(isDust, kind: "output", imageView: isDustImageView, label: dustLabel)
            
            if isChange {
                isChangeImageView.image = UIImage(systemName: "arrow.triangle.2.circlepath")
                isChangeImageView.tintColor = .systemPurple
                addressTypeLabel.text = "Change address."
            } else {
                isChangeImageView.image = UIImage(systemName: "arrow.up.right")
                isChangeImageView.tintColor = .tintColor
                addressTypeLabel.text = "Receive address."
            }
            
            var activeWalletLabel = "Bitcoin Core"
            
            if self.wallet != nil {
                activeWalletLabel = self.wallet!.label
            }
            
            if isOursBitcoind {
                verifyOwnerButton.alpha = 0
                verifiedByNodeLabel.text = "Owned by Bitcoin Core."
                outputIsOursImage.tintColor = .systemGreen
                outputIsOursImage.image = UIImage(systemName: "checkmark.circle")
                
                if self.wallet != nil {
                    let ds = Descriptor(self.wallet!.receiveDescriptor)
                    if ds.isHot {
                        signableImageView.image = UIImage(systemName: "checkmark.square")
                        signableImageView.tintColor = .systemGreen
                        signerLabel.text = "Bitcoin Core hot wallet."
                    }
                }
                
            } else {
                verifyOwnerButton.alpha = 1
                verifiedByNodeLabel.text = "Not owned by \(activeWalletLabel)."
                outputIsOursImage.tintColor = .systemOrange
                outputIsOursImage.image = UIImage(systemName: "questionmark.circle")
                
                isChangeImageView.image = UIImage(systemName: "questionmark.circle")
                isChangeImageView.tintColor = .systemOrange
                addressTypeLabel.text = "Address type unknown."
            }

            // The node says this output is our change, but Fully Noded couldn't derive the
            // address from the wallet's descriptors: treat it as someone else's output.
            if output["changeUnverified"] as? Bool ?? false {
                isChangeImageView.image = UIImage(systemName: "exclamationmark.triangle")
                isChangeImageView.tintColor = .systemRed
                addressTypeLabel.text = "Node says change, but Fully Noded couldn't verify it. Don't sign unless you recognize this address."
            }
            
            verifyOwnerButton.isHidden = verifyOwnerButton.alpha < 0.01
        }
        
        return outputCell
    }

    static func renderDust(_ isDust: Bool, kind: String, imageView: UIImageView, label: UILabel?) {
        imageView.image = UIImage(systemName: isDust ? "exclamationmark.circle" : "checkmark.circle")
        imageView.tintColor = isDust ? .systemRed : .tintColor
        label?.text = isDust ? "Dust \(kind) (under 20,000 sats)." : "Not dust."
    }

    /// Fills an input cell's "signable" row.
    func renderInputSigner(_ input: [String: Any], imageView: UIImageView?, label: UILabel?) {
        imageView?.image = UIImage(systemName: "signature")

        guard let signers = input["signers"] as? [String] else {
            imageView?.tintColor = .systemGray
            label?.text = "Checking signers…"
            return
        }

        let fingerprints = input["fingerprints"] as? [String] ?? []

        if !signers.isEmpty {
            var text = "Signable by " + signers.joined(separator: ", ")
            if input["isSilentPayment"] as? Bool ?? false {
                text += " (silent payment)"
            } else if fingerprints.count > 1 {
                text += " (\(input["matchedKeys"] as? Int ?? signers.count) of \(fingerprints.count) keys)"
            }
            imageView?.tintColor = .systemGreen
            label?.text = text
        } else if input["hotWallet"] as? Bool ?? false {
            imageView?.image = UIImage(systemName: "checkmark.square")
            imageView?.tintColor = .systemGreen
            label?.text = "Bitcoin Core hot wallet."
        } else if !fingerprints.isEmpty {
            imageView?.tintColor = .systemOrange
            label?.text = "No signer on this device for " + fingerprints.map { "[\($0)]" }.joined(separator: ", ") + "."
        } else {
            imageView?.tintColor = .systemOrange
            label?.text = "Unable to determine."
        }
    }

    func miningFeeCell(_ indexPath: IndexPath) -> UITableViewCell {
        let miningFeeCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        miningFeeCell.selectionStyle = .none
        configureCell(miningFeeCell)
        
        let miningLabel = miningFeeCell.viewWithTag(1) as! UILabel
        miningLabel.textColor = .label
        
        let imageView = miningFeeCell.viewWithTag(2) as! UIImageView
        imageView.tintColor = .white
        
        if inputTotal > 0.0 {
            if txFee < 0.0 {
                imageView.tintColor = .systemOrange
                imageView.image = UIImage(systemName: "questionmark.circle")
                miningLabel.text = "Can not determine fee for inputs which don't belong to us."
                
            } else if txFee < 0.00050000 {
                imageView.tintColor = .systemGreen
                imageView.image = UIImage(systemName: "checkmark.circle")
                miningLabel.text = miningFee + " / \(satsPerByte()) sats per byte"
                
            } else {
                imageView.tintColor = .systemRed
                imageView.image = UIImage(systemName: "exclamationmark.triangle")
                miningLabel.text = miningFee + " / \(satsPerByte()) sats per byte"
            }
        } else {
            imageView.tintColor = .systemOrange
            imageView.image = UIImage(systemName: "questionmark.circle")
            miningLabel.text = miningFee
        }
        
        return miningFeeCell
    }

    func etaCell(_ indexPath: IndexPath) -> UITableViewCell {
        let etaCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        etaCell.selectionStyle = .none
        configureCell(etaCell)
        
        let etaLabel = etaCell.viewWithTag(1) as! UILabel
        etaLabel.textColor = .label
        
        let imageView = etaCell.viewWithTag(2) as! UIImageView
        imageView.tintColor = .white
        
        var feeWarning = ""
        
        if txFee > 0.0 {
            let percentage = (satsPerByte() / smartFee) * 100
            let rounded = Double(round(10*percentage)/10)
            
            if satsPerByte() > smartFee, rounded.isFinite {
                feeWarning = "The fee paid for this transaction is \(Int(rounded - 100))% greater then your target."
            } else if rounded.isFinite {
                feeWarning = "The fee paid for this transaction is \(Int(100 - rounded))% less then your target."
            } else {
                feeWarning = "Unable to determine fee difference."
            }
            
            if percentage >= 90 && percentage <= 110 {
                imageView.tintColor = .systemGreen
                imageView.image = UIImage(systemName: "checkmark.circle")
                etaLabel.text = "Fee is on target for a confirmation in approximately \(eta()) or \(feeTarget()) blocks."
            } else {
                if percentage <= 90 {
                    imageView.tintColor = .systemRed
                    imageView.image = UIImage(systemName: "tortoise")
                    etaLabel.text = feeWarning
                } else {
                    imageView.tintColor = .systemRed
                    imageView.image = UIImage(systemName: "hare")
                    etaLabel.text = feeWarning
                }
            }
        } else {
            imageView.image = UIImage(systemName: "questionmark.circle")
            imageView.tintColor = .systemOrange
            etaLabel.text = "No fee data."
        }
        
        return etaCell
    }

    func transactionLabelCell(_ indexPath: IndexPath) -> UITableViewCell {
        let labelCell = verifyTable.dequeueReusableCell(withIdentifier: "memoLabelCell", for: indexPath)
        configureCell(labelCell)
        let label = labelCell.viewWithTag(1) as! UILabel
        let button = labelCell.viewWithTag(2) as! UIButton
        button.addTarget(self, action: #selector(updateLabelMemoAction), for: .touchUpInside)
        //button.showsTouchWhenHighlighted = true
        label.text = labelText
        label.textColor = .label
        return labelCell
    }

    func configureView(_ view: UIView) {
        view.clipsToBounds = true
        view.layer.cornerRadius = WalletTheme.radius
        view.layer.borderColor = WalletTheme.Tint.transaction.line.cgColor
        view.layer.borderWidth = 1
    }

    func configureCell(_ cell: UITableViewCell) {
        cell.selectionStyle = .none
        configureView(cell)
    }

    func satsPerByte() -> Double {
        let satsPerByte = (txFee * 100000000.0) / Double(txSize)
        return Double(round(10*satsPerByte)/10)
    }

    func feeTarget() -> Int {
        let ud = UserDefaults.standard
        return ud.object(forKey: "feeTarget") as? Int ?? 432
    }

    func eta() -> String {
        var eta = ""
        let seconds = ((feeTarget() * 10) * 60)
        
        if seconds < 86400 {
            
            if seconds < 3600 {
                eta = "\(seconds / 60) minutes"
                
            } else {
                eta = "\(seconds / 3600) hours"
            }
            
        } else {
            eta = "\(seconds / 86400) days"
        }
        
        let todaysDate = Date()
        let futureDate = Date(timeInterval: Double(seconds), since: todaysDate)
        eta += " on \(formattedDate(date: futureDate))"
        return eta
    }

    func formattedDate(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MMM-dd hh:mm"
        let strDate = dateFormatter.string(from: date)
        return strDate
    }
}

extension VerifyTransactionViewController: UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if unsignedPsbt == "" && signedRawTx == "" {
            return 1
        } else {
            return 7
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if unsignedPsbt == "" && signedRawTx == "" {
            return 1
        } else {
            switch section {
            case 3:
                return inputArray.count
                
            case 4:
                return outputArray.count
                
            case 0, 1, 5, 2, 6:
                return 1
                
            default:
                return 0
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Programmatic cells size themselves (Auto Layout).
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard inputTableArray.count > 0 && outputArray.count > 0 else {
            return defaultCell(indexPath)
        }
        
        tableView.separatorColor = .none
        
        switch indexPath.section {
            
        case 0:
            return transactionLabelCell(indexPath)
            
        case 1:
            if !alreadyBroadcast {
                return mempoolAcceptCell(indexPath)
            } else {
                return confsCell(indexPath)
            }
            
        case 2:
            return txidCell(indexPath)
            
        case 3:
            return inputCell(indexPath)
            
        case 4:
            return outputCell(indexPath)
            
        case 5:
            return miningFeeCell(indexPath)
            
        case 6:
            return etaCell(indexPath)
            
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .secondaryLabel
        textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
        
        if unsignedPsbt == "" && signedRawTx == "" {
            textLabel.text = ""
        } else {
            switch section {
            case 0:
                textLabel.text = "Label"
                textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
                
            case 1:
                if !alreadyBroadcast {
                    textLabel.text = "Mempool accept"
                } else {
                    textLabel.text = "Confirmations"
                }
                textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
                
            case 2:
                textLabel.text = "Transaction ID"
                let copyButton = UIButton()
                let copyImage = UIImage(systemName: "doc.on.doc")!
                copyButton.tintColor = .systemBlue
                copyButton.setImage(copyImage, for: .normal)
                copyButton.addTarget(self, action: #selector(copyTxid), for: .touchUpInside)
                copyButton.frame = CGRect(x: header.frame.maxX - 70, y: 0, width: 50, height: 50)
                copyButton.center.y = textLabel.center.y
                header.addSubview(copyButton)
                                
            case 3:
                textLabel.text = "Inputs"
                textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
                                
            case 4:
                textLabel.text = "Outputs"
                textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
                
            case 5:
                textLabel.text = "Mining fee"
                textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
            
            case 6:
                textLabel.text = "Estimated time to confirm"
                textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
                                
            default:
                break
            }
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
}

extension VerifyTransactionViewController: UITableViewDataSource {}

// MARK: - Theme

extension VerifyTransactionViewController {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        WalletTheme.styleCell(cell, in: tableView, tint: .transaction)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        WalletTheme.styleHeader(view, tint: .transaction)
    }
}

// MARK: - Programmatic cells
//
// The cells keep the view tags the storyboard prototypes used, so the cell builders above
// look their subviews up exactly as before. New: tag 30 (dust text) on inputs and outputs,
// and tags 31 / 32 (signable icon / signer text) on inputs.

enum VerifyCellTag {
    static let dustLabel = 30
    static let inputSignableImage = 31
    static let inputSignerLabel = 32
}

private enum VerifyCellKit {
    static func label(_ tag: Int, size: CGFloat = 13, weight: UIFont.Weight = .regular, color: UIColor = WalletTheme.text, lines: Int = 0) -> UILabel {
        let label = UILabel()
        label.tag = tag
        label.font = WalletTheme.mono(size, weight: weight)
        label.textColor = color
        label.numberOfLines = lines
        label.adjustsFontForContentSizeCategory = false
        return label
    }

    static func caption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = WalletTheme.mono(11, weight: .bold)
        label.textColor = WalletTheme.dim
        return label
    }

    static func icon(_ tag: Int) -> UIImageView {
        let imageView = UIImageView()
        imageView.tag = tag
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = WalletTheme.Tint.transaction.accent
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 22),
            imageView.heightAnchor.constraint(equalToConstant: 22)
        ])
        return imageView
    }

    /// Borderless icon button (empty title, so the theme keeps it an icon).
    static func iconButton(_ tag: Int, systemName: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: systemName,
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
        config.contentInsets = .zero
        config.baseForegroundColor = WalletTheme.Tint.transaction.accent
        let button = UIButton(configuration: config)
        button.tag = tag
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 34),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
        return button
    }

    /// Small bordered text button ("Sign", "verify owner", "edit").
    static func textButton(_ tag: Int, title: String, systemImage: String? = nil) -> UIButton {
        let config = WalletTheme.chipConfiguration(title: title,
                                                   systemImage: systemImage,
                                                   tint: .transaction,
                                                   fontSize: 12,
                                                   imageSize: 11,
                                                   imagePadding: 5,
                                                   insets: NSDirectionalEdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9))
        let button = UIButton(configuration: config)
        button.tag = tag
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    static func hStack(_ views: [UIView], spacing: CGFloat = 8, alignment: UIStackView.Alignment = .center) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.spacing = spacing
        stack.alignment = alignment
        return stack
    }

    static func spacer() -> UIView {
        let view = UIView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    /// Icon + wrapping text, optionally with a trailing control.
    static func statusRow(icon: UIImageView, label: UILabel, trailing: UIView? = nil) -> UIStackView {
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        var views: [UIView] = [icon, label]
        if let trailing = trailing { views.append(trailing) }
        return hStack(views, spacing: 10, alignment: .center)
    }

    /// Caption on the left, icon buttons on the right.
    static func captionRow(_ text: String, buttons: [UIButton]) -> UIStackView {
        let leading: [UIView] = [caption(text), spacer()]
        let row = hStack(leading + buttons.map { $0 as UIView }, spacing: 4)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        return row
    }

    static func hairline() -> UIView {
        // Drawn as a 1pt border, not a background colour: the theme walker turns coloured
        // views it sees before layout (zero size) into cards.
        let line = UIView()
        line.layer.borderWidth = 1
        line.layer.borderColor = WalletTheme.Tint.transaction.line.cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    static func descriptorView(_ tag: Int) -> UITextView {
        let textView = UITextView()
        textView.tag = tag
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.font = WalletTheme.mono(11)
        textView.textColor = WalletTheme.text
        textView.backgroundColor = WalletTheme.card
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        textView.layer.borderWidth = 1
        textView.layer.borderColor = WalletTheme.Tint.transaction.line.cgColor
        return textView
    }

    /// Pins a vertical stack inside the cell's content view (clear of the card's 4pt inset).
    static func install(_ views: [UIView], in cell: UITableViewCell, spacing: CGFloat = 8) {
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(stack)
        let bottom = stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -16)
        bottom.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            bottom
        ])
    }
}

/// One transaction input: amount, address, ownership, signatures, who can sign it, descriptor.
final class VerifyInputCell: UITableViewCell {
    static let reuseId = "inputCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        typealias K = VerifyCellKit

        let indexLabel = K.label(1, size: 14, weight: .bold, color: WalletTheme.Tint.transaction.accent, lines: 1)
        let amountLabel = K.label(2, size: 14, weight: .semibold)
        amountLabel.textAlignment = .right
        indexLabel.setContentHuggingPriority(.required, for: .horizontal)
        indexLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let topRow = K.hStack([indexLabel, amountLabel], spacing: 12, alignment: .firstBaseline)

        let signButton = K.textButton(22, title: "Sign", systemImage: "signature")

        K.install([
            topRow,
            K.hairline(),
            K.captionRow("ADDRESS", buttons: [K.iconButton(18, systemName: "doc.on.doc"),
                                              K.iconButton(20, systemName: "qrcode"),
                                              K.iconButton(21, systemName: "info.circle")]),
            K.label(3, size: 13),
            K.caption("UTXO LABEL"),
            K.label(7, size: 13),
            K.hairline(),
            K.statusRow(icon: K.icon(4), label: K.label(5)),
            K.statusRow(icon: K.icon(8), label: K.label(6)),
            K.statusRow(icon: K.icon(10), label: K.label(VerifyCellTag.dustLabel)),
            K.statusRow(icon: K.icon(17), label: K.label(14), trailing: signButton),
            K.statusRow(icon: K.icon(VerifyCellTag.inputSignableImage), label: K.label(VerifyCellTag.inputSignerLabel)),
            K.hairline(),
            K.captionRow("DESCRIPTOR", buttons: [K.iconButton(19, systemName: "doc.on.doc")]),
            K.descriptorView(15)
        ], in: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// One transaction output: amount, address, who owns it, who can sign for it, descriptor.
final class VerifyOutputCell: UITableViewCell {
    static let reuseId = "outputCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        typealias K = VerifyCellKit

        let indexLabel = K.label(1, size: 14, weight: .bold, color: WalletTheme.Tint.transaction.accent, lines: 1)
        let amountLabel = K.label(2, size: 14, weight: .semibold)
        amountLabel.textAlignment = .right
        indexLabel.setContentHuggingPriority(.required, for: .horizontal)
        indexLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let topRow = K.hStack([indexLabel, amountLabel], spacing: 12, alignment: .firstBaseline)

        K.install([
            topRow,
            K.hairline(),
            K.captionRow("ADDRESS", buttons: [K.iconButton(21, systemName: "doc.on.doc"),
                                              K.iconButton(24, systemName: "qrcode"),
                                              K.iconButton(25, systemName: "info.circle")]),
            K.label(3, size: 13),
            K.caption("UTXO LABEL"),
            K.label(7, size: 13),
            K.hairline(),
            K.statusRow(icon: K.icon(6), label: K.label(9)),
            K.statusRow(icon: K.icon(4), label: K.label(19), trailing: K.textButton(23, title: "verify owner")),
            K.statusRow(icon: K.icon(8), label: K.label(20)),
            K.statusRow(icon: K.icon(10), label: K.label(VerifyCellTag.dustLabel)),
            K.statusRow(icon: K.icon(17), label: K.label(18)),
            K.hairline(),
            K.captionRow("DESCRIPTOR", buttons: [K.iconButton(22, systemName: "doc.on.doc")]),
            K.descriptorView(15)
        ], in: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Icon + text row (mempool accept, confirmations, txid, mining fee, eta).
final class VerifyStatusCell: UITableViewCell {
    static let reuseId = "miningFeeCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        typealias K = VerifyCellKit
        let row = K.statusRow(icon: K.icon(2), label: K.label(1, size: 13))
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        K.install([row], in: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Transaction label with an edit button.
final class VerifyMemoCell: UITableViewCell {
    static let reuseId = "memoLabelCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        typealias K = VerifyCellKit
        let label = K.label(1, size: 13)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = K.hStack([label, K.textButton(2, title: "edit", systemImage: "pencil")], spacing: 10)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        K.install([row], in: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Empty state: "Add a transaction" with a plus button.
final class VerifyAddCell: UITableViewCell {
    static let reuseId = "defaultCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        typealias K = VerifyCellKit
        let label = K.label(1, size: 14, lines: 1)
        label.text = "Add a transaction"
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = K.hStack([label, K.iconButton(2, systemName: "plus")], spacing: 10)
        K.install([row], in: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
