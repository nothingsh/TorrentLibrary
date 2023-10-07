//
//  TorrentPeerTests.swift
//  
//
//  Created by Wynn Zhang on 8/22/23.
//

import XCTest
@testable import TorrentLibrary

final class TorrentPeerTests: XCTestCase {
    let ip = "127.0.0.1"
    let port: UInt16 = 123
    let peerId = Data(repeating: 1, count: 20)
    let clientId = Data(repeating: 2, count: 20)
    let infoHash = Data(repeating: 3, count: 20)
    
    let pieceSize = Int(Double(TorrentBlock.BLOCK_SIZE)*2.5)
    let pieceIndex = 123
    
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
    
    func test_creation() {
        XCTAssertEqual(sut.peerInfo, peerInfo)
        XCTAssertTrue(sut.peerChoked)
        XCTAssertFalse(sut.peerInterested)
        XCTAssertTrue(sut.amChokedToPeer)
        XCTAssertFalse(sut.amInterestedInPeer)
        XCTAssertFalse(sut.connected)
    }
    
    func test_creationWithConnectedSocket() {
        communicator.testConnected = true
        sut = TorrentPeer(peerInfo: peerInfo, bitFieldSize: 10, communicator: communicator)
        XCTAssertTrue(sut.connected)
    }
    
    // MARK: - Connection + handshake
    
    func test_canConnectToPeer() {
        try! sut.connect(withHandshakeData: (clientId, bitField))
        XCTAssert(communicator.connectCalled)
    }
    
    func test_handshakeSentOnConnect() {
        try! sut.connect(withHandshakeData: (clientId, bitField))
        
        communicator.delegate?.peerConnected(communicator)
        
        XCTAssert(communicator.sendHandshakeCalled)
        XCTAssertEqual(communicator.sendHandshakeParameters?.clientId, clientId)
    }
    
    func test_handshakeSentOnRecievingHandshakeFromLeacher() {
        
        // Given
        communicator.testConnected = true
        sut = TorrentPeer(peerInfo: peerInfo, bitFieldSize: 10, communicator: communicator)
        
        // When
        try! sut.connect(withHandshakeData: (clientId, bitField))
        communicator.delegate?.peerSentHandshake(communicator, sentHandshakeWithPeerId: peerId, onDHT: false)
        
        // Then
        XCTAssertFalse(communicator.connectCalled)
        XCTAssert(communicator.sendHandshakeCalled)
        XCTAssertEqual(communicator.sendHandshakeParameters?.clientId, clientId)
    }
    
    func test_bitFieldSentAfterHandshake() {
        
        // Given
        try! sut.connect(withHandshakeData: (clientId, bitField))
        communicator.delegate?.peerConnected(communicator)
        guard let handshakeCompletion = communicator.sendHandshakeParameters?.completion else {
            XCTFail("Cannot notify sut of handshake completion")
            return
        }
        
        // When
        handshakeCompletion()
        
        // Then
        XCTAssert(communicator.sendBitFieldCalled)
        XCTAssertEqual(communicator.sendBitFieldParameters?.bitField, bitField)
    }
    
    func test_delegateNotifiedAfterBitField() {
        communicator.delegate?.peer(communicator, hasBitFieldData: bitField.toData())
        
        XCTAssertEqual(delegate.peerHasNewAvailablePiecesCallCount, 1)
        XCTAssert(delegate.peerHasNewAvailablePiecesParameter === sut)
    }
    
    func test_delegateNotifiedAfterHaveMessage() {
        communicator.delegate?.peer(communicator, hasPiece: 0)
        
        XCTAssertEqual(delegate.peerHasNewAvailablePiecesCallCount, 1)
        XCTAssert(delegate.peerHasNewAvailablePiecesParameter === sut)
    }
    
    func test_delegateNotNotifiedAfterRedundantHaveMessage() {
        communicator.delegate?.peer(communicator, hasPiece: 0)
        communicator.delegate?.peer(communicator, hasPiece: 0)

        XCTAssertEqual(delegate.peerHasNewAvailablePiecesCallCount, 1)
    }
    
    // MARK: - Tracking peer status
    
    func test_bitFieldRecorded() {
        var bitField = BitField(size: 10)
        bitField.setBit(at: 0)
        communicator.delegate?.peer(communicator, hasBitFieldData: bitField.toData())
        XCTAssertEqual(sut.currentProgress, bitField)
    }
    
    func test_bitFieldUpdatedOnHave() {
        var bitField = BitField(size: 10)
        bitField.setBit(at: 0)
        bitField.setBit(at: 3)
        
        communicator.delegate?.peer(communicator, hasPiece: 0)
        communicator.delegate?.peer(communicator, hasPiece: 3)
        XCTAssertEqual(sut.currentProgress, bitField)
    }
    
    func test_stateUpdatedOnPeerUnchoked() {
        communicator.delegate?.peerBecameUnchoked(communicator)
        XCTAssertFalse(sut.peerChoked)
    }
    
    func test_stateUpdatedOnPeerChoked() {
        communicator.delegate?.peerBecameUnchoked(communicator)
        communicator.delegate?.peerBecameChoked(communicator)
        XCTAssertTrue(sut.peerChoked)
    }
    
    func test_stateUpdatedOnPeerInterested() {
        communicator.delegate?.peerBecameInterested(communicator)
        XCTAssertTrue(sut.peerInterested)
    }
    
    func test_stateUpdatedOnPeerUninterested() {
        communicator.delegate?.peerBecameInterested(communicator)
        communicator.delegate?.peerBecameUninterested(communicator)
        XCTAssertFalse(sut.peerInterested)
    }
    
    func test_interestedSentOnDownloadPieceRequest() {
        sut.downloadPiece(atIndex: pieceIndex, size: pieceSize)
        XCTAssert(communicator.sendInterestedCalled)
        XCTAssertTrue(sut.amInterestedInPeer)
    }
    
    func test_interestedNotSentIfAlreadyIntereseted() {
        // Given
        sut.downloadPiece(atIndex: pieceIndex, size: pieceSize)
        communicator.sendInterestedCalled = false
        
        // When
        sut.downloadPiece(atIndex: pieceIndex, size: pieceSize)
        
        // Then
        XCTAssertFalse(communicator.sendInterestedCalled)
    }
    
    // MARK: - Piece download requests
    
    func test_requestNotMadeIfPeerIsChoked() {
        sut.downloadPiece(atIndex: pieceIndex, size: pieceSize)
        XCTAssertFalse(communicator.sendRequestCalled)
    }
    
    func test_requestsMadeImmediatelyIfPeerIsUnchoked() {
        communicator.delegate?.peerBecameUnchoked(communicator)
        sut.downloadPiece(atIndex: pieceIndex, size: pieceSize)
        XCTAssertTrue(communicator.sendRequestCalled)
    }
    
    func test_sendPieceRequestOnUnchoke() {
        sut.downloadPiece(atIndex: pieceIndex, size: pieceSize)
        communicator.delegate?.peerBecameUnchoked(communicator)
        XCTAssertTrue(communicator.sendRequestCalled)
    }
    
    func test_correctBlockRequestsSent() {
        sut.downloadPiece(atIndex: pieceIndex, size: pieceSize)
        communicator.delegate?.peerBecameUnchoked(communicator)
        
        let blockSize = Int(TorrentBlock.BLOCK_SIZE)
        
        let requests = communicator.sendRequestParameters.sorted(by: { $0.begin < $1.begin }).map {
            TorrentBlock.Request(piece: $0.index, begin: $0.begin, length: $0.length)
        }
        
        let expected = [
            TorrentBlock.Request(piece: pieceIndex, begin: 0, length: blockSize),
            TorrentBlock.Request(piece: pieceIndex, begin: blockSize, length: blockSize),
            TorrentBlock.Request(piece: pieceIndex, begin: blockSize*2, length: Int(Double(blockSize)*0.5)),
        ]
        
        XCTAssertEqual(requests, expected)
    }
    
    func test_doesNotDownloadMoreThanMaximumNumberOfRequests() {
        
        let largePieceSize = Int(TorrentBlock.BLOCK_SIZE) * (TorrentPeer.maximumNumberOfPendingBlockRequests + 1)
        
        sut.downloadPiece(atIndex: pieceIndex, size: largePieceSize)
        communicator.delegate?.peerBecameUnchoked(communicator)
        
        XCTAssertEqual(communicator.sendRequestParameters.count, TorrentPeer.maximumNumberOfPendingBlockRequests)
    }
    
    func test_nextRequestMadeOnRecievingBlock() {
        let largePieceSize = Int(TorrentBlock.BLOCK_SIZE) * (TorrentPeer.maximumNumberOfPendingBlockRequests + 1)
        
        sut.downloadPiece(atIndex: pieceIndex, size: largePieceSize)
        communicator.delegate?.peerBecameUnchoked(communicator)
        
        guard let request = communicator.sendRequestParameters.first else { return }
        communicator.sendRequestParameters = []
        communicator.delegate?.peer(communicator,
                                    sentPiece: request.index,
                                    begin: request.begin,
                                    block: Data(repeating: 0, count: request.length))
        
        XCTAssertEqual(communicator.sendRequestParameters.count, 1)
    }
    
    func test_delegateNotifiedFailedToGetPiece_whenPeerChokes() {
        communicator.delegate?.peerBecameUnchoked(communicator)
        sut.downloadPiece(atIndex: pieceIndex, size: pieceSize)
        communicator.delegate?.peerBecameChoked(communicator)
        
        XCTAssert(delegate.failedToGetPieceAtIndexCalled)
        XCTAssert(delegate.failedToGetPieceAtIndexParameters?.sender === sut)
        XCTAssertEqual(delegate.failedToGetPieceAtIndexParameters?.index, pieceIndex)
    }
    
    func test_delegateNotifiedOnSuccessfulPieceDownload() {
        communicator.delegate?.peerBecameUnchoked(communicator)
        sut.downloadPiece(atIndex: pieceIndex, size: pieceSize)
        
        let requests = communicator.sendRequestParameters.sorted(by: { $0.begin < $1.begin })
        var expectedResult: Data = Data()
        
        var i: UInt8 = 1
        for request in requests {
            let block = Data(repeating: i, count: request.length)
            communicator.delegate?.peer(communicator,
                                        sentPiece: request.index,
                                        begin: request.begin,
                                        block: block)
            i += 1
            expectedResult += block
        }
        
        XCTAssert(delegate.gotPieceAtIndexCalled)
        XCTAssert(delegate.gotPieceAtIndexParameters?.sender === sut)
        XCTAssertEqual(delegate.gotPieceAtIndexParameters?.index, pieceIndex)
        XCTAssertEqual(delegate.gotPieceAtIndexParameters?.piece, expectedResult)
    }
    
    // MARK: - Peer connection lost
    
    func test_delegateNotifiedOnPeerLost() {
        communicator.delegate?.peerLost(communicator)
        
        XCTAssert(delegate.peerLostCalled)
        XCTAssert(delegate.peerLostParameter === sut)
    }
    
    func test_delegateNotifiedFailedToGetPiece_whenPeerLost() {
        communicator.delegate?.peerBecameUnchoked(communicator)
        sut.downloadPiece(atIndex: pieceIndex, size: pieceSize)
        communicator.delegate?.peerLost(communicator)
        
        XCTAssert(delegate.failedToGetPieceAtIndexCalled)
        XCTAssert(delegate.failedToGetPieceAtIndexParameters?.sender === sut)
        XCTAssertEqual(delegate.failedToGetPieceAtIndexParameters?.index, pieceIndex)
    }
    
    // MARK: -
    
    func test_connectedFlag() {
        
        XCTAssertFalse(sut.connected)
        
        try! sut.connect(withHandshakeData: (clientId, bitField))
        XCTAssertTrue(sut.connected)
        
        sut.peerLost(communicator)
        XCTAssertFalse(sut.connected)
    }
    
    func test_sendsKeepAlive() {
        
        // Given
        sut.keepAliveFrequency = 0
        try! sut.connect(withHandshakeData: (clientId, bitField))
        
        // When
        communicator.delegate?.peerSentHandshake(communicator, sentHandshakeWithPeerId: peerId, onDHT: false)

        // Then
        let e = expectation(description: "Keep alive sent")
        communicator.onSendKeepAliveCalled = {
            self.communicator.onSendKeepAliveCalled = nil
            e.fulfill()
        }
        waitForExpectations(timeout: 0.1)
    }
    
    func test_disconnectsIfNoKeepAlive() {
        // Given
        sut.keepAliveTimeout = 0
        try! sut.connect(withHandshakeData: (clientId, bitField))
        
        // When
        communicator.delegate?.peerSentHandshake(communicator, sentHandshakeWithPeerId: peerId, onDHT: false)
        
        // Then
        let e = expectation(description: "Keep alive sent")
        DispatchQueue.main.async {
            XCTAssert(self.delegate.peerLostCalled)
            XCTAssertFalse(self.sut.connected)
            e.fulfill()
        }
        waitForExpectations(timeout: 0.2)
    }
    
    func test_staysConnectedIfKeepAliveSent() {
        // Given
        sut.keepAliveTimeout = 0
        try! sut.connect(withHandshakeData: (clientId, bitField))
        
        // When
        communicator.delegate?.peerSentHandshake(communicator, sentHandshakeWithPeerId: peerId, onDHT: false)
        sut.keepAliveTimeout = .infinity
        communicator.delegate?.peerSentKeepAlive(communicator)
        
        // Then
        let e = expectation(description: "Keep alive sent")
        DispatchQueue.main.async {
            XCTAssertFalse(self.delegate.peerLostCalled)
            e.fulfill()
        }
        waitForExpectations(timeout: 0.1)
    }
    
    func test_unchokeSentOnPeerInterested() {
        sut.peerBecameInterested(communicator)
        XCTAssert(communicator.sendUnchokeCalled)
    }
    
    // MARK: - Speed trackers
    
    func test_gotPieceRecordedInSpeedTracker() {
        communicator.sendRequestParameters = []
        communicator.delegate?.peer(communicator,
                                    sentPiece: pieceIndex,
                                    begin: 0,
                                    block: Data(repeating: 0, count: pieceSize))
        
        XCTAssertEqual(sut.downloadSpeedTracker.totalNumberOfBytes, pieceSize)
    }
}
