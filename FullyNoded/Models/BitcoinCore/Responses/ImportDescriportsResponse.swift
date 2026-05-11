//
//  ImportDescriportsResponse.swift
//  FullyNoded
//
//  Created by Peter Denton on 1/5/26.
//  Copyright © 2026 Fontaine. All rights reserved.
//

import Foundation

public struct ImportDescriportsResponse: CustomStringConvertible {
    /*
     {                            (json object)
         "success" : true|false,    (boolean)
         "warnings" : [             (json array, optional)
           "str",                   (string)
           ...
         ],
         "error" : {                (json object, optional)
           ...                      JSONRPC error
         }
       }
     */
    let success: Bool
    let error: [String: Any]?
    
    init(_ dictionary: [String: Any]) {
        self.success = dictionary["success"] as! Bool
        self.error = dictionary["error"] as? [String: Any]
    }
    
    public var description: String {
        return ""
    }
}
