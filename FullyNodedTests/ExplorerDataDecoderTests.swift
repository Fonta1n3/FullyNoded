//
//  ExplorerDataDecoderTests.swift
//  FullyNodedTests
//
//  Scripts marked "mainnet" are from block 974,887. Omni and Counterparty are built here, since
//  that block had none.
//

import XCTest
@testable import FullyNoded

final class ExplorerDataDecoderTests: XCTestCase {
    private func bytes(_ hex: String) -> [UInt8] { [UInt8](Hex.decode(hex)!) }

    private func decode(_ hex: String, txid: String? = nil) -> ExplorerEmbeddedData {
        ExplorerEmbeddedData.decodeOpReturn(bytes(hex), output: 0, firstInputTxid: txid)
    }

    private func value(_ item: ExplorerEmbeddedData?, _ title: String) -> String? {
        item?.details.first { $0.title == title }?.value
    }

    func testMainnetRunestoneWithProtostones() {
        let item = decode("6a5d1f1600ff7f818ceca2d08bc0a88281d29590c0c12dff7fdd80c492c8d3f4d710")
        XCTAssertEqual(item.name, "Runes")
        XCTAssertEqual(value(item, "Extra data"), "Protostones (Alkanes style)")
    }

    func testRuneNames() {
        XCTAssertEqual(Runestone.name(.init(low: 0)), "A")
        XCTAssertEqual(Runestone.name(.init(low: 25)), "Z")
        XCTAssertEqual(Runestone.name(.init(low: 26)), "AA")
        XCTAssertEqual(Runestone.name(.init(low: 27)), "AB")
        XCTAssertEqual(Runestone.name(.init(low: 26), spacers: 1), "A•A")
    }

    func testEtchingMintAndTransfers() {
        // Etching tag 4 = 27, then mint tags, then one four-number edict.
        var payload: [UInt8] = [4, 27, 20, 0xC0, 0x84, 0x3D, 20, 5, 0, 1, 2, 3, 4]
        var item = Runestone.details(payload)
        XCTAssertTrue(item.contains(.init("Etching", "AB")))
        XCTAssertTrue(item.contains(.init("Mint", "1000000:5")))
        XCTAssertTrue(item.contains(.init("Transfers", "1")))
        // Cut off in the middle of a number.
        payload = [4, 0x80]
        item = Runestone.details(payload)
        XCTAssertEqual(item, [.init("Status", "Malformed runestone")])
    }

    func testLargeRuneValuesKeep128Bits() {
        // 2^64: nine 0x80 bytes, then 2.
        let values = Runestone.varints([0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x02])
        XCTAssertEqual(values?.first?.high, 1)
        XCTAssertEqual(values?.first?.low, 0)
        XCTAssertEqual(values?.first?.decimal, "18446744073709551616")
    }

    func testMainnetTagsAndMemos() {
        XCTAssertEqual(decode("6a24aa21a9ed6cd61eb0f0bc015f206cd61eb0f0bc015f206cd61eb0f0bc015f206cd61eb000").name, "Witness commitment")
        XCTAssertEqual(decode("6a2952534b424c4f434b3a606dbeda209d005e5eae0280761b03e204eea4f32ceab24d8389b31d008f4a9d").name, "Rootstock merged mining")
        XCTAssertEqual(decode("6a2d434f52450164db24a662e20bbdf72d1cc6e973dbb2d12897d56a931d9de30a5f313a566775a135cf47d40c0ccd").name, "Core chain tag")
        let stacks = decode("6a4c5058325b020fb5de7aa592824834063f9d60696a2aa24b3d39a6bfc5e79c12732712351ebba43305577409043b59789b000000000000000000000000000000000000000000000000000000000000000000")
        XCTAssertEqual(stacks.name, "Stacks")
        XCTAssertEqual(value(stacks, "Operation"), "Block commit")
        XCTAssertEqual(decode("6a0a" + Hex.encode(Array("=:ETH.ETH:".utf8))).name, "Cross-chain swap memo")
    }

    func testPlainTextAndBinary() {
        let text = decode("6a05" + Hex.encode(Array("hello".utf8)))
        XCTAssertEqual(text.name, "OP_RETURN text")
        XCTAssertEqual(value(text, "Text"), "hello")
        XCTAssertEqual(decode("6a20c5ce53cc654afd707bd212db8c006bb549745083b250770ce03d4ee9bec7f048").name, "Unrecognised OP_RETURN")
        XCTAssertEqual(decode("6a").name, "Empty OP_RETURN")
    }

    func testHiddenCharactersAreRemovedFromText() {
        // A right-to-left override among ordinary text.
        let text = ExplorerEmbeddedData.cleanText(Array("pay\u{202E}moc.live here please".utf8))
        XCTAssertEqual(text, "paymoc.live here please")
        XCTAssertNil(ExplorerEmbeddedData.cleanText([0x01, 0x02, 0x03, 0x04]))
        let long = String(repeating: "a", count: ExplorerEmbeddedData.maxText + 50)
        XCTAssertEqual(ExplorerEmbeddedData.cleanText(Array(long.utf8))?.count, ExplorerEmbeddedData.maxText + 1)
    }

    func testOmniUSDT() {
        // 25 USDT.
        let data = "6f6d6e69" + "0000" + "0000" + "0000001f" + "000000009502f900"
        let item = decode("6a14" + data)
        XCTAssertEqual(item.name, "Omni Layer")
        XCTAssertEqual(value(item, "Simple send"), "25.00000000 USDT")
    }

    func testCounterpartyIsDecryptedWithTheFirstInputsTxid() {
        let txid = String(repeating: "ab", count: 32)
        let key = bytes(txid)
        let cipher = ExplorerEmbeddedData.rc4(Array("CNTRPRTY".utf8) + [30, 1, 2, 3], key: key)
        let item = decode("6a0c" + Hex.encode(cipher), txid: txid)
        XCTAssertEqual(item.name, "Counterparty")
        XCTAssertEqual(value(item, "Message"), "Broadcast")
        // RC4 is its own inverse, against a published test vector ("Key", "Plaintext").
        XCTAssertEqual(Hex.encode(ExplorerEmbeddedData.rc4(Array("Plaintext".utf8), key: Array("Key".utf8))), "bbf316e8d940af0ad3")
    }

    func testStampInBareMultisig() {
        let txid = String(repeating: "cd", count: 32)
        let message = Array("CNTRPRTY".utf8) + [20] + Array("stamp:hello".utf8)
        var plain = [UInt8(message.count)] + message
        plain += [UInt8](repeating: 0, count: 62 - plain.count)
        let cipher = ExplorerEmbeddedData.rc4(plain, key: bytes(txid))
        let key1 = [0x02] + cipher[0..<31] + [0x00]
        let key2 = [0x03] + cipher[31..<62] + [0x00]
        let real = [UInt8](repeating: 0x02, count: 33)
        let script: [UInt8] = [0x51, 0x21] + key1 + [0x21] + key2 + [0x21] + real + [0x53, 0xAE]
        let item = ExplorerEmbeddedData.decodeBareMultisig(script, output: 1, firstInputTxid: txid)
        XCTAssertEqual(item?.name, "Bitcoin Stamp")
        XCTAssertEqual(value(item, "Carried in"), "Bare multisig keys")
    }

    func testOrdinaryBareMultisigIsNotAccused() {
        let key = [UInt8](repeating: 0x02, count: 33)
        let script: [UInt8] = [0x51, 0x21] + key + [0x21] + key + [0x52, 0xAE]
        let item = ExplorerEmbeddedData.decodeBareMultisig(script, output: 0, firstInputTxid: String(repeating: "00", count: 32))
        XCTAssertEqual(item?.name, "Bare multisig")
    }

    /// As in a mainnet witness: key, OP_CHECKSIG…, then the envelope.
    private func inscription(type: String, body: [UInt8]) -> [UInt8] {
        var script: [UInt8] = bytes("20e8fa1365a752f83c2af2295c86992fb88ba82aaf53ded9b9e2345e93acacda3aac")
        script += [0x00, 0x63, 0x03] + Array("ord".utf8) + [0x01, 0x01, UInt8(type.utf8.count)] + Array(type.utf8) + [0x00]
        script += [UInt8(body.count)] + body + [0x68]
        return script
    }

    func testBRC20Inscription() {
        let json = #"{"p":"brc-20","op":"mint","tick":"ordi","amt":"1000"}"#
        let item = ExplorerEmbeddedData.decodeEnvelopes(inscription(type: "text/plain;charset=utf-8", body: Array(json.utf8)), input: 2)?.first
        XCTAssertEqual(item?.name, "BRC-20")
        XCTAssertEqual(item?.location, .input(2))
        XCTAssertEqual(value(item, "Operation"), "mint")
        XCTAssertEqual(value(item, "Ticker"), "ordi")
        XCTAssertEqual(value(item, "Amount"), "1000")
    }

    func testImagesAreNamedButNotShown() {
        let item = ExplorerEmbeddedData.decodeEnvelopes(inscription(type: "image/png", body: [1, 2, 3]), input: 0)?.first
        XCTAssertEqual(item?.name, "Inscription")
        XCTAssertEqual(value(item, "Type"), "image/png")
        XCTAssertEqual(item?.size, 3)
        XCTAssertNotNil(value(item, "Content"))
    }

    func testMalformedDataNeverCrashes() {
        // A push claiming more than there is, at every length of a truncated script.
        let script = inscription(type: "text/plain", body: Array("hello".utf8))
        for length in 0...script.count {
            _ = ExplorerEmbeddedData.decodeEnvelopes(Array(script.prefix(length)), input: 0)
            _ = ExplorerEmbeddedData.decodeBareMultisig(Array(script.prefix(length)), output: 0, firstInputTxid: "zz")
        }
        for prefix in ["6a4c", "6a4cff", "6a4d", "6a4dffff00", "6a4effffffff00", "6a5d", "6a5dff", "6a5d4c"] {
            _ = decode(prefix)
        }
        var reader = ScriptReader([0x4E, 0xFF, 0xFF, 0xFF, 0x7F, 0x01])
        XCTAssertNil(reader.next())
    }

    func testDecodeWalksARawTransaction() {
        let raw: [String: Any] = [
            "vin": [["txid": String(repeating: "11", count: 32), "txinwitness": ["00", Hex.encode(inscription(type: "image/gif", body: [9]))]]],
            "vout": [["n": 0, "scriptPubKey": ["type": "nulldata", "hex": "6a0568656c6c6f"]],
                     ["n": 1, "scriptPubKey": ["type": "witness_v0_keyhash", "hex": "0014"]]]
        ]
        let found = ExplorerEmbeddedData.decode(raw: raw)
        XCTAssertEqual(found.map(\.name), ["OP_RETURN text", "Inscription"])
        XCTAssertEqual(found[0].location, .output(0))
    }
}
