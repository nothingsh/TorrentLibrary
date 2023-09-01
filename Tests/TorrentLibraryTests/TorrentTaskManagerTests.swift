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
    
    lazy var announceTimer: Timer = {
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let conf = self?.conf else {
                return
            }
            if let info = self?.manager.getTorrentDownloadInfo(for: conf) {
                print("Name: \(info.name), Download: \(info.downloadSpeed), Upload: \(info.uploadSpeed), Progress: \(info.progressPercentage), Seed: \(info.seedCount), Peer: \(info.peerCount)")
            }
        }
    }()
    
    var manager: TorrentTaskManager!
    var conf: TorrentTaskConf!

    override func setUpWithError() throws {
        self.manager = TorrentTaskManager()
        
        try self.manager.setupTorrentTask(torrent: model, rootDirectory: "")
        self.conf = self.manager.torrentList.first!.conf
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testExample() throws {
        let expectation = self.expectation(description: "check peers from trackers")
        
        announceTimer.fire()
        wait(for: [expectation], timeout: 30)
        
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
