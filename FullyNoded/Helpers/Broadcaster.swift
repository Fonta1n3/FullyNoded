//
//  Broadcaster.swift
//  BitSense
//
//  Created by Peter on 03/05/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

class Broadcaster {
    
    static let sharedInstance = Broadcaster()
    lazy var torClient = TorClient.sharedInstance
    
    func send(rawTx: String, completion: @escaping ((String?)) -> Void) {
        var blockstreamUrl = "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/api/tx"
        
        if (UserDefaults.standard.object(forKey: "chain") as! String) == "test" {
            blockstreamUrl = "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/testnet/api/tx"
        }
        
        guard let url = URL(string: blockstreamUrl) else {
            completion((nil))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = rawTx.data(using: .utf8)
        
        let task = torClient.session.dataTask(with: request as URLRequest) { (data, response, error) in
            if error != nil {
                completion(nil)
            } else {
                if let urlContent = data {
                    if let txid = String(bytes: urlContent, encoding: .utf8) {
                        completion(txid)
                    }
                }
            }
        }
        task.resume()
    }
}
