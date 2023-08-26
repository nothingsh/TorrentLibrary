//
//  TorrentLSDPeerProviderTests.swift
//  
//
//  Created by Wynn Zhang on 8/26/23.
//

import XCTest
@testable import TorrentLibrary

class TorrentLSDProviderDelegateSpy: TorrentLSDPeerProviderDelegate {
    var torrentLSDPeerProviderCalled = false
    var newPeer: TorrentPeerInfo? = nil
    var infoHash: String? = nil
    var clientID: String? = nil
    
    func torrentLSDPeerProvider(_ sender: TorrentLibrary.TorrentLSDPeerProviderProtocol, got newPeer: TorrentLibrary.TorrentPeerInfo, with infoHash: String, for clientID: String?) {
        torrentLSDPeerProviderCalled = true
        self.newPeer = newPeer
        self.infoHash = infoHash
        self.clientID = clientID
    }
}

final class TorrentLSDPeerProviderTests: XCTestCase {
    var sut: TorrentLSDPeerProvider!
    var torrentLSDDelegateSpy: TorrentLSDProviderDelegateSpy!
    var udpConnection: UDPConnectionStub!
    var clientID: String!
    var infoHashHex: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        let infoHash = Data(repeating: 0, count: 20)
        let id = TorrentPeer.makePeerID()
        self.infoHashHex = String(urlEncodingData: infoHash)
        self.clientID = "dt-client" + String(urlEncodingData: id)
        
        self.udpConnection = UDPConnectionStub()
        self.torrentLSDDelegateSpy = TorrentLSDProviderDelegateSpy()
        do {
            sut = try TorrentLSDPeerProvider(clientID: id, infoHash: infoHash, udpConnection: udpConnection)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        sut.delegate = torrentLSDDelegateSpy
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testLSDDataReceiving() {
        let header = "BT-SEARCH * HTTP/1.1\r\n"
        let port: UInt16 = 6771
        let remoteHost = "10.10.10.10"
        
        let lsdAnnounceString = "\(header)Host: \(remoteHost)\r\nPort: \(port)\r\nInfohash: \(infoHashHex!)\r\ncookie: \(clientID!)\r\n\r\n\r\n"
        let lsdAnnounceData = lsdAnnounceString.data(using: LSDAnnounce.ENCODING)!
        
        sut.udpConnection(udpConnection, receivedData: lsdAnnounceData, fromHost: remoteHost)
        
        XCTAssertTrue(torrentLSDDelegateSpy.torrentLSDPeerProviderCalled)
        XCTAssertNotNil(torrentLSDDelegateSpy.clientID)
        XCTAssertNotNil(torrentLSDDelegateSpy.infoHash)
        XCTAssertNotNil(torrentLSDDelegateSpy.newPeer)
        
        XCTAssertEqual(torrentLSDDelegateSpy.clientID, self.clientID)
        XCTAssertEqual(torrentLSDDelegateSpy.infoHash, infoHashHex)
        XCTAssertEqual(torrentLSDDelegateSpy.newPeer?.ip, remoteHost)
        XCTAssertEqual(torrentLSDDelegateSpy.newPeer?.port, port)
    }
}
