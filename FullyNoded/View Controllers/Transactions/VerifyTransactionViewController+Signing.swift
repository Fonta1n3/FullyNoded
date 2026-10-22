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
                // A payjoin was offered: try it, keeping this signed payment as the fallback.
                if let endpoint = self.payjoin, !self.payjoinAttempted, !self.unsignedPsbt.isEmpty {
                    self.payjoinAttempted = true
                    self.showActivity("negotiating payjoin...")
                    Payjoin.attempt(endpoint: endpoint, unsignedPsbt: self.unsignedPsbt, signedRawTx: rawTx,
                                    passphrase: self.passphrase) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success(let outcome):
                            let added = outcome.receiverInputs == 0
                                ? "The receiver didn't add inputs, so it's an ordinary payment."
                                : "The receiver added \(outcome.receiverInputs) input\(outcome.receiverInputs == 1 ? "" : "s"), so this payment doesn't look like one to chain analysis."
                            let fee = outcome.feeContribution > 0 ? " \(outcome.feeContribution) sats of the extra fee came from your change." : ""
                            self.showSigned(rawTx: outcome.rawTx, title: "Payjoin ready",
                                            subtitle: "\(added)\(fee) Every check passed. Review it, then broadcast.")
                        case .failure(let error):
                            self.showSigned(rawTx: rawTx, kind: .notice, title: "Signed (no payjoin)",
                                            subtitle: "\(error.errorDescription ?? "The payjoin didn't work.") Your normal payment is signed and ready to broadcast.")
                        }
                    }
                    return
                }
                self.showSigned(rawTx: rawTx)
            } else if let signedPsbt = signedPsbt {
                // Signers only finalize the inputs of their own descriptor, so a transaction mixing
                // descriptors (e.g. a timelocked output next to ordinary ones) can have every
                // signature yet no raw transaction. Ask the node to finalize before deciding it's partial.
                MakeRPCCall.sharedInstance.executeRPCCommand(method: .finalizepsbt(Finalize_Psbt(["psbt": signedPsbt]))) { [weak self] response, _ in
                    guard let self = self else { return }
                    if let dict = response as? [String: Any],
                       dict["complete"] as? Bool == true,
                       let hex = dict["hex"] as? String {
                        self.handleSigningResult(signedPsbt: nil, rawTx: hex, errorMessage: nil)
                    } else {
                        self.showPartiallySigned(signedPsbt, signerError: errorMessage)
                    }
                }
            } else {
                self.finishActivity()
                
                if let errorMessage = errorMessage {
                    showAlert(vc: self, title: "Error Signing", message: errorMessage)
                }
            }
        }
    }

    /// Fully signed: show it, then reload the screen with the raw transaction.
    func showSigned(rawTx: String, kind: SuccessView.Kind = .success, title: String = "Transaction signed",
                    subtitle: String = "Ready to broadcast. The transaction reloads so you can check it first.") {
        finishActivity()
        SuccessView.show(
            in: self,
            kind: kind,
            title: title,
            subtitle: subtitle,
            onDismiss: { [weak self] in
                guard let self = self else { return }
                unsignedPsbt = ""
                reset()
                signedRawTx = rawTx
                enableSendButton()
                load()
            }
        )
    }

    /// Partially signed: still celebrate the signature, say how many are missing,
    /// and point out that the PSBT can be exported to another signer.
    /// `signerError`: why some of this device's inputs weren't signed, shown with the result.
    func showPartiallySigned(_ signedPsbt: String, signerError: String? = nil) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .decodepsbt(param: Decode_Psbt(["psbt": signedPsbt]))) { [weak self] response, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let inputs = (response as? [String: Any])?["inputs"] as? [[String: Any]]
                // Inputs can need different cosigners, so this is the fewest more signers that
                // would complete every input, not the largest need of any one input.
                let statuses = inputs?.enumerated().map { (i, input) -> PSBTInputStatus.Status in
                    let status = PSBTInputStatus.status(from: input)
                    // This PSBT alone doesn't say how many this input needs, but the analysis may have
                    // learned it from the node (the address's descriptor).
                    guard !status.requiredKnown, self.inputTableArray.indices.contains(i),
                          self.inputTableArray[i]["sigsRequiredKnown"] as? Bool == true,
                          let required = self.inputTableArray[i]["sigsRequired"] as? Int else { return status }
                    return PSBTInputStatus.Status(present: status.present, required: required,
                                                  needed: max(0, required - status.present),
                                                  requiredKnown: true, unsignedSigners: status.unsignedSigners)
                }
                let outstanding = statuses.map { PSBTInputStatus.additionalSignersNeeded($0) }
                
                self.finishActivity()
                var subtitle = "This transaction is not fully signed yet."
                if let outstanding = outstanding, outstanding.count > 0 {
                    subtitle = "\(outstanding.isLowerBound ? "At least " : "")\(outstanding.count) more signature\(outstanding.count == 1 ? "" : "s") needed."
                    if outstanding.isLowerBound { subtitle += "\nSome inputs don't say how many signatures they need." }
                } else if outstanding?.isLowerBound == true {
                    subtitle = "Some inputs don't say how many signatures they need, so more may be required."
                }
                subtitle += "\n\nYou can export the PSBT and sign it with another signer."
                if let signerError {
                    subtitle += "\n\nSome inputs this device can sign weren't signed: \(signerError)"
                }
                SuccessView.show(
                    in: self,
                    title: "Signed",
                    subtitle: subtitle,
                    onDismiss: { [weak self] in
                        guard let self = self else { return }
                        reset()
                        unsignedPsbt = signedPsbt
                        load()
                    }
                )
            }
        }
    }

    /// Sign, handling silent payment inputs.
    ///
    /// Silent payment inputs are found without wallet labels (`SilentPaymentSpend.detect`): an
    /// input whose descriptor in the active wallet is `rawtr(<xonly>)` has its funding
    /// transaction fetched and the BIP352 math run with each signer's scan key, which proves
    /// the output is yours and yields the tweak needed to sign it.
    /// - No silent payment inputs: the normal `signNow` path, unchanged.
    /// - Otherwise: SP inputs are signed with `SilentPaymentSpend` (tweaked key),
    ///   remaining inputs with the normal `Signer` (chained per parent descriptor), and
    ///   the node's `finalizepsbt` turns a complete PSBT into the raw transaction.
    func signWithSilentPaymentSupport(passphrase: String?, parentDesc: String) {
        self.showActivity("checking for silent payment inputs...")

        let psbtToSign = unsignedPsbt

        SilentPaymentSpend.detectInputs(psbt: psbtToSign, passphrase: passphrase, knownInfo: knownWalletInfo(), knownOwned: silentPaymentOwned) { [weak self] spOutputs in
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
                self.signRemainingInputsAfterSilentPayments(psbt: signedPsbt,
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

    /// `signRemainingInputs` for a PSBT the silent payment signer just wrote. The normal Signer
    /// (BDK) rejects that PSBT as it was re-serialized ("MissingNonWitnessUtxo"), so when
    /// ordinary inputs are still left it first goes through the node's `finalizepsbt`, which
    /// returns a normalized PSBT (the signed silent payment inputs finalized), and inputs missing
    /// their funding transaction get it (`addMissingNonWitnessUtxos`), as BDK otherwise refuses
    /// the whole PSBT when a silent payment input is left for another device to sign. With
    /// nothing left to sign it behaves exactly like `signRemainingInputs`.
    func signRemainingInputsAfterSilentPayments(psbt: String,
                                                parentDescs: [String],
                                                passphrase: String?,
                                                completion: @escaping (String?, String?, String?) -> Void) {
        guard !parentDescs.isEmpty else {
            signRemainingInputs(psbt: psbt, parentDescs: parentDescs, passphrase: passphrase, completion: completion)
            return
        }

        finalizeWithNode(psbt) { [weak self] normalized, rawTx, _ in
            guard let self = self else { return }
            if let rawTx = rawTx {
                completion(nil, rawTx, nil)
                return
            }
            SilentPaymentSpend.addMissingNonWitnessUtxos(psbt: normalized ?? psbt) { [weak self] filled in
                #if DEBUG
                print("[sp-sign] normalized by node: \(normalized != nil), non_witness_utxo added: \(filled != (normalized ?? psbt)), parentDescs: \(parentDescs.map { $0.prefix(60) })")
                #endif
                self?.signRemainingInputs(psbt: filled, parentDescs: parentDescs, passphrase: passphrase, completion: completion)
            }
        }
    }

    /// Normal Signer for the non-silent-payment inputs, one parent descriptor at a time,
    /// each signing the previous result. Then finalize with the node.
    /// Completion: (psbt, rawTx, error) — rawTx if fully signed and finalized. With a psbt,
    /// error is why a descriptor your signers belong to wasn't signed (nil if all were).
    func signRemainingInputs(psbt: String,
                                     parentDescs: [String],
                                     passphrase: String?,
                                     errors: [String] = [],
                                     completion: @escaping (String?, String?, String?) -> Void) {
        guard let parentDesc = parentDescs.first else {
            finalizeWithNode(psbt) { psbt, rawTx, error in
                completion(psbt, rawTx, rawTx == nil ? (error ?? errors.first) : nil)
            }
            return
        }

        guard let wallet = wallet else {
            // SP inputs are signed; the others need a Fully Noded wallet to sign.
            finalizeWithNode(psbt) { psbt, rawTx, _ in
                completion(psbt, rawTx, rawTx == nil ? "the active wallet isn't a Fully Noded wallet with signers on this device, so only the silent payment inputs were signed." : nil)
            }
            return
        }

        Signer.shared.attemptToSignPsbt(fnWallet: wallet, psbt: psbt, passphrase: passphrase, utxoParentDesc: parentDesc) { [weak self] signedPsbt, rawTx, errorMessage in
            guard let self = self else { return }
            #if DEBUG
            print("[sp-sign] \(parentDesc.prefix(60))… → psbt: \(signedPsbt != nil), changed: \(signedPsbt.map { $0 != psbt } ?? false), rawTx: \(rawTx != nil), error: \(errorMessage ?? "none")")
            #endif

            if let rawTx = rawTx {
                completion(nil, rawTx, nil)
                return
            }

            // Keep going with whatever we have (a signer error leaves the psbt unchanged). A
            // descriptor none of your signers belong to (e.g. another device's silent payment
            // input) isn't an error worth reporting.
            var errors = errors
            if signedPsbt == nil, let errorMessage, !errorMessage.hasPrefix("None of your signers match") {
                errors.append(errorMessage)
            } else if let signedPsbt, Self.signatureCount(signedPsbt) <= Self.signatureCount(psbt) {
                // The signer ran without error but added nothing (it didn't recognise any input).
                errors.append("your signer for \(Descriptor(parentDesc).fingerprint) ran but added no signatures.")
            }
            self.signRemainingInputs(psbt: signedPsbt ?? psbt,
                                     parentDescs: Array(parentDescs.dropFirst()),
                                     passphrase: passphrase,
                                     errors: errors,
                                     completion: completion)
        }
    }

    /// Signatures in a PSBT (partial sigs, taproot key and script path sigs), to tell whether a
    /// signer added any. 0 if it can't be parsed.
    static func signatureCount(_ psbt: String) -> Int {
        guard let raw = Data(base64Encoded: psbt.trimmingCharacters(in: .whitespacesAndNewlines)),
              let parsed = try? SPPsbt(raw) else { return 0 }
        let sigKeyTypes: Set<UInt8> = [0x02, SPPsbt.inTapKeySig, 0x14]
        return parsed.inputs.reduce(0) { count, input in
            count + input.filter { sigKeyTypes.contains($0.key.first ?? 0xFF) }.count
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
                // The bump is a new, unbroadcast transaction: without this the reload treats
                // it like the original (no mempool check, Send never enabled).
                if rawTx != nil || signedPsbt != nil { self.alreadyBroadcast = false }

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
        
        SilentPaymentSpend.detectInputs(psbt: psbt, passphrase: passphrase, knownInfo: knownWalletInfo(), knownOwned: silentPaymentOwned) { [weak self] spOutputs in
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
                
                self.signRemainingInputsAfterSilentPayments(psbt: signedPsbt,
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
