//
//  VerifyTransactionViewController+Signing.swift
//  FullyNoded
//
//  Signing inputs (normal and silent payment) and bumping the fee.
//

import UIKit

extension VerifyTransactionViewController {

    @objc func bumpFeeAction(_ sender: Any) {
        guard !isShowingActivity else { return }
        if confs == 0 && alreadyBroadcast {
            if UserDefaults.standard.object(forKey: "passphrasePrompt") == nil {
                self.bumpFee(nil)
            } else {
                self.setPassphrase { [weak self] passphrase in
                    guard let self = self else { return }
                    self.passphrase = passphrase
                    
                    self.bumpFee(passphrase)
                }
            }
        } else {
            showAlert(vc: self, title: "", message: "You can only bump the fee for transactions that have zero confirmations.")
        }
    }

    func setPassphrase(onCancel: (() -> Void)? = nil, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Passphrase Prompt"
            let message = "You enabled the passphrase prompt in Security Center, please enter the passphrase you want to use for signing this transaction."
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let set = UIAlertAction(title: "Sign now", style: .default) { alertAction in
                completion((alert.textFields![0] as UITextField).text)
            }
            
            alert.addTextField { textField in
                textField.keyboardAppearance = .dark
                textField.isSecureTextEntry = true
                textField.autocorrectionType = .no
                textField.spellCheckingType = .no
            }
            
            alert.addAction(set)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { alertAction in
                onCancel?()
            }
            alert.addAction(cancel)
            self.present(alert, animated: true, completion: nil)
        }
    }

    func signNow(passphrase: String?, parentDesc: String) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showActivity("signing...")
        }
        
        guard let wallet = wallet else {
            self.finishActivity()
            showAlert(vc: self, title: "", message: "Fully Noded can only sign transactions when using a Fully Noded wallet.")
            return
        }
        
        let checksumless = "\(parentDesc.split(separator: "#")[0])"
        #if DEBUG
        print("parentDesc: \(parentDesc)")
        print("checksumless: \(checksumless)")
        #endif
        
        Signer.shared.attemptToSignPsbt(fnWallet: wallet, psbt: unsignedPsbt, passphrase: passphrase, utxoParentDesc: checksumless) { [weak self] (signedPsbt, rawTx, errorMessage) in
            guard let self = self else { return }
            self.handleSigningResult(signedPsbt: signedPsbt, rawTx: rawTx, errorMessage: errorMessage)
        }
    }

    /// Shared result handling for every signing path (normal and silent payment).
    func handleSigningResult(signedPsbt: String?, rawTx: String?, errorMessage: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let rawTx = rawTx {
                self.finishActivity()
                SuccessView.show(
                    in: self,
                    title: "Transaction signed",
                    subtitle: "Ready to broadcast. The transaction reloads so you can check it first.",
                    onDismiss: { [weak self] in
                        guard let self = self else { return }
                        unsignedPsbt = ""
                        reset()
                        signedRawTx = rawTx
                        enableSendButton()
                        load()
                    }
                )
            } else if let signedPsbt = signedPsbt {
                reset()
                unsignedPsbt = signedPsbt
                load()
                
            } else {
                self.finishActivity()
                
                if let errorMessage = errorMessage {
                    showAlert(vc: self, title: "Error Signing", message: errorMessage)
                }
            }
        }
    }

    /// Sign, handling silent payment inputs.
    ///
    /// Silent payment inputs are found from the active wallet's own records
    /// (`SilentPaymentSpend.detect(candidates:)`): only bare-key taproot inputs it holds
    /// (FN-Server's imports) are considered, using the import label's scan key and tweak.
    /// - No silent payment inputs: the normal `signNow` path, unchanged.
    /// - Otherwise: SP inputs are signed with `SilentPaymentSpend` (tweaked key),
    ///   remaining inputs with the normal `Signer` (chained per parent descriptor), and
    ///   the node's `finalizepsbt` turns a complete PSBT into the raw transaction.
    func signWithSilentPaymentSupport(passphrase: String?, parentDesc: String) {
        self.showActivity("checking for silent payment inputs...")

        let psbtToSign = unsignedPsbt

        SilentPaymentSpend.detectInputs(psbt: psbtToSign, passphrase: passphrase, knownInfo: knownWalletInfo()) { [weak self] spOutputs in
            guard let self = self else { return }

            guard !spOutputs.isEmpty else {
                // No silent payment inputs: exactly the normal flow.
                self.finishActivity()
                self.signNow(passphrase: passphrase, parentDesc: parentDesc)
                return
            }

            self.showActivity("signing silent payment inputs...")

            SilentPaymentSpend.sign(psbt: psbtToSign, outputs: spOutputs, passphrase: passphrase) { [weak self] signedPsbt, _, errorMessage in
                guard let self = self else { return }

                guard let signedPsbt = signedPsbt else {
                    self.handleSigningResult(signedPsbt: nil, rawTx: nil, errorMessage: errorMessage ?? "Unable to sign the silent payment inputs.")
                    return
                }

                self.showActivity("signing...")
                self.signRemainingInputs(psbt: signedPsbt,
                                         parentDescs: self.parentDescs(excluding: spOutputs),
                                         passphrase: passphrase) { [weak self] psbt, rawTx, error in
                    self?.handleSigningResult(signedPsbt: psbt, rawTx: rawTx, errorMessage: error)
                }
            }
        }
    }

    /// Parent descriptors (no checksum, de-duplicated) of the inputs that are NOT
    /// silent payment outputs; those are signed by the normal Signer.
    func parentDescs(excluding spOutputs: [SilentPaymentSpend.OwnedOutput]) -> [String] {
        let spOutpoints = Set(spOutputs.map { "\($0.txid.lowercased()):\($0.vout)" })
        var parentDescs: [String] = []
        for input in inputTableArray {
            let outpoint = "\((input["txid"] as? String ?? "").lowercased()):\(input["vout"] as? Int ?? -1)"
            guard !spOutpoints.contains(outpoint),
                  let desc = input["parent_desc"] as? String, !desc.isEmpty else { continue }
            let checksumless = "\(desc.split(separator: "#")[0])"
            if !parentDescs.contains(checksumless) { parentDescs.append(checksumless) }
        }
        return parentDescs
    }

    /// Normal Signer for the non-silent-payment inputs, one parent descriptor at a time,
    /// each signing the previous result. Then finalize with the node.
    /// Completion: (psbt, rawTx, error) — rawTx if fully signed and finalized.
    func signRemainingInputs(psbt: String,
                                     parentDescs: [String],
                                     passphrase: String?,
                                     completion: @escaping (String?, String?, String?) -> Void) {
        guard let parentDesc = parentDescs.first else {
            finalizeWithNode(psbt, completion: completion)
            return
        }

        guard let wallet = wallet else {
            // SP inputs are signed; the others need a Fully Noded wallet to sign.
            finalizeWithNode(psbt, completion: completion)
            return
        }

        Signer.shared.attemptToSignPsbt(fnWallet: wallet, psbt: psbt, passphrase: passphrase, utxoParentDesc: parentDesc) { [weak self] signedPsbt, rawTx, _ in
            guard let self = self else { return }

            if let rawTx = rawTx {
                completion(nil, rawTx, nil)
                return
            }

            // Keep going with whatever we have (a signer error leaves the psbt unchanged).
            self.signRemainingInputs(psbt: signedPsbt ?? psbt,
                                     parentDescs: Array(parentDescs.dropFirst()),
                                     passphrase: passphrase,
                                     completion: completion)
        }
    }

    /// finalizepsbt on the node: raw tx if every input is signed, otherwise keep the
    /// partially signed PSBT so the remaining signatures can be added.
    func finalizeWithNode(_ psbt: String, completion: @escaping (String?, String?, String?) -> Void) {
        let param = Finalize_Psbt(["psbt": psbt])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .finalizepsbt(param)) { response, _ in
            let dict = response as? [String: Any]
            if let complete = dict?["complete"] as? Bool, complete, let hex = dict?["hex"] as? String {
                completion(nil, hex, nil)
            } else {
                completion(dict?["psbt"] as? String ?? psbt, nil, nil)
            }
        }
    }

    func bumpFee(_ passphrase: String?) {
        self.showActivity("increasing fee...", button: bumpFeeOutlet)
        let param_bump_fee = Bump_Fee(["txid":self.txid])
        let param_psbt_bump_fee = PSBT_Bump_Fee(["txid":self.txid])
        let bumpfee = BTC_CLI_COMMAND.bumpfee(param: param_bump_fee)
        let psbtBumpFee = BTC_CLI_COMMAND.psbtbumpfee(param: param_psbt_bump_fee)
        var command: BTC_CLI_COMMAND = bumpfee
        
        OnchainUtils.getWalletInfo { [weak self] (walletInfo, message) in
            guard let self = self else { return }
            
            guard let walletInfo = walletInfo else {
                self.showError(error: "Error getting wallet info: \(message ?? "unknown")")
                return
            }
            
            if let privkeysenabled = walletInfo.private_keys_enabled, !privkeysenabled,
                let version = UserDefaults.standard.object(forKey: "version") as? Int,
                version >= 210000 {
                command = psbtBumpFee
            }
            
            MakeRPCCall.sharedInstance.executeRPCCommand(method: command) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let result = response as? NSDictionary,
                        let originalFee = result["origfee"] as? Double,
                        let newFee = result["fee"] as? Double else {
                    self.finishActivity()
                    showAlert(vc: self, title: "There was an issue increasing the fee.", message: errorMessage ?? "unknown")
                    return
                }
                
                guard let psbt = result["psbt"] as? String else {
                    self.finishActivity()
                    if let txid = result["txid"] as? String {
                        self.saveNewTx(txid)
                        displayAlert(viewController: self, isError: false, message: "fee bumped from \(originalFee.avoidNotation) to \(newFee.avoidNotation)")
                    } else if let errors = result["errors"] as? NSArray {
                        showAlert(vc: self, title: "There was an error increasing the fee.", message: "\(errors)")
                    }
                    return
                }
                
                // BIP352: Core's bumpfee may ADD inputs to pay the higher fee, which
                // changes the shared secret and makes any silent payment output of the
                // original transaction unfindable. Check before signing anything.
                self.checkBumpKeepsSilentPaymentOutputs(bumpedPsbt: psbt, passphrase: passphrase) { [weak self] proceed in
                    guard let self = self else { return }
                    guard proceed else {
                        self.finishActivity()
                        return
                    }
                    self.signedRawTx = ""
                    self.signBumpedPsbt(psbt, passphrase: passphrase, newFee: newFee)
                }
            }
        }
    }

    /// Silent payment outputs are derived from the transaction's inputs (BIP352), so a
    /// replacement must keep exactly the same inputs. psbtbumpfee may add inputs when
    /// the change can't cover the new fee:
    /// - same inputs → proceed;
    /// - added / changed inputs and the original pays one of YOUR silent payment
    ///   addresses (e.g. your silent payment change) → refuse, it would be lost;
    /// - added / changed inputs and the original has other taproot outputs (which may
    ///   be silent payments to someone else; that can't be told from the outside) → ask.
    /// Completion on the main queue (true = go ahead).
    func checkBumpKeepsSilentPaymentOutputs(bumpedPsbt: String,
                                                    passphrase: String?,
                                                    completion: @escaping (Bool) -> Void) {
        let finish: (Bool) -> Void = { ok in DispatchQueue.main.async { completion(ok) } }
        
        // The original (unconfirmed) transaction, with witnesses / scriptSigs.
        let param = Get_Raw_Tx(["txid": txid, "verbosity": 1])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getrawtransaction(param: param)) { [weak self] response, _ in
            guard let self = self else { return }
            
            SilentPaymentChange.decode(bumpedPsbt) { [weak self] bumped, _ in
                guard let self = self else { return }
                
                guard let original = response as? [String: Any],
                      let origVin = original["vin"] as? [[String: Any]],
                      let origVout = original["vout"] as? [[String: Any]],
                      let bumped = bumped else {
                    // Can't compare: be safe and ask.
                    self.confirmBumpWithAddedInputs(finish)
                    return
                }
                
                let origOutpoints = origVin.compactMap { vin -> String? in
                    guard let id = vin["txid"] as? String, let n = (vin["vout"] as? NSNumber)?.intValue else { return nil }
                    return "\(id.lowercased()):\(n)"
                }
                let bumpedOutpoints = bumped.inputs.map { "\($0.txid.lowercased()):\($0.vout)" }
                
                // Same inputs: every silent payment output stays valid.
                guard Set(origOutpoints) != Set(bumpedOutpoints) || origOutpoints.count != bumpedOutpoints.count else {
                    finish(true)
                    return
                }
                
                // Taproot outputs of the original: only those can be silent payments.
                let taprootIndexes: [Int] = origVout.enumerated().compactMap { i, out in
                    let hex = ((out["scriptPubKey"] as? [String: Any])?["hex"] as? String ?? "").lowercased()
                    guard SPDetect.isP2TR(hex) else { return nil }
                    return (out["n"] as? NSNumber)?.intValue ?? i
                }
                guard !taprootIndexes.isEmpty else {
                    finish(true)
                    return
                }
                
                // Rebuild the original with prevouts (its inputs are all in the bumped
                // psbt, which carries their scripts) and run our receiver scan on it.
                let prevouts = Dictionary(bumped.inputs.map { ("\($0.txid.lowercased()):\($0.vout)", $0.script) },
                                          uniquingKeysWith: { first, _ in first })
                var fundingVin: [[String: Any]] = []
                for vin in origVin {
                    guard let id = vin["txid"] as? String, let n = (vin["vout"] as? NSNumber)?.intValue,
                          let script = prevouts["\(id.lowercased()):\(n)"] else {
                        self.confirmBumpWithAddedInputs(finish)
                        return
                    }
                    var entry = vin
                    entry["prevout"] = ["scriptPubKey": ["hex": script]]
                    fundingVin.append(entry)
                }
                let fundingTx: [String: Any] = ["vin": fundingVin, "vout": origVout]
                
                SilentPaymentSpend.scanKeyCandidates(passphrase: passphrase) { [weak self] keys in
                    guard let self = self else { return }
                    var keys = keys
                    let paysYou = taprootIndexes.contains { index in
                        keys.contains { SilentPaymentSpend.scan(fundingTx: fundingTx, txid: self.txid, vout: index, keys: $0) != nil }
                    }
                    for i in keys.indices { keys[i].bScan.secureZero() }
                    
                    if paysYou {
                        DispatchQueue.main.async {
                            showAlert(vc: self, title: "Fee not bumped",
                                      message: "Bitcoin Core would add inputs to pay the higher fee, but this transaction pays one of your silent payment addresses (e.g. your silent payment change). Silent payment outputs depend on the exact inputs, so that output would be lost. The original transaction is unchanged; you can speed it up with CPFP instead.")
                        }
                        finish(false)
                    } else {
                        self.confirmBumpWithAddedInputs(finish)
                    }
                }
            }
        }
    }

    func confirmBumpWithAddedInputs(_ completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.finishActivity()
            let alert = UIAlertController(
                title: "Bitcoin Core added inputs",
                message: "To pay the higher fee the replacement spends additional inputs. If this transaction pays a silent payment address (sp1…), that payment would become impossible for the recipient to find. Only continue if it doesn't.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Continue", style: .destructive) { _ in
                self.showActivity("signing...")
                completion(true)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(false) })
            self.present(alert, animated: true)
        }
    }

    /// Signs the PSBT returned by psbtbumpfee. Silent payment inputs (your received SP
    /// outputs) are detected and signed with SilentPaymentSpend exactly as in the normal
    /// sign flow; other inputs use the normal Signer. psbtbumpfee only lowers the change
    /// output and never adds inputs, so silent payment outputs created by the original
    /// transaction (recipient or change) stay valid.
    func signBumpedPsbt(_ psbt: String, passphrase: String?, newFee: Double) {
        let finish: (String?, String?, String?) -> Void = { [weak self] signedPsbt, rawTx, errorMessage in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.finishActivity()
                self.disableBumpButton()
                
                if let rawTx = rawTx {
                    self.signedRawTx = rawTx
                    self.enableSendButton()
                    self.load()
                    showAlert(vc: self, title: "Fee increased to \(newFee.avoidNotation)", message: "Tap the send button to broadcast the new transaction.")
                    
                } else if let signedPsbt = signedPsbt {
                    self.unsignedPsbt = signedPsbt
                    self.load()
                    showAlert(vc: self, title: "Fee increased to \(newFee.avoidNotation)", message: "The transaction still needs more signatures before it can be broadcast.")
                    
                } else if let errorMessage = errorMessage {
                    showAlert(vc: self, title: "Error Signing", message: errorMessage)
                }
            }
        }
        
        self.showActivity("checking for silent payment inputs...")
        
        SilentPaymentSpend.detectInputs(psbt: psbt, passphrase: passphrase, knownInfo: knownWalletInfo()) { [weak self] spOutputs in
            guard let self = self else { return }
            
            guard !spOutputs.isEmpty else {
                // No silent payment inputs: the normal Signer, as before.
                guard let wallet = self.wallet else {
                    finish(nil, nil, "Signing transactions only works with Fully Noded wallets.")
                    return
                }
                
                var utxoParentDesc = ""
                for input in self.inputTableArray {
                    if let parentDesc = input["parent_desc"] as? String {
                        utxoParentDesc = parentDesc
                    }
                }
                
                self.showActivity("signing...")
                Signer.shared.attemptToSignPsbt(fnWallet: wallet, psbt: psbt, passphrase: passphrase, utxoParentDesc: utxoParentDesc) { (signedPsbt, rawTx, errorMessage) in
                    finish(signedPsbt, rawTx, errorMessage)
                }
                return
            }
            
            self.showActivity("signing silent payment inputs...")
            
            SilentPaymentSpend.sign(psbt: psbt, outputs: spOutputs, passphrase: passphrase) { [weak self] signedPsbt, _, errorMessage in
                guard let self = self else { return }
                
                guard let signedPsbt = signedPsbt else {
                    finish(nil, nil, errorMessage ?? "Unable to sign the silent payment inputs.")
                    return
                }
                
                self.signRemainingInputs(psbt: signedPsbt,
                                         parentDescs: self.parentDescs(excluding: spOutputs),
                                         passphrase: passphrase,
                                         completion: finish)
            }
        }
    }

    @objc func signInputAction(_ sender: UIButton) {
        guard let parentDesc = sender.restorationIdentifier else {
            showAlert(title: "", message: "Can not sign unless a parent descriptor is present.")
            return
        }
        
        guard !isShowingActivity, sender.isEnabled else { return }
        
        showActivity("signing...", button: sender)
        
        // Checks for silent payment inputs first; falls back to signNow when there are none.
        if UserDefaults.standard.object(forKey: "passphrasePrompt") == nil {
            signWithSilentPaymentSupport(passphrase: nil, parentDesc: parentDesc)
        } else {
            setPassphrase(onCancel: { [weak self] in
                self?.finishActivity()
            }) { [weak self] passphrase in
                guard let self = self else { return }
                self.passphrase = passphrase
                signWithSilentPaymentSupport(passphrase: passphrase, parentDesc: parentDesc)
            }
        }
        
    }
}
