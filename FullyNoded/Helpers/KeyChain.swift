//
//  KeyChain.swift
//  BitSense
//
//  Created by Peter on 13/05/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import Security

class KeyChain {
    
    private static let service = Bundle.main.bundleIdentifier ?? "com.yourapp.secure"
    
    // MARK: - Secure Write (No forced biometrics)
    
    class func set(_ data: Data, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:                      kSecClassGenericPassword,
            kSecAttrService as String:                service,
            kSecAttrAccount as String:                key,
            kSecAttrAccessible as String:             kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String:         false,               // Never sync to iCloud
            kSecUseDataProtectionKeychain as String:  true,
            kSecValueData as String:                  data
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    
    // MARK: - Read (Backwards compatible)
    
    class func getData(_ key: String) -> Data? {
        // 1. Try modern secure format
        if let data = getDataModern(key) {
            return data
        }
        
        // 2. Fallback to original/legacy format
        if let data = getDataLegacy(key) {
            // Migrate old key to the new secure format
            _ = set(data, forKey: key)
            return data
        }
        
        return nil
    }
    
    
    // MARK: - Private Helpers
    
    private class func getDataModern(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String:                      kSecClassGenericPassword,
            kSecAttrService as String:                service,
            kSecAttrAccount as String:                key,
            kSecReturnData as String:                 true,
            kSecMatchLimit as String:                 kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String:  true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess ? result as? Data : nil
    }
    
    private class func getDataLegacy(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess ? result as? Data : nil
    }
    
    
    // MARK: - Delete
    
    class func remove(key: String) -> Bool {
        let modernQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let legacyQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(modernQuery as CFDictionary)
        SecItemDelete(legacyQuery as CFDictionary)
        
        return true
    }
    
    
    class func removeAll() {
        let classes: [CFString] = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]
        
        for itemClass in classes {
            let query: [String: Any] = [kSecClass as String: itemClass]
            SecItemDelete(query as CFDictionary)
        }
    }
}
