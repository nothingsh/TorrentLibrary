//
//  TorrentPeerHandshakeMessageBufferTests.swift
//  
//
//  Created by Wynn Zhang on 8/21/23.
//

import XCTest
@testable import TorrentLibrary

class TorrentPeerHandshakeDelegateStub: TorrentPeerHandshakeDelegate {
    var gotBadHandshakeCalled = false
    var gotBadHandshakeError: TorrentPeerHandshakeBufferError?
    func peerHandshakeMessageBuffer(_ sender: TorrentPeerHandshakeBuffer,
                                    gotBadHandshake error: TorrentPeerHandshakeBufferError) {
        gotBadHandshakeCalled = true
        gotBadHandshakeError = error
    }
    
    var gotHandshakeCalled = false
    var gotHandshakeParameters: (sender: TorrentPeerHandshakeBuffer, peerId: Data, remainingBuffer: Data, onDHT: Bool)?
    func peerHandshakeMessageBuffer(_ sender: TorrentPeerHandshakeBuffer,
                                    gotHandshakeWithPeerId peerId: Data,
                                    remainingBuffer: Data,
                                    onDHT: Bool) {
        gotHandshakeCalled = true
        gotHandshakeParameters = (sender, peerId, remainingBuffer, onDHT)
    }
}

final class TorrentPeerHandshakeMessageBufferTests: XCTestCase {
    var delegate: TorrentPeerHandshakeDelegateStub!
    var sut: TorrentPeerHandshakeBuffer!
    
    let infoHash = Data(repeating: 1, count: 20)
    let peerId = Data(repeating: 2, count: 20)
    
    override func setUp() {
        super.setUp()
        
        delegate = TorrentPeerHandshakeDelegateStub()
        sut = TorrentPeerHandshakeBuffer(infoHash: infoHash, peerID: peerId)
        sut.delegate = delegate
    }
    
    func test_canParseHandshake() {
        var data = UInt8(19).toData() // protocol length
        data = data + "BitTorrent protocol".data(using: .ascii)! // protocol
        data = data + Data([0,0,0,0,0,0,0,0]) // 8 reserved bits
        data = data + infoHash // info_hash
        data = data + peerId // peer_id
        
        sut.appendData(data)
        
        XCTAssert(delegate.gotHandshakeCalled)
        XCTAssert(delegate.gotHandshakeParameters?.sender === sut)
        XCTAssertEqual(delegate.gotHandshakeParameters?.peerId, peerId)
        XCTAssertEqual(delegate.gotHandshakeParameters?.remainingBuffer, Data())
        XCTAssertEqual(delegate.gotHandshakeParameters?.onDHT, false)
    }
    
    func test_handshakeReceivedInChunks() {
        var data = UInt8(19).toData() // protocol length
        data = data + "BitTorrent protocol".data(using: .ascii)! // protocol
        data = data + Data([0,0,0,0,0,0,0,0]) // 8 reserved bits
        data = data + infoHash // info_hash
        data = data + peerId // peer_id
        
        let data1 = data.correctingIndicies[0..<30]
        let data2 = data.correctingIndicies[30..<data.count]
        
        sut.appendData(data1)
        XCTAssertFalse(delegate.gotHandshakeCalled)
        
        sut.appendData(data2)
        XCTAssert(delegate.gotHandshakeCalled)
    }
    
    func test_remainingData() {
        
        let extraBytes = Data([1,2,3])
        
        var data = UInt8(19).toData() // protocol length
        data = data + "BitTorrent protocol".data(using: .ascii)! // protocol
        data = data + Data([0,0,0,0,0,0,0,0]) // 8 reserved bits
        data = data + infoHash // info_hash
        data = data + peerId // peer_id
        data = data + extraBytes
        
        sut.appendData(data)
        
        XCTAssert(delegate.gotHandshakeCalled)
        XCTAssertEqual(delegate.gotHandshakeParameters?.remainingBuffer, extraBytes)
    }
    
    func test_canParseOnDHTPeerDiscoveryNetwork() {
        
        var data = UInt8(19).toData() // protocol length
        data = data + "BitTorrent protocol".data(using: .ascii)! // protocol
        data = data + Data([0,0,0,0,0,0,0,1]) // 8 reserved bits
        data = data + infoHash // info_hash
        data = data + peerId // peer_id
        
        sut.appendData(data)
        
        XCTAssertEqual(delegate.gotHandshakeParameters?.onDHT, true)
    }
    
    func test_errorCalledIfProtocolIsNot19Characters() {
        let data = UInt8(18).toData() // protocol length
        sut.appendData(data)
        XCTAssert(delegate.gotBadHandshakeCalled)
        assertError(delegate.gotBadHandshakeError, isError: .protocolMismatch)
    }
    
    func test_errorCalledIfProtocolIsDifferent() {
        var data = UInt8(19).toData() // protocol length
        data = data + "BitTorrent protocoz".data(using: .ascii)! // protocol
        sut.appendData(data)
        XCTAssert(delegate.gotBadHandshakeCalled)
        assertError(delegate.gotBadHandshakeError, isError: .protocolMismatch)
    }
    
    func test_errorCalledIfInfoHashDoesNotMatch() {
        var data = UInt8(19).toData() // protocol length
        data = data + "BitTorrent protocol".data(using: .ascii)! // protocol
        data = data + Data([0,0,0,0,0,0,0,0]) // 8 reserved bits
        data = data + Data(repeating: 3, count: 20) // info_hash
        sut.appendData(data)
        XCTAssert(delegate.gotBadHandshakeCalled)
        assertError(delegate.gotBadHandshakeError, isError: .infoHashMismatch)
    }
    
    func test_errorCalledIfPeerIdDoesNotMatch() {
        var data = UInt8(19).toData() // protocol length
        data = data + "BitTorrent protocol".data(using: .ascii)! // protocol
        data = data + Data([0,0,0,0,0,0,0,0]) // 8 reserved bits
        data = data + infoHash // info_hash
        data = data + Data(repeating: 3, count: 20) // peer_id
        
        sut.appendData(data)
        
        XCTAssert(delegate.gotBadHandshakeCalled)
        assertError(delegate.gotBadHandshakeError, isError: .peerIdMismatch)
    }
    
    func test_nilPeerIdIsAlwaysAccepted() {
        
        let sut = TorrentPeerHandshakeBuffer(infoHash: infoHash, peerID: nil)
        sut.delegate = delegate
        
        var data = UInt8(19).toData() // protocol length
        data = data + "BitTorrent protocol".data(using: .ascii)! // protocol
        data = data + Data([0,0,0,0,0,0,0,0]) // 8 reserved bits
        data = data + infoHash // info_hash
        data = data + Data(repeating: 3, count: 20) // peer_id
        
        sut.appendData(data)
        
        XCTAssert(delegate.gotHandshakeCalled)
    }
    
    // MARK: -
    
    func assertError(_ error: TorrentPeerHandshakeBufferError?,
                     isError expected: TorrentPeerHandshakeBufferError,
                     file: StaticString = #file,
                     line: UInt = #line) {
        
        guard let error = error else {
            XCTFail("Error is nil", file: file, line: line)
            return
        }
        
        switch error {
        case expected:
            return
        default:
            XCTFail("Error doesn't match", file: file, line: line)
        }
    }
}
