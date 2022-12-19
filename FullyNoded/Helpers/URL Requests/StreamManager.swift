//
//  StreamManager.swift
//  FullyNoded
//
//  Originally copied from https://stackoverflow.com/a/46082597
//  Edited by Peter Denton on 12/17/22.
//  Copyright © 2022 Fontaine. All rights reserved.
//

import Foundation

//class StreamManager : NSObject, URLSessionDataDelegate {
//
//static var shared = StreamManager()
//
//private var session: URLSession! = nil
//
//override init() {
//    super.init()
//    let config = URLSessionConfiguration.default
//    config.requestCachePolicy = .reloadIgnoringLocalCacheData
//    self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
//}
//
//private var streamingTask: URLSessionDataTask? = nil
//
//var isStreaming: Bool { return self.streamingTask != nil }
//
//func startStreaming() {
//    precondition( !self.isStreaming )
//
//    let url = URL(string: "wss://nostr-relay.wlvs.space")!
//    let request = URLRequest(url: url)
//    let task = self.session.dataTask(with: request)
//    self.streamingTask = task
//    task.resume()
//}
//
//func stopStreaming() {
//    guard let task = self.streamingTask else {
//        return
//    }
//    self.streamingTask = nil
//    task.cancel()
//    self.closeStream()
//}
//
//var outputStream: OutputStream? = nil
//
//private func closeStream() {
//    if let stream = self.outputStream {
//        stream.close()
//        self.outputStream = nil
//    }
//}
//
//func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
//    self.closeStream()
//
//    var inStream: InputStream? = nil
//    var outStream: OutputStream? = nil
//    Stream.getBoundStreams(withBufferSize: 4096, inputStream: &inStream, outputStream: &outStream)
//    self.outputStream = outStream
//
//    completionHandler(inStream)
//}
//
//func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
//    print("\(data.utf8String!)")
//    NSLog("task data: %@", data as NSData)
//
//}
//
//func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
//    if let error = error as NSError? {
//        NSLog("task error: %@ / %d", error.domain, error.code)
//    } else {
//        NSLog("task complete")
//    }
//}
//
//    urlSession
//}
final class StreamManager: NSObject {
        
    static let shared = StreamManager()
    var webSocket: URLSessionWebSocketTask?
    var node: NodeStruct?
    
    var opened = false
    
    //private var urlString = "wss://nostr-relay.wlvs.space"
    
    private override init() {
        // no-op
    }
    
    //MARK: Receive
        func receive() {
            print("receive")
            /// This Recurring will keep us connected to the server
            /*
             - Create a workItem
             - Add it to the Queue
             */
            
            let workItem = DispatchWorkItem { [weak self] in
                
                self?.webSocket?.receive(completionHandler: { result in
                    switch result {
                    case .success(let message):
                        
                        switch message {
                        
                        case .data(let data):
                            print("Data received \(data)")
                            
                        case .string(let strMessgae):
                        print("String received \(strMessgae)")
                            
                        default:
                            break
                        }
                    
                    case .failure(let error):
                        print("Error Receiving \(error)")
                    }
                    // Creates the Recurrsion
                    self?.receive()
                })
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 1 , execute: workItem)
        
        }
    
    func send() {
            /*
             - Create a workItem
             - Add it to the Queue
             */
            
            let workItem = DispatchWorkItem{
                
                self.webSocket?.send(URLSessionWebSocketTask.Message.string("Hello"), completionHandler: { error in
                    
                    
                    if error == nil {
                        // if error is nil we will continue to send messages else we will stop
                        //self.send()
                        self.receive()
                    } else {
                        print(error)
                    }
                })
            }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: workItem)
        }
                           
    
    
    
    func writeReqEvent() {
        print("writeReqEvent")
        guard let node = self.node else { return }
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
        let msg:URLSessionWebSocketTask.Message = .string(req)
        self.webSocket!.send(msg, completionHandler: { sendError in
            
            print("sendError: \(sendError?.localizedDescription ?? "unknown")")
        })
    }
    
    func writeEvent(activeNode: NodeStruct, content: String, privkey: Data) {
            guard let pubkey = Keys.privKeyToPubKey(privkey) else { return }
            let ev = NostrEvent(content: content,
                                pubkey: "\(pubkey.dropFirst(2))",
                                kind: NostrKind.ephemeral.rawValue,
                                tags: [])
            ev.calculate_id()
            ev.sign(privkey: privkey.hexString)
            guard !ev.too_big else {
                //self.onDoneBlock!((nil, "Nostr event is too big to send..."))
                #if DEBUG
                print("event too big: \(content.count)")
                #endif
                return
            }
            guard ev.validity == .ok else {
                //self.onDoneBlock!((nil, "Nostr event is invalid!"))
                #if DEBUG
                print("event invalid")
                #endif
                return
            }
            let encoder = JSONEncoder()
            let event_data = try! encoder.encode(ev)
            let event = String(decoding: event_data, as: UTF8.self)
            let encoded = "[\"EVENT\",\(event)]"
            let msg:URLSessionWebSocketTask.Message = .string(encoded)
        print("msg: \(msg)")
            self.webSocket!.send(msg, completionHandler: { sendError in
                print("sendError: \(sendError?.localizedDescription ?? "unknown")")
            })
            //self.socket.write(string: encoded) {}
    }
    
    func openWebSocket(urlString: String) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let webSocket = session.webSocketTask(with: request)
            self.webSocket = webSocket
            self.opened = true
            //self.receive()
            self.webSocket?.resume()
            
        }
    }
    
    enum MessageType: String {
        case connected = "connect.connected"
        case failed =  "connect.failed"
        case tradingQuote = "trading.quote"
        case connectionAck = "connect.ack"
    }
    
    struct GenericSocketResponse: Decodable {
        let t: String
    }
    
    
}

extension StreamManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("opened")
        opened = true
        writeReqEvent()
//        send()
    }

    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("didClose")
        self.webSocket = nil
        self.opened = false
    }
}
