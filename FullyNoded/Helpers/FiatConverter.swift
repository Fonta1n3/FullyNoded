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
        let torClient = TorClient.sharedInstance
        let url = NSURL(string: "https://blockchain.info/ticker")
        let task = torClient.session.dataTask(with: url! as URL) { (data, response, error) -> Void in
            do {
                if error != nil {
                    completion(nil)
                } else {
                    if let urlContent = data {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: urlContent, options: [.mutableContainers]) as? [String : Any] {
                                #if DEBUG
                                print("json = \(json)")
                                #endif
                                if let data = json["USD"] as? NSDictionary {
                                    if let rateCheck = data["15m"] as? Double {
                                        completion(rateCheck)
                                    }
                                }
                            }
                        } catch {
                            print("JSon processing failed")
                            completion(nil)
                        }
                    }
                }
            }
        }
        task.resume()
    }
    
    func getOriginRate(date: String, completion: @escaping ((Double?)) -> Void) {
        let torClient = TorClient.sharedInstance
        let url = NSURL(string: "https://api.coindesk.com/v1/bpi/historical/close.json?start=\(date)&end=\(date)")
        let task = torClient.session.dataTask(with: url! as URL) { (data, response, error) -> Void in
            if error != nil {
                completion(nil)
            } else {
                guard let urlContent = data,
                    let json = try? JSONSerialization.jsonObject(with: urlContent, options: [.mutableContainers]) as? [String : Any],
                    let dict = json["bpi"] as? NSDictionary,
                    let price = dict["\(date)"] as? Double else {
                        completion(nil)
                        return
                }
                completion(price)
            }
        }
        task.resume()
    }
}
