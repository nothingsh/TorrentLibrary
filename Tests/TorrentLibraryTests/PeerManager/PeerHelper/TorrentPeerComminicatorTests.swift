//
//  TorrentPeerComminicatorTests.swift
//  
//
//  Created by Wynn Zhang on 8/21/23.
//

import XCTest
@testable import TorrentLibrary

func XCTAssertEqual(_ lhs: TorrentPeerCommunicator?, _ rhs: TorrentPeerCommunicator?) {
    XCTAssert(lhs === rhs)
}

class TorrentPeerCommunicatorDelegateStub: TorrentPeerCommunicatorDelegate {
    var peerConnectedCalled = false
    var peerConnectedParameter: TorrentPeerCommunicator?
    func peerConnected(_ sender: TorrentPeerCommunicator) {
        peerConnectedCalled = true
        peerConnectedParameter = sender
    }
    
    var peerLostCalled = false
    var peerLostParameter: TorrentPeerCommunicator?
    func peerLost(_ sender: TorrentPeerCommunicator) {
        peerLostCalled = true
        peerLostParameter = sender
    }
    
    var peerSentHandshakeCalled = false
    var peerSentHandshakeParameters: (sender: TorrentPeerCommunicator, peerId: Data, onDHT: Bool)?
    func peerSentHandshake(_ sender: TorrentPeerCommunicator, sentHandshakeWithPeerId peerId: Data, onDHT: Bool) {
        peerSentHandshakeCalled = true
        peerSentHandshakeParameters = (sender, peerId, onDHT)
    }
    
    var peerSentKeepAliveCalled = false
    var peerSentKeepAliveParamter: TorrentPeerCommunicator?
    func peerSentKeepAlive(_ sender: TorrentPeerCommunicator) {
        peerSentKeepAliveCalled = true
        peerSentKeepAliveParamter = sender
    }
    
    var peerBecameChokedCalled = false
    var peerBecameChokedParameter: TorrentPeerCommunicator?
    func peerBecameChoked(_ sender: TorrentPeerCommunicator) {
        peerBecameChokedCalled = true
        peerBecameChokedParameter = sender
    }
    
    var peerBecameUnchokedCalled = false
    var peerBecameUnchokedParameter: TorrentPeerCommunicator?
    func peerBecameUnchoked(_ sender: TorrentPeerCommunicator) {
        peerBecameUnchokedCalled = true
        peerBecameUnchokedParameter = sender
    }
    
    var peerBecameInterestedCalled = false
    var peerBecameInterestedParameter: TorrentPeerCommunicator?
    func peerBecameInterested(_ sender: TorrentPeerCommunicator) {
        peerBecameInterestedCalled = true
        peerBecameInterestedParameter = sender
    }
    
    var peerBecameUninterestedCalled = false
    var peerBecameUninterestedParameter: TorrentPeerCommunicator?
    func peerBecameUninterested(_ sender: TorrentPeerCommunicator) {
        peerBecameUninterestedCalled = true
        peerBecameUninterestedParameter = sender
    }
    
    var peerHasPieceCalled = false
    var peerHasPieceParameters: (sender: TorrentPeerCommunicator, piece: Int)?
    func peer(_ sender: TorrentPeerCommunicator, hasPiece piece: Int) {
        peerHasPieceCalled = true
        peerHasPieceParameters = (sender, piece)
    }
    
    var peerHasBitFieldCalled = false
    var peerHasBitFieldParameters: (sender: TorrentPeerCommunicator, bitFieldData: Data)?
    func peer(_ sender: TorrentPeerCommunicator, hasBitFieldData bitFieldData: Data) {
        peerHasBitFieldCalled = true
        peerHasBitFieldParameters = (sender, bitFieldData)
    }
    
    var peerRequestedPieceCalled = false
    var peerRequestedPieceParameters: (sender: TorrentPeerCommunicator, index: Int, begin: Int, length: Int)?
    func peer(_ sender: TorrentPeerCommunicator, requestedPiece index: Int, begin: Int, length: Int) {
        peerRequestedPieceCalled = true
        peerRequestedPieceParameters = (sender, index, begin, length)
    }
    
    var peerSentPieceCalled = false
    var peerSentPieceParameters: (sender: TorrentPeerCommunicator, index: Int, begin: Int, block: Data)?
    func peer(_ sender: TorrentPeerCommunicator, sentPiece index: Int, begin: Int, block: Data) {
        peerSentPieceCalled = true
        peerSentPieceParameters = (sender, index, begin, block)
    }
    
    var peerCancelledRequestedPieceCalled = false
    var peerCancelledRequestedPieceParameters: (sender: TorrentPeerCommunicator, index: Int, begin: Int, length: Int)?
    func peer(_ sender: TorrentPeerCommunicator, cancelledRequestedPiece index: Int, begin: Int, length: Int) {
        peerCancelledRequestedPieceCalled = true
        peerCancelledRequestedPieceParameters = (sender, index, begin, length)
    }
    
    var peerOnDHTPortCalled = false
    var peerOnDHTPortParameters: (sender: TorrentPeerCommunicator, port: Int)?
    func peer(_ sender: TorrentPeerCommunicator, onDHTPort port: Int) {
        peerOnDHTPortCalled = true
        peerOnDHTPortParameters = (sender, port)
    }
    
    var peerSentMalformedMessageCalled = false
    var peerSentMalformedMessageParameter: TorrentPeerCommunicator?
    func peerSentMalformedMessage(_ sender: TorrentPeerCommunicator) {
        peerSentMalformedMessageCalled = true
        peerSentMalformedMessageParameter = sender
    }
}

class TCPConnectionStub: TCPConnectionProtocol {
    weak var delegate: TCPConnectionDelegate?
    
    var connectedHost: String?
    var connectedPort: UInt16?
    var connected: Bool = false
    
    var connectCalled = false
    var connectParameters: (host: String, port: UInt16)?
    func connect(to host: String, onPort port: UInt16) throws {
        connectCalled = true
        connectParameters = (host, port)
    }
    
    var disconnectCalled = false
    func disconnect() {
        disconnectCalled = true
    }
    
    var readDataCalled = false
    var readDataParameters: (timeout: TimeInterval, tag: Int)?
    func readData(withTimeout timeout: TimeInterval, tag: Int) {
        readDataCalled = true
        readDataParameters = (timeout, tag)
    }
    
    var writeDataCalled = false
    var writeDataParameters: (data: Data, timeout: TimeInterval, tag: Int?)?
    
    func write(_ data: Data, withTimeout timeout: TimeInterval, tag: Int) {
        writeDataCalled = true
        writeDataParameters = (data, timeout, tag)
    }
    
    func write(_ data: Data, withTimeout timeout: TimeInterval, completion: (() -> Void)?) {
        writeDataCalled = true
        writeDataParameters = (data, timeout, nil)
    }
}

final class TorrentPeerComminicatorTests: XCTestCase {
    var tcpConnection: TCPConnectionStub!
    var delegate: TorrentPeerCommunicatorDelegateStub!
    var sut: TorrentPeerCommunicator!
    
    // MARK: - Models and example data
    
    let ip = "127.0.0.1"
    let port: UInt16 = 123
    let peerId = "-BD0000-bxa]N#IRKqv`".data(using: .ascii)!
    let expectedTimeout: TimeInterval = 10
    
    let infoHash = Data(repeating: 1, count: 20)
    
    let handshakePayload: Data = {
        var result = Data([19])                         // pstrlen (Protocol string length)
        result += "BitTorrent protocol".data(using: .ascii)!   // pstr (Protocol string)
        result += Data([0,0,0,0,0,0,0,0])               // reserved (8 reserved bytes)
        result += Data(repeating: 1, count: 20)                // info_hash
        result += "-BD0000-bxa]N#IRKqv`".data(using: .ascii)!  // peer_id of the current user
        return result
    }()
    
    let keepAlivePayload = Data([0, 0, 0, 0])    // Length prefix of 0
    
    let chokePayload = Data([
        0, 0, 0, 1, // Length 1
        0  // Id 0
        ])
    
    let unchokePayload = Data([
        0, 0, 0, 1, // Length 1
        1  // Id 1
        ])
    
    let interestedPayload = Data([
        0, 0, 0, 1, // Length 1
        2  // Id 2
        ])
    
    let notInterestedPayload = Data([
        0, 0, 0, 1, // Length 1
        3           // Id 3
        ])
    
    func havePayload(pieceIndex: Int) -> Data {
        return Data(
            [0, 0, 0, 5,                  // Length 5
             4]) +                        // Id 4
            UInt32(pieceIndex).toData()   // Piece index
    }
    
    func bitFieldPayload(bitField: BitField) -> Data {
        return Data(
            [0, 0, 0, 3,        // Length 3
             5]) +              // Id 5
            bitField.toData()   // Piece index
    }
    
    func requestPayload(index: Int, begin: Int, length: Int) -> Data {
        return Data(
            [0, 0, 0, 13,                   // Length 13
            6                               // Id 6
            ]) + UInt32(index).toData() +   // index
            UInt32(begin).toData() +        // begin
            UInt32(length).toData()         // length
    }
    
    func piecePayload(index: Int, begin: Int, block: Data) -> Data {
        return Data(
            [0, 0, 0, 12,                   // Length 12
            7                               // Id 7
            ]) + UInt32(index).toData() +   // index
            UInt32(begin).toData() +        // begin
            block                           // block
    }
    
    func cancelPayload(index: Int, begin: Int, length: Int) -> Data {
        return Data(
            [0, 0, 0, 13,                   // Length 13
            8                               // Id 8
            ]) + UInt32(index).toData() +   // index
            UInt32(begin).toData() +        // begin
            UInt32(length).toData()         // length
    }
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        
        let peer = TorrentPeerInfo(ip: ip, port: port, id: peerId)
        
        tcpConnection = TCPConnectionStub()
        delegate = TorrentPeerCommunicatorDelegateStub()
        sut = TorrentPeerCommunicator(peerInfo: peer,
                                      infoHash: infoHash,
                                      tcpConnection: tcpConnection)
        sut.delegate = delegate
    }
    
    // Mark - Tests
    
    func test_connectedFlag() {
        tcpConnection.connected = false
        XCTAssertFalse(sut.connected)
        tcpConnection.connected = true
        XCTAssertTrue(sut.connected)
    }
    
    func test_canConnect() {
        try! sut.connect()
        
        XCTAssert(tcpConnection.connectCalled)
        XCTAssertEqual(tcpConnection.connectParameters?.host, ip)
        XCTAssertEqual(tcpConnection.connectParameters?.port, port)
    }
    
    func test_tcpConnectionIsConstantlyReadingNewData() {
        XCTAssert(tcpConnection.readDataCalled)
        XCTAssertEqual(tcpConnection.readDataParameters?.timeout, -1)
        
        if let tag = tcpConnection.readDataParameters?.tag {
            tcpConnection.readDataCalled = false
            sut.tcpConnection(tcpConnection, didRead: Data(), withTag: tag)
            XCTAssert(tcpConnection.readDataCalled)
            XCTAssertEqual(tcpConnection.readDataParameters?.timeout, -1)
        }
    }
    
    func test_sendHandshake() {
        sut.sendHandshake(for: peerId)
        assertDataSent(handshakePayload)
    }
    
    func test_sendKeepAlive() {
        sut.sendKeepAlive()
        assertDataSent(keepAlivePayload)
    }
    
    func test_sendChoke() {
        sut.sendChoke()
        assertDataSent(chokePayload)
    }
    
    func test_sendUnchoke() {
        sut.sendUnchoke()
        assertDataSent(unchokePayload)
    }
    
    func testSendInterested() {
        sut.sendInterested()
        assertDataSent(interestedPayload)
    }
    
    func testSendNotInterested() {
        sut.sendNotInterested()
        assertDataSent(notInterestedPayload)
    }
    
    func test_sendHave() {
        let pieceIndex = 456
        sut.sendHavePiece(at: pieceIndex)
        let expectedPayload = havePayload(pieceIndex: pieceIndex)
        assertDataSent(expectedPayload)
    }
    
    func test_sendBitField() {
        
        // Given
        var bitField = BitField(size: 10)
        bitField.setBit(at: 2, with: true)
        bitField.setBit(at: 5, with: true)
        bitField.setBit(at: 9, with: true)
        
        // When
        sut.sendBitField(bitField)
        
        // Then
        let expectedPayload = bitFieldPayload(bitField: bitField)
        assertDataSent(expectedPayload)
    }
    
    func test_sendRequest() {
        let index = 123
        let begin = 456
        let length = 789
        
        sut.sendRequest(fromPieceAtIndex: index, begin: begin, length: length)
        
        let expectedPayload = requestPayload(index: index, begin: begin, length: length)
        assertDataSent(expectedPayload)
    }
    
    func test_sendPiece() {
        let index = 123
        let begin = 456
        let block = Data([1,2,3])
        
        sut.sendPiece(fromPieceAtIndex: index, begin: begin, block: block)
        
        let expectedPayload = piecePayload(index: index, begin: begin, block: block)
        assertDataSent(expectedPayload)
    }
    
    func test_sendCancel() {
        let index = 123
        let begin = 456
        let length = 789
        
        sut.sendCancel(forPieceAtIndex: index, begin: begin, length: length)
        
        let expectedPayload = cancelPayload(index: index, begin: begin, length: length)
        assertDataSent(expectedPayload)
    }
    
    func test_sendPort() {
        // TODO: implement with DHT peer discovery
    }
    
    // MARK: -
    
    func assertDataSent(_ data: Data) {
        XCTAssert(tcpConnection.writeDataCalled)
        XCTAssertEqual(tcpConnection.writeDataParameters?.timeout, expectedTimeout)
        XCTAssertEqual(tcpConnection.writeDataParameters?.data, data)
    }
    
    func test_observingTCPDelegate() {
        XCTAssert(tcpConnection.delegate! === sut)
    }
    
    func test_delegateCalledOnSocketConnected() {
        // Given
        try! sut.connect()
        
        // When
        sut.tcpConnection(tcpConnection, didConnectToHost: ip, port: port)
        
        // Then
        XCTAssert(delegate.peerConnectedCalled)
        XCTAssertEqual(delegate.peerConnectedParameter, sut)
    }
    
    func test_delegateCalledOnSocketDisconnected() {
        enum MyError: Error {
            case failure
        }
        
        sut.tcpConnection(tcpConnection, disconnectedWithError: MyError.failure)
        XCTAssert(delegate.peerLostCalled)
        XCTAssertEqual(delegate.peerLostParameter, sut)
    }
    
    func test_delegateCalled_whenPeerSendsHandshake() {
        sut.tcpConnection(tcpConnection, didRead: handshakePayload, withTag: 0)
        XCTAssert(delegate.peerSentHandshakeCalled)
        XCTAssertEqual(delegate.peerSentHandshakeParameters?.sender, sut)
        XCTAssertEqual(delegate.peerSentHandshakeParameters?.peerId, peerId)
        XCTAssertEqual(delegate.peerSentHandshakeParameters?.onDHT, false)
    }
    
    func test_delegateCalled_whenPeerSendsKeepAlive() {
        sut.tcpConnection(tcpConnection, didRead: handshakePayload, withTag: 0)
        sut.tcpConnection(tcpConnection, didRead: keepAlivePayload, withTag: 0)
        XCTAssert(delegate.peerSentKeepAliveCalled)
        XCTAssertEqual(delegate.peerSentKeepAliveParamter, sut)
    }
    
    func test_delegateCalledOnReceiveHandshake_andAnotherMessage() {
        sut.tcpConnection(tcpConnection, didRead: handshakePayload + keepAlivePayload, withTag: 0)
        XCTAssert(delegate.peerSentHandshakeCalled)
        XCTAssert(delegate.peerSentKeepAliveCalled)
    }
    
    func test_delegateCalled_whenPeerSendsChoke() {
        sut.tcpConnection(tcpConnection, didRead: handshakePayload, withTag: 0)
        sut.tcpConnection(tcpConnection, didRead: chokePayload, withTag: 0)
        XCTAssert(delegate.peerBecameChokedCalled)
        XCTAssertEqual(delegate.peerBecameChokedParameter, sut)
    }
    
    func test_delegateCalled_whenPeerSendsUnchoke() {
        sut.tcpConnection(tcpConnection, didRead: handshakePayload, withTag: 0)
        sut.tcpConnection(tcpConnection, didRead: unchokePayload, withTag: 0)
        XCTAssert(delegate.peerBecameUnchokedCalled)
        XCTAssertEqual(delegate.peerBecameUnchokedParameter, sut)
    }
    
    func test_delegateCalled_whenPeerSendsInterested() {
        sut.tcpConnection(tcpConnection, didRead: handshakePayload, withTag: 0)
        sut.tcpConnection(tcpConnection, didRead: interestedPayload, withTag: 0)
        XCTAssert(delegate.peerBecameInterestedCalled)
        XCTAssertEqual(delegate.peerBecameInterestedParameter, sut)
    }
    
    func test_delegateCalled_whenPeerSendsNotInterested() {
        sut.tcpConnection(tcpConnection, didRead: handshakePayload, withTag: 0)
        sut.tcpConnection(tcpConnection, didRead: notInterestedPayload, withTag: 0)
        XCTAssert(delegate.peerBecameUninterestedCalled)
        XCTAssertEqual(delegate.peerBecameUninterestedParameter, sut)
    }
    
    func test_delegateCalled_whenPeerSendsHave() {
        let pieceIndex = 345
        sut.tcpConnection(tcpConnection, didRead: handshakePayload, withTag: 0)
        sut.tcpConnection(tcpConnection, didRead: havePayload(pieceIndex: pieceIndex), withTag: 0)
        XCTAssert(delegate.peerHasPieceCalled)
        XCTAssertEqual(delegate.peerHasPieceParameters?.sender, sut)
        XCTAssertEqual(delegate.peerHasPieceParameters?.piece, pieceIndex)
    }
    
    func test_delegateCalled_whenPeerSendsBitfield() {
        
        var bitField = BitField(size: 16)
        bitField.setBit(at: 2, with: true)
        bitField.setBit(at: 5, with: true)
        bitField.setBit(at: 9, with: true)
        
        sut.tcpConnection(tcpConnection, didRead: handshakePayload, withTag: 0)
        sut.tcpConnection(tcpConnection, didRead: bitFieldPayload(bitField: bitField), withTag: 0)
        
        XCTAssert(delegate.peerHasBitFieldCalled)
        XCTAssertEqual(delegate.peerHasBitFieldParameters?.sender, sut)
        XCTAssertEqual(delegate.peerHasBitFieldParameters?.bitFieldData, bitField.toData())
    }
    
    func test_delegateCalled_whenPeerSendsRequest() {
        
        let index = 123
        let begin = 345
        let length = 567
        let payload = requestPayload(index: index, begin: begin, length: length)
        
        sut.tcpConnection(tcpConnection, didRead: handshakePayload, withTag: 0)
        sut.tcpConnection(tcpConnection, didRead: payload, withTag: 0)
        
        XCTAssert(delegate.peerRequestedPieceCalled)
        XCTAssertEqual(delegate.peerRequestedPieceParameters?.sender, sut)
        XCTAssertEqual(delegate.peerRequestedPieceParameters?.index, index)
        XCTAssertEqual(delegate.peerRequestedPieceParameters?.begin, begin)
        XCTAssertEqual(delegate.peerRequestedPieceParameters?.length, length)
    }
    
    func test_delegateCalled_whenPeerSendsPiece() {
        let index = 123
        let begin = 345
        let block = Data([1,2,3])
        let payload = piecePayload(index: index, begin: begin, block: block)
        
        sut.tcpConnection(tcpConnection, didRead: handshakePayload, withTag: 0)
        sut.tcpConnection(tcpConnection, didRead: payload, withTag: 0)
        
        XCTAssert(delegate.peerSentPieceCalled)
        XCTAssertEqual(delegate.peerSentPieceParameters?.sender, sut)
        XCTAssertEqual(delegate.peerSentPieceParameters?.index, index)
        XCTAssertEqual(delegate.peerSentPieceParameters?.begin, begin)
        XCTAssertEqual(delegate.peerSentPieceParameters?.block, block)
    }
    
    func test_delegateCalled_whenPeerSendsCancel() {
        let index = 123
        let begin = 345
        let length = 567
        let payload = cancelPayload(index: index, begin: begin, length: length)
        
        sut.tcpConnection(tcpConnection, didRead: handshakePayload, withTag: 0)
        sut.tcpConnection(tcpConnection, didRead: payload, withTag: 0)
        
        XCTAssert(delegate.peerCancelledRequestedPieceCalled)
        XCTAssertEqual(delegate.peerCancelledRequestedPieceParameters?.sender, sut)
        XCTAssertEqual(delegate.peerCancelledRequestedPieceParameters?.index, index)
        XCTAssertEqual(delegate.peerCancelledRequestedPieceParameters?.begin, begin)
        XCTAssertEqual(delegate.peerCancelledRequestedPieceParameters?.length, length)
    }
    
    func test_delegateCalled_whenPeerSendDHTPort() {
        // TODO: implement with DHT peer discovery
    }
    
    func test_delegateCalled_onBadHandshake() {
        sut.tcpConnection(tcpConnection, didRead: Data([1,2,3,4,99]), withTag: 0)
        
        XCTAssert(delegate.peerSentMalformedMessageCalled)
        XCTAssertEqual(delegate.peerSentMalformedMessageParameter, sut)
    }
    
    func test_delegateCalled_onBadMessage() {
        sut.tcpConnection(tcpConnection, didRead: handshakePayload, withTag: 0)
        sut.tcpConnection(tcpConnection, didRead: Data([0,0,0,1,99,6,7,8,9,10]), withTag: 0)
        
        XCTAssert(delegate.peerSentMalformedMessageCalled)
        XCTAssertEqual(delegate.peerSentMalformedMessageParameter, sut)
    }
}
