//
//  Transaction.swift
//  Transaction
//
//  Created by Sjors Provoost on 18/06/2019.
//  Copyright © 2019 Blockchain. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md

import Foundation
import CLibWally

public typealias Satoshi = UInt64

public struct TxOutput {
    let wally_tx_output: wally_tx_output
    public let network: Network
    public var amount: Satoshi {
        return self.wally_tx_output.satoshi
    }
    public let scriptPubKey: ScriptPubKey
    public var address: String? {
        if let address = Address(self.scriptPubKey, self.network) {
            return address.description
        }
        return nil
    }

    public init (_ scriptPubKey: ScriptPubKey, _ amount: Satoshi, _ network: Network) {
        self.network = network
        self.scriptPubKey = scriptPubKey

        var scriptpubkey_bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: scriptPubKey.bytes.count)
        let scriptpubkey_bytes_len = scriptPubKey.bytes.count

        scriptPubKey.bytes.copyBytes(to: scriptpubkey_bytes, count: scriptpubkey_bytes_len)

        var output: UnsafeMutablePointer<wally_tx_output>?
        defer {
            if let wally_tx_output = output {
                wally_tx_output.deallocate()
            }
        }
        precondition(wally_tx_output_init_alloc(amount, scriptpubkey_bytes, scriptpubkey_bytes_len, &output) == WALLY_OK)
        precondition(output != nil)
        self.wally_tx_output = output!.pointee
    }
    
    public init (tx_output: wally_tx_output, scriptPubKey: ScriptPubKey, network: Network) {
        self.network = network
        self.wally_tx_output = tx_output
        self.scriptPubKey = scriptPubKey
    }
}

public struct TxInput {
    var wally_tx_input: UnsafeMutablePointer<wally_tx_input>?
    let transaction: Transaction
    public var vout: UInt32 {
        return self.wally_tx_input!.pointee.index
    }
    public var sequence: UInt32 {
        return self.wally_tx_input!.pointee.sequence
    }
    public var scriptPubKey: ScriptPubKey
    public var scriptSig: ScriptSig?
    public var witness: Witness?
    public var amount: Satoshi

    // For P2SH wrapped SegWit, we set scriptSig automatically
    public init? (_ tx: Transaction, _ vout: UInt32, _ amount: Satoshi, _ scriptSig: ScriptSig?, _ witness: Witness?, _ scriptPubKey: ScriptPubKey) {
        if tx.hash == nil {
            return nil
        }

        self.witness = witness
        
        if (witness == nil) {
            self.scriptSig = scriptSig
        } else {
            switch witness!.type {
            case .payToWitnessPubKeyHash(_):
                break
            case .payToScriptHashPayToWitnessPubKeyHash(let pubKey):
                self.scriptSig = ScriptSig(.payToScriptHashPayToWitnessPubKeyHash(pubKey))
            }
        }
        
        self.scriptPubKey = scriptPubKey
        
        
        self.amount = amount

        let sequence: UInt32 = 0xFFFFFFFF
        
        self.transaction = tx

        let tx_hash_bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: tx.hash!.count)
        let tx_hash_bytes_len = tx.hash!.count

        tx.hash!.copyBytes(to: tx_hash_bytes, count: tx_hash_bytes_len)

        precondition(wally_tx_input_init_alloc(tx_hash_bytes, tx_hash_bytes_len, vout, sequence, nil, 0, self.witness == nil ? nil : self.witness!.stack!, &self.wally_tx_input) == WALLY_OK)
        precondition(self.wally_tx_input != nil)

    }

    public var signed: Bool {
        return (self.scriptSig != nil && self.scriptSig!.signature != nil) || (self.witness != nil && !self.witness!.dummy)
    }
}

public struct Transaction {
    var hash: Data? = nil
    
    var wally_tx: UnsafeMutablePointer<wally_tx>?
    
    public var inputs: [TxInput]? = nil
    var outputs: [TxOutput]? = nil
    
    init (_ wally_tx: wally_tx) {
        self.wally_tx = UnsafeMutablePointer<wally_tx>.allocate(capacity: 1)
        self.wally_tx!.initialize(to: wally_tx)
    }

    public init? (_ description: String) {
        if let hex = Data(description) {
            if hex.count != SHA256_LEN { // Not a transaction hash
                var tx_bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: hex.count)
                hex.copyBytes(to: tx_bytes, count: hex.count)
                defer {
                    tx_bytes.deallocate()
                }
                if (wally_tx_from_bytes(tx_bytes, hex.count, UInt32(WALLY_TX_FLAG_USE_WITNESS), &self.wally_tx) == WALLY_OK) {
                    precondition(self.wally_tx != nil)
                    return
                }
            }
            if hex.count == SHA256_LEN { // 32 bytes, but not a valid transaction, so treat as a hash
                self.hash = Data(hex.reversed())
                return
            }
        }
        return nil
    }
    
    public init (_ inputs: [TxInput], _ outputs: [TxOutput]) {
        self.inputs = inputs
        self.outputs = outputs
        
        let version: UInt32 = 1
        let lockTime: UInt32 = 0
        
        precondition(wally_tx_init_alloc(version, lockTime, inputs.count, outputs.count, &self.wally_tx) == WALLY_OK)
        precondition(self.wally_tx != nil)
        
        for input in inputs {
            self.addInput(input)
        }
        
        for output in outputs {
            self.addOutput(output)
        }
    }
    
    public var description: String? {
        if (self.wally_tx == nil) {
            return nil
        }
        // If we have TxInput objects, make sure they're all signed. Otherwise we've been initialized
        // from a hex string, so we'll just try to reserialize what we have.
        if (self.inputs != nil) {
            for input in self.inputs! {
                if !input.signed {
                    return nil
                }
            }
        }
        
        var output: UnsafeMutablePointer<Int8>?
        defer {
            wally_free_string(output)
        }
        
        precondition(wally_tx_to_hex(self.wally_tx, UInt32(WALLY_TX_FLAG_USE_WITNESS), &output) == WALLY_OK)
        precondition(output != nil)
        return String(cString: output!)
    }
    
    mutating func addInput (_ input: TxInput) {
        precondition(wally_tx_add_input(self.wally_tx, input.wally_tx_input) == WALLY_OK)
    }
    
    mutating func addOutput (_ output: TxOutput) {
        let tx_output = UnsafeMutablePointer<wally_tx_output>.allocate(capacity: 1)
        defer {
            tx_output.deallocate()
        }
        tx_output.pointee = output.wally_tx_output
        
        precondition(wally_tx_add_output(self.wally_tx, tx_output) == WALLY_OK)
    }
    
    var totalIn: Satoshi? {
        var tally: Satoshi = 0
        if let inputs = self.inputs {
            for input in inputs {
                tally += input.amount
            }
        } else {
            return nil
        }
        
        return tally
    }
    
    var totalOut: Satoshi? {
        if (self.wally_tx == nil) {
            return nil
        }
        var value_out = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer {
            value_out.deallocate()
        }
        
        precondition(wally_tx_get_total_output_satoshi(self.wally_tx, value_out) == WALLY_OK)
        
        return value_out.pointee;
    }
    
    var funded: Bool? {
        if let totalOut = self.totalOut {
            if let totalIn = self.totalIn {
                return totalOut <= totalIn
            }
        }
        return nil
    }
    
    public var vbytes: Int? {
        if (self.wally_tx == nil) {
            return nil
        }
        
        precondition(self.inputs != nil)

        // Set scriptSig for all unsigned inputs to .feeWorstCase
        for (index, input) in self.inputs!.enumerated() {
            if (!input.signed) {
                if let scriptSig = input.scriptSig {
                    let scriptSigWorstCase = scriptSig.render(.feeWorstCase)!
                    let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: scriptSigWorstCase.count)
                    let bytes_len = scriptSigWorstCase.count
                    scriptSigWorstCase.copyBytes(to: bytes, count: bytes_len)
                    precondition(wally_tx_set_input_script(self.wally_tx, index, bytes, bytes_len) == WALLY_OK)
                }
            }
        }
        
        var value_out = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        defer {
            value_out.deallocate()
        }
        
        precondition(wally_tx_get_vsize(self.wally_tx, value_out) == WALLY_OK)
        
        return value_out.pointee;
    }
    
    public var fee: Satoshi? {
        if let totalOut = self.totalOut {
            if let totalIn = self.totalIn {
                if totalIn >= totalOut {
                    return self.totalIn! - self.totalOut!
                }
            }
        }
        return nil
    }
    
    public var feeRate: Float64? {
        if let fee = self.fee {
            if let vbytes = self.vbytes {
                precondition(vbytes > 0)
                return Float64(fee) / Float64(vbytes)
            }
        }
        return nil
    }
    
    public mutating func sign (_ privKeys: [HDKey]) -> Bool {
        if self.wally_tx == nil {
            return false
        }
        precondition(self.inputs != nil)
        if privKeys.count != self.inputs!.count {
            return false
        }
        
        // Loop through inputs to sign:
        for (i, _) in self.inputs!.enumerated() {
            let hasWitness = self.inputs![i].witness != nil
            
            var message_bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(SHA256_LEN))
            defer {
                message_bytes.deallocate()
            }
            
            if (hasWitness) {
                switch (self.inputs![i].witness!.type) {
                case .payToScriptHashPayToWitnessPubKeyHash(let pubKey):
                    let scriptSig = self.inputs![i].scriptSig!.render(.signed)!
                    let bytes_scriptsig = UnsafeMutablePointer<UInt8>.allocate(capacity: scriptSig.count)
                    let bytes_scriptsig_len = scriptSig.count
                    scriptSig.copyBytes(to: bytes_scriptsig, count: bytes_scriptsig_len)
                    
                    precondition(wally_tx_set_input_script(self.wally_tx, i, bytes_scriptsig, bytes_scriptsig_len) == WALLY_OK)

                    fallthrough
                case .payToWitnessPubKeyHash(let pubKey):
                    // Check that we're using the right public key:
                    var tmp = privKeys[i].wally_ext_key.pub_key
                    let pub_key = [UInt8](UnsafeBufferPointer(start: &tmp.0, count: Int(EC_PUBLIC_KEY_LEN)))
                    let pubKeyData = Data(pub_key)
                    precondition(pubKey.data == pubKeyData)
                    
                    let scriptCode = self.inputs![i].witness!.scriptCode
                    let scriptcode_bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: scriptCode.count)
                    scriptCode.copyBytes(to: scriptcode_bytes, count: scriptCode.count)

                    
                    precondition(wally_tx_get_btc_signature_hash(self.wally_tx, i, scriptcode_bytes, scriptCode.count, self.inputs![i].amount, UInt32(WALLY_SIGHASH_ALL), UInt32(WALLY_TX_FLAG_USE_WITNESS), message_bytes, Int(SHA256_LEN)) == WALLY_OK)
                }
            } else {
                // Prep input for signing:
                let scriptPubKey = self.inputs![i].scriptPubKey.bytes
                let scriptpubkey_bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: scriptPubKey.count)
                scriptPubKey.copyBytes(to: scriptpubkey_bytes, count: scriptPubKey.count)

                // Create hash for signing
                precondition(wally_tx_get_btc_signature_hash(self.wally_tx, i, scriptpubkey_bytes, scriptPubKey.count, 0, UInt32(WALLY_SIGHASH_ALL), 0, message_bytes, Int(SHA256_LEN)) == WALLY_OK)
            }
            
            var compact_sig_bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(EC_SIGNATURE_LEN))
            defer {
                compact_sig_bytes.deallocate()
            }
            
            // Sign hash using private key (without 0 prefix)
            precondition(EC_MESSAGE_HASH_LEN == SHA256_LEN)
            
            var tmp = privKeys[i].wally_ext_key.priv_key
            let privKey = [UInt8](UnsafeBufferPointer(start: &tmp.1, count: Int(EC_PRIVATE_KEY_LEN)))
            // Ensure private key is valid
            precondition(wally_ec_private_key_verify(privKey, Int(EC_PRIVATE_KEY_LEN)) == WALLY_OK)
        
            precondition(wally_ec_sig_from_bytes(privKey, Int(EC_PRIVATE_KEY_LEN), message_bytes, Int(EC_MESSAGE_HASH_LEN), UInt32(EC_FLAG_ECDSA | EC_FLAG_GRIND_R), compact_sig_bytes, Int(EC_SIGNATURE_LEN)) == WALLY_OK)
        
            // Check that signature is valid and for the correct public key:
            var tmpPub = privKeys[i].wally_ext_key.pub_key
            let pubKey = [UInt8](UnsafeBufferPointer(start: &tmpPub.0, count: Int(EC_PUBLIC_KEY_LEN)))
            precondition(wally_ec_sig_verify(pubKey, Int(EC_PUBLIC_KEY_LEN), message_bytes, Int(EC_MESSAGE_HASH_LEN), UInt32(EC_FLAG_ECDSA), compact_sig_bytes, Int(EC_SIGNATURE_LEN)) == WALLY_OK)
            
            // Convert to low s form:
            let sig_norm_bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(EC_SIGNATURE_LEN))
            defer {
                sig_norm_bytes.deallocate()
            }
            precondition(wally_ec_sig_normalize(compact_sig_bytes, Int(EC_SIGNATURE_LEN), sig_norm_bytes, Int(EC_SIGNATURE_LEN)) == WALLY_OK)
            
            // Convert normalized signature to DER
            let sig_bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(EC_SIGNATURE_DER_MAX_LEN))
            var sig_bytes_written = UnsafeMutablePointer<Int>.allocate(capacity: 1)
            defer {
                sig_bytes.deallocate()
                sig_bytes_written.deallocate()
            }
            precondition(wally_ec_sig_to_der(sig_norm_bytes, Int(EC_SIGNATURE_LEN), sig_bytes, Int(EC_SIGNATURE_DER_MAX_LEN), sig_bytes_written) == WALLY_OK)
            
            // Store signature in TxInput
            let signature =  Data(bytes: sig_bytes, count: sig_bytes_written.pointee)
            if (hasWitness) {
                let witness = self.inputs![i].witness!.signed(signature)
                self.inputs![i].witness = witness
                precondition(wally_tx_set_input_witness(self.wally_tx!, i, witness.stack!) == WALLY_OK)
            } else {
                self.inputs![i].scriptSig!.signature = signature
                
                // Update scriptSig:
                let signedScriptSig = self.inputs![i].scriptSig!.render(.signed)!
                let bytes_signed_scriptsig = UnsafeMutablePointer<UInt8>.allocate(capacity: signedScriptSig.count)
                let bytes_signed_scriptsig_len = signedScriptSig.count
                signedScriptSig.copyBytes(to: bytes_signed_scriptsig, count: bytes_signed_scriptsig_len)
                
                precondition(wally_tx_set_input_script(self.wally_tx, i, bytes_signed_scriptsig, bytes_signed_scriptsig_len) == WALLY_OK)
            }
        }

        return true
    }

}
