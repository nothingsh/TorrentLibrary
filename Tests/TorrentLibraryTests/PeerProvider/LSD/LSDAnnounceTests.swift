//
//  LSDAnnounceTests.swift
//  
//
//  Created by Wynn Zhang on 8/26/23.
//

import XCTest
@testable import TorrentLibrary

final class LSDAnnounceTests: XCTestCase {
    private let header = "BT-SEARCH * HTTP/1.1\r\n"
    private let host = "239.192.152.143"
    private let port: UInt16 = 6771
    private var peerID: String!
    private var infoHashHex: String!
    var lsdAnnounceString: String!
    var lsdAnnounceData: Data!

    override func setUpWithError() throws {
        let infoHash = Data(repeating: 0, count: 20)
        self.infoHashHex = String(urlEncodingData: infoHash)
        self.peerID = "dt-client" + String(urlEncodingData: TorrentPeer.makePeerID())
        
        lsdAnnounceString = "\(header)Host: \(host)\r\nPort: \(port)\r\nInfohash: \(infoHashHex!)\r\ncookie: \(peerID!)\r\n\r\n\r\n"
        
        lsdAnnounceData = lsdAnnounceString.data(using: LSDAnnounce.ENCODING)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testLSDDataParsing() throws {
        let announceInfo = try! LSDAnnounce(data: lsdAnnounceData)
        
        XCTAssertEqual(announceInfo.host, host)
        XCTAssertEqual(UInt16(announceInfo.port), port)
        XCTAssertEqual(announceInfo.cookie, peerID)
        XCTAssertEqual(announceInfo.infoHash, infoHashHex)
    }
    
    func testLSDStringGenerating() throws {
        let announceInfo = try! LSDAnnounce(data: lsdAnnounceData)
        
        XCTAssertEqual(lsdAnnounceString, announceInfo.announceString())
    }
}
