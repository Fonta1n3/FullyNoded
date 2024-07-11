//
//  Network.swift
//  Gordian Seed Tool
//
//  Created by Wolf McNally on 1/22/21.
//

import SwiftUI
import URKit
import LibWally

enum Network_: UInt32, Identifiable, CaseIterable {
    case mainnet = 0
    case testnet = 1
    
    var cbor: CBOR {
        CBOR.unsigned(UInt64(rawValue))
    }
    
    init(cbor: CBOR) throws {
        guard
            case let CBOR.unsigned(r) = cbor,
            let a = Network_(rawValue: UInt32(r)) else {
            throw GeneralError("Invalid Network.")
        }
        self = a
    }
    
    var wallyNetwork: LibWally.Network {
        switch self {
        case .mainnet:
            return .mainnet
        case .testnet:
            return .testnet
        }
    }
    
    var image: Image {
        switch self {
        case .mainnet:
            return Image("network.main")
        case .testnet:
            return Image("network.test")
        }
    }
    
//    var icon: AnyView {
//        image
//            .accessibility(label: Text(self.name))
//            //.eraseToAnyView()
//    }
    
    var name: String {
        switch self {
        case .mainnet:
            return "MainNet"
        case .testnet:
            return "TestNet"
        }
    }
    
//    var textSuffix: Text {
//        return Text(" ") + Text(image)
//    }
    
//    var iconWithName: some View {
//        HStack {
//            icon
//            Text(name)
//        }
//    }
    
    var id: String {
        "network-\(description)"
    }
    
    init?(id: String) {
        switch id {
        case "network-main":
            self = .mainnet
        case "network-test":
            self = .testnet
        default:
            return nil
        }
    }

//    var subtype: ModelSubtype {
//        ModelSubtype(id: id, icon: icon)
//    }
}

//extension Network: Segment {
//    var label: AnyView {
//        makeSegmentLabel(title: name, icon: icon)
//    }
//}

extension Network_: CustomStringConvertible {
    var description: String {
        switch self {
        case .mainnet:
            return "main"
        case .testnet:
            return "test"
        }
    }
}
