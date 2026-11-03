//
//  WalletRecoveryTests.swift
//  FullyNodedTests
//
//  Getting a wallet back after the app or the node lost it: from its seed words, its
//  descriptor or a Fully Noded wallet backup. A recovery must give the same descriptors, find
//  the node wallet it had before, and import everything (including timelocked addresses).
//

import XCTest
@testable import FullyNoded

final class WalletRecoveryTests: KeyTestCase {

    private var receive: String { Keys.descriptorsFromSigner(signer: Vectors.words, passphrase: nil).bip84! }
    private var change: String { receive.replacingOccurrences(of: "/0/*", with: "/1/*") }

    // MARK: From seed words

    func testSameWordsRecoverTheSameWallet() {
        let first = Keys.descriptorsFromSigner(signer: Vectors.words, passphrase: nil)
        let again = Keys.descriptorsFromSigner(signer: Vectors.words, passphrase: nil)
        XCTAssertEqual(first.bip84, again.bip84)
        XCTAssertEqual(first.bip86, again.bip86)
        XCTAssertEqual(first.segwitCosigner, again.segwitCosigner)
        XCTAssertEqual(first.taprootCosigner, again.taprootCosigner)
    }

    func testPassphraseRecoversADifferentWallet() {
        let withPassphrase = Keys.descriptorsFromSigner(signer: Vectors.words, passphrase: "TREZOR").bip84!
        XCTAssertNotEqual(ImportWallet.walletName(receiveDescriptor: withPassphrase), ImportWallet.walletName(receiveDescriptor: receive))
    }

    func testSeedWordsAreNotMistakenForADescriptor() throws {
        // Seeds starting "short…", "shift…", "trash…" must be offered as seeds, not read as
        // sh() / tr() descriptors.
        for firstWord in ["short", "shift", "trash", "wrap"] {
            let first11 = [firstWord] + Array(repeating: "abandon", count: 10)
            let words = (first11 + [try XCTUnwrap(Keys.checksumWords(for: first11).first)]).joined(separator: " ")
            XCTAssertTrue(Keys.validMnemonic(words), words)
            XCTAssertFalse(CreateFullyNodedWalletViewController.isDescriptor(words), words)
        }
        for descriptor in [receive, "sh(wpkh(02aa))", "tr(02aa)", "wsh(sortedmulti(1,02aa))", "addr(bcrt1qxyz)"] {
            XCTAssertTrue(CreateFullyNodedWalletViewController.isDescriptor(descriptor.lowercased()), descriptor)
        }
    }

    // MARK: Finding the node wallet again

    func testWalletNameIsTheHashOfTheDescriptor() {
        let name = ImportWallet.walletName(receiveDescriptor: receive)
        XCTAssertEqual(name, "FullyNoded-" + Crypto.sha256hash(receive))
        XCTAssertEqual(name.count, "FullyNoded-".count + 64)
    }

    func testWalletNameIgnoresChecksumAndHardenedNotation() {
        // Core prints hardened steps as h (Core 26+) or ' (older), with a checksum.
        let apostrophes = receive.replacingOccurrences(of: "/84h/0h/0h]", with: "/84'/0'/0']")
        XCTAssertNotEqual(apostrophes, receive)

        let name = ImportWallet.walletName(receiveDescriptor: receive)
        XCTAssertEqual(ImportWallet.walletName(receiveDescriptor: receive + "#8yfp4rgf"), name)
        XCTAssertEqual(ImportWallet.walletName(receiveDescriptor: apostrophes), name)
        XCTAssertEqual(ImportWallet.walletName(receiveDescriptor: apostrophes + "#gw24h6wl"), name)
    }

    func testRecoveryFindsTheExistingNodeWallet() {
        let name = ImportWallet.walletName(receiveDescriptor: ImportWallet.normalizedDescriptor(receive))
        let hash = String(name.dropFirst("FullyNoded-".count))

        // listwalletdir after the app was deleted but the node kept the wallet: it's reused.
        var found: String?
        ImportWallet.parseWallets(["miner", name, "FullyNoded-0000"], hash) { found = $0 }
        XCTAssertEqual(found, name)

        // After the node lost it too: none, so a new one is created.
        found = "unset"
        ImportWallet.parseWallets(["miner", "FullyNoded-0000"], hash) { found = $0 }
        XCTAssertNil(found)
    }

    func testMultisigKeyOrderDoesntChangeTheWallet() {
        let a = cosignerKey(Vectors.words)
        let b = cosignerKey("legal winner thank year wave sausage worth useful legal winner thank yellow")
        let ab = ImportWallet.normalizedDescriptor("wsh(sortedmulti(2,\(a),\(b)))")
        let ba = ImportWallet.normalizedDescriptor("wsh(sortedmulti(2,\(b),\(a)))")
        XCTAssertEqual(ab, ba)
        XCTAssertEqual(ImportWallet.walletName(receiveDescriptor: ab), ImportWallet.walletName(receiveDescriptor: ba))
    }

    func testAccountMapExportRecoversTheSameWallet() throws {
        let wallet = Wallet(dictionary: ["receiveDescriptor": receive + "#8yfp4rgf", "changeDescriptor": change, "label": "Spending"])
        let json = try XCTUnwrap(CreateAccountMap.create(wallet: wallet))
        let accountMap = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])

        XCTAssertEqual(accountMap["label"] as? String, "Spending")
        let descriptor = try XCTUnwrap(accountMap["descriptor"] as? String)
        XCTAssertEqual(ImportWallet.walletName(receiveDescriptor: ImportWallet.normalizedDescriptor(descriptor)),
                       ImportWallet.walletName(receiveDescriptor: wallet.receiveDescriptor))
    }

    // MARK: From a Fully Noded wallet backup

    func testBackupSurvivesExportAndImport() throws {
        let backup = try backupFromNode()
        let hex = try backup.hexEncoded()

        let restored = try XCTUnwrap(WalletBackup.decode(hex: hex))
        XCTAssertEqual(restored.descriptors.map(\.desc), backup.descriptors.map(\.desc))
        XCTAssertEqual(restored.lastUpdate.timeIntervalSince1970, backup.lastUpdate.timeIntervalSince1970, accuracy: 0.001)

        // A pasted or scanned copy can be wrapped and upper case.
        let wrapped = stride(from: 0, to: hex.count, by: 64).map { i -> String in
            let start = hex.index(hex.startIndex, offsetBy: i)
            return String(hex[start..<(hex.index(start, offsetBy: 64, limitedBy: hex.endIndex) ?? hex.endIndex)])
        }.joined(separator: "\n").uppercased()
        XCTAssertNotNil(WalletBackup.decode(hex: wrapped))

        XCTAssertNil(WalletBackup.decode(hex: "not a backup"))
        XCTAssertNil(WalletBackup.decode(hex: "abcd"))
    }

    func testBackupRecoversIntoTheSameNodeWallet() throws {
        let pair = try XCTUnwrap(try backupFromNode().walletDescriptors())
        XCTAssertEqual(pair.change.components(separatedBy: "#")[0], change)
        XCTAssertEqual(ImportWallet.walletName(receiveDescriptor: pair.receive),
                       ImportWallet.walletName(receiveDescriptor: ImportWallet.normalizedDescriptor(receive)))
    }

    func testBackupPairsReceiveAndChangeOfTheSameType() throws {
        // Core's default wallets have several active types; the change must match the receive.
        let tr = Keys.descriptorsFromSigner(signer: Vectors.words, passphrase: nil).bip86!
        let backup = WalletBackup(descriptors: [
            item(change, internal: true),
            item(tr.replacingOccurrences(of: "/0/*", with: "/1/*"), internal: true),
            item(tr, internal: false),
            item(receive, internal: false),
        ])
        let pair = try XCTUnwrap(backup.walletDescriptors())
        XCTAssertEqual(pair.receive, tr)
        XCTAssertEqual(pair.change, tr.replacingOccurrences(of: "/0/*", with: "/1/*"))
    }

    func testBackupWithoutAReceiveDescriptorCantBeRecovered() {
        let backup = WalletBackup(descriptors: [item(timelockedAddress, internal: nil, ranged: false)])
        XCTAssertNil(backup.walletDescriptors())
    }

    func testOnlyMissingDescriptorsAreImported() throws {
        let backup = try backupFromNode()
        // The node kept the receive descriptor (printed with another checksum).
        let requests = backup.missingImportRequests(existing: [receive + "#00000000"])
        XCTAssertEqual(requests.compactMap { $0["desc"] as? String }.map { $0.components(separatedBy: "#")[0] },
                       [change, timelockedAddress])
        // Nothing missing: nothing to import.
        XCTAssertTrue(backup.missingImportRequests(existing: backup.descriptors.map(\.desc)).isEmpty)
    }

    func testImportRequestsRescanFromTheRightTime() throws {
        let requests = try backupFromNode().missingImportRequests(existing: [])
        let receiveRequest = try XCTUnwrap(requests.first { ($0["desc"] as? String)?.hasPrefix(receive) == true })

        XCTAssertEqual(receiveRequest["timestamp"] as? Int, 1_700_000_000)
        XCTAssertEqual(receiveRequest["range"] as? [Int], [0, 999])
        XCTAssertEqual(receiveRequest["next_index"] as? Int, 7)
        XCTAssertEqual(receiveRequest["internal"] as? Bool, false)
        XCTAssertEqual(receiveRequest["active"] as? Bool, true)

        // No recorded time: rescan from the start rather than risk missing funds.
        let unknownAge = item(receive, internal: false, timestamp: nil).importRequest
        XCTAssertEqual(unknownAge["timestamp"] as? Int, 0)
    }

    func testTimelockedAddressIsRecoveredWithItsLabel() throws {
        let requests = try backupFromNode().missingImportRequests(existing: [])
        let timelock = try XCTUnwrap(requests.first { ($0["desc"] as? String)?.hasPrefix(timelockedAddress) == true })

        // Core doesn't return labels, so it's rebuilt from after(N). Core refuses a label
        // together with internal=false here, so "internal" is left out.
        XCTAssertEqual(timelock["label"] as? String, "Locked until \(Date(timeIntervalSince1970: 1_893_456_000).dateDisplay)")
        XCTAssertNil(timelock["internal"])
        XCTAssertNil(timelock["range"])
    }

    func testOnlyDateLocksGetALockLabel() {
        XCTAssertNotNil(BackupItem.timelockLabel(for: timelockedAddress, ranged: false))
        XCTAssertNil(BackupItem.timelockLabel(for: "wsh(and_v(v:pk(02aa),after(800000)))", ranged: false)) // block height
        XCTAssertNil(BackupItem.timelockLabel(for: receive, ranged: true))
    }

    func testBirthdayIsTheOldestDescriptor() throws {
        XCTAssertEqual(try backupFromNode().birthday, 1_600_000_000)
    }

    // MARK: Helpers

    /// A timelocked address imported on the node (Invoice screen), unlocking Jan 1, 2030.
    private let timelockedAddress = "wsh(and_v(v:pk([73c5da0a/84h/1h/0h]tpubDC8msFGeGuwnKG9Upg7DM2b4DaRqg3CUZa5g8v2SRQ6K4NSkxUgd7HsL2XVWbVm39yBA4LAxysQAm397zwQSQoQgewGiYZqrA9DsP4zbQ1M/0/5),after(1893456000)))"

    /// A backup made the way the wallet screen makes it: from the node's listdescriptors reply.
    private func backupFromNode() throws -> WalletBackup {
        let reply: [String: Any] = [
            "wallet_name": ImportWallet.walletName(receiveDescriptor: receive),
            "descriptors": [
                ["desc": receive + "#8yfp4rgf", "timestamp": 1_700_000_000, "active": true, "internal": false, "range": [0, 999], "next_index": 7],
                ["desc": change + "#qy2zxcsk", "timestamp": 1_700_000_000, "active": true, "internal": true, "range": [0, 999], "next_index": 2],
                ["desc": timelockedAddress + "#5n0d7ft4", "timestamp": 1_600_000_000, "active": false],
            ],
        ]
        let listed = try JSONDecoder().decode(ListDescriptorsResponse.self, from: JSONSerialization.data(withJSONObject: reply))
        return WalletBackup(descriptors: listed.descriptors.map(BackupItem.init(listed:)))
    }

    private func item(_ desc: String, internal isInternal: Bool?, ranged: Bool = true, timestamp: Int? = 1_700_000_000) -> BackupItem {
        BackupItem(desc: desc, active: ranged, range: ranged ? [0, 999] : nil, nextIndex: 0,
                   timestamp: timestamp, internal: isInternal, label: nil)
    }

    /// "[fingerprint/48h/1h/0h/2h]tpub…/0/*": a BIP48 multisig cosigner key.
    private func cosignerKey(_ words: String) -> String {
        let cosigner = Keys.descriptorsFromSigner(signer: words, passphrase: nil).segwitCosigner!
        return String(cosigner.dropFirst("wsh(".count).dropLast())
    }
}
