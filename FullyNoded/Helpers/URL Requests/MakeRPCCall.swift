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
//                case 0:
//                    if object as? String == "EOSE" {
//                        
//                    }
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

                        let (method, param, walletName, responseCheck, errorDescCheck) = processValidReceivedContent(content: ev.content)
                        
                        guard let method = method else {
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
                        
                        guard let param = param else {
                            #if DEBUG
                            print("unable to parse method and param from recevied event.")
                            #endif
                            return
                        }

                        if let walletName = walletName {
                            UserDefaults.standard.setValue(walletName, forKey: "walletName")
                        }

                        self.executeRPCCommand(method: method, param: param) { [weak self] (response, errorDesc) in
                            guard let self = self else { return }

                            guard let response = response else {
                                self.sendResponseToRelay(response: response, errorDesc: errorDesc ?? "unknown error")
                                return
                            }
                            self.sendResponseToRelay(response: response, errorDesc: errorDesc)
                        }
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
        
    func processValidReceivedContent(content: String) -> (method:BTC_CLI_COMMAND?, param:Any?, wallet: String?, response:Any?, errorDesc:String?) {
        guard let decryptedDict = decryptedDict(content: content) else {return (nil,nil,nil,nil,nil)}
        #if DEBUG
        print("decryptedDict: \(decryptedDict)")
        #endif
        if let part = decryptedDict["part"] as? [String:Any] {
            
            for (key, value) in part {
                guard let m = Int("\(key.split(separator: ":")[0])"),
                        let n = Int("\(key.split(separator: ":")[1])") else {
                    print("m of n parsing failed")
                    return (nil,nil,nil,nil,nil)
                }
                
                guard let encryptedValue = value as? String else {
                    guard let valueDict = value as? [String:Any] else {
                        return (nil,nil,nil,nil,nil)
                    }
                    return (nil,nil,nil,valueDict["response"], valueDict["errorDesc"] as? String)
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
                                return (nil,nil,nil,nil,"failed decrypting the entire response")
                            }
                            
                            guard let nestedPart = nestedDecryptedDict["part"] as? [String:Any] else {
                                return (nil,nil,nil,nil,"No nested part dictionary.")
                            }
                            
                            
                            for (_,value) in nestedPart {
                                guard let valueDict = value as? [String:Any] else {
                                    print("failed getting the valueDict")
                                    return (nil,nil,nil,nil,nil)
                                }
                                
                                return (nil,nil,nil,valueDict["response"],valueDict["errorDesc"] as? String)
                            }
                        }
                    }
                }
            }
        }
        
        guard let commandString = decryptedDict["command"] as? String else {
            #if DEBUG
            print("no command found")
            #endif
            guard decryptedDict["response"] != nil else {
                #if DEBUG
                print("no response")
                #endif
                return (nil,nil,nil,nil,decryptedDict["errorDesc"] as? String)
            }
            return (nil,nil,nil,decryptedDict["response"], decryptedDict["errorDesc"] as? String)
        }
        guard let method:BTC_CLI_COMMAND = .init(rawValue: commandString) else {
            #if DEBUG
            print("can not convert string to BTC_CLI_COMMAND")
            #endif
            return (nil,nil,nil,nil,nil)
        }
        guard let paramDict = decryptedDict["paramDict"] as? [String:Any] else {
            #if DEBUG
            print("unable to get paramDict, should at least be an empty dict.")
            #endif
            return (nil,nil,nil,nil,nil)
        }
        let param = paramDict["param"] as Any
        let wallet = decryptedDict["wallet"] as? String
        return (method, param, wallet, nil, nil)
    }
    
    func executeNostrRpc(method: BTC_CLI_COMMAND, param: Any) {
        var walletName:String?
        if isWalletRPC(command: method) {
            walletName = UserDefaults.standard.string(forKey: "walletName")
        }
        let dict:[String:Any] = ["command":method.rawValue,"paramDict":["param":param],"wallet":walletName ?? ""]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            #if DEBUG
            print("converting to jsonData failing...")
            #endif
            return
        }
        let encryptedContent = Crypto.encryptNostr(jsonData)!.base64EncodedString()
        writeEvent(content: encryptedContent)
    }
    
    func sendResponseToRelay(response: Any?, errorDesc: String?) {
        let mofn = "1:1"
        let part:[String:Any] = ["part":[mofn:["response":response,"errorDesc":errorDesc ?? ""]]]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: part, options: .prettyPrinted) else {
            #if DEBUG
            print("converting to jsonData failing...")
            #endif
            return
        }
        let encryptedContent = Crypto.encryptNostr(jsonData)!.base64EncodedString()
        let count = encryptedContent.count
        if count > 32000 {
            var numberOfRequiredParts = count / 18000
            if numberOfRequiredParts == 1 {
                numberOfRequiredParts += 2
            }
            guard numberOfRequiredParts < 40 else {
                onDoneBlock!((nil, "Event is too large requires 40 or more parts..."))
                return
            }
            let parts = encryptedContent.split(by: count / numberOfRequiredParts)
            for (i, part) in parts.enumerated() {
                let partDict:[String:Any] = ["part":["\(i + 1):\(parts.count)":part]]
                guard let partJsonData = try? JSONSerialization.data(withJSONObject: partDict, options: .prettyPrinted) else {
                    #if DEBUG
                    print("converting to jsonData failing...")
                    #endif
                    return
                }
                let encryptedContent = Crypto.encryptNostr(partJsonData)!.base64EncodedString()
                writeEvent(content: encryptedContent)
            }
        } else {
            writeEvent(content: encryptedContent)
        }
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
    
    func executeRPCCommand(method: BTC_CLI_COMMAND, param: Any, completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        attempts += 1
        
        if let node = self.activeNode {
            #if targetEnvironment(simulator)
            guard self.connected  else { print("not connected"); return }
            self.executeNostrRpc(method: method, param: param)
            #else
            if node.isNostr && !self.isiOSAppOnMac {
                if self.connected {
                    self.executeNostrRpc(method: method, param: param)
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
                
                var formattedParam = (param as! String).replacingOccurrences(of: "''", with: "")
                formattedParam = formattedParam.replacingOccurrences(of: "'\"'\"'", with: "'")
                
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
                let id = UUID()
                
                request.timeoutInterval = timeout
                request.httpMethod = "POST"
                request.addValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
                request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                request.httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"\(id)\",\"method\":\"\(method.rawValue)\",\"params\":[\(formattedParam)]}".data(using: .utf8)
                
                #if DEBUG
                print("url = \(url)")
                print("request: \("{\"jsonrpc\":\"1.0\",\"id\":\"\(id)\",\"method\":\"\(method.rawValue)\",\"params\":[\(formattedParam)]}")")
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
                                self.executeRPCCommand(method: method, param: param, completion: completion)
                            } else {
                                self.attempts = 0
                                completion((nil, "Unknown error, ran out of attempts"))
                            }
                            
                            return
                        }
                        
                        if self.attempts < 20 {
                            self.executeRPCCommand(method: method, param: param, completion: completion)
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
#endif
            
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

