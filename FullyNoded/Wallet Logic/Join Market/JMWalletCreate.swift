//
//  JMWallet.swift
//  FullyNoded
//
//  Created by Peter Denton on 8/14/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

// MARK: GENERAL WALLET ARCH
 
/// Default wallet account:   m/0 **mainnet and testnet**
///
/// Wallet branches:            m/0/mixdepth/[external/internal]
///
/// Mixdepth:                       The value of mixdepth runs from 0..M-1, where M is the number of mixdepths chosen by the user; by default 5.
///                  The value of [external/internal] is 0 for external, 1 for internal.
///                  Thus a default wallet will contain 10 separate branches.

///                  Note that all of the keys are of the non-hardened type.

/// Format:                          native segwit p2wpkh

class JoinMarket {
    static var index = 0
    static var descriptors = ""
    static var plain = [String()]
    static var wallet:[String:Any] = [:]

    class func descriptors(_ mk: String, _ xfp: String, completion: @escaping ((descriptors: String?, dict: [String:Any]?)) -> Void) {
        
        guard let xpub0 = xpub(0, mk),
              let xpub1 = xpub(1, mk),
              let xpub2 = xpub(2, mk),
              let xpub3 = xpub(3, mk),
              let xpub4 = xpub(4, mk) else { return }
            
            plain = [
                desc(0, xfp, xpub0, 0),
                desc(0, xfp, xpub0, 1),
                desc(1, xfp, xpub1, 0),
                desc(1, xfp, xpub1, 1),
                desc(2, xfp, xpub2, 0),
                desc(2, xfp, xpub2, 1),
                desc(3, xfp, xpub3, 0),
                desc(3, xfp, xpub3, 1),
                desc(4, xfp, xpub4, 0),
                desc(4, xfp, xpub4, 1)
            ]
            
        getDescriptorInfo(i: 0, desc: plain[0], completion: completion)
    }

    static func getDescriptorInfo(i: Int, desc: String, completion: @escaping ((descriptors: String?, dict: [String:Any]?)) -> Void) {
        if i <= 9 {
            OnchainUtils.getDescriptorInfo(desc) { (descriptorInfo, message) in
                guard let descriptorInfo = descriptorInfo else { return }
                
                let intern = !(i % 2 == 0)
                
                guard let encryptedDesc = Crypto.encrypt(descriptorInfo.descriptor.utf8) else { return }
                
                switch i {
                case 0:
                    wallet["mixDepthZeroExt"] = encryptedDesc
                case 1:
                    wallet["mixDepthZeroInt"] = encryptedDesc
                case 2:
                    wallet["mixDepthOneExt"] = encryptedDesc
                case 3:
                    wallet["mixDepthOneInt"] = encryptedDesc
                case 4:
                    wallet["mixDepthTwoExt"] = encryptedDesc
                case 5:
                    wallet["mixDepthTwoInt"] = encryptedDesc
                case 6:
                    wallet["mixDepthThreeExt"] = encryptedDesc
                case 7:
                    wallet["mixDepthThreeInt"] = encryptedDesc
                case 8:
                    wallet["mixDepthFourExt"] = encryptedDesc
                case 9:
                    wallet["mixDepthFourInt"] = encryptedDesc
                default:
                    break
                }
                
                let param = importDescsParam(descriptorInfo.descriptor, false, intern)
                
                if i > 0 {
                    descriptors += ", \(param)"
                } else {
                    descriptors += "\(param)"
                }
                
                if i == 9 {
                    wallet["mixIndexes"] = [[0,0], [0,0], [0,0], [0,0], [0,0]]
                    completion((descriptors, wallet))
                } else {
                    index += 1
                    getDescriptorInfo(i: index, desc: plain[index], completion: completion)
                }
            }
        }
    }
    
    static func desc(_ mixDepth: Int, _ xfp: String, _ xpub: String, _ child: Int) -> String {
        return "wpkh([\(xfp)/0/\(mixDepth)]\(xpub)/\(child)/*)"
    }
    
    static func xpub(_ mixDepth: Int, _ mk: String) -> String? {
        return Keys.xpub(path: "m/0/\(mixDepth)", masterKey: mk)
    }
    
    static func importDescsParam(_ desc: String, _ active: Bool, _ intern: Bool) -> String {
        return "{\"desc\": \"\(desc)\", \"active\": \(active), \"range\": [0,500], \"next_index\": 0, \"timestamp\": \"now\", \"internal\": \(intern)}"
    }
    
    // MARK: Sync address data
    static func syncAddresses() {
        activeWallet { wallet in
            guard let wallet = wallet, wallet.mixIndexes != nil else { return }
            
            // get utxos and see last used index mixdepths
            OnchainUtils.listUnspent(param: "") { (utxos, message) in
                guard let utxos = utxos, utxos.count > 0 else { return }
                
                for utxo in utxos {
                    if let desc = utxo.desc {
                        let ds = Descriptor(desc)
                        
                        let origin = ds.prefix
                        
                        guard let index = getIndex(origin) else { return }
                        
                        switch origin {
                        case _ where origin.contains("/0/0/0/") || origin.contains("/1/0/0/"):
                            print("mix depth 0 utxo external address at index: \(index)")
                            
                            parse(wallet, 0, 0, index)
                            
                        case _ where origin.contains("/0/1/0/") || origin.contains("/1/1/0/"):
                            print("mix depth 1 utxo external address at index: \(index)")
                            
                            parse(wallet, 1, 0, index)
                            
                        case _ where origin.contains("/0/2/0/") || origin.contains("/1/2/0/"):
                            print("mix depth 2 utxo external address at index: \(index)")
                            
                            parse(wallet, 2, 0, index)
                            
                        case _ where origin.contains("/0/3/0/") || origin.contains("/1/3/0/"):
                            print("mix depth 3 utxo external address at index: \(index)")
                            
                            parse(wallet, 3, 0, index)
                            
                        case _ where origin.contains("/0/4/0/") || origin.contains("/1/4/0/"):
                            print("mix depth 4 utxo external address at index: \(index)")
                            
                            parse(wallet, 4, 0, index)
                            
                        case _ where origin.contains("/0/0/1/") || origin.contains("/1/0/1/"):
                            print("mix depth 0 utxo internal address at index: \(index)")
                            
                            parse(wallet, 0, 1, index)
                            
                        case _ where origin.contains("/0/1/1/") || origin.contains("/1/1/1/"):
                            print("mix depth 1 utxo internal address at index: \(index)")
                            
                            parse(wallet, 1, 1, index)
                            
                        case _ where origin.contains("/0/2/1/") || origin.contains("/1/2/1/"):
                            print("mix depth 2 utxo internal address at index: \(index)")
                            
                            parse(wallet, 2, 1, index)
                            
                        case _ where origin.contains("/0/3/1/") || origin.contains("/1/3/1/"):
                            print("mix depth 3 utxo internal address at index: \(index)")
                            
                            parse(wallet, 3, 1, index)
                            
                        case _ where origin.contains("/0/4/1/") || origin.contains("/1/4/1/"):
                            print("mix depth 4 utxo internal address at index: \(index)")
                            
                            parse(wallet, 4, 1, index)
                            
                        default:
                            print("non mixing path index: \(index)")
                        }
                    }
                }
            }
        }
    }
    
    private class func parse(_ wallet: Wallet, _ depth: Int, _ int: Int, _ new: Int) {
        var array = wallet.mixIndexes!
        let existing = array[depth][int]
        
        if existing < new {
            array[depth][int] = new
            updateIndex(wallet, array)
        }
    }
    
    private class func updateIndex(_ wallet: Wallet, _ array: [[Int]]) {
        CoreDataService.update(id: wallet.id, keyToUpdate: "mixIndexes", newValue: array, entity: .wallets) { updated in
            print("updated: \(updated)")
        }
    }
    
    private class func getIndex(_ origin: String) -> Int? {
        var index:Int?
        var processed = origin.replacingOccurrences(of: "[", with: "")
        processed = processed.replacingOccurrences(of: "]", with: "")
        let arr = processed.split(separator: "/")
        for (i, item) in arr.enumerated() {
            if i + 1 == arr.count {
                index = Int(item)
            }
        }
        return index
    }
    
    //SourceJMTx
    static func getDepositAddress(completion: @escaping ((String?)) -> Void) {
        activeWallet { wallet in
            guard let wallet = wallet, let mixIndexes = wallet.mixIndexes else { return }
                        
            for (i, mixdepth) in mixIndexes.enumerated() {
                let externalIndex = mixdepth[0]
                
                if externalIndex < 500 {
                    fetchReceiveAddress(i, wallet, externalIndex, completion: completion)
                    break
                }
            }
        }
    }
    
    static func getChangeAddress(completion: @escaping ((String?)) -> Void) {
        activeWallet { wallet in
            guard let wallet = wallet, let mixIndexes = wallet.mixIndexes else { return }
                        
            for (i, mixdepth) in mixIndexes.enumerated() {
                let internalIndex = mixdepth[1]
                
                if internalIndex < 500 {
                    fetchChangeAddress(i, wallet, internalIndex, completion: completion)
                    break
                }
            }
        }
    }
    
    private class func decrypted(_ data: Data) -> String? {
        guard let decrypted = Crypto.decrypt(data),
              let string = decrypted.utf8String else {
            return nil
        }
        
        return string
    }
    
    private class func fetchReceiveAddress(_ mixdepth: Int, _ wallet: Wallet, _ index: Int, completion: @escaping ((String?)) -> Void) {
        var desc = ""
        
        switch mixdepth {
        case 0:
            guard let data = wallet.mixDepthZeroExt,
                  let decrypted = decrypted(data) else { return }
            
            desc = decrypted
            
        case 1:
            guard let data = wallet.mixDepthOneExt,
                  let decrypted = decrypted(data) else { return }
            
            desc = decrypted
            
        case 2:
            guard let data = wallet.mixDepthTwoExt,
                  let decrypted = decrypted(data) else { return }
            
            desc = decrypted
            
        case 3:
            guard let data = wallet.mixDepthThreeExt,
                  let decrypted = decrypted(data) else { return }
            
            desc = decrypted
            
        case 4:
            guard let data = wallet.mixDepthFourExt,
                  let decrypted = decrypted(data) else { return }
            
            desc = decrypted
        default:
            break
        }
        
        let param = "\"\(desc)\", [\(index),\(index)]"
        
        OnchainUtils.deriveAddresses(param: param) { (addresses, message) in
            guard let addresses = addresses, addresses.count > 0 else {
                completion((nil))
                return
            }
            
            print("mix depth: \(mixdepth)\nindex: \(index)\ndeposit address: \(addresses[0])")
            completion((addresses[0]))
        }
    }
    
    private class func fetchChangeAddress(_ mixdepth: Int, _ wallet: Wallet, _ index: Int, completion: @escaping ((String?)) -> Void) {
        var desc = ""
        
        switch mixdepth {
        case 0:
            guard let data = wallet.mixDepthZeroInt,
                  let decrypted = decrypted(data) else { return }
            
            desc = decrypted
        case 1:
            guard let data = wallet.mixDepthOneInt,
                  let decrypted = decrypted(data) else { return }
            
            desc = decrypted
        case 2:
            guard let data = wallet.mixDepthTwoInt,
                  let decrypted = decrypted(data) else { return }
            
            desc = decrypted
        case 3:
            guard let data = wallet.mixDepthThreeInt,
                  let decrypted = decrypted(data) else { return }
            
            desc = decrypted
        case 4:
            guard let data = wallet.mixDepthFourInt,
                  let decrypted = decrypted(data) else { return }
            
            desc = decrypted
        default:
            break
        }
        
        let param = "\"\(desc)\", [\(index),\(index)]"
        
        OnchainUtils.deriveAddresses(param: param) { (addresses, message) in
            guard let addresses = addresses, addresses.count > 0 else { return }
            
            print("mix depth: \(mixdepth)\nindex: \(index)\nchange address: \(addresses[0])")
        }
    }
}





//struct JMAddress: CustomStringConvertible {
//    let balance: Double
//    let new: Bool
//    let isInternal: Bool
//    let path: String
//}


//
//
//
// mixing depth 0 m/0/0/
//  external addresses m/0/0/0/
//   m/0/0/0/016 muijch3wHvCXm9pHJQiyQFWDZSngPUdLrB  new 0.00000000 btc
//   m/0/0/0/017 n35T2GFV2CQXuN2eZJWBG7GTkhJZs4swJD  new 0.00000000 btc
//   m/0/0/0/018 mgwSKYK1zssnJi5T9UaR1gxdzPmU6zobvk  new 0.00000000 btc
//   m/0/0/0/019 mmXouP3x92h5yvBLMn6So4BvTRShN318Za  new 0.00000000 btc
//   m/0/0/0/020 mhKpprCpmfnsS2AwBDjiRoArNjSRMKCXHL  new 0.00000000 btc
//   m/0/0/0/021 n1h6MYPJLsoJ1dz2HNGxM7L5ct4A84RvQW  new 0.00000000 btc
//  internal addresses m/0/0/1/
//   m/0/0/1/048 mrytep7Ne1t2Epzrn1zWPrBAfaDWCtekqx used 4.87792833 btc
// for mixdepth=0 balance=4.87792833btc
// mixing depth 1 m/0/1/
//  external addresses m/0/1/0/
//   m/0/1/0/045 mrjkGaHdvFqZiTXRWcvAqSTmLaxKRfDWB9 used 9.27910795 btc
//   m/0/1/0/046 mmMs5iHLZKaLHLG3zysHwEdBNVHGyCLXgf  new 0.00000000 btc
//   m/0/1/0/047 mfkPoc34Z2k15jhcwPc8ifywykXvkovv9z  new 0.00000000 btc
//   m/0/1/0/048 mn5AuW8due3KtTGXvi68xQQUyNkg8jo5uQ  new 0.00000000 btc
//   m/0/1/0/049 n4Wg3ajPgLvEpumK2sHZXiggUw3kX6XCSh  new 0.00000000 btc
//   m/0/1/0/050 mfnxp5n4nMa9fZogNBo5gTSA7HBRLYmCW2  new 0.00000000 btc
//   m/0/1/0/051 msRJ7MpC9gKjqi7GjJ8WrHqAnPwDT8Nxsc  new 0.00000000 btc
//  internal addresses m/0/1/1/
//   m/0/1/1/043 mtBYHv4vmxKfqQT2Cr2vrA578EmUzcwwKA used 1.76456658 btc
//   m/0/1/1/044 mp9yvRWwu5Lcs5EAnvGSKMKWith2qv1Rxt used 4.58622784 btc
// for mixdepth=1 balance=15.62990237btc
// mixing depth 2 m/0/2/
//  external addresses m/0/2/0/
//   m/0/2/0/042 muaApeqh9L4aQvR6Fn52oDiqz8jKKu9Rfz  new 0.00000000 btc
//   m/0/2/0/043 mqdZS695VHeNpk83YtBmutGFNcJsPC39wW  new 0.00000000 btc
//   m/0/2/0/044 mq32QZX7DszZCYzKP6TvZRom1xFMoUWkbS  new 0.00000000 btc
//   m/0/2/0/045 mterWqVTyj2oKHPr1raaY6iwqQTKbwM5ro  new 0.00000000 btc
//   m/0/2/0/046 mzaotzzCHvoZxs2RjYXWN2Yh9kB6F5gU8j  new 0.00000000 btc
//   m/0/2/0/047 mvJMCGoG5ZUARtAr5x2KD1ebNLuL618zXU  new 0.00000000 btc
//  internal addresses m/0/2/1/
// for mixdepth=2 balance=0.00000000btc
// mixing depth 3 m/0/3/
//  external addresses m/0/3/0/
//   m/0/3/0/002 mwjZyUbh78UndNtqsKathxpjE4EsYrhLzm used 3.00000000 btc
//   m/0/3/0/004 msMoHnZRKfNRPQqg2MUk1rXrqwM6VeLL8C used 0.30000000 btc
//   m/0/3/0/006 mhBHRaFwMTPPWLdukqgJaSMmmCeQ8ef6QV used 9.26824652 btc
//   m/0/3/0/007 mrdv38dX1eQsZjAof442G9Lj66bM5yUnjA used 4.58134572 btc
//   m/0/3/0/008 moWA3FEYkNbEJkHdnQbQYkrVztTviMaHwe used 5.39567085 btc
//   m/0/3/0/009 mgoTGzD46mWoMiH97QHh9TxuJp4NmVobNp used 3.00000000 btc
//   m/0/3/0/010 mjddF8HmBaenGBspTMzhF3qikbbLB4xGZN  new 0.00000000 btc
//   m/0/3/0/011 mnEvKc2JLj8s1GLfvtvqVt5pWTu5jCdtEk  new 0.00000000 btc
//   m/0/3/0/012 n1FwKgDEjzRj2YsZNoG5MWVnuq72wA8Mgr  new 0.00000000 btc
//   m/0/3/0/013 mq4vn4KX9SRrvhiRkg9KrYADhKNPAp2wyN  new 0.00000000 btc
//   m/0/3/0/014 n3nG4334F19THUACgEEveRX8JcE5awY1qz  new 0.00000000 btc
//   m/0/3/0/015 mz5yHHbud68b8CLeNk2MsnyFgSJ9rPGk7v  new 0.00000000 btc
//  internal addresses m/0/3/1/
//   m/0/3/1/000 mfbeMyajM4wYRmpWVrYnd3rBqvtBniw8gj used 0.25672994 btc
//   m/0/3/1/001 mzkFk3C9J6D9KE9cV4kuSctUKZXkr1gaio used 0.51499000 btc
//   m/0/3/1/002 n3SCTwDs4wcn7yGhFq8HJwxQ9PzBXvTJdV used 0.04199000 btc
//   m/0/3/1/006 mow4CyHNssjo2CNHdg3DdbXWYNPfY8HEPe used 0.36073270 btc
// for mixdepth=3 balance=26.71970573btc
// mixing depth 4 m/0/4/
//  external addresses m/0/4/0/
//   m/0/4/0/011 mzMWwUSvj4n3wgtSMLXt17hQTi2zinzYWZ used 2.00000000 btc
//   m/0/4/0/012 mrgNjQWjrBDB821o1Q3qG6EmKJmEqgjtqY  new 0.00000000 btc
//   m/0/4/0/013 msjynFwGoGePoheVABAEgjxjw8FNuPgtPC  new 0.00000000 btc
//   m/0/4/0/014 moJpd6ZvgAm1ZENmAuoPKnqAUntoSixao9  new 0.00000000 btc
//   m/0/4/0/015 muajyWxmjuHQDm3MpSr7Y3RLAWDqch1yix  new 0.00000000 btc
//   m/0/4/0/016 n2tPijSN4nBFGAKbXpp6H7hfznhsYWwR88  new 0.00000000 btc
//   m/0/4/0/017 mnkrhe7fMYy4yjPM54gEurgxWpDXJ3axtn  new 0.00000000 btc
//  internal addresses m/0/4/1/
// for mixdepth=4 balance=2.00000000btc
// total balance = 49.22753643btc
 
 


// MARK: RECEIVING

/// Payments into the wallet should be made into new addresses on the external branch for any mixdepth.
/// For the above wallet, muaApeqh9L4aQvR6Fn52oDiqz8jKKu9Rfz (from mixdepth 2) or mrgNjQWjrBDB821o1Q3qG6EmKJmEqgjtqY (from mixdepth 4) would be suitable candidates.
/// The index of the address on the branch is shown as the final 3 digit integer in the identifier.

// MARK: TRANSACTIONS

/// In joinmarket transactions, a single destination output goes to the address designated by the transaction initiator (which need not be an address in a joinmarket wallet; it could be any valid Bitcoin address, including P2SH). The remaining outputs go to internal addresses as follows:

/// If the transaction initiator has any change left ("sweep" transactions send a precise amount, without leaving change), it is sent to a new address in the internal branch of the same mixdepth as the initiator's inputs.
///
/// Each liquidity provider sends a single change output to a new address in the same mixdepth as its inputs.
///
/// Each liquidity provider sends a single output (with size identical to that of the destination output) to a new address in the next mixdepth, wrapping back to the first (that is, the mixdepth in BIP32 branch zero) upon reaching max_mix_depth.
///
/// The logic of this is fairly straightforward, and central to how Joinmarket works, so make sure to understand it: the coinjoin outputs of a transaction must not be reused with any of the inputs to that same transaction, or any other output that can be connected with them, as this would allow fairly trivial linkage. Merging such outputs is avoided by picking the inputs for a transaction only from a single mixdepth (although both internal and external branches can be used).

// MARK: SourceJMTx
///This is usually an ordinary bitcoin transaction paying into an unused address on an external branch for any one of the mixdepths of the wallet. As such it has no special joinmarket structure; it will usually have a change output, which will go back to the wallet funding this one. It could, however, be a payment from another joinmarket wallet, although most users will not be using more than one joinmarket wallet. This doesn't affect the analysis, in any case.

// MARK: (Canonical) CJMTx
///CJMTx The most fundamental type of joinmarket transaction involves neither a 'source' nor a 'sink', but only spends from this joinmarket wallet to itself, in conjunction with joining counterparties. The coinjoin output goes to a new address on the internal branch of the next mixdepth, as was described in the previous section.

// MARK: WALLET OBJECT

/// addr_cache:     a dict, with each entry of format Bitcoin address: (mixing depth, external/internal flag, index). The external/internal flag is 0/1 and the index is the index of the address on  the branch. Note that the address itself is not persisted, only the index of the first unused key (and address) on each specific branch (see here).
///
/// unspent:    unspent is a dict, with each entry of format utxo: {'address': address, 'value': amount in satoshis}, where utxo has format txid:n as usual in Bitcoin wallets. This is the fundamental data structure that Joinmarket uses to decide which coins to spend in joins.
///
/// seed: master xprv
///
/// gaplimit: default is 6
///
/// keys: is a list of pairs of parent keys that are used to generate the individual branches, i.e. it has the form: [(key for mixdepth 0 external branch, key for mixdepth 0 internal branch), (key for mixdepth 1 external branch, key for mixdepth 1 internal branch), ...]
///
/// index: this (too generically named!) is a list of pairs of pointers into each of the branches, marking the first unused address in that branch, format [[a,b],[c,d]...] with each letter standing for a positive integer. Note that this is persisted to file storage to prevent address reuse in case of failures

// MARK: WALLET PERSISTANCE

/// {"index_cache": [[113, 163], [149, 161], [154, 134], [128, 149], [135, 120]], "encrypted_seed":
/// "15336f8220ee6da168c153e1e11c0402c862fa377d2422c27b5f92ed37d52a840d1a80c4eda7ca9731ec5e0ebfa92cdd",
/// "creation_time": "2015/05/08 15:56:58", "network": "mainnet", "creator": "joinmarket project"}

/// index_cache:  a list of 5 x 2 entries, one for each branch in the wallet (in the default case) as described above. Each number is a pointer to the next unused address on the branch. This is of high importance because it allows the entity in control of the wallet to ensure that an address on that branch is not reused in more than one transaction. To achieve this, it's necessary that the function Wallet.update_index_cache is called immediately a new transaction is proposed for that entity, even if the transaction fails to complete. Note that this can lead to practical difficulties (such as large wallet gaps) in the case of Sybil attacks or errors where a long string of proposed but incompleted transactions occurs.




// MARK: JOINMARKET.CFG

/*
 import io
 import logging
 import os
 import re
 import sys

 from configparser import ConfigParser, NoOptionError

 import jmbitcoin as btc
 from jmclient.jsonrpc import JsonRpc
 from jmbase.support import (get_log, joinmarket_alert, core_alert, debug_silence,
                             set_logging_level, jmprint, set_logging_color,
                             JM_APP_NAME, lookup_appdata_folder, EXIT_FAILURE)
 from jmclient.podle import set_commitment_file

 log = get_log()


 class AttributeDict(object):
     """
     A class to convert a nested Dictionary into an object with key-values
     accessibly using attribute notation (AttributeDict.attribute) instead of
     key notation (Dict["key"]). This class recursively sets Dicts to objects,
     allowing you to recurse down nested dicts (like: AttributeDict.attr.attr)
     """

     def __init__(self, **entries):
         self.currentnick = None
         self.add_entries(**entries)

     def add_entries(self, **entries):
         for key, value in entries.items():
             if isinstance(value, dict):
                 self.__dict__[key] = AttributeDict(**value)
             else:
                 self.__dict__[key] = value

     def __setattr__(self, name, value):
         if name == 'nickname' and value != self.currentnick:
             self.currentnick = value
             logFormatter = logging.Formatter(
                 ('%(asctime)s [%(threadName)-12.12s] '
                  '[%(levelname)-5.5s]  %(message)s'))
             logsdir = os.path.join(os.path.dirname(
                 global_singleton.config_location), "logs")
             fileHandler = logging.FileHandler(
                 logsdir + '/{}.log'.format(value))
             fileHandler.setFormatter(logFormatter)
             log.addHandler(fileHandler)

         super().__setattr__(name, value)

     def __getitem__(self, key):
         """
         Provides dict-style access to attributes
         """
         return getattr(self, key)


 global_singleton = AttributeDict()
 global_singleton.JM_VERSION = 5
 global_singleton.APPNAME = JM_APP_NAME
 global_singleton.datadir = None
 global_singleton.nickname = None
 global_singleton.BITCOIN_DUST_THRESHOLD = 2730
 global_singleton.DUST_THRESHOLD = 10 * global_singleton.BITCOIN_DUST_THRESHOLD
 global_singleton.bc_interface = None
 global_singleton.maker_timeout_sec = 60
 global_singleton.debug_file_handle = None
 global_singleton.core_alert = core_alert
 global_singleton.joinmarket_alert = joinmarket_alert
 global_singleton.debug_silence = debug_silence
 global_singleton.config = ConfigParser(strict=False)
 #This is reset to a full path after load_program_config call
 global_singleton.config_location = 'joinmarket.cfg'
 #as above
 global_singleton.commit_file_location = 'cmtdata/commitments.json'
 global_singleton.wait_for_commitments = 0


 def jm_single():
     return global_singleton

 # FIXME: Add rpc_* options here in the future!
 required_options = {'BLOCKCHAIN': ['blockchain_source', 'network'],
                     'MESSAGING': ['host', 'channel', 'port'],
                     'POLICY': ['absurd_fee_per_kb', 'taker_utxo_retries',
                                'taker_utxo_age', 'taker_utxo_amtpercent']}

 _DEFAULT_INTEREST_RATE = "0.015"

 _DEFAULT_BONDLESS_MAKERS_ALLOWANCE = "0.125"

 defaultconfig = \
     """
 [DAEMON]
 #set to 1 to run the daemon service within this process;
 #set to 0 if the daemon is run separately (using script joinmarketd.py)
 no_daemon = 1
 #port on which daemon serves; note that communication still
 #occurs over this port even if no_daemon = 1
 daemon_port = 27183
 #currently, running the daemon on a remote host is
 #*NOT* supported, so don't change this variable
 daemon_host = localhost
 #by default the client-daemon connection is plaintext, set to 'true' to use TLS;
 #for this, you need to have a valid (self-signed) certificate installed
 use_ssl = false
 [BLOCKCHAIN]
 # options: bitcoin-rpc, regtest, bitcoin-rpc-no-history, no-blockchain
 # When using bitcoin-rpc-no-history remember to increase the gap limit to scan for more addresses, try -g 5000
 # Use 'no-blockchain' to run the ob-watcher.py script in scripts/obwatch without current access
 # to Bitcoin Core; note that use of this option for any other purpose is currently unsupported.
 blockchain_source = bitcoin-rpc
 # options: signet, testnet, mainnet
 # Note: for regtest, use network = testnet
 network = mainnet
 rpc_host = localhost
 # default ports are 8332 for mainnet, 18443 for regtest, 18332 for testnet, 38332 for signet
 rpc_port = 8332
 rpc_user = bitcoin
 rpc_password = password
 rpc_wallet_file =
 [MESSAGING:server1]
 host = irc.darkscience.net
 channel = joinmarket-pit
 port = 6697
 usessl = true
 socks5 = false
 socks5_host = localhost
 socks5_port = 9050
 #for tor
 #host = darkirc6tqgpnwd3blln3yfv5ckl47eg7llfxkmtovrv7c7iwohhb6ad.onion
 #socks5 = true
 [MESSAGING:server2]
 host = irc.hackint.org
 channel = joinmarket-pit
 port = 6697
 usessl = true
 socks5 = false
 socks5_host = localhost
 socks5_port = 9050
 #for tor
 #host = ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion
 #port = 6667
 #usessl = false
 #socks5 = true
 #Agora sometimes seems to be unreliable. Not active by default for that reason.
 #[MESSAGING:server3]
 #host = agora.anarplex.net
 #channel = joinmarket-pit
 #port = 14716
 #usessl = true
 #socks5 = false
 #socks5_host = localhost
 #socks5_port = 9050
 #
 ##for tor
 ##host = agora3cdw6kdty5y.onion
 ##port = 6667
 ##usessl = false
 ##socks5 = true
 [LOGGING]
 # Set the log level for the output to the terminal/console
 # Possible choices: DEBUG / INFO / WARNING / ERROR
 # Log level for the files in the logs-folder will always be DEBUG
 console_log_level = INFO
 # Use color-coded log messages to help distinguish log levels?:
 color = true
 [TIMEOUT]
 maker_timeout_sec = 60
 unconfirm_timeout_sec = 180
 confirm_timeout_hours = 6
 [POLICY]
 # Use segwit style wallets and transactions
 # Only set to false for old wallets, Joinmarket is now segwit only.
 segwit = true
 # Use native segwit (bech32) wallet. If set to false, p2sh-p2wkh
 # will be used when generating the addresses for this wallet.
 # Notes: 1. The default joinmarket pit is native segwit.
 #        2. You cannot change the type of a pre-existing wallet.
 native = true
 # for dust sweeping, try merge_algorithm = gradual
 # for more rapid dust sweeping, try merge_algorithm = greedy
 # for most rapid dust sweeping, try merge_algorithm = greediest
 # but don't forget to bump your miner fees!
 merge_algorithm = default
 # The fee estimate is based on a projection of how many satoshis
 # per kB are needed to get in one of the next N blocks, N set here
 # as the value of 'tx_fees'. This cost estimate is high if you set
 # N=1, so we choose 3 for a more reasonable figure, as our default.
 # You can also set your own fee/kb: any number higher than 1000 will
 # be interpreted as the fee in satoshi per kB that you wish to use
 # example: N=30000 will use 30000 sat/kB as a fee, while N=5
 # will use the estimate from your selected blockchain source
 # Note that there will be a 20% variation around any manually chosen
 # values, so if you set N=10000, it might use any value between
 # 8000 and 12000 for your transactions.
 tx_fees = 3
 # For users getting transaction fee estimates over an API,
 # place a sanity check limit on the satoshis-per-kB to be paid.
 # This limit is also applied to users using Core, even though
 # Core has its own sanity check limit, which is currently
 # 1,000,000 satoshis.
 absurd_fee_per_kb = 350000
 # In decimal, the maximum allowable change either lower or
 # higher, that the fee rate used for coinjoin sweeps is
 # allowed to be.
 # (note: coinjoin sweeps *must estimate* fee rates;
 # they cannot be exact due to the lack of change output.)
 #
 # Example: max_sweep_fee_change = 0.4, with tx_fees = 10000,
 # means actual fee rate achieved in the sweep can be as low
 # as 6000 sats/kilo-vbyte up to 14000 sats/kilo-vbyte.
 #
 # If this is not achieved, the transaction is aborted. For tumbler,
 # it will then be retried until successful.
 # WARNING: too-strict setting may result in using up a lot
 # of PoDLE commitments, hence the default 0.8 (80%).
 max_sweep_fee_change = 0.8
 # Maximum absolute coinjoin fee in satoshi to pay to a single
 # market maker for a transaction. Both the limits given in
 # max_cj_fee_abs and max_cj_fee_rel must be exceeded in order
 # to not consider a certain offer.
 #max_cj_fee_abs = x
 # Maximum relative coinjoin fee, in fractions of the coinjoin value
 # e.g. if your coinjoin amount is 2 btc (200000000 satoshi) and
 # max_cj_fee_rel = 0.001 (0.1%), the maximum fee allowed would
 # be 0.002 btc (200000 satoshi)
 #max_cj_fee_rel = x
 # the range of confirmations passed to the `listunspent` bitcoind RPC call
 # 1st value is the inclusive minimum, defaults to one confirmation
 # 2nd value is the exclusive maximum, defaults to most-positive-bignum (Google Me!)
 # leaving it unset or empty defers to bitcoind's default values, ie [1, 9999999]
 #listunspent_args = []
 # that's what you should do, unless you have a specific reason, eg:
 #  !!! WARNING !!! CONFIGURING THIS WHILE TAKING LIQUIDITY FROM
 #  !!! WARNING !!! THE PUBLIC ORDERBOOK LEAKS YOUR INPUT MERGES
 #  spend from unconfirmed transactions:  listunspent_args = [0]
 # display only unconfirmed transactions: listunspent_args = [0, 1]
 # defend against small reorganizations:  listunspent_args = [3]
 #   who is at risk of reorganization?:   listunspent_args = [0, 2]
 # NB: using 0 for the 1st value with scripts other than wallet-tool could cause
 # spends from unconfirmed inputs, which may then get malleated or double-spent!
 # other counterparties are likely to reject unconfirmed inputs... don't do it.
 # tx_broadcast: options: self, random-peer, not-self.
 #
 # self = broadcast transaction with your own bitcoin node.
 #
 # random-peer = everyone who took part in the coinjoin has a chance of broadcasting
 # note: if your counterparties do not support it, you will fall back
 # to broadcasting via your own node.
 #
 # not-self = never broadcast with your own bitcoin node.
 # note: in this case if your counterparties do not broadcast for you, you
 # will have to broadcast the tx manually (you can take the tx hex from the log
 # or terminal) via some other channel. It is not recommended to choose this
 # option when running schedules/tumbler.
 tx_broadcast = random-peer
 # If makers do not respond while creating a coinjoin transaction,
 # the non-responding ones will be ignored. This is the minimum
 # amount of makers which we are content with for the coinjoin to
 # succceed. Less makers means that the whole process will restart
 # after a timeout.
 minimum_makers = 4
 # Threshold number of satoshis below which an incoming utxo
 # to a reused address in the wallet will be AUTOMATICALLY frozen.
 # This avoids forced address reuse attacks; see:
 # https://en.bitcoin.it/wiki/Privacy#Forced_address_reuse
 #
 # The default is to ALWAYS freeze a utxo to an already used address,
 # whatever the value of it, and this is set with the value -1.
 max_sats_freeze_reuse = -1
 # Interest rate used when calculating the value of fidelity bonds created
 # by locking bitcoins in timelocked addresses
 # See also:
 # https://gist.github.com/chris-belcher/87ebbcbb639686057a389acb9ab3e25b#determining-interest-rate-r
 # Set as a real number, i.e. 1 = 100% and 0.01 = 1%
 interest_rate = """ + _DEFAULT_INTEREST_RATE + """
 # Some makers run their bots to mix their funds not just to earn money
 # So to improve privacy very slightly takers dont always choose a maker based
 # on his fidelity bond but allow a certain small percentage to be chosen completely
 # randomly without taking into account fidelity bonds
 # This parameter sets how many makers on average will be chosen regardless of bonds
 # A real number, i.e. 1 = 100%, 0.125 = 1/8 = 1 in every 8 makers on average will be bondless
 bondless_makers_allowance = """ + _DEFAULT_BONDLESS_MAKERS_ALLOWANCE + """
 ##############################
 #THE FOLLOWING SETTINGS ARE REQUIRED TO DEFEND AGAINST SNOOPERS.
 #DON'T ALTER THEM UNLESS YOU UNDERSTAND THE IMPLICATIONS.
 ##############################
 # number of retries allowed for a specific utxo, to prevent DOS/snooping.
 # Lower settings make snooping more expensive, but also prevent honest users
 # from retrying if an error occurs.
 taker_utxo_retries = 3
 # number of confirmations required for the commitment utxo mentioned above.
 # this effectively rate-limits a snooper.
 taker_utxo_age = 5
 # percentage of coinjoin amount that the commitment utxo must have
 # as a minimum BTC amount. Thus 20 means a 1BTC coinjoin requires the
 # utxo to be at least 0.2 btc.
 taker_utxo_amtpercent = 20
 #Set to 1 to accept broadcast PoDLE commitments from other bots, and
 #add them to your blacklist (only relevant for Makers).
 #There is no way to spoof these values, so the only "risk" is that
 #someone fills your blacklist file with a lot of data.
 accept_commitment_broadcasts = 1
 #Location of your commitments.json file (stores commitments you've used
 #and those you want to use in future), relative to the scripts directory.
 commit_file_location = cmtdata/commitments.json
 ##############################
 # END OF ANTI-SNOOPING SETTINGS
 ##############################
 [PAYJOIN]
 # for the majority of situations, the defaults
 # need not be altered - they will ensure you don't pay
 # a significantly higher fee.
 # MODIFICATION OF THESE SETTINGS IS DISADVISED.
 # Payjoin protocol version; currently only '1' is supported.
 payjoin_version = 1
 # servers can change their destination address by default (0).
 # if '1', they cannot. Note that servers can explicitly request
 # that this is activated, in which case we respect that choice.
 disable_output_substitution = 0
 # "default" here indicates that we will allow the receiver to
 # increase the fee we pay by:
 # 1.2 * (our_fee_rate_per_vbyte * vsize_of_our_input_type)
 # (see https://github.com/bitcoin/bips/blob/master/bip-0078.mediawiki#span_idfeeoutputspanFee_output)
 # (and 1.2 to give breathing room)
 # which indicates we are allowing roughly one extra input's fee.
 # If it is instead set to an integer, then that many satoshis are allowed.
 # Additionally, note that we will also set the parameter additionafeeoutputindex
 # to that of our change output, unless there is none in which case this is disabled.
 max_additional_fee_contribution = default
 # this is the minimum satoshis per vbyte we allow in the payjoin
 # transaction; note it is decimal, not integer.
 min_fee_rate = 1.1
 # for payjoins to hidden service endpoints, the socks5 configuration:
 onion_socks5_host = localhost
 onion_socks5_port = 9050
 # for payjoin onion service creation, the tor control configuration:
 tor_control_host = localhost
 # or, to use a UNIX socket
 # control_host = unix:/var/run/tor/control
 tor_control_port = 9051
 # in some exceptional case the HS may be SSL configured,
 # this feature is not yet implemented in code, but here for the
 # future:
 hidden_service_ssl = false
 [YIELDGENERATOR]
 # [string, 'reloffer' or 'absoffer'], which fee type to actually use
 ordertype = reloffer
 # [satoshis, any integer] / absolute offer fee you wish to receive for coinjoins (cj)
 cjfee_a = 500
 # [fraction, any str between 0-1] / relative offer fee you wish to receive based on a cj's amount
 cjfee_r = 0.00002
 # [fraction, 0-1] / variance around the average fee. Ex: 200 fee, 0.2 var = fee is btw 160-240
 cjfee_factor = 0.1
 # [satoshis, any integer] / the average transaction fee you're adding to coinjoin transactions
 txfee = 100
 # [fraction, 0-1] / variance around the average fee. Ex: 1000 fee, 0.2 var = fee is btw 800-1200
 txfee_factor = 0.3
 # [satoshis, any integer] / minimum size of your cj offer. Lower cj amounts will be disregarded
 minsize = 100000
 # [fraction, 0-1] / variance around all offer sizes. Ex: 500k minsize, 0.1 var = 450k-550k
 size_factor = 0.1
 gaplimit = 6
 [SNICKER]
 # any other value than 'true' will be treated as False,
 # and no SNICKER actions will be enabled in that case:
 enabled = false
 # in satoshis, we require any SNICKER to pay us at least
 # this much (can be negative), otherwise we will refuse
 # to sign it:
 lowest_net_gain = 0
 # comma separated list of servers (if port is omitted as :port, it
 # is assumed to be 80) which we will poll against (all, in sequence); note
 # that they are allowed to be *.onion or cleartext servers, and no
 # scheme (http(s) etc) needs to be added to the start.
 servers = cn5lfwvrswicuxn3gjsxoved6l2gu5hdvwy5l3ev7kg6j7lbji2k7hqd.onion,
 # how many minutes between each polling event to each server above:
 polling_interval_minutes = 60
 """

 #This allows use of the jmclient package with a
 #configuration set by an external caller; not to be used
 #in conjuction with calls to load_program_config.
 def set_config(cfg, bcint=None):
     global_singleton.config = cfg
     if bcint:
         global_singleton.bc_interface = bcint


 def get_irc_mchannels():
     SECTION_NAME = 'MESSAGING'
     # FIXME: remove in future release
     if jm_single().config.has_section(SECTION_NAME):
         log.warning("Old IRC configuration detected. Please adopt your "
                     "joinmarket.cfg as documented in 'docs/config-irc-"
                     "update.md'. Support for the old setting will be removed "
                     "in a future version.")
         return _get_irc_mchannels_old()

     SECTION_NAME += ':'
     irc_sections = []
     for s in jm_single().config.sections():
         if s.startswith(SECTION_NAME):
             irc_sections.append(s)
     assert irc_sections

     fields = [("host", str), ("port", int), ("channel", str), ("usessl", str),
               ("socks5", str), ("socks5_host", str), ("socks5_port", str)]

     configs = []
     for section in irc_sections:
         server_data = {}
         for option, otype in fields:
             val = jm_single().config.get(section, option)
             server_data[option] = otype(val)
         server_data['btcnet'] = get_network()
         configs.append(server_data)
     return configs


 def _get_irc_mchannels_old():
     fields = [("host", str), ("port", int), ("channel", str), ("usessl", str),
               ("socks5", str), ("socks5_host", str), ("socks5_port", str)]
     configdata = {}
     for f, t in fields:
         vals = jm_single().config.get("MESSAGING", f).split(",")
         if t == str:
             vals = [x.strip() for x in vals]
         else:
             vals = [t(x) for x in vals]
         configdata[f] = vals
     configs = []
     for i in range(len(configdata['host'])):
         newconfig = dict([(x, configdata[x][i]) for x in configdata])
         newconfig['btcnet'] = get_network()
         configs.append(newconfig)
     return configs


 def get_config_irc_channel(channel_name):
     channel = "#" + channel_name
     if get_network() == 'testnet':
         channel += '-test'
     elif get_network() == 'signet':
         channel += '-sig'
     return channel

 class JMPluginService(object):
     """ Allows us to configure on-startup
     any additional service (such as SNICKER).
     For now only covers logging.
     """
     def __init__(self, name, requires_logging=True):
         self.name = name
         self.requires_logging = requires_logging

     def start_plugin_logging(self, wallet):
         """ This requires the name of the active wallet
         to set the logfile; TODO other plugin services may
         need a different setup.
         """
         self.wallet = wallet
         self.logfilename = "{}-{}.log".format(self.name,
                             self.wallet.get_wallet_name())
         self.start_logging()

     def set_log_dir(self, logdirname):
         self.logdirname = logdirname

     def start_logging(self):
         logFormatter = logging.Formatter(
             ('%(asctime)s [%(levelname)-5.5s] {} - %(message)s'.format(
                 self.name)))
         fileHandler = logging.FileHandler(
             self.logdirname + '/{}'.format(self.logfilename))
         fileHandler.setFormatter(logFormatter)
         get_log().addHandler(fileHandler)

 def get_network():
     """Returns network name"""
     return global_singleton.config.get("BLOCKCHAIN", "network")

 def validate_address(addr):
     try:
         # automatically respects the network
         # as set in btc.select_chain_params(...)
         dummyaddr = btc.CCoinAddress(addr)
     except Exception as e:
         return False, repr(e)
     # additional check necessary because python-bitcointx
     # does not check hash length on p2sh construction.
     try:
         dummyaddr.to_scriptPubKey()
     except Exception as e:
         return False, repr(e)
     return True, "address validated"

 _BURN_DESTINATION = "BURN"

 def is_burn_destination(destination):
     return destination == _BURN_DESTINATION

 def get_interest_rate():
     return float(global_singleton.config.get('POLICY', 'interest_rate',
         fallback=_DEFAULT_INTEREST_RATE))

 def get_bondless_makers_allowance():
     return float(global_singleton.config.get('POLICY', 'bondless_makers_allowance',
         fallback=_DEFAULT_BONDLESS_MAKERS_ALLOWANCE))

 def remove_unwanted_default_settings(config):
     for section in config.sections():
         if section.startswith('MESSAGING:'):
             config.remove_section(section)

 def load_program_config(config_path="", bs=None, plugin_services=[]):
     global_singleton.config.readfp(io.StringIO(defaultconfig))
     if not config_path:
         config_path = lookup_appdata_folder(global_singleton.APPNAME)
     # we set the global home directory, but keep the config_path variable
     # for callers of this function:
     global_singleton.datadir = config_path
     jmprint("User data location: " + global_singleton.datadir, "info")
     if not os.path.exists(global_singleton.datadir):
         os.makedirs(global_singleton.datadir)
     # prepare folders for wallets and logs
     if not os.path.exists(os.path.join(global_singleton.datadir, "wallets")):
         os.makedirs(os.path.join(global_singleton.datadir, "wallets"))
     if not os.path.exists(os.path.join(global_singleton.datadir, "logs")):
         os.makedirs(os.path.join(global_singleton.datadir, "logs"))
     if not os.path.exists(os.path.join(global_singleton.datadir, "cmtdata")):
         os.makedirs(os.path.join(global_singleton.datadir, "cmtdata"))
     global_singleton.config_location = os.path.join(
         global_singleton.datadir, global_singleton.config_location)

     remove_unwanted_default_settings(global_singleton.config)
     try:
         loadedFiles = global_singleton.config.read(
             [global_singleton.config_location])
     except UnicodeDecodeError:
         jmprint("Error loading `joinmarket.cfg`, invalid file format.",
             "info")
         sys.exit(EXIT_FAILURE)

     #Hack required for electrum; must be able to enforce a different
     #blockchain interface even in default/new load.
     if bs:
         global_singleton.config.set("BLOCKCHAIN", "blockchain_source", bs)
     # Create default config file if not found
     if len(loadedFiles) != 1:
         with open(global_singleton.config_location, "w") as configfile:
             configfile.write(defaultconfig)
         jmprint("Created a new `joinmarket.cfg`. Please review and adopt the "
               "settings and restart joinmarket.", "info")
         sys.exit(EXIT_FAILURE)

     #These are left as sanity checks but currently impossible
     #since any edits are overlays to the default, these sections/options will
     #always exist.
     # FIXME: This check is a best-effort attempt. Certain incorrect section
     # names can pass and so can non-first invalid sections.
     for s in required_options: #pragma: no cover
         # check for sections
         avail = None
         if not global_singleton.config.has_section(s):
             for avail in global_singleton.config.sections():
                 if avail.startswith(s):
                     break
             else:
                 raise Exception(
                     "Config file does not contain the required section: " + s)
         # then check for specific options
         k = avail or s
         for o in required_options[s]:
             if not global_singleton.config.has_option(k, o):
                 raise Exception("Config file does not contain the required "
                                 "option '{}' in section '{}'.".format(o, k))

     loglevel = global_singleton.config.get("LOGGING", "console_log_level")
     try:
         set_logging_level(loglevel)
     except:
         jmprint("Failed to set logging level, must be DEBUG, INFO, WARNING, ERROR",
                 "error")

     # Logs to the console are color-coded if user chooses (file is unaffected)
     if global_singleton.config.get("LOGGING", "color") == "true":
         set_logging_color(True)
     else:
         set_logging_color(False)

     try:
         global_singleton.maker_timeout_sec = global_singleton.config.getint(
             'TIMEOUT', 'maker_timeout_sec')
     except NoOptionError: #pragma: no cover
         log.debug('TIMEOUT/maker_timeout_sec not found in .cfg file, '
                   'using default value')

     # configure the interface to the blockchain on startup
     global_singleton.bc_interface = get_blockchain_interface_instance(
         global_singleton.config)

     # set the location of the commitments file; for non-mainnet a different
     # file is used to avoid conflict
     try:
         global_singleton.commit_file_location = global_singleton.config.get(
             "POLICY", "commit_file_location")
     except NoOptionError: #pragma: no cover
         if get_network() == "mainnet":
             log.debug("No commitment file location in config, using default "
                   "location cmtdata/commitments.json")
     if get_network() != "mainnet":
         # no need to be flexible for tests; note this is used
         # for regtest, signet and testnet3
         global_singleton.commit_file_location = "cmtdata/" + get_network() + \
             "_commitments.json"
     set_commitment_file(os.path.join(config_path,
                                          global_singleton.commit_file_location))

     for p in plugin_services:
         # for now, at this config level, the only significance
         # of a "plugin" is that it keeps its own separate log.
         # We require that a section exists in the config file,
         # and that it has enabled=true:
         assert isinstance(p, JMPluginService)
         if not (global_singleton.config.has_section(p.name) and \
                 global_singleton.config.has_option(p.name, "enabled") and \
                 global_singleton.config.get(p.name, "enabled") == "true"):
             break
         if p.requires_logging:
             # make sure the environment can accept a logfile by
             # creating the directory in the correct place,
             # and setting that in the plugin object; the plugin
             # itself will switch on its own logging when ready,
             # attaching a filehandler to the global log.
             plogsdir = os.path.join(os.path.dirname(
                 global_singleton.config_location), "logs", p.name)
             if not os.path.exists(plogsdir):
                 os.makedirs(plogsdir)
             p.set_log_dir(plogsdir)

 def load_test_config(**kwargs):
     if "config_path" not in kwargs:
         load_program_config(config_path=".", **kwargs)
     else:
         load_program_config(**kwargs)

 ##########################################################
 ## Returns a tuple (rpc_user: String, rpc_pass: String) ##
 ##########################################################
 def get_bitcoin_rpc_credentials(_config):
     filepath = None

     try:
         filepath = _config.get("BLOCKCHAIN", "rpc_cookie_file")
     except NoOptionError:
         pass

     if filepath:
         if os.path.isfile(filepath):
             rpc_credentials_string = open(filepath, 'r').read()
             return rpc_credentials_string.split(":")
         else:
             raise ValueError("Invalid cookie auth credentials file location")
     else:
         rpc_user = _config.get("BLOCKCHAIN", "rpc_user")
         rpc_password = _config.get("BLOCKCHAIN", "rpc_password")
         if not (rpc_user and rpc_password):
             raise ValueError("Invalid RPC auth credentials `rpc_user` and `rpc_password`")
         return rpc_user, rpc_password

 def get_blockchain_interface_instance(_config):
     # todo: refactor joinmarket module to get rid of loops
     # importing here is necessary to avoid import loops
     from jmclient.blockchaininterface import BitcoinCoreInterface, \
         RegtestBitcoinCoreInterface, ElectrumWalletInterface, \
         BitcoinCoreNoHistoryInterface
     source = _config.get("BLOCKCHAIN", "blockchain_source")
     network = get_network()
     testnet = (network == 'testnet' or network == 'signet')

     if source in ('bitcoin-rpc', 'regtest', 'bitcoin-rpc-no-history'):
         rpc_host = _config.get("BLOCKCHAIN", "rpc_host")
         rpc_port = _config.get("BLOCKCHAIN", "rpc_port")
         rpc_user, rpc_password = get_bitcoin_rpc_credentials(_config)
         rpc_wallet_file = _config.get("BLOCKCHAIN", "rpc_wallet_file")
         rpc = JsonRpc(rpc_host, rpc_port, rpc_user, rpc_password,
             rpc_wallet_file)
         if source == 'bitcoin-rpc': #pragma: no cover
             bc_interface = BitcoinCoreInterface(rpc, network)
             if testnet:
                 btc.select_chain_params("bitcoin/testnet")
             else:
                 btc.select_chain_params("bitcoin")
         elif source == 'regtest':
             bc_interface = RegtestBitcoinCoreInterface(rpc)
             btc.select_chain_params("bitcoin/regtest")
         elif source == "bitcoin-rpc-no-history":
             bc_interface = BitcoinCoreNoHistoryInterface(rpc, network)
             if testnet or network == "regtest":
                 # in tests, for bech32 regtest addresses, for bc-no-history,
                 # this will have to be reset manually:
                 btc.select_chain_params("bitcoin/testnet")
             else:
                 btc.select_chain_params("bitcoin")
         else:
             assert 0
     elif source == 'electrum':
         bc_interface = ElectrumWalletInterface(testnet)
     elif source == 'no-blockchain':
         bc_interface = None
     else:
         raise ValueError("Invalid blockchain source")
     return bc_interface

 def update_persist_config(section, name, value):
     """ Unfortunately we cannot persist an updated config
     while preserving the full set of comments with ConfigParser's
     model (the 'set no-value settings' doesn't cut it).
     Hence if we want to update and persist, we must manually
     edit the file at the same time as editing the in-memory
     config object.
     Arguments: section and name must be strings (and
     section must already exist), while value can be any valid
     type for a config value, but must be cast-able to string.
     Returns: False if the config setting was not found,
     or True if it was found and edited+saved as intended.
     """

     m_line  = re.compile(r"^\s*" + name + r"\s*" + "=", re.IGNORECASE)
     m_section = re.compile(r"\[\s*" + section + r"\s*\]", re.IGNORECASE)

     # Find the single line containing the specified value; only accept
     # if it's the right section; create a new copy of all the config
     # lines, with that one line edited.
     # If one match is found and edited, rewrite the config and update
     # the in-memory config, else return an error.
     sectionname = None
     newlines = []
     match_found = False
     with open(jm_single().config_location, "r") as f:
         for line in f.readlines():
             newline  = line
             # ignore comment lines
             if line.strip().startswith("#"):
                 newlines.append(line)
                 continue
             regexp_match_section = m_section.search(line)
             if regexp_match_section:
                 # get the section name from the match
                 sectionname = regexp_match_section.group().strip("[]").strip()
             regexp_match = m_line.search(line)
             if regexp_match and sectionname and sectionname.upper(
                 ) == section.upper():
                 # We have the right line; change it
                 newline = name + " = " + str(value)+"\n"
                 match_found = True
             newlines.append(newline)
     # If it wasn't found, do nothing but return an error
     if not match_found:
         return False
     # success: update in-mem and re-persist
     jm_single().config.set(section, name, value)
     with open(jm_single().config_location, "wb") as f:
         f.writelines([x.encode("utf-8") for x in newlines])
     return True

 def is_segwit_mode():
     return jm_single().config.get('POLICY', 'segwit') != 'false'

 def is_native_segwit_mode():
     if not is_segwit_mode():
         return False
     return jm_single().config.get('POLICY', 'native') != 'false'

 def process_shutdown(mode="command-line"):
     if mode=="command-line":
         from twisted.internet import reactor
         for dc in reactor.getDelayedCalls():
             dc.cancel()
         reactor.stop()

 def process_startup():
     from twisted.internet import reactor
     reactor.run()
 */
