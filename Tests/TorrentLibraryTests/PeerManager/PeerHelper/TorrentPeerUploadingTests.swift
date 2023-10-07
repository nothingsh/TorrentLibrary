//
//  TorrentPeerUploadingTests.swift
//  
//
//  Created by Wynn Zhang on 8/22/23.
//

import XCTest
@testable import TorrentLibrary

class TorrentPeerDelegateStub: TorrentPeerDelegate {
    var peerHasNewAvailablePiecesCallCount = 0
    var peerHasNewAvailablePiecesParameter: TorrentPeer?
    func peerHasNewAvailablePieces(_ sender: TorrentPeer) {
        peerHasNewAvailablePiecesCallCount += 1
        peerHasNewAvailablePiecesParameter = sender
    }
    
    var peerLostCalled = false
    var peerLostParameter: TorrentPeer?
    func peerLost(_ sender: TorrentPeer) {
        peerLostCalled = true
        peerLostParameter = sender
    }
    
    var failedToGetPieceAtIndexCalled = false
    var failedToGetPieceAtIndexParameters: (sender: TorrentPeer, index: Int)?
    func peer(_ sender: TorrentPeer, failedToGetPieceAtIndex index: Int) {
        failedToGetPieceAtIndexCalled = true
        failedToGetPieceAtIndexParameters = (sender, index)
    }
    
    var gotPieceAtIndexCalled = false
    var gotPieceAtIndexParameters: (sender: TorrentPeer, index: Int, piece: Data)?
    func peer(_ sender: TorrentPeer, gotPieceAtIndex index: Int, piece: Data) {
        gotPieceAtIndexCalled = true
        gotPieceAtIndexParameters = (sender, index, piece)
    }
    
    var requestedPieceAtIndexCalled = false
    var requestedPieceAtIndexParameters: (sender: TorrentPeer, index: Int)?
    var requestedPieceAtIndexResult: Data?
    func peer(_ sender: TorrentPeer, requestedPieceAtIndex index: Int) -> Data? {
        requestedPieceAtIndexCalled = true
        requestedPieceAtIndexParameters = (sender, index)
        return requestedPieceAtIndexResult
    }
}

class TorrentPeerCommunicatorStub: TorrentPeerCommunicator {
    var testConnected: Bool = false
    override var connected: Bool {
        return testConnected
    }
    
    var connectCalled = false
    override func connect() throws {
        connectCalled = true
    }
    
    var sendHandshakeCalled = false
    var sendHandshakeParameters: (clientId: Data, completion: (()->Void)?)?
    override func sendHandshake(for clientId: Data, _ completion: (() -> Void)?) {
        sendHandshakeCalled = true
        sendHandshakeParameters = (clientId, completion)
    }
    
    var sendBitFieldCalled = false
    var sendBitFieldParameters: (bitField: BitField, completion: (()->Void)?)?
    override func sendBitField(_ bitField: BitField, _ completion: (() -> Void)?) {
        sendBitFieldCalled = true
        sendBitFieldParameters = (bitField, completion)
    }
    
    var sendInterestedCalled = false
    var sendInterestedParameter: ((()->Void)?)?
    override func sendInterested(_ completion: (() -> Void)?) {
        sendInterestedCalled = true
        sendInterestedParameter = completion
    }
    
    var sendRequestCalled = false
    var sendRequestParameters: [(index: Int, begin: Int, length: Int, completion:(()->Void)?)] = []
    override func sendRequest(fromPieceAtIndex index: Int, begin: Int, length: Int, _ completion: (() -> Void)?) {
        sendRequestCalled = true
        sendRequestParameters.append((index, begin, length, completion))
    }
    
    var sendKeepAliveCalled = false
    var onSendKeepAliveCalled: (()->Void)?
    override func sendKeepAlive(_ completion: (() -> Void)?) {
        sendKeepAliveCalled = true
        onSendKeepAliveCalled?()
    }
    
    var sendPieceCallCount = 0
    var sendPieceParameters: (index: Int, begin: Int, block: Data, completion: (()->Void)?)?
    override func sendPiece(fromPieceAtIndex index: Int, begin: Int, block: Data, _ completion: (() -> Void)?) {
        sendPieceCallCount += 1
        sendPieceParameters = (index, begin, block, completion)
    }
    
    var sendUnchokeCalled = false
    override func sendUnchoke(_ completion: (() -> Void)?) {
        sendUnchokeCalled = true
    }
}

final class TorrentPeerUploadingTests: XCTestCase {
    let ip = "127.0.0.1"
    let port: UInt16 = 123
    let peerId = Data(repeating: 1, count: 20)
    let clientId = Data(repeating: 2, count: 20)
    let infoHash = Data(repeating: 3, count: 20)
    
    let bitField: BitField = {
        var bitField = BitField(size: 10)
        bitField.setBit(at: 2)
        bitField.setBit(at: 5)
        bitField.setBit(at: 9)
        return bitField
    }()
    
    var delegate: TorrentPeerDelegateStub!
    var communicator: TorrentPeerCommunicatorStub!
    var peerInfo: TorrentPeerInfo!
    var sut: TorrentPeer!
    
    override func setUp() {
        super.setUp()
        
        peerInfo = TorrentPeerInfo(ip: ip, port: port, id: peerId)
        communicator = TorrentPeerCommunicatorStub(peerInfo: peerInfo,
                                                   infoHash: infoHash,
                                                   tcpConnection: TCPConnectionStub())
        delegate = TorrentPeerDelegateStub()
        sut = TorrentPeer(peerInfo: peerInfo, bitFieldSize: 10, communicator: communicator)
        sut.delegate = delegate
    }
    
    func test_pieceSentOnRequest() {
        
        // Given
        let pieceIndex = 123
        let begin = 0
        let data = Data(repeating: 4, count: 10)
        delegate.requestedPieceAtIndexResult = data
        
        // When
        sut.peer(communicator, requestedPiece: pieceIndex, begin: begin, length: 10)
        
        // Then
        XCTAssert(delegate.requestedPieceAtIndexCalled)
        XCTAssertEqual(communicator.sendPieceCallCount, 1)
        if let sendPieceParameters = communicator.sendPieceParameters {
            XCTAssertEqual(sendPieceParameters.index, pieceIndex)
            XCTAssertEqual(sendPieceParameters.begin, begin)
            XCTAssertEqual(sendPieceParameters.block, data)
        }
    }
    
    func test_blocksSentOneByOne() {
        
        // Given
        let pieceIndex = 123
        let begin1 = 0
        let begin2 = 10
        let data = Data(repeating: 4, count: 20)
        delegate.requestedPieceAtIndexResult = data
        
        // When
        sut.peer(communicator, requestedPiece: pieceIndex, begin: begin1, length: 10)
        sut.peer(communicator, requestedPiece: pieceIndex, begin: begin2, length: 10)
        
        // Then
        XCTAssertEqual(communicator.sendPieceCallCount, 1)
        
        // And When
        guard let sendPieceParameters = communicator.sendPieceParameters else { return }
        sendPieceParameters.completion?()
        
        // Then
        XCTAssertEqual(communicator.sendPieceCallCount, 2)
        if let sendPieceParameters2 = communicator.sendPieceParameters {
            XCTAssertEqual(sendPieceParameters2.begin, begin2)
        }
    }
    
    func test_canRequestMultiplePieces() {
        
        // Given
        let pieceIndex1 = 1
        let pieceIndex2 = 2
        let data = Data(repeating: 0, count: 20)
        delegate.requestedPieceAtIndexResult = data
        
        // When
        sut.peer(communicator, requestedPiece: pieceIndex1, begin: 0, length: 10)
        sut.peer(communicator, requestedPiece: pieceIndex1, begin: 10, length: 10)
        sut.peer(communicator, requestedPiece: pieceIndex2, begin: 0, length: 10)
        
        communicator.sendPieceParameters?.completion?()
        communicator.sendPieceParameters?.completion?()
        communicator.sendPieceParameters?.completion?()
        
        // Then
        XCTAssertEqual(communicator.sendPieceCallCount, 3)
    }
    
    func test_peerCanCancelUnsentBlock() {
        
        // Given
        let pieceIndex = 123
        let begin1 = 0
        let begin2 = 10
        let data = Data(repeating: 4, count: 10)
        delegate.requestedPieceAtIndexResult = data
        
        // When
        sut.peer(communicator, requestedPiece: pieceIndex, begin: begin1, length: 10)
        sut.peer(communicator, requestedPiece: pieceIndex, begin: begin2, length: 10)
        sut.peer(communicator, cancelledRequestedPiece: pieceIndex, begin: begin2, length: 10)
        
        // And When
        communicator.sendPieceParameters?.completion?()
        
        // Then
        XCTAssertEqual(communicator.sendPieceCallCount, 1)
    }
    
    func test_onLostPeerUploadStops() {
        
        // Given
        let pieceIndex = 123
        let begin1 = 0
        let begin2 = 10
        let data = Data(repeating: 4, count: 10)
        delegate.requestedPieceAtIndexResult = data
        
        // When
        sut.peer(communicator, requestedPiece: pieceIndex, begin: begin1, length: 10)
        sut.peer(communicator, requestedPiece: pieceIndex, begin: begin2, length: 10)
        sut.peerLost(communicator)
        
        // And When
        communicator.sendPieceParameters?.completion?()
        
        // Then
        XCTAssertEqual(communicator.sendPieceCallCount, 1)
    }
    
    func test_onPeerChokedUploadsCancelled() {
        
        // Given
        let pieceIndex = 123
        let begin1 = 0
        let begin2 = 10
        let data = Data(repeating: 4, count: 10)
        delegate.requestedPieceAtIndexResult = data
        
        // When
        sut.peer(communicator, requestedPiece: pieceIndex, begin: begin1, length: 10)
        sut.peer(communicator, requestedPiece: pieceIndex, begin: begin2, length: 10)
        sut.peerBecameChoked(communicator)
        
        // Even if
        sut.peerBecameUnchoked(communicator)
        
        // Then When
        communicator.sendPieceParameters?.completion?()
        
        // Then
        XCTAssertEqual(communicator.sendPieceCallCount, 1)
    }
    
    func test_onPeerUninterestedUploadsCancelled() {
        
        // Given
        let pieceIndex = 123
        let begin1 = 0
        let begin2 = 10
        let data = Data(repeating: 4, count: 10)
        delegate.requestedPieceAtIndexResult = data
        
        // When
        sut.peer(communicator, requestedPiece: pieceIndex, begin: begin1, length: 10)
        sut.peer(communicator, requestedPiece: pieceIndex, begin: begin2, length: 10)
        sut.peerBecameUninterested(communicator)
        
        // Even if
        sut.peerBecameUnchoked(communicator)
        
        // Then When
        communicator.sendPieceParameters?.completion?()
        
        // Then
        XCTAssertEqual(communicator.sendPieceCallCount, 1)
    }
}
