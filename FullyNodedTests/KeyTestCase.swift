//
//  KeyTestCase.swift
//  FullyNodedTests
//
//  Shared setup for the private key tests. They run inside the app (in the simulator), so
//  they use the same Keychain and settings Fully Noded does.
//

import XCTest
@testable import FullyNoded

/// Published test vectors used across the tests.
enum Vectors {
    /// BIP39 test vector 1 (all-zero entropy): the seed the BIP32/84/86 test vectors use.
    static let words = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
}

/// Runs each test on mainnet settings and puts the app's network setting back afterwards.
/// Fully Noded reads the network ("chain") from UserDefaults, so tests that need another
/// network set `chain` themselves.
class KeyTestCase: XCTestCase {
    private var savedChain: Any?

    var chain: String {
        get { UserDefaults.standard.string(forKey: "chain") ?? "main" }
        set { UserDefaults.standard.set(newValue, forKey: "chain") }
    }

    override func setUp() {
        super.setUp()
        savedChain = UserDefaults.standard.object(forKey: "chain")
        chain = "main"
    }

    override func tearDown() {
        UserDefaults.standard.set(savedChain, forKey: "chain")
        super.tearDown()
    }
}

extension Data {
    /// Hex test vector to bytes (the vectors are known good, so this never fails).
    init(hex: String) {
        self.init(hexString: hex)!
    }
}
