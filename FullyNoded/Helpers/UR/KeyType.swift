//
//  KeyType.swift
//  Gordian Seed Tool
//
//  Created by Wolf McNally on 1/24/21.
//

import SwiftUI

extension View {
    func encircle(color: Color) -> some View {
        padding(2)
            .background(
            Circle().fill(color)
        )
    }
}

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
    
//    var icon: AnyView {
//        switch self {
//        case .private:
//            return Image("key.prv.circle")
//                .icon()
//                .foregroundColor(.black)
//                .encircle(color: .lightRedBackground)
//                .eraseToAnyView()
//        case .public:
//            return Image("key.pub.circle")
//                .icon()
//                .foregroundColor(.white)
//                .encircle(color: Color.darkGreenBackground)
//                .eraseToAnyView()
//        }
//    }
    
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

//extension KeyType: Segment {
//    var label: AnyView {
//        makeSegmentLabel(title: name, icon: icon)
//    }
//}
