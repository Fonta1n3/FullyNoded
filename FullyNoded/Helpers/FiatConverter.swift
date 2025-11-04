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
    
    //let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
    let torClient = TorClient.sharedInstance
    var task: URLSessionDataTask? = nil
    
    func getFxRate(currency: String, completion: @escaping ((Double?)) -> Void) {
        let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
        let urlString = useBlockchainInfo ? "https://blockchain.info/ticker" : "https://api.coindesk.com/v1/bpi/currentprice.json"
        let url: NSURL? = NSURL(string: urlString)
        
        task = torClient.session.dataTask(with: url! as URL) { (data, response, error) -> Void in
            guard let json = self.fetchJson(data: data) else { completion(nil); return }
            
            if useBlockchainInfo {
                self.parseBlockChainInfoJson(currency: currency, json: json, completion: completion)
            } else {
                self.parseCoindeskJson(currency: currency, json: json, completion: completion)
            }
        }
        task?.resume()
    }
    
    private func parseCoindeskJson(currency: String, json: [String: Any], completion: @escaping ((Double?)) -> Void) {
        guard let dict = json["bpi"] as? NSDictionary,
              let usd = dict["\(currency)"] as? NSDictionary,
              let price = usd["rate_float"] as? Double else {
            completion(nil)
            return
        }
        completion(price.rounded())
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
    
    func getOriginRate(date: String, completion: @escaping ((Double?)) -> Void) {
        let url = NSURL(string: "https://api.coindesk.com/v1/bpi/historical/close.json?start=\(date)&end=\(date)")
        task = torClient.session.dataTask(with: url! as URL) { (data, response, error) -> Void in
            guard let json = self.fetchJson(data: data) else { completion(nil); return }
            guard let dict = json["bpi"] as? NSDictionary,
                let price = dict["\(date)"] as? Double else {
                    completion(nil)
                    return
            }
            completion(price)
        }
        task?.resume()
    }
}
