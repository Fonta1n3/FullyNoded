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
    
    func getFxRate(completion: @escaping ((Double?)) -> Void) {
        let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        let torClient = TorClient.sharedInstance
        let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
        var task: URLSessionDataTask? = nil
        var url: NSURL? = nil
        
        if useBlockchainInfo {
            url = NSURL(string: "https://blockchain.info/ticker")
            task = torClient.session.dataTask(with: url! as URL) { (data, response, error) -> Void in
                guard let json = self.fetchJson(data: data),
                      let data = json["\(currency)"] as? NSDictionary,
                      let rateCheck = data["15m"] as? Double else {
                    completion(nil)
                    return
                }
                completion(rateCheck)
            }
            task?.resume()
        } else {
            url = NSURL(string: "https://api.coindesk.com/v1/bpi/currentprice.json")
            task = torClient.session.dataTask(with: url! as URL) { (data, response, error) -> Void in
                guard let json = self.fetchJson(data: data),
                      let dict = json["bpi"] as? NSDictionary,
                      let usd = dict["\(currency)"] as? NSDictionary,
                      let price = usd["rate_float"] as? Double else {
                    completion(nil)
                    return
                }
                completion(price.rounded())
            }
            task?.resume()
        }
    }
    
    private func fetchJson(data: Data?) -> [String: Any]? {
        guard let urlContent = data, let json = try? JSONSerialization.jsonObject(with: urlContent, options: [.mutableContainers]) as? [String : Any] else {
            return nil
        }
        return json
    }
    
    func getOriginRate(date: String, completion: @escaping ((Double?)) -> Void) {
        let torClient = TorClient.sharedInstance
        let url = NSURL(string: "https://api.coindesk.com/v1/bpi/historical/close.json?start=\(date)&end=\(date)")
        let task = torClient.session.dataTask(with: url! as URL) { (data, response, error) -> Void in
            guard let urlContent = data,
                let json = try? JSONSerialization.jsonObject(with: urlContent, options: [.mutableContainers]) as? [String : Any],
                let dict = json["bpi"] as? NSDictionary,
                let price = dict["\(date)"] as? Double else {
                    completion(nil)
                    return
            }
            completion(price)
        }
        task.resume()
    }
}
