//
//  SeedWordTests.swift
//  FullyNodedTests
//
//  Creating and checking BIP39 seed words (Keys.seedWords, validMnemonic, checksumWords).
//

import XCTest
@testable import FullyNoded

final class SeedWordTests: KeyTestCase {

    func testNewSeedHas24ValidWords() throws {
        let words = try XCTUnwrap(Keys.seedWords())
        XCTAssertEqual(words.split(separator: " ").count, 24)
        XCTAssertTrue(Keys.validMnemonic(words))
    }

    func testNew12WordSeed() throws {
        let words = try XCTUnwrap(Keys.seedWords(wordCount: 12))
        XCTAssertEqual(words.split(separator: " ").count, 12)
        XCTAssertTrue(Keys.validMnemonic(words))
    }

    func testEveryNewSeedIsDifferent() {
        let seeds = Set((0..<20).compactMap { _ in Keys.seedWords() })
        XCTAssertEqual(seeds.count, 20)
    }

    func testOnly12Or24WordSeedsAreMade() {
        XCTAssertNil(Keys.seedWords(wordCount: 18))
        XCTAssertNil(Keys.seedWords(wordCount: 0))
    }

    func testChecksumIsChecked() {
        XCTAssertTrue(Keys.validMnemonic(Vectors.words))
        // Twelve "abandon"s: every word is real, but the last one fails the checksum.
        XCTAssertFalse(Keys.validMnemonic(Array(repeating: "abandon", count: 12).joined(separator: " ")))
        XCTAssertFalse(Keys.validMnemonic(Vectors.words.replacingOccurrences(of: "about", with: "bitcoins")))
        XCTAssertFalse(Keys.validMnemonic(""))
    }

    func testLastWordOptionsFor12Words() {
        let first11 = Array(repeating: "abandon", count: 11)
        let options = Keys.checksumWords(for: first11)

        // 7 free bits + a 4-bit checksum: 128 possible last words, all of them valid.
        XCTAssertEqual(options.count, 128)
        XCTAssertTrue(options.contains("about"))
        for word in options {
            XCTAssertTrue(Keys.validMnemonic((first11 + [word]).joined(separator: " ")), word)
        }
    }

    func testLastWordOptionsFor24Words() {
        let first23 = Array(repeating: "abandon", count: 23)
        let options = Keys.checksumWords(for: first23)

        // 3 free bits + an 8-bit checksum: 8 options. "art" completes BIP39 test vector 4.
        XCTAssertEqual(options.count, 8)
        XCTAssertTrue(options.contains("art"))
        for word in options {
            XCTAssertTrue(Keys.validMnemonic((first23 + [word]).joined(separator: " ")), word)
        }
    }

    func testNoLastWordOptionsForBadInput() {
        XCTAssertEqual(Keys.checksumWords(for: ["abandon", "notaword"] + Array(repeating: "abandon", count: 9)), [])
        XCTAssertEqual(Keys.checksumWords(for: Array(repeating: "abandon", count: 10)), [])
    }
}
