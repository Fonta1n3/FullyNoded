//
//  SilentPaymentKeyTests.swift
//  FullyNodedTests
//
//  Silent payment (BIP352) keys: the address and scan key made from a seed, the sender's
//  output key, the receiver finding the payment, and signing its spend.
//

import XCTest
@testable import FullyNoded

final class SilentPaymentKeyTests: KeyTestCase {

    /// BIP352 test vector "Simple send: two inputs" (bip-0352/send_and_receive_test_vectors.json).
    private enum SimpleSend {
        static let inputs = [
            (txid: "f4184fc596403b9d638783cf57adfe4c75c605f6356fbc91338530e9831e9e16",
             privateKey: "eadc78165ff1f8ea94ad7cfdc54990738a4c53f6e0507b42154201b8e5dff3b1",
             scriptSig: "483046022100ad79e6801dd9a8727f342f31c71c4912866f59dc6e7981878e92c5844a0ce929022100fb0d2393e813968648b9753b7e9871d90ab3d815ebf91820d704b19f4ed224d621025a1e61f898173040e20616d43e9f496fba90338a39faa1ed98fcbaeee4dd9be5",
             prevoutScript: "76a91419c2f3ae0ca3b642bd3e49598b8da89f50c1416188ac"),
            (txid: "a1075db55d416d3ca199f55b6084e2115b9345e16c5cf302fc80e9d5fbf5d48d",
             privateKey: "93f5ed907ad5b2bdbbdcb5d9116ebc0a4e1f92f910d5260237fa45a9408aad16",
             scriptSig: "48304602210086783ded73e961037e77d49d9deee4edc2b23136e9728d56e4491c80015c3a63022100fda4c0f21ea18de29edbce57f7134d613e044ee150a89e2e64700de2d4e83d4e2103bd85685d03d111699b15d046319febe77f8de5286e9e512703cdee1bf3be3792",
             prevoutScript: "76a914d9317c66f54ff0a152ec50b1d19c25be50c8e15988ac"),
        ]
        static let inputKeySum = "7ed265a6dac7aba8508a32d6d6b84c7f1dbd0a0941dd01088d69e8d556345f86"
        static let address = "sp1qqgste7k9hx0qftg6qmwlkqtwuy6cycyavzmzj85c6qdfhjdpdjtdgqjuexzk6murw56suy3e0rd2cgqvycxttddwsvgxe2usfpxumr70xc9pkqwv"
        static let scanPrivateKey = "0f694e068028a717f8af6b9411f9a133dd3565258714cc226594b34db90c1f2c"
        static let spendPrivateKey = "9d6ad855ce3417ef84e836892e5a56392bfba05fa5d97ccea30e266f540e08b3"
        static let outputKey = "3e9fce73d4e77a4809908e3c3a2e54ee147b9312dc5044a193d1fc85de46e3c1"
        static let tweak = "f438b40179a3c4262de12986c0e6cce0634007cdc79c1dcd3e20b9ebc2e7eef6"
    }

    // MARK: BIP352 test vector

    func testSenderMakesTheExpectedOutput() throws {
        let keys = SimpleSend.inputs.map { SPInputKeys.Key(secret: Data(hex: $0.privateKey)) }
        let outpoints = SimpleSend.inputs.map { outpoint(txid: $0.txid, vout: 0) }

        let output = try SPSender.outputKey(inputKeys: keys, outpoints: outpoints,
                                            recipient: SPRecipient(address: SimpleSend.address))
        XCTAssertEqual(output.hexString, SimpleSend.outputKey)
    }

    func testPrivateKeysAddUp() {
        let sum = SPScalar.add(Data(hex: SimpleSend.inputs[0].privateKey), Data(hex: SimpleSend.inputs[1].privateKey))
        XCTAssertEqual(sum.hexString, SimpleSend.inputKeySum)
    }

    func testReceiverFindsThePaymentAndItsSpendKey() throws {
        let tx: [String: Any] = [
            "vin": SimpleSend.inputs.map { input -> [String: Any] in
                ["txid": input.txid, "vout": 0,
                 "scriptSig": ["hex": input.scriptSig],
                 "prevout": ["scriptPubKey": ["hex": input.prevoutScript]]]
            },
            "vout": [["n": 0, "scriptPubKey": ["hex": "5120" + SimpleSend.outputKey]]],
        ]
        let spendKey = Data(hex: SimpleSend.spendPrivateKey)
        let keys = SilentPaymentSpend.ScanKeys(bScan: Data(hex: SimpleSend.scanPrivateKey),
                                               bSpendPub: Keys.compressedPublicKey(privateKey: spendKey)!)

        let found = try XCTUnwrap(SilentPaymentSpend.scan(fundingTx: tx, txid: SimpleSend.inputs[0].txid, vout: 0, keys: keys))
        XCTAssertEqual(found.tweakHex, SimpleSend.tweak)

        // The key that spends it is b_spend + tweak.
        XCTAssertEqual(xOnlyPublicKey(SPScalar.add(spendKey, Data(hex: found.tweakHex))), SimpleSend.outputKey)
    }

    // MARK: Fully Noded's own keys

    func testAddressFromSeed() throws {
        let mainnet = try XCTUnwrap(WalletLogic.shared.silentPaymentAddress(mnemonic: Vectors.words, passphrase: nil, mainnet: true))
        let testnet = try XCTUnwrap(WalletLogic.shared.silentPaymentAddress(mnemonic: Vectors.words, passphrase: nil, mainnet: false))
        XCTAssertTrue(mainnet.hasPrefix("sp1q"), mainnet)
        XCTAssertTrue(testnet.hasPrefix("tsp1q"), testnet)

        // A passphrase is a different wallet, so a different address.
        XCTAssertNotEqual(WalletLogic.shared.silentPaymentAddress(mnemonic: Vectors.words, passphrase: "TREZOR", mainnet: true), mainnet)
    }

    func testExportedScanKeyIsNotTheSpendKey() throws {
        let keys = try WalletLogic.shared.silentPaymentAddressFromMnemonic(mnemonic: Vectors.words)
        let exported = WalletLogic.shared.silentPaymentScanPrivateKey(mnemonic: Vectors.words, passphrase: nil, mainnet: true)

        XCTAssertEqual(exported, keys.scanPrivHex)
        XCTAssertNotEqual(exported, keys.spendPrivHex)
        // Each private key belongs to the public key in the address.
        XCTAssertEqual(Keys.compressedPublicKey(privateKey: Data(hex: keys.scanPrivHex))?.hexString, keys.scanPubHex)
        XCTAssertEqual(Keys.compressedPublicKey(privateKey: Data(hex: keys.spendPrivHex))?.hexString, keys.spendPubHex)
    }

    /// Pay our own address, find the payment with the scan key, then sign a transaction
    /// spending it with the spend key.
    func testPayFindAndSpendOwnSilentPayment() throws {
        let keys = try WalletLogic.shared.silentPaymentAddressFromMnemonic(mnemonic: Vectors.words)

        // The sender spends a P2WPKH coin with private key 0x11…11.
        let senderKey = Data(repeating: 0x11, count: 32)
        let senderPub = try XCTUnwrap(Keys.compressedPublicKey(privateKey: senderKey))
        let fundingTxid = String(repeating: "22", count: 32)
        let output = try SPSender.outputKey(inputKeys: [SPInputKeys.Key(secret: senderKey)],
                                            outpoints: [outpoint(txid: fundingTxid, vout: 1)],
                                            recipient: SPRecipient(address: keys.address))

        // Find it.
        let paymentTxid = String(repeating: "33", count: 32)
        let tx: [String: Any] = [
            "vin": [["txid": fundingTxid, "vout": 1,
                     "txinwitness": ["30440220", senderPub.hexString],
                     "prevout": ["scriptPubKey": ["hex": "0014" + SPHashFN.hash160(senderPub).hexString]]]],
            "vout": [["n": 0, "scriptPubKey": ["hex": "5120" + output.hexString]]],
        ]
        let scanKeys = SilentPaymentSpend.ScanKeys(bScan: Data(hex: keys.scanPrivHex), bSpendPub: Data(hex: keys.spendPubHex))
        let found = try XCTUnwrap(SilentPaymentSpend.scan(fundingTx: tx, txid: paymentTxid, vout: 0, keys: scanKeys))

        // Spend it.
        let coin = SilentPaymentSweep.Input(txid: paymentTxid, vout: 0, amount: 100_000,
                                            scriptPubKey: Data(hex: "5120" + output.hexString))
        let sweep = try SilentPaymentSweep.psbt(inputs: [coin], destination: Data(hex: "0014" + String(repeating: "44", count: 20)), feeRate: 2)
        let signed = try SilentPaymentSpend.sign(psbt: sweep.psbt, outputs: [found], spendKey: Data(hex: keys.spendPrivHex))
        XCTAssertEqual(signed.signed, 1)

        let rawTx = try SilentPaymentSweep.extractKeyPathTransaction(psbt: signed.psbt)
        XCTAssertTrue(Keys.validTx(rawTx))
    }

    func testWrongSpendKeyCannotSign() throws {
        let output = SilentPaymentSpend.OwnedOutput(txid: String(repeating: "33", count: 32), vout: 0,
                                                    tweakHex: SimpleSend.tweak, labelTweakHex: nil)
        let coin = SilentPaymentSweep.Input(txid: output.txid, vout: 0, amount: 100_000,
                                            scriptPubKey: Data(hex: "5120" + SimpleSend.outputKey))
        let sweep = try SilentPaymentSweep.psbt(inputs: [coin], destination: Data(hex: "0014" + String(repeating: "44", count: 20)), feeRate: 2)

        // The vector's real spend key signs; the scan key in its place doesn't.
        XCTAssertNoThrow(try SilentPaymentSpend.sign(psbt: sweep.psbt, outputs: [output], spendKey: Data(hex: SimpleSend.spendPrivateKey)))
        XCTAssertThrowsError(try SilentPaymentSpend.sign(psbt: sweep.psbt, outputs: [output], spendKey: Data(hex: SimpleSend.scanPrivateKey)))
    }

    // MARK: Key arithmetic

    func testNegatingAKey() {
        let key = Data(hex: SimpleSend.spendPrivateKey)
        XCTAssertEqual(SPScalar.negate(SPScalar.negate(key)), key)
        XCTAssertTrue(SPScalar.isZero(SPScalar.add(key, SPScalar.negate(key))))
    }

    func testValidPrivateKeys() {
        XCTAssertTrue(SPScalar.isValid(Data(hex: SimpleSend.spendPrivateKey)))
        XCTAssertFalse(SPScalar.isValid(Data(repeating: 0, count: 32)))      // zero
        XCTAssertFalse(SPScalar.isValid(Data(repeating: 0xff, count: 32)))   // not below the curve order
        XCTAssertFalse(SPScalar.isValid(Data(repeating: 1, count: 31)))      // wrong length
    }

    // MARK: Helpers

    /// The 36-byte outpoint BIP352 hashes: txid (internal byte order) then vout (little-endian).
    private func outpoint(txid: String, vout: UInt32) -> Data {
        Data(Data(hex: txid).reversed()) + withUnsafeBytes(of: vout.littleEndian) { Data($0) }
    }

    private func xOnlyPublicKey(_ privateKey: Data) -> String? {
        Keys.compressedPublicKey(privateKey: privateKey).map { Data($0.dropFirst()).hexString }
    }
}
