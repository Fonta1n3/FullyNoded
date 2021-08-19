//
//  IRC.swift
//  IRC
//
//  Created by Samuel Ryan Goodwin on 8/12/17.
//  Copyright © 2017 Roundwall Software. All rights reserved.
//
import Foundation

public struct IRCUser {
    public let username: String
    public let realName: String
    public let nick: String
    
    public init(username: String, realName: String, nick: String) {
        self.username = username
        self.realName = realName
        self.nick = nick
    }
}

public class IRCChannel {
    public var delegate: IRCChannelDelegate? = nil {
        didSet {
            guard let delegate = delegate else {
                return
            }
            
            buffer.forEach { (line) in
                delegate.didRecieveMessage(self, message: line)
            }
            buffer = []
        }
    }
    public let name: String
    public let server: IRCServer
    private var buffer = [String]()
    
    public init(name: String, server: IRCServer) {
        self.name = name
        self.server = server
    }
    
    
    func receive(_ text: String) {
        if let delegate = self.delegate {
            delegate.didRecieveMessage(self, message: text)
        } else {
            buffer.append(text)
        }
    }
    
    public func send(_ text: String) {
        server.send("PRIVMSG #\(name) :\(text)")
    }
}

public class IRCServer {
    public var delegate: IRCServerDelegate? {
        didSet {
            guard let delegate = delegate else {
                return
            }
            
            buffer.forEach { (line) in
                delegate.didRecieveMessage(self, message: line)
            }
            buffer = []
        }
    }
    
    private var buffer = [String]()
    private var session = TorClient.sharedInstance.session
    private var task: URLSessionStreamTask!
    private var channels = [IRCChannel]()
    
    public required init(hostname: String, port: Int, user: IRCUser, session: URLSession) {
        self.session = session
        
        task = session.streamTask(withHostName: hostname, port: port)
        task.resume()
        read()
        
        send("USER \(user.username) 0 * :\(user.realName)")
        send("NICK \(user.nick)")
    }
    
    public class func connect(_ hostname: String, port: Int, user: IRCUser, session: URLSession = URLSession.shared) -> Self {
        return self.init(hostname: hostname, port: port, user: user, session: session)
    }
    
    private func read() {
        task.readData(ofMinLength: 0, maxLength: 9999, timeout: 0) { (data, atEOF, error) in
            print("data: \(data)")
            print("error: \(error)")
            
            guard let data = data, let message = String(data: data, encoding: .utf8) else {
                return
            }
            
            for line in message.split(separator: "\r\n") {
                self.processLine(String(line))
            }
            
            self.read()
        }
    }
    
    private func processLine(_ message: String) {
        let input = IRCServerInputParser.parseServerMessage(message)
        switch input {
        case .serverMessage(_, let message):
            print(message)
            if let delegate = self.delegate {
                delegate.didRecieveMessage(self, message: message)
            } else {
                self.buffer.append(message)
            }
        case .joinMessage(let user, let channelName):
            self.channels.forEach({ (channel) in
                if channel.name == channelName {
                    channel.receive("\(user) joined \(channelName)")
                }
            })
        case .channelMessage(let channelName, let user, let message):
            self.channels.forEach({ (channel) in
                if channel.name == channelName {
                    channel.receive("\(user): \(message)")
                }
            })
        case .userList(let channelName, let users):
            self.channels.forEach({ (channel) in
                if channel.name == channelName {
                    users.forEach({ (user) in
                        channel.receive("\(user) joined")
                    })
                }
            })
        default:
            print("Unknown: \(message)")
        }
    }
    
    public func send(_ message: String) {
        task.write((message + "\r\n").data(using: .utf8)!, timeout: 0) { (error) in
            if let error = error {
                print("Failed to send: \(String(describing: error))")
            } else {
                print("Sent!")
            }
        }
    }
    
    public func join(_ channelName: String) -> IRCChannel {
        send("JOIN #\(channelName)")
        let channel = IRCChannel(name: channelName, server: self)
        channels.append(channel)
        return channel
    }
}

public protocol IRCServerDelegate {
    func didRecieveMessage(_ server: IRCServer, message: String)
}


public protocol IRCChannelDelegate {
    func didRecieveMessage(_ channel: IRCChannel, message: String)
}
