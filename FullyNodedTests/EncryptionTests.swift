//
//  EncryptionTests.swift
//  FullyNodedTests
//
//  How secrets are stored: encrypted with ChaChaPoly (Crypto) under one key kept in the
//  Keychain (KeyChain), and wiped from memory after use.
//

import XCTest
@testable import FullyNoded

final class EncryptionTests: KeyTestCase {

    // MARK: Encryption

    func testEncryptThenDecrypt() throws {
        let secret = Data(Vectors.words.utf8)
        let sealed = try XCTUnwrap(Crypto.encrypt(secret))

        XCTAssertNil(sealed.range(of: secret), "the encrypted data contains the plaintext")
        XCTAssertEqual(Crypto.decrypt(sealed), secret)
    }

    func testEncryptingTwiceGivesDifferentData() {
        // A fresh random nonce each time, so equal secrets can't be spotted.
        let secret = Data(Vectors.words.utf8)
        XCTAssertNotEqual(Crypto.encrypt(secret), Crypto.encrypt(secret))
    }

    func testChangedDataDoesNotDecrypt() throws {
        var sealed = try XCTUnwrap(Crypto.encrypt(Data(Vectors.words.utf8)))
        sealed[sealed.count - 1] ^= 0x01
        XCTAssertNil(Crypto.decrypt(sealed))
    }

    func testGarbageDoesNotDecrypt() {
        XCTAssertNil(Crypto.decrypt(Data()))
        XCTAssertNil(Crypto.decrypt(Data(repeating: 7, count: 64)))
    }

    func testEncryptionKeyNeverChanges() throws {
        // Replacing it would make every stored seed unreadable.
        let first = try XCTUnwrap(Crypto.encryptionKey())
        XCTAssertEqual(first.count, 32)
        XCTAssertEqual(Crypto.encryptionKey(), first)
    }

    // MARK: Keychain

    func testKeychainStoresReadsAndRemoves() {
        let key = "FullyNodedTests-\(UUID().uuidString)"
        let value = Data("secret".utf8)

        XCTAssertTrue(KeyChain.set(value, forKey: key))
        XCTAssertEqual(KeyChain.getData(key), value)

        XCTAssertTrue(KeyChain.remove(key: key))
        XCTAssertNil(KeyChain.getData(key))
    }

    func testKeychainAddNeverOverwrites() {
        // Crypto.encryptionKey() relies on this to never replace the encryption key.
        let key = "FullyNodedTests-\(UUID().uuidString)"
        defer { _ = KeyChain.remove(key: key) }

        XCTAssertEqual(KeyChain.add(Data("first".utf8), forKey: key), errSecSuccess)
        XCTAssertEqual(KeyChain.add(Data("second".utf8), forKey: key), errSecDuplicateItem)
        XCTAssertEqual(KeyChain.getData(key), Data("first".utf8))
    }

    // MARK: Wiping

    func testWipingData() {
        var secret = Data(Vectors.words.utf8)
        secret.secureZero()
        XCTAssertTrue(secret.isEmpty)
    }

    func testWipingStrings() {
        var words = Vectors.words
        words.secureWipe()
        XCTAssertEqual(words, "")
    }
}
