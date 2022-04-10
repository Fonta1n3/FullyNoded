////
////  Taker.swift
////  FullyNoded
////
////  Created by Peter Denton on 9/6/21.
////  Copyright © 2021 Fontaine. All rights reserved.
////
//
///*
// Encryption handshake in JoinMarket
// ==================================
//
// In the clear
// ============
//
// TAK: !fill <order id> <coinjoin amount> <taker encryption pubkey>
// MAK: !pubkey <maker encryption pubkey>
//
// Both maker and taker construct a crypto Box object to allow authenticated encryption between the parties.
// These Box objects are properties of the CoinJoinTx and CoinJoinOrder objects, so they are specific to
// transactions and not to Maker and Taker entities.
//
// Encrypted
// =========
//
// TAK: !auth <input utxo pubkey> <btc sig of taker encryption pubkey using input utxo pubkey>
// (Maker verifies the btc sig; if not valid, connection is dropped - send REJECT message)
// MAK: !ioauth <utxo list> <coinjoin pubkey> <change address> <btc sig of maker encryption pubkey using coinjoin pubkey>
// (Taker verifies the btc sig; if not valid, as for previous)
//
// Because the !auth messages are under encryption, there is no privacy leak of bitcoin pubkeys or output addresses.
//
// If both verifications pass, the remainder of the messages exchanged between the two parties will continue under encryption.
//
// Specifically, these message types will be encrypted:
// !auth
// !ioauth
// !tx
// !sig
//
// Note
// ====
// A key part of the authorisation process is the matching between the bitcoin pubkeys used in the coinjoin
// transaction and the encryption pubkeys used. This ensures that the messages we are sending are only
// readable by the entity which is conducting the bitcoin transaction with us.
//
// To ensure this, the maker should not sign any transaction that doesn't use the previously identified
// input utxo as its input, and the taker should not push/sign any transaction that doesn't use the
// previously identified maker coinjoin pubkey/address as its output.
// */
//
//import Foundation
//
//class Taker: NSObject {
//    
//    static let shared = Taker()
//    
//    private override init() {}
//    
//    func handshake(_ offer: JMOffer, _ utxo: Utxo, completion: @escaping ((String?) -> Void)) {
//        //!fill <order id> <coinjoin amount> <taker encryption pubkey> <commitment>
//        
//        //!auth <input utxo pubkey> <btc sig of taker encryption pubkey using input utxo pubkey>
//        
//        guard let privkey = Keys.randomPrivKey() else { print("privkey failing"); return }
//        guard let pubkey = Keys.privKeyToPubKey(privkey) else { print("pubkey failing"); return }
//        guard let server = JoinMarketPit.sharedInstance.server else { print("server failing"); return }
//        let maker = offer.maker
//        guard let oid = offer.oid else { print("oid failing"); return }
//        guard let cjAmount = utxo.amount else { print("cjamount failing"); return }
//        guard let commitment = utxo.commitment else { print("commitment failing"); return }
//        
//        
//        server.delegate = self
//                
//        let amount = Int(cjAmount * 100000000)
//        
//        let fill = "PRIVMSG \(maker) :!fill \(oid) \(amount) \(pubkey) \(commitment)"
//        
//        server.send(fill)
//    }
//
//}
//
//extension Taker: IRCServerDelegate {
//    func didRecieveMessage(_ server: IRCServer, message: String) {
//        print("message: \(message)")
//    }
//    
//    func didConnect(_ server: IRCServer) {
//        print("server did connect")
//    }
//    
//    func offers(_ server: IRCServer) {
//        print("offers")
//    }
//}
