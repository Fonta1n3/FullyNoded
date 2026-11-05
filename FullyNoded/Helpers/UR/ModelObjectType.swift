//
//  ModelObjectType.swift
//  Gordian Seed Tool
//
//  Created by Wolf McNally on 12/10/20.
//

enum ModelObjectType {
    case seed
    case privateKey
    case publicKey

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
