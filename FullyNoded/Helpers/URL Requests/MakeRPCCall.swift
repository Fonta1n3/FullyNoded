//
//  MakeRPCCall.swift
//  BitSense
//
//  Created by Peter on 31/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import Starscream

class MakeRPCCall: WebSocketDelegate {
        
    static let sharedInstance = MakeRPCCall()
    let torClient = TorClient.sharedInstance
    private var attempts = 0
    var socket:WebSocket!
    var connected:Bool = false
    var onDoneBlock : (((response: Any?, errorDesc: String?)) -> Void)?
    var eoseReceivedBlock : (((Bool)) -> Void)?
    var activeNode:NodeStruct?
    var isiOSAppOnMac: Bool = {
    #if targetEnvironment(macCatalyst)
        return true
    #else
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        } else {
            return false
        }
    #endif
        }()
    
    private init() {}
    
    func writeReqEvent(node: NodeStruct) {
        guard let encryptedSubscribeTo = node.subscribeTo else { return }
        guard let decryptedSubscribeTo = Crypto.decrypt(encryptedSubscribeTo) else { return }
        let filter:NostrFilter = NostrFilter.filter_authors(["\(decryptedSubscribeTo.hexString.dropFirst(2))"])
        let encoder = JSONEncoder()
        var req = "[\"REQ\",\"\(Keys.randomPrivKey()!.hex)\","
        guard let filter_json = try? encoder.encode(filter) else {
            #if DEBUG
            print("converting to jsonData failing...")
            #endif
            return
        }
        let filter_json_str = String(decoding: filter_json, as: UTF8.self)
        req += filter_json_str
        req += "]"
        #if DEBUG
        print("req: \(req)")
        #endif
        self.socket.write(string: req) {}
    }
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected:
            connected = true
            if let node = activeNode {
                writeReqEvent(node: node)
            }
            
        case .disconnected(let reason, let code):
            #if DEBUG
            print("websocket is disconnected: \(reason) with code: \(code)")
            #endif
            connected = false
            
        case .text(let string):
            #if DEBUG
            print("Received text: \(string)")
            #endif
            let encoder = JSONEncoder()
            encoder.outputFormatting = .withoutEscapingSlashes
            guard let data = string.data(using: .utf8) else { return }
            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options : []) as? [Any] else {
                #if DEBUG
                print("converting to json failing...")
                #endif
                return
            }
            
            for (i, object) in jsonObject.enumerated() {
                switch i {
                case 0:
                    if object as? String == "EOSE" {
                        self.eoseReceivedBlock?(true)
                    }
                case 2:
                    if let dict = object as? [String:Any], let created_at = dict["created_at"] as? Int {
                        let now = NSDate().timeIntervalSince1970
                        let diff = (now - TimeInterval(created_at))
                        guard diff < 5.0 else { return }
                        guard let ev = self.parseEvent(event: dict) else {
                            self.onDoneBlock!((nil,"Nostr event parsing failed..."))
                            #if DEBUG
                            print("event parsing failed")
                            #endif
                            return
                        }

                        let (responseCheck, errorDescCheck) = processValidReceivedContent(content: ev.content)
                        
                        guard let reponse = responseCheck else {
                            self.onDoneBlock!((nil,errorDescCheck))
                            return
                        }

                        guard let _ = errorDescCheck else {
                            self.onDoneBlock!((reponse as Any,nil))
                            return
                        }
                        
                        self.onDoneBlock!((reponse as Any,errorDescCheck))
                        return
                    }
                default:
                    break
                }
            }
        case .error(let error):
            #if DEBUG
            print("error: \(error?.localizedDescription ?? "")")
            #endif
            self.connected = false
        default:
            break
        }
    }
    
    func connectToRelay(completion: @escaping (Bool) -> Void) {
        if !self.connected {
            let relay = UserDefaults.standard.string(forKey: "nostrRelay") ?? "wss://nostr-relay.wlvs.space"
            //ws://jgqaglhautb4k6e6i2g34jakxiemqp6z4wynlirltuukgkft2xuglmqd.onion//wss://nostr-pub.wellorder.net/
            guard let url = URL(string: relay) else { return }
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            self.socket = WebSocket(request: request)
            self.socket.respondToPingWithPong = true
            self.socket.delegate = self
            self.socket.connect()
            completion(true)
        } else {
            completion(true)
        }
    }
    
    func getActiveNode(completion: @escaping ((NodeStruct?) -> Void)) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            guard let nodes = nodes, nodes.count > 0 else {
                completion((nil))
                return
            }
            var activeNode: [String:Any]?
            for node in nodes {
                if let isActive = node["isActive"] as? Bool,
                   let isLightning = node["isLightning"] as? Bool,
                   !isLightning,
                   !(node["isJoinMarket"] as? Bool ?? false) {
                    if isActive {
                        activeNode = node
                    }
                }
            }
            guard let active = activeNode else {
                completion((nil))
                return
            }
            
            let n = NodeStruct(dictionary: active)
            self.activeNode = n
            completion(n)
        }
    }
    
    func parseEvent(event: [String:Any]) -> NostrEvent? {
        guard let content = event["content"] as? String else { return nil }
        guard let id = event["id"] as? String else { return nil }
        guard let kind = event["kind"] as? Int else { return nil }
        guard let pubkey = event["pubkey"] as? String else { return nil }
        guard let sig = event["sig"] as? String else { return nil }
        guard let tags = event["tags"] as? [[String]] else { return nil }
        let ev = NostrEvent(content: content,
                            pubkey: pubkey,
                            kind: kind,
                            tags: tags)
        ev.sig = sig
        ev.id = id
        return ev
    }
    
    var collectedPartArray:[String] = []
    
    func decryptedDict(content: String) -> [String:Any]? {
        guard let contentData = Data(base64Encoded: content),
                let decryptedContent = Crypto.decryptNostr(contentData) else { return nil }
        guard let decryptedDict = try? JSONSerialization.jsonObject(with: decryptedContent, options : []) as? [String:Any] else {
            #if DEBUG
            print("converting to jsonData failing...")
            #endif
            return nil
        }
        return decryptedDict
    }
        
    func processValidReceivedContent(content: String) -> (response:Any?, errorDesc:String?) {
        guard let decryptedDict = decryptedDict(content: content) else {return (nil,nil)}
        #if DEBUG
        print("decryptedDict: \(decryptedDict)")
        #endif
        if let part = decryptedDict["part"] as? [String:Any] {
            for (key, value) in part {
                guard let m = Int("\(key.split(separator: ":")[0])"),
                      let n = Int("\(key.split(separator: ":")[1])") else {
                    print("m of n parsing failed")
                    return (nil,nil)
                }
                
                guard let encryptedValue = value as? String else {
                    guard let valueDict = value as? [String:Any] else {
                        return (nil,nil)
                    }
                    return (valueDict["response"], valueDict["errorDesc"] as? String)
                }
                
                if m < n {
                    collectedPartArray.append(encryptedValue)
                } else if m == n {
                    collectedPartArray.append(encryptedValue)
                    var entireEncryptedResponse = ""
                    for (i,part) in collectedPartArray.enumerated() {
                        entireEncryptedResponse += "\(part)"
                        if i + 1 == collectedPartArray.count {
                            collectedPartArray.removeAll()
                            
                            guard let nestedDecryptedDict = self.decryptedDict(content: entireEncryptedResponse) else {
                                print("failed decrypting the entire response")
                                return (nil,"failed decrypting the entire response")
                            }
                            
                            guard let nestedPart = nestedDecryptedDict["part"] as? [String:Any] else {
                                return (nil,"No nested part dictionary.")
                            }
                            
                            
                            for (_,value) in nestedPart {
                                guard let valueDict = value as? [String:Any] else {
                                    print("failed getting the valueDict")
                                    return (nil,nil)
                                }
                                
                                return (valueDict["response"],valueDict["errorDesc"] as? String)
                            }
                        }
                    }
                }
            }
        } else {
            return(nil,nil)
        }
        return (nil, nil)
    }
    
    
    func executeNostrRpc(method: BTC_CLI_COMMAND) {
        var walletName:String?
        if isWalletRPC(command: method) {
            walletName = UserDefaults.standard.string(forKey: "walletName")
        }
        let dict:[String:Any] = ["command":method.stringValue,"paramDict":["param":method.paramDict],"wallet":walletName ?? ""]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            #if DEBUG
            print("converting to jsonData failing...")
            #endif
            return
        }
        let encryptedContent = Crypto.encryptNostr(jsonData)!.base64EncodedString()
        writeEvent(content: encryptedContent)
    }

    
    func writeEvent(content: String) {
        if let node = activeNode {
            guard let encryptedPrivkey = node.nostrPrivkey,
                  let decryptedPrivkey = Crypto.decrypt(encryptedPrivkey),
                  let pubkey = Keys.privKeyToPubKey(decryptedPrivkey) else { return }
            let ev = NostrEvent(content: content,
                                pubkey: "\(pubkey.dropFirst(2))",
                                kind: NostrKind.ephemeral.rawValue,
                                tags: [])
            ev.calculate_id()
            ev.sign(privkey: decryptedPrivkey.hexString)
            guard !ev.too_big else {
                self.collectedPartArray.removeAll()
                self.onDoneBlock!((nil, "Nostr event is too big to send..."))
                #if DEBUG
                print("event too big: \(content.count)")
                #endif
                return
            }
            guard ev.validity == .ok else {
                self.onDoneBlock!((nil, "Nostr event is invalid!"))
                #if DEBUG
                print("event invalid")
                #endif
                return
            }
            let encoder = JSONEncoder()
            let event_data = try! encoder.encode(ev)
            let event = String(decoding: event_data, as: UTF8.self)
            let encoded = "[\"EVENT\",\(event)]"
            self.socket.write(string: encoded) {}
        }
    }
    
    
    func disconnect() {
        if socket != nil {
            self.socket.disconnect()
            self.connected = false
        }
    }
    
    
    func executeRPCCommand(method: BTC_CLI_COMMAND, completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        attempts += 1
        
        if let node = self.activeNode {
            if node.isNostr {
                if self.connected {
                    self.executeNostrRpc(method: method)
                }
            } else {
                guard let encAddress = node.onionAddress, let encUser = node.rpcuser, let encPassword = node.rpcpassword else {
                    completion((nil, "error getting encrypted node credentials"))
                    return
                }
                
                let onionAddress = decryptedValue(encAddress)
                let rpcusername = decryptedValue(encUser)
                let rpcpassword = decryptedValue(encPassword)
                
                guard onionAddress != "", rpcusername != "", rpcpassword != "" else {
                    completion((nil, "error decrypting node credentials"))
                    return
                }
                
                var walletUrl = "http://\(rpcusername):\(rpcpassword)@\(onionAddress)"
                let ud = UserDefaults.standard
                
                if ud.object(forKey: "walletName") != nil {
                    if let walletName = ud.object(forKey: "walletName") as? String {
                        let b = isWalletRPC(command: method)
                        if b {
                            walletUrl += "/wallet/" + walletName
                        }
                    }
                }
                
                guard let url = URL(string: walletUrl) else {
                    completion((nil, "url error"))
                    return
                }
                
                var request = URLRequest(url: url)
                var timeout = 10.0
                
                switch method {
                case .gettxoutsetinfo:
                    timeout = 1000.0
                    
                case .importmulti, .deriveaddresses, .loadwallet:
                    timeout = 60.0
                    
                default:
                    break
                }
                
                let loginString = String(format: "%@:%@", rpcusername, rpcpassword)
                let loginData = loginString.data(using: String.Encoding.utf8)!
                let base64LoginString = loginData.base64EncodedString()
                let id = UUID().uuidString
                
                request.timeoutInterval = timeout
                request.httpMethod = "POST"
                request.addValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
                request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                
                let dict:[String:Any] = ["jsonrpc":"1.0","id":id,"method":method.stringValue,"params":method.paramDict]
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
                    #if DEBUG
                    print("converting to jsonData failing...")
                    #endif
                    return
                }
                
                request.httpBody = jsonData
                
                #if DEBUG
                print("url = \(url)")
                print("request: \(dict)")
                #endif
                
                var sesh = URLSession(configuration: .default)
                
                if onionAddress.contains("onion") {
                    sesh = self.torClient.session
                }
                
                let task = sesh.dataTask(with: request as URLRequest) { [weak self] (data, response, error) in
                    guard let self = self else { return }
                    
                    guard let urlContent = data else {
                        
                        guard let error = error else {
                            if self.attempts < 20 {
                                self.executeRPCCommand(method: method, completion: completion)
                            } else {
                                self.attempts = 0
                                completion((nil, "Unknown error, ran out of attempts"))
                            }
                            
                            return
                        }
                        
                        if self.attempts < 20 {
                            self.executeRPCCommand(method: method, completion: completion)
                        } else {
                            self.attempts = 0
                            completion((nil, error.localizedDescription))
                        }
                        
                        return
                    }
                    
                    self.attempts = 0
                    
                    guard let json = try? JSONSerialization.jsonObject(with: urlContent, options: .mutableLeaves) as? NSDictionary else {
                        if let httpResponse = response as? HTTPURLResponse {
                            switch httpResponse.statusCode {
                            case 401:
                                completion((nil, "Looks like your rpc credentials are incorrect, please double check them. If you changed your rpc creds in your bitcoin.conf you need to restart your node for the changes to take effect."))
                            case 403:
                                completion((nil, "The bitcoin-cli \(method) command has not been added to your rpcwhitelist, add \(method) to your bitcoin.conf rpcwhitelsist, reboot Bitcoin Core and try again."))
                            default:
                                completion((nil, "Unable to decode the response from your node, http status code: \(httpResponse.statusCode)"))
                            }
                        } else {
                            completion((nil, "Unable to decode the response from your node..."))
                        }
                        return
                    }
                    
                    #if DEBUG
                    print("json: \(json)")
                    #endif
                    
                    guard let errorCheck = json["error"] as? NSDictionary else {
                        completion((json["result"], nil))
                        return
                    }
                    
                    guard let errorMessage = errorCheck["message"] as? String else {
                        completion((nil, "Uknown error from bitcoind"))
                        return
                    }
                    
                    completion((nil, errorMessage))
                }
                
                task.resume()
            }
        }
    }
}

    extension String {
        func split(by length: Int) -> [String] {
            var startIndex = self.startIndex
            var results = [Substring]()

            while startIndex < self.endIndex {
                let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
                results.append(self[startIndex..<endIndex])
                startIndex = endIndex
            }

            return results.map { String($0) }
        }
    }

