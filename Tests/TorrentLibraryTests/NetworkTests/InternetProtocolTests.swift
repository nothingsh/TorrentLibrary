//
//  InternetProtocolTests.swift
//  
//
//  Created by Wynn Zhang on 8/19/23.
//

import XCTest
@testable import TorrentLibrary

final class InternetProtocolTests: XCTestCase {
    func test_canDecodeIPv4AddressFromData() {
        let data = Data([16,2,122,105,127,0,0,1,0,0,0,0,0,0,0,0])
        let result = InternetHelper.parseSocketIPAddress(from: data)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, "127.0.0.1")
    }
    
    func test_canDecodeSocketPortFromData() {
        let data = Data([16,2,122,105,127,0,0,1,0,0,0,0,0,0,0,0])
        let result = InternetHelper.parseSocketPort(from: data)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, 27002)
    }
}
