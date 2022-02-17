////
////  IRC.swift
////  IRC
////
////  Created by Samuel Ryan Goodwin on 8/12/17.
////  Copyright © 2017 Roundwall Software. All rights reserved.
////
//import Foundation
//
//public struct IRCUser {
//    public let username: String
//    public let realName: String
//    public let nick: String
//    
//    public init(username: String, realName: String, nick: String) {
//        self.username = username
//        self.realName = realName
//        self.nick = nick
//    }
//}
//
//public class IRCChannel {
//    public var delegate: IRCChannelDelegate? = nil {
//        didSet {
//            guard let delegate = delegate else {
//                return
//            }
//            
//            buffer.forEach { (line) in
//                delegate.didRecieveMessage(self, message: line)
//            }
//            buffer = []
//        }
//    }
//    public let name: String
//    public let server: IRCServer
//    private var buffer = [String]()
//    
//    public init(name: String, server: IRCServer) {
//        self.name = name
//        self.server = server
//    }
//    
//    
//    func receive(_ text: String) {
//        if let delegate = self.delegate {
//            delegate.didRecieveMessage(self, message: text)
//        } else {
//            buffer.append(text)
//        }
//    }
//    
//    public func send(_ text: String) {
//        server.send("PRIVMSG #\(name) :\(text)")
//    }
//}
//
//public class IRCServer {
//    public var delegate: IRCServerDelegate? {
//        didSet {
//            guard let delegate = delegate else {
//                return
//            }
//            
//            buffer.forEach { (line) in
//                delegate.didRecieveMessage(self, message: line)
//            }
//            buffer = []
//        }
//    }
//    
//    private var buffer = [String]()
//    private let session = TorClient.sharedInstance.session
//    private var task: URLSessionStreamTask!
//    private var channels = [IRCChannel]()
//    private var user: IRCUser
//    private var timer: Timer?
//    private var pingMessage = ""
//    public var alive = false
//    public var absOffers = [JMOffer]()
//    public var relOffers = [JMOffer]()
//    
//    public required init(hostname: String, port: Int, user: IRCUser) {
//        self.user = user
//        
//        task = session.streamTask(withHostName: hostname, port: port)
//        task.resume()
//        read()
//        
//        send("USER \(user.username) 0 * :\(user.realName)")
//        send("NICK \(user.nick)")
//    }
//    
//    public class func connect(_ hostname: String, port: Int, user: IRCUser) -> Self {
//        return self.init(hostname: hostname, port: port, user: user)
//    }
//    
//    private func read() {
//        task.readData(ofMinLength: 0, maxLength: 9999, timeout: 60) { (data, atEOF, error) in
//            guard let data = data, let message = String(data: data, encoding: .utf8) else {
//                if let error = error {
//                    print("error: \(error.localizedDescription)")
//                }
//                
//                return
//            }
//            
//            //print("message: \(message)")
//            
//            for line in message.split(separator: "\r\n") {
//                self.processLine(String(line))
//            }
//            
//            self.read()
//        }
//    }
//    
//    private func processLine(_ message: String) {
//        let input = IRCServerInputParser.parseServerMessage(message)
//        
//        switch input {
//        case .serverMessage(_, let message):
//            if let delegate = self.delegate {
//                delegate.didRecieveMessage(self, message: message)
//            } else {
//                self.buffer.append(message)
//            }
//            
//        case .joinMessage(let user, let channelName):
//            channels.forEach({ (channel) in
//                if channel.name == channelName {
//                    channel.receive("\(user) joined \(channelName)")
//                }
//            })
//            
//        case .channelMessage(let channelName, let user, let message):
//            channels.forEach({ (channel) in
//                if channel.name == channelName {
//                    channel.receive("\(user): \(message)")
//                }
//            })
//            
//        case .ping(message):
//            send(message.pong)
//            
//        case .pong(message: message):
//            if message.contains(pingMessage) {
//                alive = true
//            }
//            
//        case .endOfMOTD(message: message):
//            joinNow()
//            
//        case .sw0absoffer(let offer):
//            print("append absoffer")
//            absOffers.append(offer)
//            
//        case .sw0reloffer(let offer):
//            print("append reloffer")
//            relOffers.append(offer)
//            
////        case .unknown(raw: message):
////            print("unknown message type: \(message)")
//            
//        default:
//            //print("Unknown: \(message)")
//        break
//        }
//    }
//    
//    public func send(_ message: String) {
//        task.write((message + "\r\n").data(using: .utf8)!, timeout: 20) { error in
//            if let error = error {
//                print("Failed to send: \(message)\n\(String(describing: error.localizedDescription))")
//            } else {
//                print("sent message: \(message)")
//            }
//        }
//    }
//    
//    private func joinNow() {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
//            guard let self = self else { return }
//            
//            let _ = self.join()
//        }
//    }
//    
//    enum Channel: String {
//        case testnet = "#joinmarket-pit-test"
//        case mainnet = "#joinmarket-pit"
//    }
//    
//    private func join() -> IRCChannel {
//        var channelString = Channel.mainnet.rawValue
//        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
//        
//        if chain == "test" {
//            channelString = Channel.testnet.rawValue
//        }
//        
//        send("JOIN \(channelString)")
//        send("MODE \(user.nick) +B")
//        send("MODE \(user.nick) -R")
//        
//        let channel = IRCChannel(name: channelString, server: self)
//        channels.append(channel)
//        setTimer()
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) { [weak self] in
//            guard let self = self else { return }
//            
//            print("fire off didConnect")
//            self.delegate?.didConnect(self)
//            self.exportOffers()
//        }
//        
//        return channel
//    }
//    
//    private func exportOffers() {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
//            guard let self = self else { return }
//            
//            print("fire off offers")
//            self.delegate?.offers(self)
//        }
//    }
//    
//    private func setTimer() {
//        self.timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(self.keepAlive), userInfo: nil, repeats: true)
//        
//    }
//    
//    @objc func keepAlive() {
//        self.pingMessage = randomString(length: 10)
//        self.send("PING \(pingMessage)")
//    }
//}
//
//public protocol IRCServerDelegate: AnyObject {
//    func didRecieveMessage(_ server: IRCServer, message: String)
//    func didConnect(_ server: IRCServer)
//    func offers(_ server: IRCServer)
//}
//
//public protocol IRCChannelDelegate {
//    func didRecieveMessage(_ channel: IRCChannel, message: String)
//}
