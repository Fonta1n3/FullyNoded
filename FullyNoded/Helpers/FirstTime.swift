//
//  FirstTime.swift
//  BitSense
//
//  Created by Peter on 05/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

enum FirstTime {
    
    /// Ensures the master encryption key exists. It's created only if the keychain says
    /// it doesn't exist; an unreadable keychain (e.g. device locked) returns false
    /// without touching anything.
    static func firstTimeHere() -> Bool {
        return Crypto.encryptionKey() != nil
    }
    
}

