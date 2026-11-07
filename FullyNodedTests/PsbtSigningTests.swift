//
//  PsbtSigningTests.swift
//  FullyNodedTests
//
//  Signing a PSBT the way the transaction verifier does (WalletLogic.wallet + signPsbt),
//  with no node: the PSBT is built from a watch-only wallet given a made-up coin.
//

import XCTest
import BitcoinDevKit
@testable import FullyNoded

final class PsbtSigningTests: KeyTestCase {

    private var receiveDescriptor = ""
    private var changeDescriptor = ""

    override func setUp() {
        super.setUp()
        chain = "regtest"
        receiveDescriptor = Keys.descriptorsFromSigner(signer: Vectors.words, passphrase: nil).bip84!
        changeDescriptor = receiveDescriptor.replacingOccurrences(of: "/0/*", with: "/1/*")
    }

    func testSignerSignsItsOwnPsbt() throws {
        let psbt = try unsignedPsbt()
        let result = try sign(psbt, words: Vectors.words, passphrase: "")

        XCTAssertNil(result.errorMessage)
        let rawTx = try XCTUnwrap(result.rawTx, "the PSBT should be fully signed and finalized")
        XCTAssertTrue(Keys.validTx(rawTx))

        // It spends the PSBT's input.
        let signed = try BitcoinDevKit.Transaction(transactionBytes: Data(hex: rawTx))
        let unsigned = try BitcoinDevKit.Psbt(psbtBase64: psbt).extractTx()
        XCTAssertEqual(signed.input().first?.previousOutput.txid.description,
                       unsigned.input().first?.previousOutput.txid.description)
    }

    func testSignerWithAPassphraseSignsItsOwnPsbt() throws {
        receiveDescriptor = Keys.descriptorsFromSigner(signer: Vectors.words, passphrase: "TREZOR").bip84!
        changeDescriptor = receiveDescriptor.replacingOccurrences(of: "/0/*", with: "/1/*")

        let result = try sign(try unsignedPsbt(), words: Vectors.words, passphrase: "TREZOR")
        XCTAssertNotNil(result.rawTx, result.errorMessage ?? "")
    }

    func testWrongPassphraseCannotSign() throws {
        let result = try sign(try unsignedPsbt(), words: Vectors.words, passphrase: "wrong")
        XCTAssertNil(result.rawTx)
        XCTAssertNil(result.signedPsbt)
        XCTAssertNotNil(result.errorMessage)
    }

    func testOtherSeedCannotSign() throws {
        let otherWords = try XCTUnwrap(Keys.seedWords())
        let result = try sign(try unsignedPsbt(), words: otherWords, passphrase: "")
        XCTAssertNil(result.rawTx)
        XCTAssertNotNil(result.errorMessage)
    }

    func testGarbageIsNotSigned() throws {
        let result = try sign("not a psbt", words: Vectors.words, passphrase: "")
        XCTAssertNil(result.rawTx)
        XCTAssertNotNil(result.errorMessage)
    }

    // MARK: Helpers

    /// Signs like the verifier: a signing wallet from the seed and the wallet's
    /// descriptors, then signPsbt.
    private func sign(_ psbt: String, words: String, passphrase: String) throws -> (signedPsbt: String?, rawTx: String?, errorMessage: String?) {
        var signingWallet: (bdkWallet: WalletLogic.BDKWallet?, errorMessage: String?)?
        WalletLogic.shared.wallet(passphrase: passphrase,
                                  network: .regtest,
                                  mnemonic: try BitcoinDevKit.Mnemonic.fromString(mnemonic: words),
                                  recDescStr: receiveDescriptor,
                                  changeDesStr: changeDescriptor) { signingWallet = $0 }

        guard let wallet = signingWallet?.bdkWallet else {
            return (nil, nil, signingWallet?.errorMessage ?? "no signing wallet")
        }
        return WalletLogic.shared.signPsbt(wallet: wallet, psbtBase64: psbt)
    }

    /// A PSBT sending 100,000 sats from the wallet's first address back to itself, made by
    /// a watch-only wallet that's told about a (made-up) transaction paying that address.
    private func unsignedPsbt() throws -> String {
        let watchOnly = try BitcoinDevKit.Wallet(
            descriptor: BitcoinDevKit.Descriptor(descriptor: receiveDescriptor, networkKind: .test),
            changeDescriptor: BitcoinDevKit.Descriptor(descriptor: changeDescriptor, networkKind: .test),
            network: .regtest,
            persister: Persister.newInMemory())

        let address = watchOnly.revealNextAddress(keychain: .external).address
        let script = address.scriptPubkey()
        let funding = try BitcoinDevKit.Transaction(transactionBytes: Self.transaction(paying: script.toBytes(), sats: 100_000))
        watchOnly.applyUnconfirmedTxs(unconfirmedTxs: [UnconfirmedTx(tx: funding, lastSeen: 1)])

        return try TxBuilder()
            .drainWallet()
            .drainTo(script: script)
            .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: 2))
            .finish(wallet: watchOnly)
            .serialize()
    }

    /// A legacy-format transaction with one made-up input and one output paying `script`.
    private static func transaction(paying script: Data, sats: UInt64) -> Data {
        var tx = Data([2, 0, 0, 0])                                // version 2
        tx += [1] + Data(repeating: 0x11, count: 32) + [0, 0, 0, 0] // 1 input: txid, vout 0
        tx += [0] + [0xff, 0xff, 0xff, 0xff]                       // empty scriptSig, sequence
        tx += [1] + withUnsafeBytes(of: sats.littleEndian) { Data($0) } // 1 output: amount
        tx += [UInt8(script.count)] + script                       // its script
        tx += [0, 0, 0, 0]                                         // locktime 0
        return tx
    }
}
