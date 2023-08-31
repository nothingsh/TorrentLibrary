//
//  TorrentTaskManagerTests.swift
//  
//
//  Created by Wynn Zhang on 8/30/23.
//

import XCTest
import TorrentModel
@testable import TorrentLibrary

final class TorrentTaskManagerTests: XCTestCase {
    let model: TorrentModel = {
        let path = Bundle.module.path(forResource: "test", ofType: "torrent")
        let data = try! Data(contentsOf: URL(fileURLWithPath: path!))
        return try! TorrentModel.decode(data: data)
    }()
    
    var manager: TorrentTaskManager!

    override func setUpWithError() throws {
        self.manager = TorrentTaskManager()
        
        try self.manager.setupTorrentTask(torrent: model, rootDirectory: "")
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let expectation = self.expectation(description: "check peers from trackers")
        
        wait(for: [expectation], timeout: 10)
        
        let conf = self.manager.torrentList.first!.conf
        manager.peerProvider.fetchMorePeersImediatly(for: conf)
        expectation.fulfill()
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
