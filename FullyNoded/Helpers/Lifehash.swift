//
//  Lifehash.swift
//  FullyNoded
//
//  Created by Peter on 1/20/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation
import LifeHash
import UIKit

enum LifeHash {
    
    static func image(_ input: String) -> UIImage? {
        return LifeHashGenerator.generateSync(input, version: .version2)
    }
}

