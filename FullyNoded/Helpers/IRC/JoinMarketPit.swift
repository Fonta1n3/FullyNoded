//
//  JoinMarketPit.swift
//  FullyNoded
//
//  Created by Peter Denton on 8/25/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class JoinMarketPit: NSObject {
    static let sharedInstance = JoinMarketPit()
    
    private override init() {}
    
    var connectedToPit: ((Bool) -> Void)?
    var server:IRCServer!
    var absOffers = [JMOffer]()
    var relOffers = [JMOffer]()
    
    enum HostName: String {
        case darkScience = "darkirc6tqgpnwd3blln3yfv5ckl47eg7llfxkmtovrv7c7iwohhb6ad.onion"
        case hackInt = "ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion"
    }
    
    func connect() {
        server = JoinMarketPit.server()
        server.delegate = self
    }
    
    func getOrderBook() {
        server.send("PRIVMSG #joinmarket-pit-test :!orderbook")
    }
    
    private class func server() -> IRCServer {
        return IRCServer(hostname: HostName.darkScience.rawValue, port: 6667, user: user())
    }
    
    private class func user() -> IRCUser {
        let userName = randomString(length: 10)
        let realName = randomString(length: 8)
        let nick = randomNick() ?? ""
        return IRCUser(username: userName, realName: realName, nick: nick)
    }
    
    private class func randomNick() -> String? {
        guard let secret = Crypto.secretNick(),
              let pubkey = Keys.privKeyToPubKey(secret),
              let data = Data(hexString: Crypto.sha256hash(pubkey)) else { return nil }
                
        let firstTen = data.subdata(in: Range(0...9))
        var b58 = Base58.encode([UInt8](firstTen))
        
        if b58.count < 14 {
            for _ in 0 ... (15 - b58.count) {
                b58 += "O"
            }
        }
                
        return "J5" + b58
    }
}

extension JoinMarketPit: IRCServerDelegate {
    func didRecieveMessage(_ server: IRCServer, message: String) {
        print("did recieve server message from \(server): \(message)")
    }
    
    func didConnect(_ server: IRCServer) {
        print("didConnect \(server)")
        JoinMarketPit.sharedInstance.connectedToPit?((server.alive))
    }
    
    func offers(_ server: IRCServer) {
        JoinMarketPit.sharedInstance.absOffers = server.absOffers
        JoinMarketPit.sharedInstance.relOffers = server.relOffers
    }
}

extension JoinMarketPit: IRCChannelDelegate {
    func didRecieveMessage(_ channel: IRCChannel, message: String) {
        print("did receive channel message from \(channel): \(message)")
    }
}
