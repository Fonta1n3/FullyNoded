//
//  ModelObjectType.swift
//  Gordian Seed Tool
//
//  Created by Wolf McNally on 12/10/20.
//

import SwiftUI

enum ModelObjectType {
    case seed
    case privateKey
    case publicKey

//    var icon: AnyView {
//        switch self {
//        case .seed:
//            return Image("seed.circle")
//        case .privateKey:
//            return KeyType.private.icon
//        case .publicKey:
//            return KeyType.public.icon
//        }
//    }
    
    var name: String {
        switch self {
        case .seed:
            return "Seed"
        case .privateKey:
            return "Private Key"
        case .publicKey:
            return "Public Key"
        }
    }
}
