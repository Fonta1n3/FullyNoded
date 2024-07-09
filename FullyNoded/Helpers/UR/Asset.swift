//
//  Asset.swift
//  Gordian Seed Tool
//
//  Created by Wolf McNally on 1/22/21.
//

import SwiftUI
import URKit

enum Asset: UInt32, Identifiable, CaseIterable {
    // Values from [SLIP44] with high bit turned off
    case btc = 0
    //case eth = 0x3c
//    case bch = 0x91
    
    var cbor: CBOR {
        CBOR.unsigned(UInt64(rawValue))
    }
    
    init(cbor: CBOR) throws {
        guard
            case let CBOR.unsigned(r) = cbor,
            let a = Asset(rawValue: UInt32(r)) else {
            throw GeneralError("Invalid Asset.")
        }
        self = a
    }
    
//    var icon: AnyView {
//        switch self {
//        case .btc:
//            return Image("asset.btc")
//                .renderingMode(.original)
//                .accessibility(label: Text(self.name))
//                //.eraseToAnyView()
//        case .eth:
//            return Image("asset.eth")
//                .renderingMode(.original)
//                .accessibility(label: Text(self.name))
//                //.eraseToAnyView()
////        case .bch:
////            return Image("asset.bch").renderingMode(.original).eraseToAnyView()
//        }
//    }
    
    var id: String {
        "asset-\(description)"
    }
    
//    var subtype: ModelSubtype {
//        ModelSubtype(id: id, icon: AnyView())
//    }
    
    var name: String {
        switch self {
        case .btc:
            return "Bitcoin"
//        case .eth:
//            return "Ethereum"
//        case .bch:
//            return "Bitcoin Cash"
        }
    }
}

//extension Asset: Segment {
//    var label: AnyView {
//        makeSegmentLabel(title: name, icon: icon)
//    }
//}

extension Asset: CustomStringConvertible {
    var description: String {
        switch self {
        case .btc:
            return "btc"
//        case .eth:
//            return "eth"
//        case .bch:
//            return "bch"
        }
    }
}
