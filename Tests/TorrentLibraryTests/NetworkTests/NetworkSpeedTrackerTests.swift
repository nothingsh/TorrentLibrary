//
//  NetworkSpeedTrackerTests.swift
//  
//
//  Created by Wynn Zhang on 8/24/23.
//

import XCTest
@testable import TorrentLibrary

final class NetworkSpeedTrackerTests: XCTestCase {
    func test_increaseBytes() {
        var sut = NetworkSpeedTracker()
        sut.increase(by: 10)
        XCTAssertEqual(sut.totalNumberOfBytes, 10)
    }
    
    func test_canGetBytesDownloadedSinceDate() {
        var sut = NetworkSpeedTracker()
        sut.increase(by: 2)
        let date = Date()
        sut.increase(by: 10)
        sut.increase(by: 5)
        XCTAssertEqual(sut.numberOfBytesDownloaded(since: date), 15)
    }
    
    func test_0BytesIfNoDataRecrodedSince() {
        var sut = NetworkSpeedTracker()
        sut.increase(by: 2)
        let date = Date()
        XCTAssertEqual(sut.numberOfBytesDownloaded(since: date), 0)
    }
    
    func test_canGetBytesOverAllTime() {
        let date = Date()
        var sut = NetworkSpeedTracker()
        sut.increase(by: 10)
        sut.increase(by: 5)
        XCTAssertEqual(sut.numberOfBytesDownloaded(since: date), 15)
    }
    
    func test_canGetBytesDownloadedOverTimePeriod() {
        var sut = NetworkSpeedTracker()
        sut.increase(by: 2)
        usleep(2000)
        sut.increase(by: 10)
        sut.increase(by: 5)
        let timePeriod: TimeInterval = 0.002
        XCTAssertEqual(sut.numberOfBytesDownloaded(over: timePeriod), 15)
    }
}
