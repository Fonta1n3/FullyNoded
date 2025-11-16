//
//  MakeRPCCall.swift
//  BitSense
//
//  Created by Peter on 31/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class MakeRPCCall: NSObject, URLSessionDelegate {
    
    static let sharedInstance = MakeRPCCall()
    
    private override init() {}
    
    let torClient = TorClient.sharedInstance
    private var attempts = 0
    var connected: Bool = false
    var onDoneBlock: (((response: Any?, errorDesc: String?)) -> Void)?
    var activeNode: NodeStruct?
    let delegate = UserCertURLSessionDelegate()
    
    
    func getActiveNode(completion: @escaping ((NodeStruct?) -> Void)) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            guard let nodes = nodes, nodes.count > 0 else {
                completion((nil))
                return
            }
            var activeNode: [String:Any]?
            for node in nodes {
                if let isActive = node["isActive"] as? Bool {
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
    
    func executeRPCCommand(method: BTC_CLI_COMMAND, completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        attempts += 1
        
        guard let node = activeNode else {
            completion((nil, "No active Bitcoin Core node."))
            return
        }
        
        var encryptedCert: Data?
        var decryptedCert: String?
        var cert: SecCertificate?
        
        if let _ = node.cert {
            encryptedCert = node.cert!
            decryptedCert = decryptedValue(encryptedCert!)
            cert = CertificateManager.shared.base64ToCert(base64: decryptedCert!)
        }
        
        guard let encAddress = node.onionAddress,
              let encUser = node.rpcuser,
              let encPassword = node.rpcpassword else {
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
        
        if decryptedCert != "" && decryptedCert != nil {
            walletUrl = "https://\(rpcusername):\(rpcpassword)@\(onionAddress)"
        }
        
        if decryptedCert == nil || decryptedCert == "" {
            guard onionAddress.contains(".onion:") || onionAddress.hasPrefix("127.0.0.1") || onionAddress.hasPrefix("localhost") else {
                completion((nil, "You are attempting to make an http network request that is not over Tor or localhost. This is not allowed."))
                return
            }
        }
        
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
        var timeout = 30.0
        
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
        
        let dict:[String:Any] = [
            "jsonrpc": "1.0",
            "id": id,
            "method": method.stringValue,
            "params": method.paramDict
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            #if DEBUG
            print("Converting to jsonData failing...")
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
            attempts = 0
            sesh = self.torClient.session
            
        } else {
            guard let cert = cert else {
                print("no cert here")
                return
            }
            
            delegate.cert = cert
            
            delegate.onTrustError = { errorMessage in
                completion((nil, "SSL error:\(errorMessage)"))
                return
            }
            
            // Only with Tor do we need to attempt more then once.
            attempts = 20
            sesh = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: .main)
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
            
            if onionAddress.contains(".onion:") {
                self.attempts = 0
            }
            
            
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
            
            if errorMessage.hasPrefix("Wallet file not specified") {
                completion((nil, "No active wallet, either select one via the wallets button (squares) on the wallt view or the plus button to create one."))
            } else {
                completion((nil, errorMessage))
            }
        }
        
        task.resume()
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



