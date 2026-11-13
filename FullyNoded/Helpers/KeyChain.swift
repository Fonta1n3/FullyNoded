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
    
    /// Insert or replace `data` for `key`.
    /// Use `add(_:forKey:)` for values that must never be overwritten (e.g. the master
    /// encryption key).
    class func set(_ data: Data, forKey key: String) -> Bool {
        // Match the existing item by identity only. The old code also put the NEW
        // value, accessibility and sync flag in the delete query, so the delete could
        // miss the existing item and the add then failed with errSecDuplicateItem.
        let match: [String: Any] = [
            kSecClass as String:                      kSecClassGenericPassword,
            kSecAttrService as String:                service,
            kSecAttrAccount as String:                key,
            kSecUseDataProtectionKeychain as String:  true
        ]
        
        // Delete any existing item first
        SecItemDelete(match as CFDictionary)
        
        return add(data, forKey: key) == errSecSuccess
    }
    
    /// Add-only write: never deletes or replaces an existing item.
    /// Returns errSecDuplicateItem if `key` already exists.
    @discardableResult
    class func add(_ data: Data, forKey key: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String:                      kSecClassGenericPassword,
            kSecAttrService as String:                service,
            kSecAttrAccount as String:                key,
            kSecAttrAccessible as String:             kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String:         false,               // Never sync to iCloud
            kSecUseDataProtectionKeychain as String:  true,
            kSecValueData as String:                  data
        ]
        return SecItemAdd(query as CFDictionary, nil)
    }
    
    
    /// Result of a keychain read that keeps "doesn't exist" apart from "couldn't read"
    /// (e.g. errSecInteractionNotAllowed while the device is locked).
    enum ReadResult {
        case found(Data)
        case notFound
        case error(OSStatus)
    }
    
    /// Read `key`, modern format first, then legacy. Only reports `.notFound` when BOTH
    /// lookups say the item doesn't exist.
    class func read(_ key: String) -> ReadResult {
        let modern = copyMatching(modernQuery(key))
        if case .found = modern { return modern }
        
        let legacy = copyMatching(legacyQuery(key))
        if case .found(let data) = legacy {
            // Migrate old key to the new secure format
            _ = set(data, forKey: key)
            return legacy
        }
        
        // Any real error wins over "not found": we can't tell whether the item exists.
        if case .error = modern { return modern }
        if case .error = legacy { return legacy }
        return .notFound
    }
    
    
    // MARK: - Read (Backwards compatible)
    
    /// Convenience read: the data, or nil if missing OR unreadable. Don't use this to
    /// decide that an item doesn't exist; use `read(_:)`.
    class func getData(_ key: String) -> Data? {
        if case .found(let data) = read(key) { return data }
        return nil
    }
    
    
    // MARK: - Private Helpers
    
    private class func modernQuery(_ key: String) -> [String: Any] {
        return [
            kSecClass as String:                      kSecClassGenericPassword,
            kSecAttrService as String:                service,
            kSecAttrAccount as String:                key,
            kSecReturnData as String:                 true,
            kSecMatchLimit as String:                 kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String:  true
        ]
    }
    
    private class func legacyQuery(_ key: String) -> [String: Any] {
        return [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
    }
    
    private class func copyMatching(_ query: [String: Any]) -> ReadResult {
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return .error(errSecDecode) }
            return .found(data)
        case errSecItemNotFound:
            return .notFound
        default:
            return .error(status)
        }
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
