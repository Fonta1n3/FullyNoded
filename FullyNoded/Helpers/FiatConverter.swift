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
        let url = NSURL(string: "http://bhnabseew4xlooaatukm7sxmvel2ntj53phtx3om4pcxcyg5moyciryd.onion/now/USD/kraken")
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
                                if let data = json["close"] as? Double {
                                    completion(data)
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
}
