//
//  FiatConverter.swift
//  BitSense
//
//  Created by Peter on 26/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class FiatConverter {
    static let sharedInstance = FiatConverter()
    
    private init() {}
    
    let torClient = TorClient.sharedInstance
    var task: URLSessionDataTask? = nil
    
    func getFxRate(currency: String, completion: @escaping ((Double?)) -> Void) {
        let urlString = "https://blockchain.info/ticker"
        let url: NSURL? = NSURL(string: urlString)
        
        task = torClient.session.dataTask(with: url! as URL) { [weak self] (data, response, error) -> Void in
            guard let self = self else { return }
            guard let json = self.fetchJson(data: data) else {
                completion(nil)
                return
            }
            
            parseBlockChainInfoJson(currency: currency, json: json, completion: completion)
        }
        task?.resume()
    }
    
    private func parseBlockChainInfoJson(currency: String, json: [String: Any], completion: @escaping ((Double?)) -> Void) {
        guard let data = json["\(currency)"] as? NSDictionary,
              let rateCheck = data["15m"] as? Double else {
            completion(nil)
            return
        }
        completion(rateCheck)
    }
    
    private func fetchJson(data: Data?) -> [String: Any]? {
        guard let urlContent = data, let json = try? JSONSerialization.jsonObject(with: urlContent, options: [.mutableContainers]) as? [String : Any] else {
            return nil
        }
        return json
    }
}
