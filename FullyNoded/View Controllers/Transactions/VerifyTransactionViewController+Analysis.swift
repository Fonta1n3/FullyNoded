//
//  VerifyTransactionViewController+Analysis.swift
//  FullyNoded
//
//  Loading a psbt / raw transaction: decode, look up every input's previous output,
//  verify inputs and outputs with the node and locally, fee data, who can sign each input,
//  and the "verify owner" check against other wallets.
//

import UIKit

extension VerifyTransactionViewController {

    func saveNewTx(_ txid: String) {
        var transaction = [String:Any]()
        
        self.id = UUID()
        transaction["id"] = self.id
        transaction["label"] = labelText
        transaction["date"] = Date()
        transaction["txid"] = txid
        transaction["fiatCurrency"] = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        if let fx = fxRate {
            transaction["originFxRate"] = fx
        }
        
        CoreDataService.saveEntity(dict: transaction, entityName: .transactions) { _ in }
    }

    func load() {
        showActivity("analyzing transaction...")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // The previous contents are stale until the analysis finishes.
            UIView.animate(withDuration: 0.2) { self.verifyTable.alpha = 0.35 }
            self.verifyTable.isUserInteractionEnabled = false
        }
        
        inputArray.removeAll()
        inputTableArray.removeAll()
        outputArray.removeAll()
        recipients.removeAll()
        signatures.removeAll()
        
        if unsignedPsbt == "" {
            updateLabel("decoding raw transaction...")
            decodeTx(param: Decode_Raw_Tx(["hexstring": signedRawTx]))
        } else {
            updateLabel("decoding psbt...")
            decodePsbt(param: Decode_Psbt(["psbt": unsignedPsbt]))
        }
    }

    func decodePsbt(param: Decode_Psbt) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .decodepsbt(param: param)) { [weak self] (object, errorDesc) in
            guard let self = self else { return }
            
            guard let dict = object as? NSDictionary else {
                self.finishActivity()
                displayAlert(viewController: self, isError: true, message: errorDesc ?? "")
                return
            }
            
            self.psbtDict = dict
            
            if let inputs = dict["inputs"] as? NSArray, inputs.count > 0 {
                for (i, input) in inputs.enumerated() {
                    var isSigned = false
                    var sigsRequired = 0
                    var sigsPresent = 0
                    var sigsRemaining = 0
                    
                    if let inputDict = input as? NSDictionary {
                        let status = PSBTInputStatus.sigsNeeded(from: inputDict as! [String : Any])
                        sigsPresent = status.present
                        sigsRequired = status.required
                        sigsRemaining = status.needed
                        
                        if let signatures = inputDict["partial_signatures"] as? NSDictionary {
                            for (key, value) in signatures {
                                self.signatures.append(["\(key)":(value as? String ?? "")])
                            }
                        } else if let _ = inputDict["final_scriptwitness"] as? [String] {
                            isSigned = true
                        }
                        
                        if let taproot_script_path_sigs = inputDict["taproot_script_path_sigs"] as? [[String: Any]] {
                            for taprootSig in taproot_script_path_sigs {
                                for (key, value) in taprootSig {
                                    if key == "sig" {
                                        self.signatures.append(["\(key)":(value as? String ?? "")])
                                    }
                                }
                            }
                        }
                        
                        let tableInputDict:[String:Any] = [
                            "index": i + 1,
                            "amount": "Unknown.",
                            "address": "Unknown.",
                            "isOurs": false,// Hardcode at this stage and update before displaying
                            "isDust": true,
                            "isSigned": isSigned,
                            "sigsRequired": sigsRequired,
                            "sigsPresent": sigsPresent,
                            "sigsRemaining": sigsRemaining
                        ]
                        
                        self.inputTableArray.append(tableInputDict)
                    }
                }
            }
            
            if let txDict = dict["tx"] as? NSDictionary {
                
                if let size = txDict["vsize"] as? Int {
                    self.txSize = size
                }
                
                if let id = txDict["txid"] as? String {
                    self.txid = id
                    self.loadLabelAndMemo()
                }
                
                self.parseTransaction(tx: txDict)
            }
        }
    }

    func decodeTx(param: Decode_Raw_Tx) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .decoderawtransaction(param: param)) { [weak self] (object, errorDesc) in
            guard let self = self else { return }
            
            guard let dict = object as? NSDictionary else {
                self.finishActivity()
                displayAlert(viewController: self, isError: true, message: errorDesc ?? "")
                return
            }
            
            if let size = dict["vsize"] as? Int {
                self.txSize = size
            }
            
            if let id = dict["txid"] as? String {
                self.txid = id
                self.loadLabelAndMemo()
            }
            
            if let inputs = dict["vin"] as? [[String: Any]] {
                
                for (i, _) in inputs.enumerated() {
                    let inputDict:[String:Any] = [
                        "index": i + 1,
                        "amount": "Unknown amount.",
                        "address": "Unknown address.",
                        "isOurs": false,// Hardcode at this stage and update before displaying
                        "isDust": true,
                        "isSigned": false
                    ]
                    
                    self.inputTableArray.append(inputDict)
                }
                
                self.index = 0
                self.signedTxInputs = inputs
            }
            
            self.parseTransaction(tx: dict)
        }
    }

    func parseTransaction(tx: NSDictionary) {
        if let inputs = tx["vin"] as? NSArray, let outputs = tx["vout"] as? NSArray {
            parseOutputs(outputs: outputs)
            parseInputs(inputs: inputs) { [weak self] in
                self?.index = 0
                self?.getInputInfo(index: 0)
            }
        }
    }

    func getInputInfo(index: Int) {
        let dict = inputArray[index]
        if let txid = dict["txid"] as? String, let vout = dict["vout"] as? Int {
            let param = Get_Tx(["txid": txid, "verbose": true])
            parsePrevTx(method: .gettransaction(param), vout: vout, txid: txid)
        } else if dict["txid"] as? String == "coinbase" {
            self.parsePrevTxOutput(outputs: [], vout: 0, txid: txid)
        }
    }

    func parseInputs(inputs: NSArray, completion: @escaping () -> Void) {
        for (index, i) in inputs.enumerated() {
            if let input = i as? NSDictionary {
                if let txid = input["txid"] as? String, let vout = input["vout"] as? Int {
                    let dict = ["inputNumber":index + 1, "txid":txid, "vout":vout as Any] as [String : Any]
                    inputArray.append(dict)
                    
                    if index + 1 == inputs.count {
                        completion()
                    }
                } else if let _ = input["coinbase"] as? String {
                    let dict = ["inputNumber":index + 1, "txid":"coinbase"] as [String : Any]
                    inputArray.append(dict)
                    if index + 1 == inputs.count {
                        completion()
                    }
                }
            }
        }
    }

    func parseOutputs(outputs: NSArray) {
        for (i, o) in outputs.enumerated() {
            if let output = o as? NSDictionary {
                if let scriptpubkey = output["scriptPubKey"] as? NSDictionary, let amount = output["value"] as? Double {
                    let number = i + 1
                    let addressString = Self.address(from: scriptpubkey)
                    
                    outputTotal += amount
                    var isChange = true
                    
                    for recipient in recipients {
                        if addressString == recipient {
                            isChange = false
                        }
                    }
                    
                    if sweeping {
                        isChange = false
                    }
                                        
                    let amountString = self.amountString(amount)
                                        
                    let outputDict:[String:Any] = [
                        "index": number,
                        "amount": amountString,
                        "address": addressString,
                        "isChange": isChange,
                        "isOursBitcoind": false,// Hardcode at this stage and update before displaying
                        "isOursFullyNoded": false,
                        "walletLabel": "",
                        "signable": false,
                        "signerLabel": "",
                        "isDust": amount < 0.00020000
                    ]
                    
                    outputArray.append(outputDict)
                }
            }
        }
    }

    func parsePrevTxOutput(outputs: NSArray, vout: Int, txid: String) {
        if outputs.count > 0 {
            for o in outputs {
                if let output = o as? NSDictionary {
                    if let n = output["n"] as? Int {
                        if n == vout {
                            //this is our inputs output, we can now get the amount and address for the input (PITA)
                            let addressString = (output["scriptPubKey"] as? NSDictionary).map(Self.address(from:)) ?? ""
                            
                            if let amount = output["value"] as? Double {
                                inputTotal += amount
                                self.inputTableArray[index]["amount"] = amountString(amount)
                                self.inputTableArray[index]["address"] = addressString
                                self.inputTableArray[index]["isDust"] = amount < 0.00020000
                                self.inputTableArray[index]["txid"] = txid
                                self.inputTableArray[index]["vout"] = vout
                                                     
                            }
                        }
                    }
                }
            }
        }
        
        if index + 1 < inputArray.count {
            index += 1
            getInputInfo(index: index)
            
        } else if index + 1 == inputArray.count {
            index = 0
            txFee = inputTotal - outputTotal
            
            if inputTotal > 0.0 {
                let txfeeString = txFee.avoidNotation
                if fxRate != nil {
                    self.miningFee = "\(txfeeString) btc / \(fiatAmount(btc: self.txFee))"
                } else {
                    self.miningFee = "\(txfeeString) btc / error fetching fx rate"
                }
            } else {
                self.miningFee = "No fee data. Your node may be pruned."
            }
            
            verifyInputs()
        }
    }

    func verifyInputs() {
        if index < inputTableArray.count {
            self.updateLabel("verifying input #\(self.index + 1) out of \(self.inputTableArray.count)")
            
            if let address = inputTableArray[index]["address"] as? String, address != "Unknown address.", address != "" {
                
                let param:Get_Address_Info = .init(["address":address])
                MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: param)) { [weak self] (response, errorMessage) in
                    guard let self = self else { return }
                    
                    guard errorMessage == nil else {
                        self.finishActivity()
                        if errorMessage!.contains("Wallet file not specified (must request wallet RPC through") {
                            showAlert(vc: self, title: "No wallet specified!", message: "Please go to your Active Wallet tab and toggle on a wallet then try this operation again, for certain commands Bitcoin Core needs to know which wallet to talk to.")
                        } else {
                            showAlert(vc: self, title: "Error", message: errorMessage ?? "unknown")
                        }
                        
                        return
                    }
                    
                    guard let dict = response as? NSDictionary else { return }
                    
                    let solvable = dict["solvable"] as? Bool ?? false
                    let keypath = dict["hdkeypath"] as? String ?? "no key path"
                    let labels = dict["labels"] as? NSArray ?? ["no label"]
                    let desc = dict["desc"] as? String ?? "no descriptor"
                    if let parentDesc = dict["parent_desc"] as? String {
                        //let parentFnDesc = Descriptor(parentDesc)
                        self.inputTableArray[self.index]["parent_desc"] = parentDesc
                    }
                    var isChange = dict["ischange"] as? Bool ?? false
                    let fingerprint = dict["hdmasterfingerprint"] as? String ?? "no fingerprint"
                    let script = dict["script"] as? String ?? ""
                    let sigsrequired = dict["sigsrequired"] as? Int ?? 0
                    let pubkeys = dict["pubkeys"] as? [String] ?? []
                    let labelsText = Self.labelsText(labels)
                    
                    isChange = desc.contains("/1/")
                    
                    self.inputTableArray[self.index]["isOurs"] = solvable
                    self.inputTableArray[self.index]["hdKeyPath"] = keypath
                    self.inputTableArray[self.index]["isChange"] = isChange
                    self.inputTableArray[self.index]["label"] = labelsText
                    self.inputTableArray[self.index]["fingerprint"] = fingerprint
                    self.inputTableArray[self.index]["desc"] = desc
                    // Raw wallet facts, for silent payment detection without extra RPCs.
                    self.inputTableArray[self.index]["isMine"] = dict["ismine"] as? Bool ?? false
                    self.inputTableArray[self.index]["walletLabels"] = labels.compactMap { $0 as? String }
                    
                    
                    if script == "multisig" && self.signedRawTx == "" {
                        self.inputTableArray[self.index]["sigsrequired"] = sigsrequired
                        self.inputTableArray[self.index]["pubkeys"] = pubkeys
                        var numberOfSigs = 0
                        
                        // Will only be any for a psbt
                        for (i, sigs) in self.signatures.enumerated() {
                            for (key, _) in sigs {
                                for pk in pubkeys {
                                    if pk == key {
                                        numberOfSigs += 1
                                    }
                                }
                            }
                            
                            if i + 1 == self.signatures.count {
                                self.inputTableArray[self.index]["signatures"] = "\(numberOfSigs) out of \(sigsrequired) signatures"
                            }
                            
                        }
                    } else {
                        // Will only be any for a signed raw transaction
                        // This input's own scriptSig / witness (vin is in the same order).
                        if self.index < self.signedTxInputs.count {
                            let signedTxInput = self.signedTxInputs[self.index]
                            let scriptSigHex = (signedTxInput["scriptSig"] as? [String: Any])?["hex"] as? String ?? ""
                            let witness = signedTxInput["txinwitness"] as? [Any] ?? []
                            self.inputTableArray[self.index]["signatures"] =
                                (!scriptSigHex.isEmpty || !witness.isEmpty) ? "Signatures complete" : "Unsigned"
                        }
                    }
                    self.index += 1
                    self.verifyInputs()
                }
            } else {
                self.index += 1
                self.verifyInputs()
            }
        } else {
            self.index = 0
            verifyOutputs()
        }
    }

    func verifyOutputs() {
        if index < outputArray.count {
            self.updateLabel("verifying output #\(self.index + 1) out of \(self.outputArray.count)")
            
            if let address = outputArray[index]["address"] as? String, address != "" {
                let param:Get_Address_Info = .init(["address":address])
                MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: param)) { [weak self] (response, errorMessage) in
                    guard let self = self else { return }
                    
                    guard let dict = response as? NSDictionary else {
                        // The node couldn't look this address up: show it as unverified
                        // and carry on with the rest, rather than stalling the analysis.
                        self.outputArray[self.index]["isOursFullyNoded"] = false
                        self.outputArray[self.index]["walletLabel"] = ""
                        self.outputArray[self.index]["label"] = "Node error: \(errorMessage ?? "unknown")"
                        self.index += 1
                        self.verifyOutputs()
                        return
                    }

                    do {
                        let solvable = dict["solvable"] as? Bool ?? false
                        var keypath = dict["hdkeypath"] as? String ?? "no key path"
                        let labels = dict["labels"] as? NSArray ?? ["no label"]
                        let desc = dict["desc"] as? String ?? "no descriptor"
                        var isChange = dict["ischange"] as? Bool ?? false
                        let fingerprint = dict["hdmasterfingerprint"] as? String ?? "no fingerprint"
                        let parentDesc = dict["parent_desc"] as? String ?? ""
                        let labelsText = Self.labelsText(labels)
                        
                        if desc.contains("/1/") {
                            isChange = true
                        }
                        
                        if keypath == "no key path" {
                            let descriptorStr = Descriptor(desc)
                            keypath = descriptorStr.derivation
                        }
                        
                        self.outputArray[self.index]["isOursBitcoind"] = solvable
                        self.outputArray[self.index]["hdKeyPath"] = keypath
                        self.outputArray[self.index]["isChange"] = isChange
                        self.outputArray[self.index]["label"] = labelsText
                        self.outputArray[self.index]["fingerprint"] = fingerprint
                        self.outputArray[self.index]["desc"] = desc
                        //self.outputArray[self.index]["parent_desc"] = parentDesc
                        
                        // Currently only verify address if the node knows about it.. otherwise we have to brute force 200k addresses...
                        // will add a dedicated verify button for unsolvable to cross check against all wallets
                        // also adding a signer verify button to show whether FN is able to sign for the output or not
                        if solvable && self.wallet != nil {
                            // Only do this if we are not using the default wallet.
                            Keys.verifyAddress(parentDesc: parentDesc, passphrase: self.passphrase) { (_, _, signable, signer) in
                                // "Ours" and "change" are decided by deriving the address from
                                // our own descriptors, NOT by what the node reports.
                                self.locallyVerifyOutput(address: address, keyPath: keypath) { local in
                                    self.applyLocalVerification(local, nodeSaysChange: isChange, to: &self.outputArray[self.index])
                                    self.outputArray[self.index]["signable"] = signable
                                    self.outputArray[self.index]["signerLabel"] = signer
                                    self.index += 1
                                    self.verifyOutputs()
                                }
                            }
                        } else {
                            self.outputArray[self.index]["isOursFullyNoded"] = false
                            self.outputArray[self.index]["walletLabel"] = ""
                            self.index += 1
                            self.verifyOutputs()
                        }
                    }
                }
            } else {
                self.index += 1
                self.verifyOutputs()
            }
        } else {
            guard signedRawTx != "" else {
                getFeeRate()
                return
            }
            
            if !alreadyBroadcast {
                updateLabel("verifying mempool accept...")
                let param:Test_Mempool_Accept = .init(["rawtxs":[signedRawTx]])
                MakeRPCCall.sharedInstance.executeRPCCommand(method: .testmempoolaccept(param)) { [weak self] (response, errorMessage) in
                    guard let self = self else { return }
                    
                    if let errorMessage = errorMessage {
                        showAlert(vc: self, title: "testmempoolaccept error", message: errorMessage)
                    }
                    
                    guard let arr = response as? NSArray, arr.count > 0,
                        let dict = arr[0] as? NSDictionary,
                        let allowed = dict["allowed"] as? Bool else {
                        self.getFeeRate()
                        return
                    }
                    
                    self.txValid = allowed
                    
                    if allowed {
                        self.enableSendButton()
                    }
                    
                    self.rejectionMessage = dict["reject-reason"] as? String ?? ""
                    self.getFeeRate()
                }
            } else {
                self.getFeeRate()
            }
        }
    }

    func getFeeRate() {
        let target = UserDefaults.standard.object(forKey: "feeTarget") as? Int ?? 432
        
        updateLabel("estimating smart fee...")
        let param:Estimate_Smart_Fee_Param = .init(["conf_target": target])
        
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .estimatesmartfee(param: param)) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary, let feeRate = dict["feerate"] as? Double else {
                self.loadTableData()
                return
            }
            
            let inSatsPerKb = Double(feeRate) * 100000000.0
            self.smartFee = inSatsPerKb / 1000.0
            self.loadTableData()
        }
    }

    /// "0.01 234 567" plus " / $12.34" when there's an fx rate.
    func amountString(_ btc: Double) -> String {
        guard let fxRate = fxRate else { return btc.btcBalanceWithSpaces }
        return btc.btcBalanceWithSpaces + " / " + (fxRate * btc).fiatString
    }

    /// Address(es) of a decoded output's scriptPubKey (old Core: `addresses` array).
    static func address(from scriptPubKey: NSDictionary) -> String {
        if let addresses = scriptPubKey["addresses"] as? [String], !addresses.isEmpty {
            return addresses.count == 1 ? addresses[0] : addresses.map { $0 + " " }.joined()
        }
        return scriptPubKey["address"] as? String ?? ""
    }

    /// getaddressinfo labels as one string ("no label" for empty ones).
    static func labelsText(_ labels: NSArray) -> String {
        guard labels.count > 0 else { return "no label " }
        return labels.map { label -> String in
            let text = label as? String ?? ""
            return (text.isEmpty ? "no label" : text) + " "
        }.joined()
    }

    func fiatAmount(btc: Double) -> String {
        guard let fxRate = fxRate else { return "error getting fiat rate" }
        let fiat = fxRate * btc
        let roundedFiat = Double(round(100*fiat)/100)
        return roundedFiat.fiatString
    }

    func loadTableData() {
        resolveInputSigners()
        
        DispatchQueue.main.async { [weak self] in
            self?.verifyTable.reloadData()
            self?.finishActivity()
        }
        
        
        guard let _ = KeyChain.getData("UnlockPassword") else {
            showAlert(vc: self, title: "You are not using the app securely...", message: "Anyone who gets access to this device will be able to spend your Bitcoin, we urge you to add a lock password via the lock button on the home screen.")
            
            return
        }
    }

    func parsePrevTx(method: BTC_CLI_COMMAND, vout: Int, txid: String) {
        func decodeRaw() {
            updateLabel("decoding inputs previous output...")
            MakeRPCCall.sharedInstance.executeRPCCommand(method: method) { [weak self] (object, errorDescription) in
                guard let self = self else { return }
                
                guard let txDict = object as? NSDictionary, let outputs = txDict["vout"] as? NSArray else {
                    self.finishActivity()
                    displayAlert(viewController: self, isError: true, message: "Error decoding raw transaction")
                    return
                }
                
                self.parsePrevTxOutput(outputs: outputs, vout: vout, txid: txid)
            }
        }
        
        
        func getRawTx() {
            updateLabel("fetching inputs previous output...")
            MakeRPCCall.sharedInstance.executeRPCCommand(method: method) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                guard let response = response as? [String:Any] else {
                    self.parsePrevTxOutput(outputs: [], vout: 0, txid: txid)
                    return
                }
                
                guard let hex = response["hex"] as? String else {
                    guard let errorMessage = errorMessage else { return }
                    
                    guard errorMessage.contains("No such mempool transaction") else {
                        self.finishActivity()
                        displayAlert(viewController: self, isError: true, message: "Error parsing inputs: \(errorMessage)")
                        return
                    }
                    
                    let param_get_tx:Get_Tx = .init(["txid":txid, "verbose": true])
                    MakeRPCCall.sharedInstance.executeRPCCommand(method: .gettransaction(param_get_tx)) { (response, errorMessage) in
                        guard let dict = response as? NSDictionary, let hexToParse = dict["hex"] as? String else {
                            self.parsePrevTxOutput(outputs: [], vout: 0, txid: txid)
                            return
                        }
                        
                        let param_decode_raw:Decode_Raw_Tx = .init(["hexstring":hexToParse])
                        self.parsePrevTx(method: .decoderawtransaction(param: param_decode_raw), vout: vout, txid: txid)
                    }
                    
                    return
                }
                let param_decode_raw:Decode_Raw_Tx = .init(["hexstring":hex])
                self.parsePrevTx(method: .decoderawtransaction(param: param_decode_raw), vout: vout, txid: txid)
            }
        }
        
        switch method {
        case .decoderawtransaction:
            decodeRaw()
            
        case .gettransaction:
            getRawTx()
            
        default:
            break
        }
        
    }

    /// Works out which stored signer(s) can sign each input, for the input cell's
    /// "signable" row. PSBT inputs carry the master fingerprint of every key that can sign
    /// them (`bip32_derivs` / `taproot_bip32_derivs`); a raw transaction falls back to the
    /// key origins in the input's descriptor. Those are matched against each signer's
    /// fingerprint. Taproot inputs no signer matches are then checked for silent payment
    /// outputs owned by one of your signers (no fingerprint is involved there).
    func resolveInputSigners() {
        let psbtInputs: [[String: Any]] = unsignedPsbt != "" ? (psbtDict?["inputs"] as? [[String: Any]] ?? []) : []
        let isHotWallet = wallet.map { Descriptor($0.receiveDescriptor).isHot } ?? false

        CoreDataService.retrieveEntity(entityName: .signers) { [weak self] signers in
            var known: [(xfp: String, label: String)] = []
            var withWords: Set<String> = []
            for dict in signers ?? [] {
                let signer = SignerStruct(dictionary: dict)
                guard let encrypted = signer.xfp,
                      let decrypted = Crypto.decrypt(encrypted),
                      let xfp = decrypted.utf8String else { continue }
                known.append((xfp.lowercased(), signer.label))
                if signer.words != nil { withWords.insert(xfp.lowercased()) }
            }
            // With the passphrase prompt the signing keys depend on what gets typed, so
            // stored fingerprints can't rule a signer out.
            let passphrasePrompt = UserDefaults.standard.object(forKey: "passphrasePrompt") != nil

            DispatchQueue.main.async {
                guard let self = self else { return }
                var silentPaymentCandidates: [SilentPaymentSpend.Candidate] = []

                for i in self.inputTableArray.indices {
                    let input = self.inputTableArray[i]
                    let fingerprints = Self.masterFingerprints(input: input, psbtInput: i < psbtInputs.count ? psbtInputs[i] : nil)
                    let matches = known.filter { fingerprints.contains($0.xfp) }

                    self.inputTableArray[i]["signers"] = matches.map { "\($0.label) [\($0.xfp)]" }
                    self.inputTableArray[i]["fingerprints"] = fingerprints
                    self.inputTableArray[i]["matchedKeys"] = Set(matches.map { $0.xfp }).count
                    self.inputTableArray[i]["hotWallet"] = isHotWallet && (input["isOurs"] as? Bool ?? false)

                    let canSignHere = matches.contains { withWords.contains($0.xfp) } && self.wallet != nil
                    if matches.isEmpty, let candidate = Self.silentPaymentCandidate(input) {
                        silentPaymentCandidates.append(candidate)
                        self.inputTableArray[i]["canSign"] = nil      // known once the SP check is done
                    } else {
                        self.inputTableArray[i]["canSign"] = passphrasePrompt ? nil : canSignHere
                    }
                }

                self.verifyTable.reloadData()
                self.resolveSilentPaymentSigners(silentPaymentCandidates)
            }
        }
    }

    /// Silent payment inputs have no BIP32 origin. Name the signer from what the active
    /// wallet already told us (getaddressinfo in `verifyInputs`): FN-Server's import label
    /// carries the scan key and tweak, checked locally. No extra RPC for labeled inputs.
    func resolveSilentPaymentSigners(_ candidates: [SilentPaymentSpend.Candidate]) {
        guard !candidates.isEmpty else { return }
        let txid = self.txid
        let candidateOutpoints = Set(candidates.map { "\($0.txid.lowercased()):\($0.vout)" })
        let passphrasePrompt = UserDefaults.standard.object(forKey: "passphrasePrompt") != nil

        SilentPaymentSpend.detectInputSigners(candidates: candidates, passphrase: passphrase) { [weak self] found in
            guard let self = self, self.txid == txid else { return }

            for i in self.inputTableArray.indices {
                guard let txid = self.inputTableArray[i]["txid"] as? String,
                      let vout = self.inputTableArray[i]["vout"] as? Int else { continue }
                let outpoint = "\(txid.lowercased()):\(vout)"
                guard candidateOutpoints.contains(outpoint) else { continue }
                guard let signer = found[outpoint] else {
                    if !passphrasePrompt { self.inputTableArray[i]["canSign"] = false }
                    continue
                }
                self.inputTableArray[i]["signers"] = [signer]
                self.inputTableArray[i]["isSilentPayment"] = true
                self.inputTableArray[i]["canSign"] = true
            }

            self.verifyTable.reloadData()
        }
    }

    /// A taproot input as a silent payment candidate, with the wallet info
    /// `verifyInputs` already fetched (nil info if it wasn't looked up).
    static func silentPaymentCandidate(_ input: [String: Any]) -> SilentPaymentSpend.Candidate? {
        guard isTaproot(input["address"] as? String),
              let address = input["address"] as? String,
              let txid = input["txid"] as? String,
              let vout = input["vout"] as? Int,
              let decoded = try? WalletLogic.Bech32m.decode(address),
              decoded.1 == 1, decoded.2.count == 32 else { return nil }

        var info: SilentPaymentSpend.WalletInfo?
        if let labels = input["walletLabels"] as? [String] {
            info = SilentPaymentSpend.WalletInfo(isMine: input["isMine"] as? Bool ?? false,
                                                 desc: input["desc"] as? String ?? "",
                                                 labels: labels)
        }
        return SilentPaymentSpend.Candidate(txid: txid, vout: vout, outputKey: SPHexFN.encode(decoded.2), info: info)
    }

    /// Wallet info per input ("txid:vout" lowercase), so signing doesn't look it up again.
    func knownWalletInfo() -> [String: SilentPaymentSpend.WalletInfo] {
        var known: [String: SilentPaymentSpend.WalletInfo] = [:]
        for input in inputTableArray {
            guard let candidate = Self.silentPaymentCandidate(input), let info = candidate.info else { continue }
            known["\(candidate.txid.lowercased()):\(candidate.vout)"] = info
        }
        return known
    }

    /// Lowercase master fingerprints of the keys that can sign an input (de-duplicated).
    static func masterFingerprints(input: [String: Any], psbtInput: [String: Any]?) -> [String] {
        var result: [String] = []
        func add(_ fingerprint: String?) {
            guard let fingerprint = fingerprint?.lowercased(), fingerprint.count == 8, !result.contains(fingerprint) else { return }
            result.append(fingerprint)
        }

        for key in ["bip32_derivs", "taproot_bip32_derivs"] {
            for derivation in psbtInput?[key] as? [[String: Any]] ?? [] {
                add(derivation["master_fingerprint"] as? String)
            }
        }

        if result.isEmpty {
            for key in ["desc", "parent_desc"] {
                guard let descriptor = input[key] as? String else { continue }
                originFingerprints(in: descriptor).forEach { add($0) }
            }
        }

        return result
    }

    /// The `[fingerprint/...]` key origins in a descriptor.
    static func originFingerprints(in descriptor: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "\\[([0-9a-fA-F]{8})") else { return [] }
        let range = NSRange(descriptor.startIndex..., in: descriptor)
        return regex.matches(in: descriptor, range: range).compactMap { match in
            Range(match.range(at: 1), in: descriptor).map { String(descriptor[$0]) }
        }
    }

    static func isTaproot(_ address: String?) -> Bool {
        guard let address = address?.lowercased() else { return false }
        return address.hasPrefix("bc1p") || address.hasPrefix("tb1p") || address.hasPrefix("bcrt1p")
    }

    /// Checks whether `address` derives from one of our Fully Noded wallets' descriptors,
    /// active wallet first. `keyPath` from the node is only a hint for the index.
    func locallyVerifyOutput(address: String,
                                     keyPath: String,
                                     completion: @escaping ((isOurs: Bool, isChange: Bool, walletLabel: String?)) -> Void) {
        if let active = wallet {
            let result = WalletLogic.shared.locallyVerifyAddress(address, keyPath: keyPath, fnWallet: active)
            if result.isOurs {
                completion((true, result.isChange, active.label))
                return
            }
        }

        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self = self else { return }
            for dict in wallets ?? [] {
                let fnWallet = Wallet(dictionary: dict)
                if fnWallet.id == self.wallet?.id { continue }
                let result = WalletLogic.shared.locallyVerifyAddress(address, keyPath: keyPath, fnWallet: fnWallet)
                if result.isOurs {
                    completion((true, result.isChange, fnWallet.label))
                    return
                }
            }
            completion((false, false, nil))
        }
    }

    /// Writes the local verification result into an output dict. "Change" is only shown
    /// when WE derived it from a change descriptor; if the node claimed change but we
    /// couldn't verify it, the output is flagged `changeUnverified`.
    func applyLocalVerification(_ local: (isOurs: Bool, isChange: Bool, walletLabel: String?),
                                        nodeSaysChange: Bool,
                                        to output: inout [String: Any]) {
        output["isOursFullyNoded"] = local.isOurs
        output["walletLabel"] = local.isOurs ? (local.walletLabel ?? "") : ""
        output["isChange"] = local.isOurs && local.isChange
        output["changeUnverified"] = nodeSaysChange && !(local.isOurs && local.isChange)
    }

    @objc func verifyOwner(_ sender: UIButton) {
        guard let id = sender.restorationIdentifier else { return }
        let arr = id.split(separator: " ")
        let address = "\(arr[0])"
        guard let index = Int(arr[1]) else { return }
                
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Verify Owner",
                                          message: "This address does not belong to the current Active Wallet, you can run this check to see if any of your other wallets are the owner.",
                                          preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Verify Owner", style: .default, handler: { action in
                self.showActivity("checking other FN wallets...")
                self.getBitcoinCoreWallets(address, index)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }

    func checkEachWallet(_ address: String, _ walletsToCheck: [String], _ int: Int) {
        var updatedOutput = outputArray[int]
        
        func resetActiveWallet() {
            UserDefaults.standard.set(self.wallet!.name, forKey: "walletName")
        }
        
        if walletIndex < walletsToCheck.count {
            let wallet = walletsToCheck[walletIndex]
            UserDefaults.standard.set(wallet, forKey: "walletName")
            let param:Get_Address_Info = .init(["address":address])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: param)) { [weak self] (response, errorMessage) in
                guard let self = self else { resetActiveWallet(); return }
                
                if let dict = response as? NSDictionary, let solvable = dict["solvable"] as? Bool, solvable {
                    let keypath = dict["hdkeypath"] as? String ?? "no key path"
                    let labels = dict["labels"] as? NSArray ?? ["no label"]
                    let desc = dict["desc"] as? String ?? "no descriptor"
                    var isChange = dict["ischange"] as? Bool ?? false
                    let fingerprint = dict["hdmasterfingerprint"] as? String ?? "no fingerprint"
                    let parentDesc = dict["parent_desc"] as? String ?? ""
                    let labelsText = Self.labelsText(labels)
                    
                    if desc.contains("/1/") {
                        isChange = true
                    }
                    updatedOutput["isOursBitcoind"] = solvable
                    updatedOutput["hdKeyPath"] = keypath
                    updatedOutput["isChange"] = isChange
                    updatedOutput["label"] = labelsText
                    updatedOutput["fingerprint"] = fingerprint
                    updatedOutput["desc"] = desc
                    
                    // Currently only verify address if the node knows about it.. otherwise we have to brute force 200k addresses...
                    // will add a dedicated verify button for unsolvable to cross check against all wallets
                    // also adding a signer verify button to show whether FN is able to sign for the output or not
                    
                    Keys.verifyAddress(parentDesc: parentDesc, passphrase: self.passphrase) { (_, nodeWalletLabel, signable, signer) in
                        // Confirm locally from our own descriptors before saying it's ours.
                        self.locallyVerifyOutput(address: address, keyPath: keypath) { local in
                            self.applyLocalVerification(local, nodeSaysChange: isChange, to: &updatedOutput)
                            updatedOutput["signable"] = signable
                            updatedOutput["signerLabel"] = signer
                        
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                            
                                resetActiveWallet()
                                self.outputArray[int] = updatedOutput
                                self.verifyTable.reloadData()
                                self.finishActivity()
                                if local.isOurs {
                                    showAlert(vc: self, title: "", message: "Owned by \(local.walletLabel ?? "your wallet") ✓ (verified from the wallet's descriptors)")
                                } else {
                                    showAlert(vc: self, title: "⚠️ Not verified", message: "The node says this address belongs to \(nodeWalletLabel ?? "one of its wallets"), but Fully Noded couldn't derive it from any of your wallets' descriptors.")
                                }
                            }
                        }
                        
                        return
                    }
                } else {
                    self.walletIndex += 1
                    self.checkEachWallet(address, walletsToCheck, int)
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                resetActiveWallet()
                self.verifyTable.reloadData()
                self.finishActivity()
                showAlert(vc: self, title: "", message: "Address not owned by any of the FN Wallets associated with this node.")
            }
        }
    }

    /// Other Fully Noded wallets loaded on this node, then checks each for `address`.
    func getBitcoinCoreWallets(_ address: String, _ int: Int) {
        OnchainUtils.listWalletDir { [weak self] (walletDir, message) in
            guard let self = self else { return }
            
            guard let walletDir = walletDir else {
                DispatchQueue.main.async {
                    self.finishActivity()
                    displayAlert(viewController: self, isError: true, message: "error getting wallets: \(message ?? "")")
                }
                return
            }
            
            let onNode = Set(walletDir.wallets)
            CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
                guard let self = self, let activeWallet = self.wallet else { return }
                let walletsToCheck = (wallets ?? [])
                    .filter { $0["id"] != nil }
                    .map { Wallet(dictionary: $0) }
                    .filter { $0.id != activeWallet.id && onNode.contains($0.name) }
                    .map { $0.name }
                self.walletIndex = 0
                self.checkEachWallet(address, walletsToCheck, int)
            }
        }
    }

    func loadLabelAndMemo() {
        CoreDataService.retrieveEntity(entityName: .transactions) { [weak self] transactions in
            guard let self = self else { return }
            
            guard let transactions = transactions, transactions.count > 0 else {
                self.saveNewTx(self.txid)
                return
            }
            
            var alreadySaved = false
            
            for (i, transaction) in transactions.enumerated() {
                let txStruct = TransactionStruct(dictionary: transaction)
                if txStruct.txid == self.txid {
                    alreadySaved = true
                    self.id = txStruct.id!
                    self.labelText = txStruct.label
                }
                
                if i + 1 == transactions.count && !alreadySaved {
                    self.saveNewTx(self.txid)
                }
            }
        }
    }
}
