//
//  GetTx.swift
//  FullyNoded
//
//  Created by Peter on 9/7/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

class GetTx {
    
    static let sharedInstance = GetTx()
    lazy var torClient = TorClient.sharedInstance
    
    func fetch(txid: String, completion: @escaping ((String?)) -> Void) {
        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? ""
        //http://explorernuoc63nb.onion
        //var blockstreamUrl = "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/api/tx/\(txid)/hex"
        var blockstreamUrl = "http://explorernuoc63nb.onion/api/tx/\(txid)/hex"
        if chain == "test" {
            blockstreamUrl = "http://explorernuoc63nb.onion/testnet/api/tx/\(txid)/hex"
        }
        guard let url = URL(string: blockstreamUrl) else {
            completion((nil))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        let task = torClient.session.dataTask(with: request as URLRequest) { (data, response, error) in
            if error != nil {
                completion(nil)
            } else {
                if let urlContent = data {
                    if let hex = String(bytes: urlContent, encoding: .utf8) {
                        completion(hex)
                    }
                }
            }
        }
        task.resume()
    }
}
