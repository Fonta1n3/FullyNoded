//
//  KeyDerivationTests.swift
//  FullyNodedTests
//
//  Seed words → master key → account keys → descriptors and addresses, checked against the
//  published BIP39, BIP32, BIP84 and BIP86 test vectors.
//

import XCTest
@testable import FullyNoded

final class KeyDerivationTests: KeyTestCase {

    private var masterKey: String { Keys.masterKey(words: Vectors.words, coinType: "0", passphrase: "")! }

    // MARK: Master key

    func testMasterKeyWithPassphrase() {
        // BIP39 test vector 1, passphrase "TREZOR".
        XCTAssertEqual(Keys.masterKey(words: Vectors.words, coinType: "0", passphrase: "TREZOR"),
                       "xprv9s21ZrQH143K3h3fDYiay8mocZ3afhfULfb5GX8kCBdno77K4HiA15Tg23wpbeF1pLfs1c5SPmYHrEpTuuRhxMwvKDwqdKiGJS9XFKzUsAF")
    }

    func testMasterPublicKey() {
        XCTAssertEqual(Keys.xpub(fromXprv: masterKey),
                       "xpub661MyMwAqRbcFkPHucMnrGNzDwb6teAX1RbKQmqtEF8kK3Z7LZ59qafCjB9eCRLiTVG3uxBxgKvRgbubRhqSKXnGGb1aoaqLrpMBDrVxga8")
    }

    func testFingerprint() {
        XCTAssertEqual(Keys.fingerprint(masterKey: masterKey), "73c5da0a")
    }

    func testPassphraseMakesADifferentWallet() {
        let withPassphrase = Keys.masterKey(words: Vectors.words, coinType: "0", passphrase: "TREZOR")!
        XCTAssertNotEqual(Keys.fingerprint(masterKey: withPassphrase), "73c5da0a")
    }

    func testTestNetworksUseTprv() {
        let testKey = Keys.masterKey(words: Vectors.words, coinType: "1", passphrase: "")
        XCTAssertEqual(testKey?.hasPrefix("tprv"), true)
        // Same key, so the same fingerprint.
        XCTAssertEqual(Keys.fingerprint(masterKey: testKey!), "73c5da0a")
    }

    func testInvalidWordsGiveNoKey() {
        XCTAssertNil(Keys.masterKey(words: "not a seed", coinType: "0", passphrase: ""))
        XCTAssertNil(Keys.fingerprint(masterKey: "xprvNotAKey"))
    }

    // MARK: Account keys and descriptors

    func testBIP84AccountKey() {
        // BIP84 test vector: account 0 (m/84'/0'/0'), zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs
        // in the vector, written here as the xpub Fully Noded uses (same key, xpub version bytes).
        XCTAssertEqual(Keys.bip84AccountXpub(masterKey: masterKey, coinType: "0", account: 0),
                       "xpub6CatWdiZiodmUeTDp8LT5or8nmbKNcuyvz7WyksVFkKB4RHwCD3XyuvPEbvqAQY3rAPshWcMLoP2fMFMKHPJ4ZeZXYVUhLv1VMrjPC7PW6V")
    }

    func testSignerDescriptorsGiveTheBIP84AndBIP86Addresses() throws {
        let descriptors = Keys.descriptorsFromSigner(signer: Vectors.words, passphrase: nil)
        XCTAssertNil(descriptors.errorMess)

        let bip84 = try XCTUnwrap(descriptors.bip84)
        XCTAssertTrue(bip84.hasPrefix("wpkh([73c5da0a/84h/0h/0h]xpub"), bip84)
        XCTAssertEqual(try firstAddress(bip84), "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu")

        let bip86 = try XCTUnwrap(descriptors.bip86)
        XCTAssertTrue(bip86.hasPrefix("tr([73c5da0a/86h/0h/0h]xpub"), bip86)
        XCTAssertEqual(try firstAddress(bip86), "bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr")
    }

    func testDescriptorsNeverContainPrivateKeys() {
        let d = Keys.descriptorsFromSigner(signer: Vectors.words, passphrase: nil)
        for descriptor in [d.bip84, d.bip86, d.segwitCosigner, d.taprootCosigner] {
            XCTAssertNotNil(descriptor)
            XCTAssertFalse(descriptor!.contains("prv"), descriptor!)
        }
    }

    func testTestnetDescriptorsUseCoinType1() {
        chain = "test"
        let bip84 = Keys.descriptorsFromSigner(signer: Vectors.words, passphrase: nil).bip84
        XCTAssertEqual(bip84?.hasPrefix("wpkh([73c5da0a/84h/1h/0h]tpub"), true, bip84 ?? "nil")
    }

    // MARK: Raw keys

    func testPublicKeyOfPrivateKeyOne() {
        // 1·G is the curve's generator point.
        let one = Data(repeating: 0, count: 31) + [1]
        XCTAssertEqual(Keys.compressedPublicKey(privateKey: one)?.hexString,
                       "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
    }

    func testInvalidPrivateKeysAreRejected() {
        XCTAssertNil(Keys.compressedPublicKey(privateKey: Data(repeating: 0, count: 32)))   // zero
        XCTAssertNil(Keys.compressedPublicKey(privateKey: Data(repeating: 0xff, count: 32))) // above the curve order
    }

    // MARK: Helpers

    private func firstAddress(_ descriptor: String) throws -> String {
        try WalletLogic.BDKDescriptor(descriptor: descriptor, networkKind: .main)
            .deriveAddress(index: 0, network: .bitcoin)
            .description
    }
}
