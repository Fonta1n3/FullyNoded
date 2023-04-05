//
//  StreamManager.swift
//  FullyNoded
//
//  Originally copied from https://stackoverflow.com/a/46082597
//  Edited by Peter Denton on 12/17/22.
//  Copyright © 2022 Fontaine. All rights reserved.
//

import Foundation

final class StreamManager: NSObject {
        
    static let shared = StreamManager()
    var webSocket: URLSessionWebSocketTask?
    var node: NodeStruct?
    var opened = false
    var eoseReceivedBlock : (((Bool)) -> Void)?
    var onDoneBlock : (((response: Any?, errorDesc: String?)) -> Void)?
    var subId: String?
    var connected = false
    var timer = Timer()
    var lastSentId:String?
    
    private override init() {}
    
    
    func receive() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard let webSocket = self.webSocket else { print("websocket is nil"); return }
            webSocket.receive(completionHandler: { [weak self] result in
                guard let self = self else { return }
                self.timer.invalidate()
                switch result {
                case .success(let message):
                    self.processMessage(message: message)
                case .failure(let error):
                    print("Error Receiving \(error)")
                }
                self.receive()
            })
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: workItem)
    }
    
    
    private func processMessage(message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let strMessgae):
            let data = strMessgae.data(using: .utf8)!
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data, options : .allowFragments) as? NSArray
                {
                    switch jsonArray[0] as? String {
                    case "EOSE":
                        parseEose(arr: jsonArray)
                    case "EVENT":
                        parseEventDict(arr: jsonArray)
                    case "OK":
                        onDoneBlock!((nil, jsonArray[3] as? String))
                    default:
                        break
                    }
                }
            } catch let error as NSError {
                print(error)
            }
        default:
            break
        }
    }
    
    
    private func parseEose(arr: NSArray) {
        guard let recievedSubId = arr[1] as? String else { print("subid not recieved"); return }
        guard self.subId == recievedSubId else { print("subid does not match"); return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connected = true
            self.eoseReceivedBlock!(true)
        }
    }
    
    
    private func parseEventDict(arr: NSArray) {
        if let dict = arr[2] as? [String:Any], let created_at = dict["created_at"] as? Int {
            let now = NSDate().timeIntervalSince1970
            let diff = (now - TimeInterval(created_at))
            guard diff < 5.0 else { print("diff > 5, ignoring."); return }
            guard let ev = self.parseEvent(event: dict) else {
                self.onDoneBlock!((nil,"Nostr event parsing failed..."))
                #if DEBUG
                print("event parsing failed")
                #endif
                return
            }
            
            let (responseCheck, errorDescCheck, requestId) = self.processValidReceivedContent(content: ev.content)
            
            guard self.lastSentId == requestId else {
                self.onDoneBlock!((nil, "Ignoring out of order response."))
                return
            }
                        
            guard let response = responseCheck else {
                self.onDoneBlock!((nil, errorDescCheck))
                return
            }
            
            guard let _ = errorDescCheck else {
                self.onDoneBlock!((response as Any,nil))
                return
            }
            
            self.onDoneBlock!((response as Any,errorDescCheck))
        }
    }
    
    
    private func writeReqEvent() {
        guard let node = self.node else { print("no node"); return }
        guard let encryptedSubscribeTo = node.subscribeTo else { print("no encrypted subscribeTo"); return }
        guard let decryptedSubscribeTo = Crypto.decrypt(encryptedSubscribeTo) else { print("no decrypted subscribeTo"); return }
        let filter:NostrFilter = NostrFilter.filter_authors(["\(decryptedSubscribeTo.hexString.dropFirst(2))"])
        let encoder = JSONEncoder()
        guard let randomKey = Keys.randomPrivKey() else { print("unable to derive random key"); return }
        self.subId = randomKey.hex
        guard let randomSubId = self.subId else { return }
        var req = "[\"REQ\",\"\(randomSubId)\","
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
        self.sendMsg(string: req)
    }
    
    
    func writeEvent(content: String) {
        guard let node = node else { print("no node"); return }
        guard let encryptedNostrPrivKey = node.nostrPrivkey else { print("no encrypted private key"); return }
        guard let decryptedPrivKey = Crypto.decrypt(encryptedNostrPrivKey) else { print("unable to decrypt nostr priv key"); return }
        guard let pubkey = Keys.privKeyToPubKey(decryptedPrivKey) else { print("no pubkey"); return }
        
        let ev = NostrEvent(content: content,
                            pubkey: "\(pubkey.dropFirst(2))",
                            kind: NostrKind.ephemeral.rawValue,
                            tags: [])
        ev.calculate_id()
        ev.sign(privkey: decryptedPrivKey.hexString)
        guard !ev.too_big else {
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
        sendMsg(string: encoded)
    }
    
    
    private func sendMsg(string: String) {
        let msg:URLSessionWebSocketTask.Message = .string(string)
        guard let ws = self.webSocket else { print("no websocket"); return }
        ws.send(msg, completionHandler: { [weak self] sendError in
            guard let self = self else { return }
            guard let sendError = sendError else {
                var seconds = 0
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
                        seconds += 1
                        self.updateCounting(seconds: seconds)
                    })
                }
                self.receive()
                return
            }
            #if DEBUG
            print("sendError: \(sendError.localizedDescription)")
            #endif
        })
    }
    
    
    private func parseEvent(event: [String:Any]) -> NostrEvent? {
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
    
    
    private func processValidReceivedContent(content: String) -> (response:Any?, errorDesc:String?, requestId: String?) {
        guard let decryptedDict = decryptedDict(content: content) else {return (nil,nil,nil)}
        #if DEBUG
        print("decryptedDict: \(decryptedDict)")
        #endif
        let response = decryptedDict["response"]
        let errorDesc = decryptedDict["error_desc"] as? String
        let requestId = decryptedDict["request_id"] as? String
        return (response, errorDesc, requestId)
    }
    
    
    private func decryptedDict(content: String) -> [String:Any]? {
        guard let contentData = Data(base64Encoded: content),
              let node = self.node,
                let encryptedWords = node.nostrWords,
              let decryptedWords = Crypto.decrypt(encryptedWords),
              let words = decryptedWords.utf8String,
              let decryptedContent = Crypto.decryptNostr(contentData, words) else {
            onDoneBlock!((nil, "Error decrypting content..."))
            return nil
        }
        guard let decryptedDict = try? JSONSerialization.jsonObject(with: decryptedContent, options : []) as? [String:Any] else {
            #if DEBUG
            print("converting to jsonData failing...")
            #endif
            return nil
        }
        return decryptedDict
    }
    
    
    private func updateCounting(seconds: Int) {
        if seconds == 10 {
            self.timer.invalidate()
            self.onDoneBlock!((nil, "Timed out after \(seconds) seconds, no response from your nostr relay..."))
        }
    }
    
    
    func openWebSocket(urlString: String) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            self.webSocket = session.webSocketTask(with: request)
            self.opened = true
            self.webSocket?.resume()
        }
    }
}

extension StreamManager: URLSessionWebSocketDelegate {
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        opened = true
        writeReqEvent()
    }
    
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        webSocket = nil
        opened = false
    }
}
