//
//  DescriptorInfo.swift
//  FullyNoded
//
//  Created by Peter Denton on 8/13/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

public struct DescriptorInfo: CustomStringConvertible {
    
    /*
     {                                   (json object)
       "descriptor" : "str",             (string) The descriptor in canonical form, without private keys
       "checksum" : "str",               (string) The checksum for the input descriptor
       "isrange" : true|false,           (boolean) Whether the descriptor is ranged
       "issolvable" : true|false,        (boolean) Whether the descriptor is solvable
       "hasprivatekeys" : true|false     (boolean) Whether the input descriptor contained at least one private key
     }
     */
    
    let checksum: String
    let hasprivatekeys: Bool
    let issolvable: Bool
    let isrange: Bool
    let descriptor: String
    
    init(_ dictionary: [String: Any]) {
        hasprivatekeys = dictionary["hasprivatekeys"] as! Bool
        checksum = dictionary["checksum"] as! String
        
        if hasprivatekeys {
            // (this required for versions prior to 22)
            descriptor = (dictionary["descriptor"] as! String)//+ "#" + checksum
        } else {
            descriptor = (dictionary["descriptor"] as! String)
        }
        
        issolvable = dictionary["issolvable"] as! Bool
        isrange = dictionary["isrange"] as! Bool
    }
    
    public var description: String {
        return ""
    }
}
