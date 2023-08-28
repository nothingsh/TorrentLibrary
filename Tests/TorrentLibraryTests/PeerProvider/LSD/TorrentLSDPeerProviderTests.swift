//
//  TorrentLSDPeerProviderTests.swift
//  
//
//  Created by Wynn Zhang on 8/26/23.
//

import XCTest
import TorrentModel
@testable import TorrentLibrary

class TorrentLSDProviderDelegateSpy: TorrentLSDPeerProviderDelegate {
    var torrentLSDPeerProviderCalled = false
    var newPeer: TorrentPeerInfo? = nil
    var clientID: Data? = nil
    
    func torrentLSDPeerProvider(_ sender: TorrentLibrary.TorrentLSDPeerProviderProtocol, got newPeer: TorrentLibrary.TorrentPeerInfo, for clientID: Data) {
        self.torrentLSDPeerProviderCalled = true
        self.newPeer = newPeer
        self.clientID = clientID
    }
}

final class TorrentLSDPeerProviderTests: XCTestCase {
    var sut: TorrentLSDPeerProvider!
    var torrentLSDDelegateSpy: TorrentLSDProviderDelegateSpy!
    var udpConnection: UDPConnectionStub!
    var clientID: Data!
    var infoHashHex: String!
    
    var taskConfs: [TorrentTaskConf]!
    
    let torrent1: TorrentModel = {
        let torrentURL = Bundle.module.url(forResource: "TrackerManagerTests", withExtension: "torrent")
        let data = try! Data(contentsOf: torrentURL!)
        return try! TorrentModel.decode(data: data)
    }()
    
    let torrent2: TorrentModel = {
        let torrentURL = Bundle.module.url(forResource: "TestText", withExtension: "torrent")
        let data = try! Data(contentsOf: torrentURL!)
        return try! TorrentModel.decode(data: data)
    }()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        let infoHash = torrent1.infoHashSHA1
        self.infoHashHex = infoHash.hexEncodedString
        
        self.udpConnection = UDPConnectionStub()
        self.torrentLSDDelegateSpy = TorrentLSDProviderDelegateSpy()
        do {
            sut = try TorrentLSDPeerProvider(udpConnection: udpConnection)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        sut.delegate = torrentLSDDelegateSpy
        
        self.taskConfs = [
            TorrentTaskConf(torrent: torrent1, torrentID: TorrentTaskConf.makePeerID()),
            TorrentTaskConf(torrent: torrent2, torrentID: TorrentTaskConf.makePeerID())
        ]
        
        self.clientID = self.taskConfs[0].id
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testSetupLSDProvider() {
        sut.setupLSDProvider(taskConf: taskConfs[0])
        sut.setupLSDProvider(taskConf: taskConfs[1])
        
        XCTAssertEqual(sut.taskConfs.count, taskConfs.count)
    }
    
    func testStopLSDProvider() {
        sut.setupLSDProvider(taskConf: taskConfs[0])
        
        sut.stopLSDPeerProvider(for: taskConfs[0])
        
        XCTAssertEqual(sut.taskConfs.first!.status, false)
    }
    
    func testResumeLSDProvider() {
        sut.setupLSDProvider(taskConf: taskConfs[0])
        
        sut.stopLSDPeerProvider(for: taskConfs[0])
        sut.resumeLSDPeerProvider(for: taskConfs[0])
        
        XCTAssertEqual(sut.taskConfs.first!.status, true)
    }
    
    func testRemoveLSDProvider() {
        sut.setupLSDProvider(taskConf: taskConfs[0])
        
        sut.removeLSDPeerProvider(for: taskConfs[0])
        
        XCTAssertEqual(sut.taskConfs.count, 0)
    }
    
    func testStopAnnounce() {
        sut.setupLSDProvider(taskConf: taskConfs[0])
        sut.stopLSDPeerProvider(for: taskConfs[0])
        
        sut.startLSDProviderImediatly(for: taskConfs[0])
        
        XCTAssertFalse(torrentLSDDelegateSpy.torrentLSDPeerProviderCalled)
    }
    
    func testLSDDataReceiving() {
        sut.setupLSDProvider(taskConf: self.taskConfs[0])
        
        let header = "BT-SEARCH * HTTP/1.1\r\n"
        let port: UInt16 = 6771
        let remoteHost = "10.10.10.10"
        
        let lsdAnnounceString = "\(header)Host: \(remoteHost)\r\nPort: \(port)\r\nInfohash: \(infoHashHex!)\r\ncookie: \(clientID!)\r\n\r\n\r\n"
        let lsdAnnounceData = lsdAnnounceString.data(using: LSDAnnounce.ENCODING)!
        
        sut.udpConnection(udpConnection, receivedData: lsdAnnounceData, fromHost: remoteHost)
        
        XCTAssertTrue(torrentLSDDelegateSpy.torrentLSDPeerProviderCalled)
        XCTAssertNotNil(torrentLSDDelegateSpy.clientID)
        XCTAssertNotNil(torrentLSDDelegateSpy.newPeer)
        
        XCTAssertEqual(torrentLSDDelegateSpy.clientID, self.clientID)
        XCTAssertEqual(torrentLSDDelegateSpy.newPeer?.ip, remoteHost)
        XCTAssertEqual(torrentLSDDelegateSpy.newPeer?.port, port)
    }
}
