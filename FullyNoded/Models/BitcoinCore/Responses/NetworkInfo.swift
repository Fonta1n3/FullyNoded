//
//  NetworkInfo.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct NetworkInfo: CustomStringConvertible {
    
    let version:String
    let torReachable:Bool
    
    init(dictionary: [String: Any]) {
        self.version = dictionary["subversion"] as? String ?? ""
        self.torReachable = dictionary["reachable"] as? Bool ?? false
    }
    
    public var description: String {
        return ""
    }
}
