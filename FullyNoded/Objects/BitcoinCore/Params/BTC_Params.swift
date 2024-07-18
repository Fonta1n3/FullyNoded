//
//  BTC_Params.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/10/22.
//  Copyright © 2022 Fontaine. All rights reserved.
//
import Foundation

public struct BTC_Params: CustomStringConvertible {
    
    let param: [String:Any]?
    
    init(_ command: BTC_CLI_COMMAND) {
        param = command.paramDict
    }
    
    public var description: String {
        return ""
    }
}

public struct Create_Wallet_Param: CustomStringConvertible {
    public var description: String {
        return ""
    }
    
    /*
     
      1. wallet_name             (string, required) The name for the new wallet. If this is a path, the wallet will be created at the path location.
      2. disable_private_keys    (boolean, optional, default=false) Disable the possibility of private keys (only watchonlys are possible in this mode).
      3. blank                   (boolean, optional, default=false) Create a blank wallet. A blank wallet has no keys or HD seed. One can be set using sethdseed.
      4. passphrase              (string, optional) Encrypt the wallet with this passphrase.
      5. avoid_reuse             (boolean, optional, default=false) Keep track of coin reuse, and treat dirty and clean coins differently with privacy considerations in mind.
      6. descriptors             (boolean, optional, default=true) Create a native descriptor wallet. The wallet will use descriptors internally to handle address creation
      7. load_on_startup         (boolean, optional) Save wallet name to persistent settings and load on startup. True to add wallet to startup list, false to remove, null to leave unchanged.
      8. external_signer          (boolean, optional, default=false) Use an external signer such as a hardware wallet. Requires -signer to be configured. Wallet creation will fail if keys cannot be fetched. Requires disable_private_keys and descriptors set to true.
      
     
     {\"wallet_name\":\"\(walletName)\",\"avoid_reuse\":true,\"descriptors\":true,\"load_on_startup\":true,\"disable_private_keys\":true}"
     */
    
    let param: [String:Any]
    
    init(_ dict: [String:Any]) {
        let wallet_name = dict["wallet_name"] as! String
        let disable_private_keys = dict["disable_private_keys"] as? Bool ?? true
        let blank = dict["blank"] as? Bool ?? false
        let passphrase = dict["passphrase"] as? String ?? ""
        param = [
            "wallet_name": wallet_name,
            "disable_private_keys": disable_private_keys,
            "blank": blank,
            "passphrase": passphrase,
            "avoid_reuse": true,
            "descriptors": true,
            "load_on_startup": true
        ]
    }
    
}

public struct Get_Balance_Param: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     1. dummy                (string, optional) Remains for backward compatibility. Must be excluded or set to "*".
     2. minconf              (numeric, optional, default=0) Only include transactions confirmed at least this many times.
     3. include_watchonly    (boolean, optional, default=true for watch-only wallets, otherwise false) Also include balance in watch-only addresses (see 'importaddress')
     4. avoid_reuse          (boolean, optional, default=true) (only available if avoid_reuse wallet flag is set) Do not include balance in dirty outputs; addresses are considered dirty if they have previously been used in a transaction.
     */
    let param:[String:Any]
    
    init(_ dict: [String:Any]) {
        let dummy = dict["dummy"] as? String ?? "*"
        let minconf = dict["minconf"] as? Int ?? 0
        let include_watchonly = dict["include_watchonly"] as? Bool ?? true
        let avoid_reuse = dict["avoid_reuse"] as? Bool ?? false
        param = ["dummy":dummy,"minconf":minconf,"include_watchonly":include_watchonly,"avoid_reuse":avoid_reuse]
    }
}

public struct Estimate_Smart_Fee_Param: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. conf_target      (numeric, required) Confirmation target in blocks (1 - 1008)
     2. estimate_mode    (string, optional, default="conservative") The fee estimate mode.
                         Whether to return a more conservative estimate which also satisfies
                         a longer history. A conservative estimate potentially returns a
                         higher feerate and is more likely to be sufficient for the desired
                         target, but is not as responsive to short term drops in the
                         prevailing fee market. Must be one of (case insensitive):
                         "unset"
                         "economical"
                         "conservative"
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let conf_target = dict["conf_target"] as? Int ?? 0
        let estimate_mode = dict["estimate_mode"] as? String ?? "conservative"
        param = ["conf_target":conf_target, "estimate_mode":estimate_mode]
    }
}

public struct Get_Descriptor_Info: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. descriptor    (string, required) The descriptor.
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let desc = dict["descriptor"] as? String ?? ""
        param = ["descriptor": desc]
    }
}

public struct Import_Descriptors: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. requests                                 (json array, required) Data to be imported
          [
            {                                    (json object)
              "desc": "str",                     (string, required) Descriptor to import.
              "active": bool,                    (boolean, optional, default=false) Set this descriptor to be the active descriptor for the corresponding output type/externality
              "range": n or [n,n],               (numeric or array) If a ranged descriptor is used, this specifies the end or the range (in the form [begin,end]) to import
              "next_index": n,                   (numeric) If a ranged descriptor is set to active, this specifies the next index to generate addresses from
              "timestamp": timestamp | "now",    (integer / string, required) Time from which to start rescanning the blockchain for this descriptor, in UNIX epoch time
                                                 Use the string "now" to substitute the current synced blockchain time.
                                                 "now" can be specified to bypass scanning, for outputs which are known to never have been used, and
                                                 0 can be specified to scan the entire blockchain. Blocks up to 2 hours before the earliest timestamp
                                                 of all descriptors being imported will be scanned.
              "internal": bool,                  (boolean, optional, default=false) Whether matching outputs should be treated as not incoming payments (e.g. change)
              "label": "str",                    (string, optional, default="") Label to assign to the address, only allowed with internal=false. Disabled for ranged descriptors
            },
            ...
          ]
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let requests = dict["requests"] as! [[String:Any]]
        var parts:[[String:Any]] = []
        for request in requests {
            let desc = request["desc"] as? String ?? ""
            let active = request["active"] as? Bool ?? false
            let range = request["range"] as? [Int] ?? []
            let next_index = request["next_index"] as? Int ?? 0
            let timestamp = request["timestamp"] as? String ?? "now"
            let internal_ = request["internal"] as? Bool ?? false
            let label = request["label"] as? String ?? ""
            
            if range.count > 0 {
                let part = [
                    "desc":desc,
                    "active":active,
                    "range":range,
                    "next_index":next_index,
                    "timestamp":timestamp,
                    "internal":internal_,
                ] as [String:Any]
                
                parts.append(part)
            } else {
                let part = [
                    "desc":desc,
                    "active":active,
                    "range":range,
                    "next_index":next_index,
                    "timestamp":timestamp,
                    "internal":internal_,
                    "label": label
                ] as [String:Any]
                
                parts.append(part)
            }
        }
        param = [
            "requests": parts
        ]
    }
}

public struct Analyze_PSBT: CustomStringConvertible {
    public var description: String {
        return ""
    }
    
    let param:[String: Any]
    /*
     Arguments:
     1. psbt           (string, required) The transaction base64 string
     */
    
    init(_ dict: [String: Any]) {
        let psbt = dict["psbt"] as? String ?? ""
        
        param = [
            "psbt": psbt
        ]
    }
}

public struct Wallet_Process_PSBT: CustomStringConvertible {
    public var description: String {
        return ""
    }
    
    let param:[String:Any]
    /*
     Arguments:
     1. psbt           (string, required) The transaction base64 string
     2. sign           (boolean, optional, default=true) Also sign the transaction when updating (requires wallet to be unlocked)
     3. sighashtype    (string, optional, default="DEFAULT for Taproot, ALL otherwise") The signature hash type to sign with if not specified by the PSBT. Must be one of
                       "DEFAULT"
                       "ALL"
                       "NONE"
                       "SINGLE"
                       "ALL|ANYONECANPAY"
                       "NONE|ANYONECANPAY"
                       "SINGLE|ANYONECANPAY"
     4. bip32derivs    (boolean, optional, default=true) Include BIP 32 derivation paths for public keys if we know them
     5. finalize       (boolean, optional, default=true) Also finalize inputs if possible
     */
    
    init(_ dict: [String:Any]) {
        let psbt = dict["psbt"] as? String ?? ""
        let sign = dict["sign"] as? Bool ?? true
        let sighashtype = dict["sighashtype"] as? String ?? "ALL"
        let bip32derivs = dict["bip32derivs"] as? Bool ?? true
        let finalize = dict["finalize"] as? Bool ?? true
        
        param = [
            "psbt": psbt,
            "sign": sign,
            "bip32derivs": bip32derivs,
            "sighashtype": sighashtype,
            "finalize": finalize
        ]
    }
}

public struct Wallet_Passphrase: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. passphrase    (string, required) The wallet passphrase
     2. timeout       (numeric, required) The time to keep the decryption key in seconds; capped at 100000000 (~3 years).
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let passphrase = dict["passphrase"] as? String ?? ""
        let timeout = dict["timeout"] as? Int ?? 0
        param = ["passphrase": passphrase, "timeout": timeout]
    }
}

public struct Derive_Addresses: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. descriptor    (string, required) The descriptor.
     2. range         (numeric or array, optional) If a ranged descriptor is used, this specifies the end or the range (in [begin,end] notation) to derive.
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let descriptor = dict["descriptor"] as? String ?? ""
        let range = dict["range"] as? [Int] ?? []
        param = ["descriptor": descriptor, "range": range]
    }
}

public struct Get_New_Address: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. label           (string, optional, default="") The label name for the address to be linked to. It can also be set to the empty string "" to represent the default label. The label does not need to exist, it will be created if there is no label by the given name.
     2. address_type    (string, optional, default=set by -addresstype) The address type to use. Options are "legacy", "p2sh-segwit", "bech32", and "bech32m".
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let label = dict["label"] as? String ?? ""
        let address_type = dict["address_type"] as? String ?? ""
        param = ["label": label, "address_type": address_type]
    }
}

public struct Bump_Fee: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. txid                           (string, required) The txid to be bumped
     2. options                        (json object, optional)
          {
            "conf_target": n,          (numeric, optional, default=wallet -txconfirmtarget) Confirmation target in blocks
                                       
            "fee_rate": amount,        (numeric or string, optional, default=not set, fall back to wallet fee estimation)
                                       Specify a fee rate in sat/vB instead of relying on the built-in fee estimator.
                                       Must be at least 1.000 sat/vB higher than the current transaction fee rate.
                                       WARNING: before version 0.21, fee_rate was in BTC/kvB. As of 0.21, fee_rate is in sat/vB.
                                       
            "replaceable": bool,       (boolean, optional, default=true) Whether the new transaction should still be
                                       marked bip-125 replaceable. If true, the sequence numbers in the transaction will
                                       be left unchanged from the original. If false, any input sequence numbers in the
                                       original transaction that were less than 0xfffffffe will be increased to 0xfffffffe
                                       so the new transaction will not be explicitly bip-125 replaceable (though it may
                                       still be replaceable in practice, for example if it has unconfirmed ancestors which
                                       are replaceable).
                                       
            "estimate_mode": "str",    (string, optional, default="unset") The fee estimate mode, must be one of (case insensitive):
                                       "unset"
                                       "economical"
                                       "conservative"
          }
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let txid = dict["txid"] as? String ?? ""
        let options:[String:Any] = dict["options"] as? [String:Any] ?? [:]
        param = ["txid": txid, "options": options]
    }
}

public struct PSBT_Bump_Fee: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. txid                           (string, required) The txid to be bumped
     2. options                        (json object, optional)
          {
            "conf_target": n,          (numeric, optional, default=wallet -txconfirmtarget) Confirmation target in blocks
                                       
            "fee_rate": amount,        (numeric or string, optional, default=not set, fall back to wallet fee estimation)
                                       Specify a fee rate in sat/vB instead of relying on the built-in fee estimator.
                                       Must be at least 1.000 sat/vB higher than the current transaction fee rate.
                                       WARNING: before version 0.21, fee_rate was in BTC/kvB. As of 0.21, fee_rate is in sat/vB.
                                       
            "replaceable": bool,       (boolean, optional, default=true) Whether the new transaction should still be
                                       marked bip-125 replaceable. If true, the sequence numbers in the transaction will
                                       be left unchanged from the original. If false, any input sequence numbers in the
                                       original transaction that were less than 0xfffffffe will be increased to 0xfffffffe
                                       so the new transaction will not be explicitly bip-125 replaceable (though it may
                                       still be replaceable in practice, for example if it has unconfirmed ancestors which
                                       are replaceable).
                                       
            "estimate_mode": "str",    (string, optional, default="unset") The fee estimate mode, must be one of (case insensitive):
                                       "unset"
                                       "economical"
                                       "conservative"
          }
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let txid = dict["txid"] as? String ?? ""
        let options:[String:Any] = dict["options"] as? [String:Any] ?? [:]
        param = ["txid": txid, "options": options]
    }
}

public struct Send_Raw_Transaction: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. hexstring     (string, required) The hex string of the raw transaction
     2. maxfeerate    (numeric or string, optional, default="0.10") Reject transactions whose fee rate is higher than the specified value, expressed in BTC/kvB.
                      Set to 0 to accept any fee rate.
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let hexstring = dict["hexstring"] as? String ?? ""
        param = ["hexstring": hexstring]
    }
}

public struct Decode_Psbt: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. psbt    (string, required) The PSBT base64 string
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let psbt = dict["psbt"] as? String ?? ""
        param = ["psbt": psbt]
    }
}

public struct Decode_Raw_Tx: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. hexstring    (string, required) The transaction hex string
     2. iswitness    (boolean, optional, default=depends on heuristic tests) Whether the transaction hex is a serialized witness transaction.
                     If iswitness is not present, heuristic tests will be used in decoding.
                     If true, only witness deserialization will be tried.
                     If false, only non-witness deserialization will be tried.
                     This boolean should reflect whether the transaction has inputs
                     (e.g. fully valid, or on-chain transactions), if known by the caller.
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let hexstring = dict["hexstring"] as? String ?? ""
        //let iswitness = dict["iswitness"] as? Bool
        param = ["hexstring": hexstring]
    }
}

public struct Get_Address_Info: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. address    (string, required) The bitcoin address for which to get information.
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let address = dict["address"] as? String ?? ""
        param = ["address": address]
    }
}

public struct Test_Mempool_Accept: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. rawtxs          (json array, required) An array of hex strings of raw transactions.
          [
            "rawtx",    (string)
            ...
          ]
     2. maxfeerate      (numeric or string, optional, default="0.10") Reject transactions whose fee rate is higher than the specified value, expressed in BTC/kvB
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let rawtxs = dict["rawtxs"] as? [String] ?? []
        param = ["rawtxs": rawtxs]
    }
}

public struct Get_Raw_Tx: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. txid         (string, required) The transaction id
     2. verbose      (boolean, optional, default=false) If false, return a string, otherwise return a json object
     3. blockhash    (string, optional) The block in which to look for the transaction
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let txid = dict["txid"] as? String ?? ""
        param = ["txid": txid]
    }
}

public struct Get_Tx: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. txid                 (string, required) The transaction id
     2. include_watchonly    (boolean, optional, default=true for watch-only wallets, otherwise false) Whether to include watch-only addresses in balance calculation and details[]
     3. verbose              (boolean, optional, default=false) Whether to include a `decoded` field containing the decoded transaction (equivalent to RPC decoderawtransaction)
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let txid = dict["txid"] as? String ?? ""
        let verbose = dict["verbose"] as? Bool ?? false
        let include_watchonly = dict["include_watchonly"] as? Bool ?? true
        param = ["txid": txid, "verbose": verbose, "include_watchonly": include_watchonly]
    }
}

public struct Lock_Unspent: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. unlock                  (boolean, required) Whether to unlock (true) or lock (false) the specified transactions
     2. transactions            (json array, optional, default=[]) The transaction outputs and within each, the txid (string) vout (numeric).
          [
            {                   (json object)
              "txid": "hex",    (string, required) The transaction id
              "vout": n,        (numeric, required) The output number
            },
            ...
          ]
     3. persistent              (boolean, optional, default=false) Whether to write/erase this lock in the wallet database, or keep the change in memory only. Ignored for unlocking.
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let unlock = dict["unlock"] as! Bool
        let txs:[[String:Any]] = dict["transactions"] as? [[String:Any]] ?? [[:]]
        param = ["unlock": unlock, "transactions": txs]
    }
}

public struct Wallet_Create_Funded_Psbt: CustomStringConvertible {
    public var description: String {
        return ""
    }
    
    /*
     Arguments:
     1. inputs                             (json array, optional) Leave empty to add inputs automatically. See add_inputs option.
          [
            {                              (json object)
              "txid": "hex",               (string, required) The transaction id
              "vout": n,                   (numeric, required) The output number
              "sequence": n,               (numeric, optional, default=depends on the value of the 'locktime' and 'options.replaceable' arguments) The sequence number
              "weight": n,                 (numeric, optional, default=Calculated from wallet and solving data) The maximum weight for this input, including the weight of the outpoint and sequence number. Note that signature sizes are not guaranteed to be consistent, so the maximum DER signatures size of 73 bytes should be used when considering ECDSA signatures.Remember to convert serialized sizes to weight units when necessary.
            },
            ...
          ]
     2. outputs                            (json array, required) The outputs (key-value pairs), where none of the keys are duplicated.
                                           That is, each address can only appear once and there can only be one 'data' object.
                                           For compatibility reasons, a dictionary, which holds the key-value pairs directly, is also
                                           accepted as second parameter.
          [
            {                              (json object)
              "address": amount,           (numeric or string, required) A key-value pair. The key (string) is the bitcoin address, the value (float or string) is the amount in BTC
              ...
            },
            {                              (json object)
              "data": "hex",               (string, required) A key-value pair. The key must be "data", the value is hex-encoded data
            },
            ...
          ]
     3. locktime                           (numeric, optional, default=0) Raw locktime. Non-0 value also locktime-activates inputs
     4. options                            (json object, optional)
          {
            "add_inputs": bool,            (boolean, optional, default=false) If inputs are specified, automatically include more if they are not enough.
            "include_unsafe": bool,        (boolean, optional, default=false) Include inputs that are not safe to spend (unconfirmed transactions from outside keys and unconfirmed replacement transactions).
                                           Warning: the resulting transaction may become invalid if one of the unsafe inputs disappears.
                                           If that happens, you will need to fund the transaction with different inputs and republish it.
            "changeAddress": "hex",        (string, optional, default=pool address) The bitcoin address to receive the change
            "changePosition": n,           (numeric, optional, default=random) The index of the change output
            "change_type": "str",          (string, optional, default=set by -changetype) The output type to use. Only valid if changeAddress is not specified. Options are "legacy", "p2sh-segwit", and "bech32".
            "includeWatching": bool,       (boolean, optional, default=true for watch-only wallets, otherwise false) Also select inputs which are watch only
            "lockUnspents": bool,          (boolean, optional, default=false) Lock selected unspent outputs
            "fee_rate": amount,            (numeric or string, optional, default=not set, fall back to wallet fee estimation) Specify a fee rate in sat/vB.
            "feeRate": amount,             (numeric or string, optional, default=not set, fall back to wallet fee estimation) Specify a fee rate in BTC/kvB.
            "subtractFeeFromOutputs": [    (json array, optional, default=[]) The outputs to subtract the fee from.
                                           The fee will be equally deducted from the amount of each specified output.
                                           Those recipients will receive less bitcoins than you enter in their corresponding amount field.
                                           If no outputs are specified here, the sender pays the fee.
              vout_index,                  (numeric) The zero-based output index, before a change output is added.
              ...
            ],
            "conf_target": n,              (numeric, optional, default=wallet -txconfirmtarget) Confirmation target in blocks
            "estimate_mode": "str",        (string, optional, default="unset") The fee estimate mode, must be one of (case insensitive):
                                           "unset"
                                           "economical"
                                           "conservative"
            "replaceable": bool,           (boolean, optional, default=wallet default) Marks this transaction as BIP125-replaceable.
                                           Allows this transaction to be replaced by a transaction with higher fees
            "solving_data": {              (json object, optional) Keys and scripts needed for producing a final transaction with a dummy signature.
                                           Used for fee estimation during coin selection.
              "pubkeys": [                 (json array, optional, default=[]) Public keys involved in this transaction.
                "pubkey",                  (string) A public key
                ...
              ],
              "scripts": [                 (json array, optional, default=[]) Scripts involved in this transaction.
                "script",                  (string) A script
                ...
              ],
              "descriptors": [             (json array, optional, default=[]) Descriptors that provide solving data for this transaction.
                "descriptor",              (string) A descriptor
                ...
              ],
            },
          }
     5. bip32derivs                        (boolean, optional, default=true) Include BIP 32 derivation paths for public keys if we know them

     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let inputs = dict["inputs"] as? [[String:Any]] ?? []
        let outputs = dict["outputs"] as? [[String:Any]] ?? []
        //let locktime = dict["locktime"] as? Int ?? 0
        let options = dict["options"] as? [String:Any] ?? [:]
        let bip32derivs = dict["bip32derivs"] as? Bool ?? true
        param = [
            "inputs": inputs,
            "outputs": outputs,
            //"locktime": locktime,
            "options": options,
            "bip32derivs": bip32derivs
        ]
    }
}

public struct Encrypt_Wallet: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. passphrase    (string, required) The pass phrase to encrypt the wallet with. It must be at least 1 character, but should be long.
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let passphrase = dict["passphrase"] as? String ?? ""
        param = ["passphrase": passphrase]
    }
}


public struct Wallet_Change_Passphrase: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     //Arguments:
     1. oldpassphrase    (string, required) The current passphrase
     2. newpassphrase    (string, required) The new passphrase
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let oldpassphrase = dict["oldpassphrase"] as? String ?? ""
        let newpassphrase = dict["newpassphrase"] as? String ?? ""
        param = ["oldpassphrase": oldpassphrase, "newpassphrase": newpassphrase]
    }
}


public struct List_Transactions: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. label                (string, optional) If set, should be a valid label name to return only incoming transactions
                             with the specified label, or "*" to disable filtering and return all transactions.
     2. count                (numeric, optional, default=10) The number of transactions to return
     3. skip                 (numeric, optional, default=0) The number of transactions to skip
     4. include_watchonly    (boolean, optional, default=true for watch-only wallets, otherwise false) Include transactions to watch-only addresses (see 'importaddress')
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let count = dict["count"] as? Int ?? 100
        let include_watchonly = dict["include_watchonly"] as? Bool ?? true
        param = ["count": count, "include_watchonly": include_watchonly]
    }
}


public struct Rescan_Blockchain: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. start_height    (numeric, optional, default=0) block height where the rescan should start
     2. stop_height     (numeric, optional) the last block height that should be scanned. If none is provided it will rescan up to the tip at return time of this call.
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let start_height = dict["start_height"] as? Int ?? 0
        param = ["start_height": start_height]
    }
}


public struct List_Unspent: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. minconf                            (numeric, optional, default=1) The minimum confirmations to filter
     2. maxconf                            (numeric, optional, default=9999999) The maximum confirmations to filter
     3. addresses                          (json array, optional, default=[]) The bitcoin addresses to filter
          [
            "address",                     (string) bitcoin address
            ...
          ]
     4. include_unsafe                     (boolean, optional, default=true) Include outputs that are not safe to spend
                                           See description of "safe" attribute below.
     5. query_options                      (json object, optional) JSON with query options
          {
            "minimumAmount": amount,       (numeric or string, optional, default="0.00") Minimum value of each UTXO in BTC
            "maximumAmount": amount,       (numeric or string, optional, default=unlimited) Maximum value of each UTXO in BTC
            "maximumCount": n,             (numeric, optional, default=unlimited) Maximum number of UTXOs
            "minimumSumAmount": amount,    (numeric or string, optional, default=unlimited) Minimum sum value of all UTXOs in BTC
          }
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let minconf = dict["minconf"] as? Int ?? 0
        let query_options = ["maximumCount": 100]
        param = ["minconf": minconf, "query_options": query_options]
    }
}


public struct Join_Psbt: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. txs            (json array, required) The base64 strings of partially signed transactions
          [
            "psbt",    (string, required) A base64 string of a PSBT
            ...
          ]
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let txs = dict["txs"] as? [String] ?? []
        param = ["txs": txs]
    }
}


public struct Finalize_Psbt: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. psbt       (string, required) A base64 string of a PSBT
     2. extract    (boolean, optional, default=true) If true and the transaction is complete,
                   extract and return the complete transaction in normal network serialization instead of the PSBT.
     */
    let param:[String:Any]
    init(_ dict: [String:Any]) {
        let psbt = dict["psbt"] as? String ?? ""
        param = ["psbt": psbt]
    }
}

public struct Load_Wallet: CustomStringConvertible {
    public var description: String {
        return ""
    }
    /*
     Arguments:
     1. filename           (string, required) The wallet directory or .dat file.
     2. load_on_startup    (boolean, optional) Save wallet name to persistent settings and load on startup. True to add wallet to startup list, false to remove, null to leave unchanged.
     */
    let param: [String:Any]
    init(_ dict: [String:Any]) {
        let filename = dict["filename"] as? String ?? ""
        param = ["filename": filename]
    }
}

public struct Create_Psbt: CustomStringConvertible {
    public var description: String {
        return ""
    }
    
    /*
     1. inputs                      (json array, required) The inputs
          [
            {                       (json object)
              "txid": "hex",        (string, required) The transaction id
              "vout": n,            (numeric, required) The output number
              "sequence": n,        (numeric, optional, default=depends on the value of the 'replaceable' and 'locktime' arguments) The sequence number
            },
            ...
          ]
     2. outputs                     (json array, required) The outputs (key-value pairs), where none of the keys are duplicated.
                                    That is, each address can only appear once and there can only be one 'data' object.
                                    For compatibility reasons, a dictionary, which holds the key-value pairs directly, is also
                                    accepted as second parameter.
          [
            {                       (json object)
              "address": amount,    (numeric or string, required) A key-value pair. The key (string) is the bitcoin address, the value (float or string) is the amount in BTC
              ...
            },
            {                       (json object)
              "data": "hex",        (string, required) A key-value pair. The key must be "data", the value is hex-encoded data
            },
            ...
          ]
     3. locktime                    (numeric, optional, default=0) Raw locktime. Non-0 value also locktime-activates inputs
     4. replaceable                 (boolean, optional, default=false) Marks this transaction as BIP125-replaceable.
                                    Allows this transaction to be replaced by a transaction with higher fees. If provided, it is an error if explicit sequence numbers are incompatible.
     */
    let param: [String:Any]
    let inputs:[[String:Any]]
    let outputs:[[String:Any]]
    init(_ dict:[String:Any]) {
        inputs = dict["inputs"] as? [[String:Any]] ?? [[:]]
        outputs = dict["outputs"] as? [[String:Any]] ?? [[:]]
        param = ["inputs": inputs, "outputs": outputs, "replaceable": true]
    }
}


public struct Utxo_Update_Psbt: CustomStringConvertible {
     /*
      utxoupdatepsbt "psbt" ( ["",{"desc":"str","range":n or [n,n]},...] )

      Updates all segwit inputs and outputs in a PSBT with data from output descriptors, the UTXO set or the mempool.

      Arguments:
      1. psbt                          (string, required) A base64 string of a PSBT
      2. descriptors                   (json array, optional) An array of either strings or objects
           [
             "",                       (string) An output descriptor
             {                         (json object) An object with an output descriptor and extra information
               "desc": "str",          (string, required) An output descriptor
               "range": n or [n,n],    (numeric or array, optional, default=1000) Up to what index HD chains should be explored (either end or [begin,end])
             },
             ...
           ]

      Result:
      "str"    (string) The base64-encoded partially signed transaction with inputs updated

      Examples:
      > bitcoin-cli utxoupdatepsbt "psbt"
      */
    let psbt: String
    let descriptors: [[String:Any]]
    let param: [String:Any]
    public var description: String {
        return ""
    }
    init(_ dict: [String:Any]) {
        psbt = dict["psbt"] as! String
        descriptors = dict["descriptors"] as? [[String:Any]] ?? [[:]]
        param = ["psbt": psbt, "descriptors": descriptors]
       
    }
}

public struct Scan_Tx_Out: CustomStringConvertible {
    /*
     Arguments:
     1. action                        (string, required) The action to execute
                                      "start" for starting a scan
                                      "abort" for aborting the current scan (returns true when abort was successful)
                                      "status" for progress report (in %) of the current scan
     2. scanobjects                   (json array) Array of scan objects. Required for "start" action
                                      Every scan object is either a string descriptor or an object:
          [
            "descriptor",             (string) An output descriptor
            {                         (json object) An object with output descriptor and metadata
              "desc": "str",          (string, required) An output descriptor
              "range": n or [n,n],    (numeric or array, optional, default=1000) The range of HD chain indexes to explore (either end or [begin,end])
            },
            ...
          ]

     Result (When action=='abort'):
     true|false    (boolean)

     Result (When action=='status' and no scan is in progress):
     null    (json null)

     Result (When action=='status' and scan is in progress):
     {                    (json object)
       "progress" : n     (numeric) The scan progress
     }

     Result (When action=='start'):
     {                                (json object)
       "success" : true|false,        (boolean) Whether the scan was completed
       "txouts" : n,                  (numeric) The number of unspent transaction outputs scanned
       "height" : n,                  (numeric) The current block height (index)
       "bestblock" : "hex",           (string) The hash of the block at the tip of the chain
       "unspents" : [                 (json array)
         {                            (json object)
           "txid" : "hex",            (string) The transaction id
           "vout" : n,                (numeric) The vout value
           "scriptPubKey" : "hex",    (string) The script key
           "desc" : "str",            (string) A specialized descriptor for the matched scriptPubKey
           "amount" : n,              (numeric) The total amount in BTC of the unspent output
           "height" : n               (numeric) Height of the unspent transaction output
         },
         ...
       ],
       "total_amount" : n             (numeric) The total amount of all found unspent outputs in BTC
     }
     */
    
    let action: String
    var scanobjects: [[String:Any]] = [[:]]
    let descriptor: String
    let scanObject: [String:Any]
    let param: [String:Any]
    public var description: String {
        return ""
    }
    init(_ dict: [String:Any]) {
        action = dict["action"] as! String
        descriptor = dict["descriptor"] as! String
        scanObject = ["desc": descriptor, "range": [50001,100000]]
        scanobjects[0] = scanObject
        param = ["action": action, "scanobjects": scanobjects]
    }
    
}















