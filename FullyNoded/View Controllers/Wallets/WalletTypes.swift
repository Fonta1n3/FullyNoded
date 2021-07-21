//
//  WalletTypes.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/21/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

public enum WalletType: String {
    case descriptor
    case single
    case multi
    
    var stringValue: String {
        switch self {
        case .descriptor:
            return "Native-Descriptor"
        case .single:
            return "Single-Sig"
        case .multi:
            return "Multi-Sig"
        }
    }
}


