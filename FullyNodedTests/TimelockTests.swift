//
//  TimelockTests.swift
//  FullyNodedTests
//
//  Timelocked addresses (the Invoice screen's "timelock" option): the address and descriptor
//  made for each wallet type, spending a timelocked coin, reading the lock back from scripts
//  and policies, and whether the UTXO screen shows a coin as locked.
//

import XCTest
import BitcoinDevKit
@testable import FullyNoded

final class TimelockTests: KeyTestCase {

    /// A unix time (Jan 1, 2030) and a block height, the two kinds of after(N).
    private let date: UInt32 = 1_893_456_000
    private let height: UInt32 = 200

    override func setUp() {
        super.setUp()
        chain = "regtest"
    }

    // MARK: Creating timelocked addresses

    func testSingleSigSegwitTimelock() throws {
        let bip84 = descriptors().bip84!
        let locked = try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet(bip84), pubkey: nil, descriptor: bip84,
                                                                     timelock: date, keyIndex: 5)

        // The key of the address being locked (index 5), spendable only after the date.
        let key = bip84.replacingOccurrences(of: "wpkh(", with: "").replacingOccurrences(of: "/0/*)", with: "/0/5")
        XCTAssertEqual(locked.descriptor, "wsh(and_v(v:pk(\(key)),after(\(date))))")
        XCTAssertEqual(locked.timelockedAddress, try address(of: locked.descriptor))
        XCTAssertTrue(locked.timelockedAddress.hasPrefix("bcrt1q"))
    }

    func testEachAddressIndexGetsItsOwnTimelock() throws {
        let bip84 = descriptors().bip84!
        let five = try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet(bip84), pubkey: nil, descriptor: bip84, timelock: date, keyIndex: 5)
        let six = try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet(bip84), pubkey: nil, descriptor: bip84, timelock: date, keyIndex: 6)
        XCTAssertNotEqual(five.timelockedAddress, six.timelockedAddress)
    }

    func testTheChecksumOfTheNodesDescriptorIsIgnored() throws {
        // The node's getaddressinfo parent_desc carries a checksum.
        let bip84 = descriptors().bip84!
        let withChecksum = try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet(bip84), pubkey: nil, descriptor: bip84 + "#abcdefgh", timelock: date, keyIndex: 5)
        let without = try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet(bip84), pubkey: nil, descriptor: bip84, timelock: date, keyIndex: 5)
        XCTAssertEqual(withChecksum.descriptor, without.descriptor)
    }

    func testSingleSigTaprootTimelock() throws {
        let bip86 = descriptors().bip86!
        let locked = try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet(bip86), pubkey: nil, descriptor: bip86,
                                                                     timelock: date, keyIndex: 5)

        // The key only spends through the script path, after the date. The key path uses an
        // unspendable internal key that isn't the wallet's.
        let key = bip86.replacingOccurrences(of: "tr(", with: "").replacingOccurrences(of: "/0/*)", with: "/0/5")
        XCTAssertTrue(locked.descriptor.hasPrefix("tr("), locked.descriptor)
        XCTAssertTrue(locked.descriptor.hasSuffix(",and_v(v:pk(\(key)),after(\(date))))"), locked.descriptor)
        XCTAssertFalse(Descriptor(locked.descriptor).internalKey.contains("73c5da0a"))
        XCTAssertEqual(locked.timelockedAddress, try address(of: locked.descriptor))
        XCTAssertTrue(locked.timelockedAddress.hasPrefix("bcrt1p"))
    }

    func testMultisigTimelockSortsKeysLikeTheAddress() throws {
        // A 2-of-2 sortedmulti wallet; the node describes the address being locked (index 3) with
        // its explicit public keys.
        let cosignerA = try cosigner(Vectors.words)
        let cosignerB = try cosigner("legal winner thank year wave sausage worth useful legal winner thank yellow")
        let parent = "wsh(sortedmulti(2,\(cosignerA.account)/0/*,\(cosignerB.account)/0/*))"
        let derived = "wsh(sortedmulti(2,\(cosignerB.originAt3)\(cosignerB.pubkeyAt3),\(cosignerA.originAt3)\(cosignerA.pubkeyAt3)))"

        let locked = try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet(parent), pubkey: nil, descriptor: parent,
                                                                     timelock: date, keyIndex: 3, derivedDescriptor: derived)

        // multi() keeps its order, so the keys are written in sortedmulti's order (by public key).
        let sorted = [cosignerA, cosignerB].sorted { $0.pubkeyAt3 < $1.pubkeyAt3 }.map { "\($0.account)/0/3" }
        XCTAssertEqual(locked.descriptor, "wsh(and_v(v:multi(2,\(sorted[0]),\(sorted[1])),after(\(date))))")
        XCTAssertEqual(locked.timelockedAddress, try address(of: locked.descriptor))
    }

    func testMultisigTimelockRefusesKeysItCantMatch() throws {
        let cosignerA = try cosigner(Vectors.words)
        let cosignerB = try cosigner("legal winner thank year wave sausage worth useful legal winner thank yellow")
        let parent = "wsh(sortedmulti(2,\(cosignerA.account)/0/*,\(cosignerB.account)/0/*))"
        let strangerKey = "[deadbeef/48h/1h/0h/2h/0/3]\(cosignerB.pubkeyAt3)"
        let derived = "wsh(sortedmulti(2,\(cosignerA.originAt3)\(cosignerA.pubkeyAt3),\(strangerKey)))"

        XCTAssertThrowsError(try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet(parent), pubkey: nil, descriptor: parent,
                                                                            timelock: date, keyIndex: 3, derivedDescriptor: derived))
        XCTAssertThrowsError(try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet(parent), pubkey: nil, descriptor: parent,
                                                                            timelock: date, keyIndex: 3, derivedDescriptor: nil))
    }

    func testUnsupportedWalletTypesAreRefused() {
        let legacy = "pkh([73c5da0a/44h/1h/0h]tpubDC5FSnBiZDMmhiuCmWAYsLwgLYrrT9rAqvTySfuCCrgsWz8wxMXUS9Tb9iVMvcRbvFcAHGkMD5Kx8koh4GquNGNTfohfk7pgjhaPCdXpoba/0/*)"
        XCTAssertThrowsError(try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet(legacy), pubkey: nil, descriptor: legacy, timelock: date))
    }

    // MARK: Spending a timelocked coin

    func testTimelockedCoinSignsWithItsLocktime() throws {
        let bip84 = descriptors().bip84!
        let change = bip84.replacingOccurrences(of: "/0/*", with: "/1/*")
        let locked = try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet(bip84), pubkey: nil, descriptor: bip84,
                                                                     timelock: height, keyIndex: 5)

        // A watch-only wallet holding one coin on the timelocked address builds the PSBT.
        let watchOnly = try BitcoinDevKit.Wallet(
            descriptor: BitcoinDevKit.Descriptor(descriptor: locked.descriptor, networkKind: .test),
            changeDescriptor: BitcoinDevKit.Descriptor(descriptor: change, networkKind: .test),
            network: .regtest,
            persister: Persister.newInMemory())
        let lockedScript = try Address(address: locked.timelockedAddress, network: .regtest).scriptPubkey()
        let funding = try BitcoinDevKit.Transaction(transactionBytes: Self.transaction(paying: lockedScript.toBytes(), sats: 100_000))
        watchOnly.applyUnconfirmedTxs(unconfirmedTxs: [UnconfirmedTx(tx: funding, lastSeen: 1)])
        let psbt = try TxBuilder()
            .drainWallet()
            .drainTo(script: watchOnly.revealNextAddress(keychain: .internal).address.scriptPubkey())
            .nlocktime(locktime: .blocks(height: height))
            .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: 2))
            .finish(wallet: watchOnly)

        // Fully Noded reads the lock from the coin's witness script (how it sets the locktime of
        // PSBTs the node makes).
        let witnessScript = try XCTUnwrap(psbt.input().first?.witnessScript)
        XCTAssertEqual(WalletLogic.shared.extractCLTV(fromWitnessScript: witnessScript.toBytes().hexString), height)

        // The seed signs it, and the transaction carries the locktime the script demands.
        var signingWallet: (bdkWallet: WalletLogic.BDKWallet?, errorMessage: String?)?
        WalletLogic.shared.wallet(passphrase: "", network: .regtest,
                                  mnemonic: try BitcoinDevKit.Mnemonic.fromString(mnemonic: Vectors.words),
                                  recDescStr: locked.descriptor, changeDesStr: change) { signingWallet = $0 }
        let signer = try XCTUnwrap(signingWallet?.bdkWallet, signingWallet?.errorMessage ?? "")
        let signed = WalletLogic.shared.signPsbt(wallet: signer, psbtBase64: psbt.serialize())

        let rawTx = try XCTUnwrap(signed.rawTx, signed.errorMessage ?? "not finalized")
        let tx = try BitcoinDevKit.Transaction(transactionBytes: Data(hex: rawTx))
        XCTAssertEqual(tx.lockTime(), height)
        XCTAssertLessThan(tx.input()[0].sequence, 0xFFFF_FFFF, "a final sequence would switch the locktime off")
    }

    // MARK: Reading locks back

    func testLocktimeFromWitnessScript() {
        // <locktime> OP_CHECKLOCKTIMEVERIFY OP_DROP …, the locktime as a little-endian number.
        XCTAssertEqual(WalletLogic.shared.extractCLTV(fromWitnessScript: "02c800b175"), 200)
        XCTAssertEqual(WalletLogic.shared.extractCLTV(fromWitnessScript: "0480d8db70b175"), date)
        XCTAssertNil(WalletLogic.shared.extractCLTV(fromWitnessScript: "76a914" + String(repeating: "00", count: 20) + "88ac"))
        XCTAssertNil(WalletLogic.shared.extractCLTV(fromWitnessScript: "not hex"))
    }

    func testLocktimeFromDescriptor() {
        XCTAssertEqual(WalletLogic.shared.extractAfterLocktime(from: "wsh(and_v(v:pk(02aa),after(1893456000)))"), date)
        XCTAssertNil(WalletLogic.shared.extractAfterLocktime(from: descriptors().bip84!))
    }

    func testLocktimeFromWalletPolicy() throws {
        // The spending policy BDK reports for a timelocked wallet (JSON).
        let bip84 = descriptors().bip84!
        let locked = try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet(bip84), pubkey: nil, descriptor: bip84,
                                                                     timelock: height, keyIndex: 5)
        let watchOnly = try BitcoinDevKit.Wallet(
            descriptor: BitcoinDevKit.Descriptor(descriptor: locked.descriptor, networkKind: .test),
            changeDescriptor: BitcoinDevKit.Descriptor(descriptor: bip84.replacingOccurrences(of: "/0/*", with: "/1/*"), networkKind: .test),
            network: .regtest,
            persister: Persister.newInMemory())
        let policy = try XCTUnwrap(watchOnly.policies(keychain: .external)).asString()

        XCTAssertEqual(WalletLogic.shared.extractAfterLocktime(from: policy), height, policy)
    }

    // MARK: Is a coin locked?

    func testHeightLockOpensAtItsBlock() {
        // A transaction with locktime N goes in the block after N, so the coin is spendable
        // once the tip reaches N.
        XCTAssertTrue(coin(locked: "after(200)", tip: 199).isTimelocked)
        XCTAssertFalse(coin(locked: "after(200)", tip: 200).isTimelocked)
    }

    func testDateLockOpensWhenMedianTimePassesIt() {
        // Checked against the median time of the last 11 blocks (BIP113), not the clock.
        XCTAssertTrue(coin(locked: "after(\(date))", tip: 1000, medianTime: Int(date) - 1).isTimelocked)
        XCTAssertTrue(coin(locked: "after(\(date))", tip: 1000, medianTime: Int(date)).isTimelocked)
        XCTAssertFalse(coin(locked: "after(\(date))", tip: 1000, medianTime: Int(date) + 1).isTimelocked)
    }

    func testRelativeLockCountsConfirmations() {
        XCTAssertTrue(coin(locked: "older(144)", tip: 1000, confirmations: 143).isTimelocked)
        XCTAssertFalse(coin(locked: "older(144)", tip: 1000, confirmations: 144).isTimelocked)
    }

    func testLockOnOnlyOnePathDoesntLockTheCoin() {
        // e.g. a recovery key that can only spend after the date, next to keys that always can.
        let desc = "wsh(or_d(pk(02aa),and_v(v:pk(02bb),after(\(date)))))"
        let item = UTXOItem(UTXO(from: ["desc": desc, "confirmations": 1, "txid": "aa", "vout": 0, "amount": 0.1]),
                            tip: UTXOChainTip(height: 1000, medianTime: 0))
        XCTAssertEqual(item.traits.timelock?.isAlternativePath, true)
        XCTAssertFalse(item.isTimelocked)
    }

    func testUnknownTipIsNotShownAsLocked() {
        let item = UTXOItem(UTXO(from: ["desc": "wsh(and_v(v:pk(02aa),after(200)))", "confirmations": 1, "txid": "aa", "vout": 0, "amount": 0.1]), tip: nil)
        XCTAssertFalse(item.isTimelocked)
        if case .unknown = item.timelockState {} else { XCTFail("expected unknown, got \(String(describing: item.timelockState))") }
    }

    // MARK: Helpers

    private func descriptors() -> (bip84: String?, bip86: String?, segwitCosigner: String?, taprootCosigner: String?, errorMess: String?) {
        Keys.descriptorsFromSigner(signer: Vectors.words, passphrase: nil)
    }

    private func wallet(_ receive: String) -> FullyNoded.Wallet {
        FullyNoded.Wallet(dictionary: ["receiveDescriptor": receive, "changeDescriptor": receive.replacingOccurrences(of: "/0/*", with: "/1/*")])
    }

    private func address(of descriptor: String) throws -> String {
        try BitcoinDevKit.Descriptor(descriptor: descriptor, networkKind: .test).deriveAddress(index: 0, network: .regtest).description
    }

    private func coin(locked fragment: String, tip: Int, medianTime: Int = 0, confirmations: Int = 1) -> UTXOItem {
        let utxo = UTXO(from: ["desc": "wsh(and_v(v:pk(02aa),\(fragment)))", "confirmations": confirmations,
                               "txid": "aa", "vout": 0, "amount": 0.1])
        return UTXOItem(utxo, tip: UTXOChainTip(height: tip, medianTime: medianTime))
    }

    /// One cosigner of a BIP48 (m/48'/1'/0'/2') multisig: its account key with origin, and its
    /// key at receive index 3.
    private func cosigner(_ words: String) throws -> (account: String, originAt3: String, pubkeyAt3: String) {
        let master = try XCTUnwrap(Keys.masterKey(words: words, coinType: "1", passphrase: ""))
        let fingerprint = try XCTUnwrap(Keys.fingerprint(masterKey: master))
        let accountXpub = try XCTUnwrap(Keys.xpub(path: "m/48h/1h/0h/2h", masterKey: master))
        let childXpub = try XCTUnwrap(Keys.xpub(path: "m/48h/1h/0h/2h/0/3", masterKey: master))
        let pubkey = try XCTUnwrap(Keys.extendedKeyPayload(childXpub)?.key.hexString)
        return ("[\(fingerprint)/48h/1h/0h/2h]\(accountXpub)", "[\(fingerprint)/48h/1h/0h/2h/0/3]", pubkey)
    }

    /// A legacy-format transaction with one made-up input and one output paying `script`.
    private static func transaction(paying script: Data, sats: UInt64) -> Data {
        var tx = Data([2, 0, 0, 0])                                     // version 2
        tx += [1] + Data(repeating: 0x11, count: 32) + [0, 0, 0, 0]     // 1 input: txid, vout 0
        tx += [0] + [0xff, 0xff, 0xff, 0xff]                            // empty scriptSig, sequence
        tx += [1] + withUnsafeBytes(of: sats.littleEndian) { Data($0) } // 1 output: amount
        tx += [UInt8(script.count)] + script                            // its script
        tx += [0, 0, 0, 0]                                              // locktime 0
        return tx
    }
}
