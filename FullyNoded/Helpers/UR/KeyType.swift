//
//  KeyType.swift
//  Gordian Seed Tool
//
//  Created by Wolf McNally on 1/24/21.
//

import SwiftUI

enum KeyType: Identifiable, CaseIterable {
    case `private`
    case `public`
    
    var id: String {
        switch self {
        case .private:
            return "keytype-private"
        case .public:
            return "keytype-public"
        }
    }

    var name: String {
        switch self {
        case .private:
            return "Private"
        case .public:
            return "Public"
        }
    }
    
    var isPrivate: Bool {
        switch self {
        case .private:
            return true
        case .public:
            return false
        }
    }
    
    init(isPrivate: Bool) {
        if isPrivate {
            self = .private
        } else {
            self = .public
        }
    }
}

