//
//  PeerInfoTests.swift
//  FullyNodedTests
//
//  Reading getpeerinfo, and the address setban is given (it refuses one with a port).
//

import XCTest
@testable import FullyNoded

final class PeerInfoTests: XCTestCase {

    func testHostDropsThePort() {
        XCTAssertEqual(PeerInfo.host(of: "1.2.3.4:8333"), "1.2.3.4")
        XCTAssertEqual(PeerInfo.host(of: "[2001:db8::1]:8333"), "2001:db8::1")
        XCTAssertEqual(PeerInfo.host(of: "abcdef.onion:8333"), "abcdef.onion")
    }

    func testHostLeavesAddressesWithoutAPort() {
        XCTAssertEqual(PeerInfo.host(of: "1.2.3.4"), "1.2.3.4")
        XCTAssertEqual(PeerInfo.host(of: "2001:db8::1"), "2001:db8::1")
    }

    func testSetBanGetsTheBareAddress() {
        let param = Set_Ban(dict: ["subnet": "[2001:db8::1]:8333"]).param
        XCTAssertEqual(param["subnet"] as? String, "2001:db8::1")
        XCTAssertEqual(param["command"] as? String, "add")
    }

    func testLocalProxyAddressesAreRecognised() throws {
        XCTAssertTrue(try peer(["addr": "127.0.0.1:50123"]).isLocalAddress)
        XCTAssertTrue(try peer(["addr": "[::1]:50123"]).isLocalAddress)
        XCTAssertFalse(try peer(["addr": "1.2.3.4:8333"]).isLocalAddress)
    }

    func testReadsAFullEntry() throws {
        let info = try peer([
            "id": 7, "addr": "1.2.3.4:8333", "subver": "/Satoshi:32.1.0/", "inbound": false,
            "connection_type": "block-relay-only", "network": "ipv4", "transport_protocol_type": "v2",
            "servicesnames": ["NETWORK", "WITNESS"], "bytessent": 2048, "bytesrecv": 4096,
            "pingtime": 0.042, "conntime": 1_700_000_000, "synced_blocks": 900_000
        ])
        XCTAssertEqual(info.id, 7)
        XCTAssertEqual(info.clientName, "Satoshi:32.1.0")
        XCTAssertEqual(info.networkName, "IPv4")
        XCTAssertEqual(info.connectionName, "Block relay")
        XCTAssertEqual(info.transportName, "Encrypted (BIP324)")
        XCTAssertEqual(info.services, ["NETWORK", "WITNESS"])
        XCTAssertEqual(info.bytesReceived, 4096)
        XCTAssertEqual(info.ping, 0.042)
        XCTAssertEqual(info.syncedBlocks, 900_000)
    }

    /// Core drops fields between releases: an old or sparse entry still reads.
    func testReadsASparseEntry() throws {
        let info = try peer(["addr": "1.2.3.4:8333"])
        XCTAssertNil(info.ping)
        XCTAssertNil(info.transportName)
        XCTAssertEqual(info.services, [])
        XCTAssertEqual(info.clientName, "Unknown client")
    }

    private func peer(_ entry: [String: Any]) throws -> PeerInfo {
        try XCTUnwrap(GetPeerInfoResponse(from: [entry] as NSArray).peers.first)
    }
}
