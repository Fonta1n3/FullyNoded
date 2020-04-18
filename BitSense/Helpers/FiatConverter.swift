//
//  FiatConverter.swift
//  BitSense
//
//  Created by Peter on 26/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class FiatConverter {
    
//    var torClient:TorClient!
//    var fxRate = Double()
//    var errorBool = Bool()
//    
//    func getFxRate(completion: @escaping () -> Void) {
//        
//        torClient = TorClient.sharedInstance
//        
//        func getResult() {
//            
//            var url:NSURL!
//            url = NSURL(string: "https://api.coindesk.com/v1/bpi/currentprice.json")
//            
//            let task = torClient.session.dataTask(with: url! as URL) { (data, response, error) -> Void in
//                
//                do {
//                    
//                    if error != nil {
//                        
//                        print(error as Any)
//                        print("error = \(String(describing: error))")
//                        self.errorBool = true
//                        completion()
//                        
//                    } else {
//                        
//                        if let urlContent = data {
//                            
//                            do {
//                                
//                                let json = try JSONSerialization.jsonObject(with: urlContent, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
//                                
//                                
//                                if let exchangeCheck = json["bpi"] as? NSDictionary {
//                                    
//                                    print("exchangeCheck = \(exchangeCheck)")
//                                    
//                                    if let usdCheck = exchangeCheck["USD"] as? NSDictionary {
//                                        
//                                        print("usdCheck = \(usdCheck)")
//                                        
//                                        if let rateCheck = usdCheck["rate_float"] as? Double {
//                                            
//                                            self.errorBool = false
//                                            self.fxRate = rateCheck
//                                            completion()
//                                            
//                                        }
//                                        
//                                    }
//                                    
//                                }
//                                
//                            } catch {
//                                
//                                print("JSon processing failed")
//                                
//                            }
//                            
//                        }
//                        
//                    }
//                    
//                }
//                
//            }
//            
//            task.resume()
//            
//        }
//        
//        self.torClient.start(completion: getResult)
//            
//    }
    
}
