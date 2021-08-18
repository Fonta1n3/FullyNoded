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
                        let dp = DescriptorParser()
                        let ds = dp.descriptor(desc)
                        
                        let origin = ds.prefix
                        print("origin: \(origin)")
                        
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
              let string = decrypted.utf8 else {
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
    
    static func connectToPit() {
        let user = IRCUser(username: "fullynoded", realName: "satoshi nakamoto", nick: "WIP")
        let server = IRCServer.connect("ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion", port: 6667, user: user)
        let _ = server.join("joinmarket-pit")
    }
    
    class func receivedServerMessage(_ message: String) {
        print("received server message: \(message)")
    }
    
    class func receivedChannelMessage(_ message: String) {
        print("received channel message: \(message)")
    }
    
}

extension JoinMarket: IRCServerDelegate {
    func didRecieveMessage(_ server: IRCServer, message: String) {
        JoinMarket.receivedServerMessage(message)
    }
}

extension JoinMarket: IRCChannelDelegate {
    func didRecieveMessage(_ channel: IRCChannel, message: String) {
        JoinMarket.receivedChannelMessage(message)
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





