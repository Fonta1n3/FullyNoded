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
        hasprivatekeys = RPCValue.bool(dictionary["hasprivatekeys"]) ?? false
        checksum = dictionary["checksum"] as? String ?? ""
        descriptor = dictionary["descriptor"] as? String ?? ""
        issolvable = RPCValue.bool(dictionary["issolvable"]) ?? false
        isrange = RPCValue.bool(dictionary["isrange"]) ?? false
    }
    
    public var description: String {
        return ""
    }
}
