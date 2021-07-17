//
//  ModelObject.swift
//  Gordian Seed Tool
//
//  Created by Wolf McNally on 12/15/20.
//

import SwiftUI
import LifeHash
import URKit

struct ModelSubtype: Identifiable, Hashable {
    var id: String
    var icon: AnyView
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func ==(lhs: ModelSubtype, rhs: ModelSubtype) -> Bool {
        lhs.id == rhs.id
    }
}

protocol ModelObject: Fingerprintable, Identifiable, ObservableObject, Hashable {
    var modelObjectType: ModelObjectType { get }
    var name: String { get set }
    var ur: UR { get }
    var sizeLimitedUR: UR { get }
    var urString: String { get }
    var qrData: Data { get }
    var sizeLimitedURString: String { get }
    var id: UUID { get }
    var subtypes: [ModelSubtype] { get }
    var instanceDetail: String? { get }
}

extension ModelObject {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

extension ModelObject {
    var subtypes: [ModelSubtype] { [] }
    var instanceDetail: String? { nil }
//    func printPages(model: Model) -> [AnyView] {
//        [
//            Text("No print page provided.")
//                .eraseToAnyView()
//        ]
//    }

    var urString: String {
        ur.string
    }
    
    var qrData: Data {
        ur.qrData
    }
    
    var sizeLimitedURString: String {
        UREncoder.encode(sizeLimitedUR)
    }
}
