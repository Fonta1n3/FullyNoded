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
    var activeNode: NodeStruct? {
        didSet {
            let isOnion = activeNode.map(Self.isOnion) ?? false
            guard isOnion != activeNodeIsOnion else { return }
            activeNodeIsOnion = isOnion
            torClient.syncOnionOnly()
        }
    }
    /// The active node is reached at its onion: Tor goes onion only (TorClient.onionOnly).
    private(set) var activeNodeIsOnion = false

    private static func isOnion(_ node: NodeStruct) -> Bool {
        guard node.nostrConnect == nil, let address = node.onionAddress.flatMap({ Crypto.decrypt($0)?.utf8String }) else { return false }
        return address.lowercased().contains(".onion")
    }
    let delegate = UserCertURLSessionDelegate()
    // One session per kind of connection. A session per call leaves its idle connections open, and
    // new calls then wait for them to time out: seconds apart, on a local node.
    private let plainSession = URLSession(configuration: .default)
    private var certSession: (cert: String, session: URLSession)?
    /// Calls start on any queue (often a previous call's completion), so `certSession` is guarded.
    private let sessionLock = NSLock()

    /// The session for a node with this self-signed cert, made once per cert.
    private func session(forCert decryptedCert: String) -> URLSession {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        if let current = certSession, current.cert == decryptedCert { return current.session }
        certSession?.session.finishTasksAndInvalidate()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: .main)
        certSession = (decryptedCert, session)
        return session
    }
    
    func getActiveNode(completion: @escaping ((NodeStruct?) -> Void)) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            guard let nodes = nodes, nodes.count > 0 else {
                completion((nil))
                return
            }
            guard let active = nodes.last(where: { $0["isActive"] as? Bool == true }) else {
                completion((nil))
                return
            }
            
            let n = NodeStruct(dictionary: active)
            self.activeNode = n
            completion(n)
        }
    }
    
    /// `walletName` targets a specific wallet for this one call; when nil the active wallet
    /// (UserDefaults "walletName") is used. Passing it avoids ever touching the active wallet.
    func executeRPCCommand(method: BTC_CLI_COMMAND, walletName walletOverride: String? = nil, completion done: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        // psbt_version only goes to nodes known to take it (Core 32+). If the node rejects it anyway
        // (the stored version is from another node), stop sending it and try once more without.
        let params = PSBTVersion.mustRequestV0 ? method.paramDict : PSBTVersion.stripped(method.paramDict)
        var completion: ((response: Any?, errorDesc: String?)) -> Void = { [weak self] result in
            if PSBTVersion.sends(params), PSBTVersion.isRejection(result.errorDesc), let self = self {
                PSBTVersion.nodeRejectedParam = true
                self.executeRPCCommand(method: method, walletName: walletOverride, completion: done)
                return
            }
            done(result)
        }
        #if DEBUG
        // Every call, over HTTP / Tor or Nostr Connect: the command, its wallet and arguments
        // going out, and how it came back. No credentials.
        let started = Date()
        let rpcWallet = isWalletRPC(command: method) ? (walletOverride ?? UserDefaults.standard.object(forKey: "walletName") as? String) : nil
        print("[rpc] → \(method.stringValue)\(rpcWallet.map { " (wallet \($0))" } ?? "") params: \(params)")
        let finish = completion
        completion = { result in
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            print("[rpc] ← \(method.stringValue) \(result.errorDesc.map { "error: \($0)" } ?? "ok") (\(ms) ms)")
            finish(result)
        }
        #endif
        guard let node = activeNode else {
            completion((nil, "No active Bitcoin Core node."))
            return
        }
        
        let walletName = walletOverride ?? UserDefaults.standard.object(forKey: "walletName") as? String
        var walletPath = ""
        if isWalletRPC(command: method), let walletName = walletName {
            let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
            walletPath = "/wallet/" + (walletName.addingPercentEncoding(withAllowedCharacters: allowed) ?? walletName)
        }
        
        // Nostr Connect node: the same JSON-RPC request, through Fully Noded Server's relay.
        if let encryptedLink = node.nostrConnect {
            guard let link = Crypto.decrypt(encryptedLink)?.utf8String else {
                completion((nil, "error decrypting node credentials"))
                return
            }
            let dict: [String: Any] = ["jsonrpc": "1.0", "id": UUID().uuidString, "method": method.stringValue, "params": params]
            guard let body = try? JSONSerialization.data(withJSONObject: dict) else {
                completion((nil, "Unable to encode the request."))
                return
            }
            NostrRPC.shared.send(body: body, path: walletPath, timeout: timeout(for: method), link: link) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    self.handleResponse(response.body, statusCode: response.status, method: method, walletName: walletName,
                                        walletOverride: walletOverride, completion: completion)
                case .failure(let error):
                    completion((nil, error.localizedDescription))
                }
            }
            return
        }
        
        let decryptedCert = node.cert.map(decryptedValue) ?? ""
        let cert = decryptedCert.isEmpty ? nil : CertificateManager.shared.base64ToCert(base64: decryptedCert)
        
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
        
        let scheme = decryptedCert.isEmpty ? "http" : "https"
        let walletUrl = "\(scheme)://\(rpcusername):\(rpcpassword)@\(onionAddress)\(walletPath)"
        
        guard let url = URL(string: walletUrl) else {
            completion((nil, "url error"))
            return
        }
        
        var request = URLRequest(url: url)
        let timeout = self.timeout(for: method)
        
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
            "params": params
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            completion((nil, "Unable to encode the request."))
            return
        }
        
        request.httpBody = jsonData
        
        var sesh = plainSession
        
        if onionAddress.contains("onion") {
            sesh = self.torClient.session
            
        } else {
            if let cert = cert {
                delegate.cert = cert
                
                delegate.onTrustError = { errorMessage in
                    completion((nil, "SSL error:\(errorMessage)"))
                    return
                }
                
                sesh = session(forCert: decryptedCert)
            }
        }
        
        let task = sesh.dataTask(with: request as URLRequest) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            guard error == nil else {
                completion((nil, error!.localizedDescription))
                return
            }
            
            guard let urlContent = data else {
                completion((nil, "No resonse and no error from your node..."))
                return
            }
            
            self.handleResponse(urlContent, statusCode: (response as? HTTPURLResponse)?.statusCode, method: method,
                                walletName: walletName, walletOverride: walletOverride, completion: completion)
        }
        
        task.resume()
    }
    
    private func timeout(for method: BTC_CLI_COMMAND) -> Double {
        switch method {
        case .gettxoutsetinfo: return 1000.0
        // Reads the whole UTXO set: over a minute on a fast node, more on a small one.
        case .scantxoutset: return 600.0
        // A full block or template is many megabytes, slow over Tor.
        case .getblock, .getblocktemplate: return 300.0
        case .importdescriptors: return 180.0
        default: return 60.0
        }
    }
    
    /// Bitcoin Core's JSON-RPC response (over HTTP or Nostr Connect) → result or error message.
    private func handleResponse(_ urlContent: Data, statusCode: Int?, method: BTC_CLI_COMMAND, walletName: String?,
                                walletOverride: String?, completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        guard let json = try? JSONSerialization.jsonObject(with: urlContent, options: .mutableLeaves) as? NSDictionary else {
            if let statusCode = statusCode {
                switch statusCode {
                case 401:
                    completion((nil, "Looks like your rpc credentials are incorrect, please double check them. If you changed your rpc creds in your bitcoin.conf you need to restart your node for the changes to take effect."))
                case 403:
                    completion((nil, "The bitcoin-cli \(method) command has not been added to your rpcwhitelist, add \(method) to your bitcoin.conf rpcwhitelsist, reboot Bitcoin Core and try again."))
                default:
                    completion((nil, "Unable to decode the response from your node, http status code: \(statusCode)"))
                }
            } else {
                completion((nil, "Unable to decode the response from your node..."))
            }
            return
        }
        
        #if DEBUG
        // Whole blocks are tens of megabytes: printing one stalls the app.
        if urlContent.count < 100_000 { print("json: \(json)") }
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
            
        } else if errorMessage.contains("Requested wallet does not exist or is not loaded"), let walletName = walletName {
            let p = Load_Wallet(["filename": walletName])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .loadwallet(p)) { [weak self] (response, _) in
                guard let self = self else { return }
                
                guard let response = response as? [String: Any] else {
                    completion((nil, errorMessage))
                    return
                }
                
                guard let name = response["name"] as? String, name == walletName else {
                    completion((nil, errorMessage))
                    return
                }
                
                executeRPCCommand(method: method, walletName: walletOverride, completion: completion)
            }
        } else {
            completion((nil, errorMessage))
        }
    }
}
