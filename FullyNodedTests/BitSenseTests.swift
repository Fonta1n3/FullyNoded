//
//  BitSenseTests.swift
//  BitSenseTests
//
//  Created by Peter on 27/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import XCTest
@testable import BitSense

class BitSenseTests: XCTestCase {
    
    var sut:TorClient!

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        super.setUp()
        print("setup")
        sut = TorClient()
        sut.start(completion: getResult)
        
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        print("tearDown")
        sut = nil
        super.tearDown()
    }
    
    func getResult() {
        
        print("getResult")
        
    }

//    func testExample() {
//        // This is an example of a functional test case.
//        // Use XCTAssert and related functions to verify your tests produce the correct results.
//        print("testExample")
//    }
//
//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        print("testPerformanceExample")
//        measure {
//            // Put the code you want to measure the time of here.
//        }
//    }

}
