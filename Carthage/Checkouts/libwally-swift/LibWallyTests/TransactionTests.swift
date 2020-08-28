//
//  TransactionTests.swift
//  TransactionTests
//
//  Created by Sjors Provoost on 18/06/2019.
//  Copyright © 2019 Blockchain. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md

import XCTest
@testable import LibWally

class TransactionTests: XCTestCase {
    let scriptPubKey = ScriptPubKey("76a914bef5a2f9a56a94aab12459f72ad9cf8cf19c7bbe88ac")!
    let pubKey = PubKey(Data("03501e454bf00751f24b1b489aa925215d66af2234e3891c3b21a52bedb3cd711c")!, .mainnet)!

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testFromHash() {
        let hash = ("0000000000000000000000000000000000000000000000000000000000000000")
        let tx = Transaction(hash)
        XCTAssertNotNil(tx)
        XCTAssertEqual(tx?.hash?.hexString, hash)

        XCTAssertNil(Transaction("00")) // Wrong length
    }

    func testOutput() {
        let output = TxOutput(scriptPubKey, 1000, .mainnet)
        XCTAssertNotNil(output)
        XCTAssertEqual(output.amount, 1000)
        XCTAssertEqual(output.scriptPubKey, scriptPubKey)
    }

    func testInput() {
        let tx = Transaction("0000000000000000000000000000000000000000000000000000000000000000")!
        let vout = UInt32(0)
        let amount: Satoshi = 1000
        let scriptSig = ScriptSig(.payToPubKeyHash(pubKey))

        let input = TxInput(tx, vout, amount, scriptSig, nil, scriptPubKey)
        XCTAssertNotNil(input)
        XCTAssertEqual(input?.transaction.hash, tx.hash)
        XCTAssertEqual(input?.vout, 0)
        XCTAssertEqual(input?.sequence, 0xFFFFFFFF)
        XCTAssertEqual(input?.scriptSig, scriptSig)
        XCTAssertEqual(input?.signed, false)
    }

    func testComposeTransaction() {
        // Input
        let prevTx = Transaction("0000000000000000000000000000000000000000000000000000000000000000")!
        let vout = UInt32(0)
        let amount: Satoshi = 1000
        let scriptSig = ScriptSig(.payToPubKeyHash(pubKey))
        let txInput = TxInput(prevTx, vout, amount, scriptSig, nil, scriptPubKey)!

        // Output:
        let txOutput = TxOutput(scriptPubKey, 1000, .mainnet)

        // Transaction
        let tx = Transaction([txInput], [txOutput])
        XCTAssertNil(tx.hash)
        XCTAssertEqual(tx.wally_tx?.pointee.version, 1)
        XCTAssertEqual(tx.wally_tx?.pointee.num_inputs, 1)
        XCTAssertEqual(tx.wally_tx?.pointee.num_outputs, 1)
    }
    
    func testDeserialize() {
        let hex = "01000000010000000000000000000000000000000000000000000000000000000000000000000000006a47304402203d274300310c06582d0186fc197106120c4838fa5d686fe3aa0478033c35b97802205379758b11b869ede2f5ab13a738493a93571268d66b2a875ae148625bd20578012103501e454bf00751f24b1b489aa925215d66af2234e3891c3b21a52bedb3cd711cffffffff01e8030000000000001976a914bef5a2f9a56a94aab12459f72ad9cf8cf19c7bbe88ac00000000"
        let tx = Transaction(hex)
        XCTAssertEqual(tx?.description, hex)
    }
    
}

class TransactionInstanceTests: XCTestCase {
    let legacyInputBytes: Int = 192
    let nativeSegWitInputBytes: Int = 113
    let wrappedSegWitInputBytes: Int = 136
    
    // From: legacy P2PKH address 1JQheacLPdM5ySCkrZkV66G2ApAXe1mqLj
    // To: legacy P2PKH address 1JQheacLPdM5ySCkrZkV66G2ApAXe1mqLj
    let scriptPubKey1 = ScriptPubKey("76a914bef5a2f9a56a94aab12459f72ad9cf8cf19c7bbe88ac")!
    let pubKey = PubKey(Data("03501e454bf00751f24b1b489aa925215d66af2234e3891c3b21a52bedb3cd711c")!, .mainnet)!
    var tx1: Transaction? = nil
    var tx2: Transaction? = nil
    var tx3: Transaction? = nil
    var hdKey: HDKey? = nil // private key for signing
    
    override func setUp() {
        // Input (legacy P2PKH)
        let prevTx = Transaction("0000000000000000000000000000000000000000000000000000000000000000")!
        let vout = UInt32(0)
        let amount1: Satoshi = 1000 + Satoshi(legacyInputBytes)
        let scriptSig = ScriptSig(.payToPubKeyHash(pubKey))
        let txInput1 = TxInput(prevTx, vout, amount1, scriptSig, nil, scriptPubKey1)!

        // Input (native SegWit)
        let witness = Witness(.payToWitnessPubKeyHash(pubKey))
        let amount2: Satoshi = 1000 + Satoshi(nativeSegWitInputBytes)
        let scriptPubKey2 = ScriptPubKey("0014bef5a2f9a56a94aab12459f72ad9cf8cf19c7bbe")!
        let txInput2 = TxInput(prevTx, vout, amount2, nil, witness, scriptPubKey2)!

        // Input (wrapped SegWit)
        let witness3 = Witness(.payToScriptHashPayToWitnessPubKeyHash(pubKey))
        let amount3: Satoshi = 1000 + Satoshi(wrappedSegWitInputBytes)
        let scriptPubKey3 = ScriptPubKey("a91486cc442a97817c245ce90ed0d31d6dbcde3841f987")!
        let txInput3 = TxInput(prevTx, vout, amount3, nil, witness3, scriptPubKey3)!
        
        // Output:
        let txOutput = TxOutput(scriptPubKey1, 1000, .mainnet)
        
        // Transaction spending legacy
        tx1 = Transaction([txInput1], [txOutput])
        
        // Transaction spending native SegWit
        tx2 = Transaction([txInput2], [txOutput])
        
        // Transaction spending wrapped SegWit
        tx3 = Transaction([txInput3], [txOutput])
        
        // Corresponding private key
       hdKey = HDKey("xprv9wTYmMFdV23N2TdNG573QoEsfRrWKQgWeibmLntzniatZvR9BmLnvSxqu53Kw1UmYPxLgboyZQaXwTCg8MSY3H2EU4pWcQDnRnrVA1xe8fs")!
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testTotalIn() {
        XCTAssertEqual(tx1?.totalIn, 1000 + Satoshi(legacyInputBytes))
        XCTAssertEqual(tx2?.totalIn, 1000 + Satoshi(nativeSegWitInputBytes))
        XCTAssertEqual(tx3?.totalIn, 1000 + Satoshi(wrappedSegWitInputBytes))
        
        let tx4 = Transaction("0000000000000000000000000000000000000000000000000000000000000000")
        XCTAssertNil(tx4?.totalIn)
        
    }
    
    func testTotalOut() {
        XCTAssertEqual(tx1?.totalOut, 1000)
        
        let tx2 = Transaction("0000000000000000000000000000000000000000000000000000000000000000")
        XCTAssertNil(tx2?.totalOut)

    }
    
    func testFunded() {
        XCTAssertEqual(tx1?.funded, true)
    }
    
    func testSize() {
        XCTAssertEqual(tx1?.vbytes, legacyInputBytes)
        XCTAssertEqual(tx2?.vbytes, nativeSegWitInputBytes)
        XCTAssertEqual(tx3?.vbytes, wrappedSegWitInputBytes)

        let tx4 = Transaction("0000000000000000000000000000000000000000000000000000000000000000")
        XCTAssertNil(tx4?.vbytes)
        
    }
    
    func testFee() {
        XCTAssertEqual(tx1?.fee, Satoshi(legacyInputBytes))
    }
    
    func testFeeRate() {
        XCTAssertEqual(tx1?.feeRate, 1.0)
        XCTAssertEqual(tx2?.feeRate, 1.0)
        XCTAssertEqual(tx3?.feeRate, 1.0)
    }
    
    func testSign() {
        XCTAssertTrue(tx1!.sign([hdKey!]))
        XCTAssertEqual(tx1!.inputs?[0].signed, true)
        XCTAssertEqual(tx1!.description, "01000000010000000000000000000000000000000000000000000000000000000000000000000000006a47304402203d274300310c06582d0186fc197106120c4838fa5d686fe3aa0478033c35b97802205379758b11b869ede2f5ab13a738493a93571268d66b2a875ae148625bd20578012103501e454bf00751f24b1b489aa925215d66af2234e3891c3b21a52bedb3cd711cffffffff01e8030000000000001976a914bef5a2f9a56a94aab12459f72ad9cf8cf19c7bbe88ac00000000")
        
        XCTAssertEqual(tx1!.vbytes, legacyInputBytes - 1)
    }
    
    func testSignNativeSegWit() {
        XCTAssertTrue(tx2!.sign([hdKey!]))
        XCTAssertEqual(tx2!.inputs?[0].signed, true)
        XCTAssertEqual(tx2!.description, "0100000000010100000000000000000000000000000000000000000000000000000000000000000000000000ffffffff01e8030000000000001976a914bef5a2f9a56a94aab12459f72ad9cf8cf19c7bbe88ac0247304402204094361e267c39fb942b3d30c6efb96de32ea0f81e87fc36c53e00de2c24555c022069f368ac9cacea21be7b5e7a7c1dad01aa244e437161d000408343a4d6f5da0e012103501e454bf00751f24b1b489aa925215d66af2234e3891c3b21a52bedb3cd711c00000000")
        XCTAssertEqual(tx2!.vbytes, nativeSegWitInputBytes)
    }

    func testSignWrappedSegWit() {
        XCTAssertTrue(tx3!.sign([hdKey!]))
        XCTAssertEqual(tx3!.inputs?[0].signed, true)
        XCTAssertEqual(tx3!.description, "0100000000010100000000000000000000000000000000000000000000000000000000000000000000000017160014bef5a2f9a56a94aab12459f72ad9cf8cf19c7bbeffffffff01e8030000000000001976a914bef5a2f9a56a94aab12459f72ad9cf8cf19c7bbe88ac024730440220514e02e6d4aff5e1bfcf72a98eab3a415176c757e2bf6feb7ccb893f8ffcf09b022048fe33e6a1dc80585f30aac20f58442d711739ac07d192a3a7867a1dbef6b38d012103501e454bf00751f24b1b489aa925215d66af2234e3891c3b21a52bedb3cd711c00000000")
        XCTAssertEqual(tx3!.vbytes, wrappedSegWitInputBytes)
    }

}
