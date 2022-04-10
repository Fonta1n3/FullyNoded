////
////  IRCServerInputParser.swift
////  IRC
////
////  Created by Samuel Ryan Goodwin on 7/22/17.
////  Copyright © 2017 Roundwall Software. All rights reserved.
////
//import Foundation
//
//struct IRCServerInputParser {
//    
//    // MARK: Example !orderbook response
//    
//    // :J53e4hHsY9qVniYa!~J53e4hHsY@reid-kmg.07u.39.84.IP PRIVMSG J5ETF5dtzTkn1SGB :!sw0reloffer 0 1041735 2297121166 0 0.000018 035f6d1db12174d17636124b7ff99a48202a52ae30202c77a60fbb1a7fc41eb3fa MEUCIQDgt6AY5UAK/jttwy0EUknf1rP5hx34SEp04rum/ejCogIgblJmQ/HDgB9VimQnukUDdWFVNclCEpvUy6R8GonVODk= ~
//    
//    static func parseServerMessage(_ message: String) -> IRCServerInput? {
//        
//        switch message {
//        
//        // MARK: todo handle erroneous nick
//        //:Erroneous Nickname
//        
//        case _ where message.contains("End of /MOTD command") || message.contains("Welcome to Darkscience"):
//            return .endOfMOTD(message: message)
//            
//        case _ where message.hasPrefix("PING"):
//            return .ping(message: message)
//            
//        case _ where message.hasPrefix(":"):
//            if let firstSpaceIndex = message.firstIndex(of: " ") {
//                let source = message[..<firstSpaceIndex]
//                let rest = message[firstSpaceIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
//                //source = :J5AjwrSeb4Dvpf29!J5AjwrSeb4@tor.darkscience.net
//                let sourceChunks = source.split(separator: "!")
//                
//                if sourceChunks.count == 2 {
//                    let maker = "\(sourceChunks[0])".replacingOccurrences(of: ":", with: "")
//                    
//                    let offerChunks = rest.split(separator: "!")
//                    //offerChunks[0] = "PRIVMSG J55dwWZtXgVNVckn :"
//                    //offerChunks[1] = "sw0reloffer 0 27300 1130638816 0 0.002500"
//                    //offerChunks[2] = "tbond //8wRAIgUuRfeUYW0TBwlcX8+Bvg5wwE8+DxU1sLfgyPF1sgVq8CIGmhg1XemT9F/JsKtd27T53FC2tUdiix31IgX6LUe6VU//8wRAIgISN5peEJQSU/1ZYkH+e1TkInxPSg5w2WMb06YFMqe0MCIBekR60FkxUv7WmX1KPL/FaIvM4evZqMd0D0mPWTqT1AA/W43SXCmM4IQhnZvCNqiYvPojY4zu3n+25rmv3PkFNkWgEC8vlSXYrSw94MW1gt7q95LTdDS+Yx4AS/vG4Q1DNLY5/UA0Fvqnggve8D3+OoOb36dI+9ZLrWt5vE4IsfH2f7tQAAAAAArJZi 036b7dd4ca556b7c6549fdde88a3b9f84846 ;"
//                    
//                    for (i, chunk) in offerChunks.enumerated() {
//                        if i > 0 {
//                            switch chunk {
//                            case _ where chunk.hasPrefix("sw0reloffer"):
//                                return .sw0reloffer(offer: JMOffer(["maker": maker, "offer": "\(chunk)"]))
//                            case _ where chunk.hasPrefix("sw0absoffer"):
//                                return .sw0absoffer(offer: JMOffer(["maker": maker, "offer": "\(chunk)"]))
//                            default:
//                                break
//                            }
//                        }
//                    }
//                    
//                    //print("rest: \(rest)")
//                    //PRIVMSG J55dwWZtXgVNVckn :!sw0reloffer 0 27300 1130638816 0 0.002500!tbond //8wRAIgUuRfeUYW0TBwlcX8+Bvg5wwE8+DxU1sLfgyPF1sgVq8CIGmhg1XemT9F/JsKtd27T53FC2tUdiix31IgX6LUe6VU//8wRAIgISN5peEJQSU/1ZYkH+e1TkInxPSg5w2WMb06YFMqe0MCIBekR60FkxUv7WmX1KPL/FaIvM4evZqMd0D0mPWTqT1AA/W43SXCmM4IQhnZvCNqiYvPojY4zu3n+25rmv3PkFNkWgEC8vlSXYrSw94MW1gt7q95LTdDS+Yx4AS/vG4Q1DNLY5/UA0Fvqnggve8D3+OoOb36dI+9ZLrWt5vE4IsfH2f7tQAAAAAArJZi 036b7dd4ca556b7c6549fdde88a3b9f84846 ;
//                    
////                    if rest.hasPrefix("PRIVMSG") && rest.count > 7 {
////                        let remaining = rest[rest.index(message.startIndex, offsetBy: 8)...]
////                        print("remaining: \(remaining)")
////
////                        //nick, ordertype, oid, minsize, maxsize, txfee, cjfee
////
////                        //J5Etzdoiyh2NRMLR :!sw0absoffer 0 3574 18462061 0 3955 02f688091f596d4e1b7f00f7e3721865f073dd1ffbc7a0be8212138f1c88cd5a74 MEQCIFH3XPQgpBsFZoHVvHe4dTTpKpUmlhWfMw2Hv381fi0qAiBIzTESxvoY/q7jG2zqCVam/BrR0DLc9pKlJx+mHCYlFA== ~
////
////                        let messageArray = remaining.split(separator: " ")
////
////                        if messageArray.count > 2 {
////                            let command = messageArray[1]
////                            print("command: \(command)")
////
////                            switch command {
////                            case ":!sw0reloffer":
////                                print("sw0reloffer: \(message)")
////                                return .sw0reloffer(message: message)
////                            case ":!sw0absoffer":
////                                print("sw0absoffer: \(message)")
////                                return .sw0absoffer(message: message)
////                            default:
////                                break
////                            }
////                        }
////                }
//                
//                
//                    
//                } else if rest.hasPrefix("JOIN") {
//                    let user = source.components(separatedBy: "!")[0].trimmingCharacters(in: CharacterSet(charactersIn: ":"))
//                    let channel = rest[rest.index(message.startIndex, offsetBy: 5)...].trimmingCharacters(in: CharacterSet(charactersIn: "# "))
//                    return .joinMessage(user: user, channel: channel)
//                    
//                } else if rest.hasPrefix("PONG") {
//                    return .pong(message: message)
//                    
//                }/* else {
//                    let server = source.trimmingCharacters(in: CharacterSet(charactersIn: ": "))
//                    
//                    if rest.hasSuffix(":End of /NAMES list.") {
//                        let scanner = Scanner(string: rest)
//                        scanner.scanUpTo("#", into: nil)
//                        
//                        var channel: NSString?
//                        
//                        scanner.scanUpTo(" ", into: &channel)
//                        
//                        let channelName = (channel as String?)!.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
//                        
//                        var users = [String]()
//                        var user: NSString?
//                        scanner.scanUpTo(" ", into: &user)
//                        users.append((user as String?)!.trimmingCharacters(in: CharacterSet(charactersIn: ":")))
//                        
//                        return .userList(channel: channelName, users: users)
//                    }
//                    
//                    if rest.contains(":") {
//                        let serverMessage = rest.components(separatedBy: ":")[1]
//                        return .serverMessage(server: server, message: serverMessage)
//                    } else {
//                        return .serverMessage(server: server, message: rest)
//                    }
//                }*/
//            }/* else if !message.hasPrefix("PRIVMSG") && !message.hasPrefix("JOIN") {
////                let server = message.trimmingCharacters(in: CharacterSet(charactersIn: ": "))
////                let serverMessage = message.components(separatedBy: ":")[1]
////                return .serverMessage(server: server, message: serverMessage)
//                
//                print("unknown message type: \(message)")
//            }*/
//        default:
//            return .unknown(raw: message)
//        }
//        
//        return nil
//    }
//}
//
//enum IRCServerInput: Equatable {
//    case unknown(raw: String)
//    case ping(message: String)
//    case pong(message: String)
//    case serverMessage(server: String, message: String)
//    case channelMessage(channel: String, user: String, message: String)
//    case joinMessage(user: String, channel: String)
//    case userList(channel: String, users: [String])
//    case endOfMOTD(message: String)
//    case sw0absoffer(offer: JMOffer)
//    case sw0reloffer(offer: JMOffer)
//}
//
//func ==(lhs: IRCServerInput, rhs: IRCServerInput) -> Bool{
//    switch (lhs, rhs) {
//    case (.ping, .ping):
//        return true
//    case (.channelMessage(let lhsChannel, let lhsUser, let lhsMessage),
//          .channelMessage(let rhsChannel, let rhsUser, let rhsMessage)):
//        return lhsChannel == rhsChannel && lhsMessage == rhsMessage && lhsUser == rhsUser
//    case (.serverMessage(let lhsServer, let lhsMessage),
//          .serverMessage(let rhsServer, let rhsMessage)):
//        return lhsServer == rhsServer && lhsMessage == rhsMessage
//    case (.joinMessage(let lhsUser, let lhsChannel), .joinMessage(let rhsUser, let rhsChannel)):
//        return lhsUser == rhsUser && lhsChannel == rhsChannel
//    case (.userList(let lhsChannel, let lhsUsers), .userList(let rhsChannel, let rhsUsers)):
//        return lhsChannel == rhsChannel && lhsUsers == rhsUsers
//    default:
//        return false
//    }
//}
