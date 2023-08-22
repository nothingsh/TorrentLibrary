//
//  TorrentPeerMessageBufferTests.swift
//  
//
//  Created by Wynn Zhang on 8/21/23.
//

import XCTest
@testable import TorrentLibrary

class TorrentPeerMessageBufferDelegateStub: TorrentPeerMessageBufferDelegate {
    var gotMessageCalled = false
    var gotMessageCallCount = 0
    var gotMessageParameters: (sender: TorrentPeerMessageBuffer, message: Data)?
    var previousMessages: [Data] = []
    func peerMessageBuffer(_ sender: TorrentPeerMessageBuffer, gotMessage message: Data) {
        gotMessageCalled = true
        gotMessageCallCount += 1
        previousMessages.append(message)
        gotMessageParameters = (sender, message)
    }
}

final class TorrentPeerMessageBufferTests: XCTestCase {
    var delegate: TorrentPeerMessageBufferDelegateStub!
    var sut: TorrentPeerMessageBuffer!
    
    override func setUp() {
        super.setUp()
        
        delegate = TorrentPeerMessageBufferDelegateStub()
        sut = TorrentPeerMessageBuffer()
        sut.delegate = delegate
    }
    
    func test_delegateNotCalledUntilMessageLengthIsCorrect() {
        let lengthPrefixOf5Bytes = UInt32(5).toData()
        let incompleteData = Data([1,2,3])
        let data = lengthPrefixOf5Bytes + incompleteData
        sut.appendData(data)
        
        XCTAssertFalse(delegate.gotMessageCalled)
    }
    
    func test_delegateNotCalledIfMessageLengthIsNotYetKnown() {
        let incompleteLengthPrefix = Data([0, 0])
        sut.appendData(incompleteLengthPrefix)
        XCTAssertFalse(delegate.gotMessageCalled)
    }
    
    func test_canProcessKeepAliveMessage() {
        // Length prefix saying message is 0 bytes
        let keepAliveMessage = UInt32(0).toData()
        sut.appendData(keepAliveMessage)
        XCTAssert(delegate.gotMessageCalled)
        XCTAssert(delegate.gotMessageParameters?.sender === sut)
        XCTAssertEqual(delegate.gotMessageParameters?.message, keepAliveMessage)
    }
    
    func test_delegateCalledOnAppendingCompleteMessage() {
        let lengthPrefixOf5Bytes = UInt32(5).toData()
        let data = Data([1,2,3,4,5])
        let completeMessage = lengthPrefixOf5Bytes + data
        
        sut.appendData(completeMessage)
        
        XCTAssert(delegate.gotMessageCalled)
        XCTAssert(delegate.gotMessageParameters?.sender === sut)
        XCTAssertEqual(delegate.gotMessageParameters?.message, completeMessage)
    }
    
    func test_delegateCalledOnAppendingFinalBitOfMessage() {
        let dataPart1 = UInt32(5).toData() + Data([1,2,3])
        let dataPart2 = Data([4,5])
        
        sut.appendData(dataPart1)
        sut.appendData(dataPart2)
        
        XCTAssert(delegate.gotMessageCalled)
        XCTAssert(delegate.gotMessageParameters?.sender === sut)
        XCTAssertEqual(delegate.gotMessageParameters?.message, dataPart1 + dataPart2)
    }
    
    func test_canGetMultipleMessagesSequentially() {
        let message1 = UInt32(5).toData() + Data([1,2,3,4,5])
        let message2 = UInt32(2).toData() + Data([6,7])
        
        sut.appendData(message1)
        XCTAssert(delegate.gotMessageCalled)
        XCTAssert(delegate.gotMessageParameters?.sender === sut)
        XCTAssertEqual(delegate.gotMessageParameters?.message, message1)
        
        delegate.gotMessageCalled = false
        delegate.gotMessageParameters = nil
        
        sut.appendData(message2)
        XCTAssert(delegate.gotMessageCalled)
        XCTAssert(delegate.gotMessageParameters?.sender === sut)
        XCTAssertEqual(delegate.gotMessageParameters?.message, message2)
    }
    
    func test_canAppendEndOfOneMessage_andStartOfTheNext() {
        let message1 = UInt32(2).toData() + Data([6,7])
        let message2 = UInt32(5).toData() + Data([1,2,3,4,5])
        
        var data1 = UInt32(2).toData() + Data([6,7])
        data1 = data1 + UInt32(5).toData() + Data([1,2])
        
        let data2 = Data([3,4,5])
        
        sut.appendData(data1)
        XCTAssert(delegate.gotMessageCalled)
        XCTAssert(delegate.gotMessageParameters?.sender === sut)
        XCTAssertEqual(delegate.gotMessageParameters?.message, message1)
        
        delegate.gotMessageCalled = false
        delegate.gotMessageParameters = nil
        
        sut.appendData(data2)
        XCTAssert(delegate.gotMessageCalled)
        XCTAssert(delegate.gotMessageParameters?.sender === sut)
        XCTAssertEqual(delegate.gotMessageParameters?.message, message2)
    }
    
    func test_canGetMultipleMessagesAtOnce() {
        let message1 = UInt32(5).toData() + Data([1,2,3,4,5])
        let message2 = UInt32(2).toData() + Data([6,7])
        
        let combined = message1 + message2
        
        sut.appendData(combined)
        XCTAssertEqual(delegate.gotMessageCallCount, 2)
        XCTAssertEqual(delegate.previousMessages.first!, message1)
        XCTAssertEqual(delegate.previousMessages.last!, message2)
    }
}
