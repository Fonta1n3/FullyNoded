//
//  AddressTests.swift
//  AddressTests
//
//  Created by Bitcoin Dev on 14/06/2019.
//  Copyright © 2019 Blockchain. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md

import XCTest
@testable import LibWally

class AddressTests: XCTestCase {
    let hdKey = HDKey("xpub6ASuArnXKPbfEwhqN6e3mwBcDTgzisQN1wXN9BJcM47sSikHjJf3UFHKkNAWbWMiGj7Wf5uMash7SyYq527Hqck2AxYysAA7xmALppuCkwQ")!
    let hdKeyTestnet = HDKey("tpubDDgEAMpHn8tX5Bs19WWJLZBeFzbpE7BYuP3Qo71abZnQ7FmN3idRPg4oPWt2Q6Uf9huGv7AGMTu8M2BaCxAdThQArjLWLDLpxVX2gYfh2YJ")!


    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDeriveLegacyAddress() {
        let address = hdKey.address(.payToPubKeyHash)
        XCTAssertEqual(address.description, "1JQheacLPdM5ySCkrZkV66G2ApAXe1mqLj")
    }

    func testDeriveLegacyAddressTestnet() {
        let address = hdKeyTestnet.address(.payToPubKeyHash)
        XCTAssertEqual(address.description, "mnicNaAVzyGdFvDa9VkMrjgNdnr2wHBWxk")
    }

    
    func testDeriveWrappedSegWitAddress() {
        let address = hdKey.address(.payToScriptHashPayToWitnessPubKeyHash)
        XCTAssertEqual(address.description, "3DymAvEWH38HuzHZ3VwLus673bNZnYwNXu")
    }
    
    func testDeriveWrappedSegWitAddressTestnet() {
        let address = hdKeyTestnet.address(.payToScriptHashPayToWitnessPubKeyHash)
        XCTAssertEqual(address.description, "2N6M3ah9EoggimNz5pnAmQwnpE1Z3ya3V7A")
    }
    
    
    func testDeriveNativeSegWitAddress() {
        let address = hdKey.address(.payToWitnessPubKeyHash)
        XCTAssertEqual(address.description, "bc1qhm6697d9d2224vfyt8mj4kw03ncec7a7fdafvt")
    }
    
    func testDeriveNativeSegWitAddressTestnet() {
        let address = hdKeyTestnet.address(.payToWitnessPubKeyHash)
        XCTAssertEqual(address.description, "tb1qfm7nmm28m9n7gy3fsfpze8vymds9qwtjwn4w7y")
    }
    
    func testParseLegacyAddress() {
        let address = Address("1JQheacLPdM5ySCkrZkV66G2ApAXe1mqLj")
        XCTAssertNotNil(address)
        XCTAssertEqual(address!.scriptPubKey, ScriptPubKey("76a914bef5a2f9a56a94aab12459f72ad9cf8cf19c7bbe88ac"))
    }
    
    func testParseWrappedSegWitAddress() {
        let address = Address("3DymAvEWH38HuzHZ3VwLus673bNZnYwNXu")
        XCTAssertNotNil(address)
        XCTAssertEqual(address!.scriptPubKey, ScriptPubKey("a91486cc442a97817c245ce90ed0d31d6dbcde3841f987"))
    }
    
    func testParseNativeSegWitAddress() {
        let address = Address("bc1qhm6697d9d2224vfyt8mj4kw03ncec7a7fdafvt")
        XCTAssertNotNil(address)
        XCTAssertEqual(address!.scriptPubKey, ScriptPubKey("0014bef5a2f9a56a94aab12459f72ad9cf8cf19c7bbe"))
    }
    
    func testParseWIF() {
        // https://en.bitcoin.it/wiki/Wallet_import_format
        let wif = "5HueCGU8rMjxEXxiPuD5BDku4MkFqeZyd4dZ1jvhTVqvbTLvyTJ"
        if let key = Key(wif, .mainnet, compressed: false) {
            XCTAssertEqual(key.data.hexString, "0c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d")
            XCTAssertEqual(key.network, .mainnet)
            XCTAssertEqual(key.compressed, false)
        } else { XCTFail() }

    }

    func testToWIF() {
        // https://en.bitcoin.it/wiki/Wallet_import_format
        let data = Data("0c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d")
        let key = Key(data!, .mainnet, compressed: false)
        XCTAssertNotNil(key)
        XCTAssertEqual(key!.wif, "5HueCGU8rMjxEXxiPuD5BDku4MkFqeZyd4dZ1jvhTVqvbTLvyTJ")
    }

}
