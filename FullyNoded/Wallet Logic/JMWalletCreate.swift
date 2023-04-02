//
//  JMWallet.swift
//  FullyNoded
//
//  Created by Peter Denton on 8/14/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class JoinMarket {
    static var index = 0
    static var descriptors = ""
    static var plain = [String()]
    static var wallet:[String:Any] = [:]

    class func descriptors(_ mk: String, _ xfp: String, completion: @escaping (([String]?)) -> Void) {
        guard let xpub0 = xpub(0, mk),
              let xpub1 = xpub(1, mk),
              let xpub2 = xpub(2, mk),
              let xpub3 = xpub(3, mk),
              let xpub4 = xpub(4, mk) else {
                  completion(nil)
                  return
              }
            
            plain = [
                desc(0, xfp, xpub0, 0),
                desc(0, xfp, xpub0, 1),
                desc(1, xfp, xpub1, 0),
                desc(1, xfp, xpub1, 1),
                desc(2, xfp, xpub2, 0),
                desc(2, xfp, xpub2, 1),
                desc(3, xfp, xpub3, 0),
                desc(3, xfp, xpub3, 1),
                desc(4, xfp, xpub4, 0),
                desc(4, xfp, xpub4, 1)
            ]
        
        completion((plain))
    }
    
    static func desc(_ mixDepth: Int, _ xfp: String, _ xpub: String, _ branch: Int) -> String {
        var cointType = "0"
        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        if chain != "main" {
            cointType = "1"
        }
        return "wpkh([\(xfp)/84h/\(cointType)h/\(mixDepth)h]\(xpub)/\(branch)/*)"
    }
    
    static func xpub(_ mixDepth: Int, _ mk: String) -> String? {
        var cointType = "0"
        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        if chain != "main" {
            cointType = "1"
        }
        return Keys.xpub(path: "m/84h/\(cointType)h/\(mixDepth)h", masterKey: mk)
    }
}
