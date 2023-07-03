//
//  TorrentPeerMessageBuffer.swift
//  
//
//  Created by Wynn Zhang on 7/1/23.
//

import Foundation

protocol TorrentPeerMessageBufferDelegate: AnyObject {
    func peerMessageBuffer(_ sender: TorrentPeerMessageBuffer, gotMessage data: Data)
}

class TorrentPeerMessageBuffer {
    weak var delegate: TorrentPeerMessageBufferDelegate?
    
    private var messageBuffer = Data()
    
    func appendData(_ data: Data) {
        messageBuffer = messageBuffer + data
        testIfBufferContainsCompletedMessage()
    }
    
    func testIfBufferContainsCompletedMessage() {
        guard messageBuffer.count >= 4 else {
            return
        }
        
        let lengthPrefixEndIndex = messageBuffer.startIndex + 4
        let lengthPrefix = messageBuffer[messageBuffer.startIndex..<lengthPrefixEndIndex]
        let expectedLength = Int(try! UInt32(data: lengthPrefix)) + 4
        
        if messageBuffer.count >= expectedLength {
            let messageEndIndex = messageBuffer.startIndex + expectedLength
            let message = messageBuffer[messageBuffer.startIndex..<messageEndIndex]
            delegate?.peerMessageBuffer(self, gotMessage: message)
            
            let newStartIndex = expectedLength, newEndIndex = messageBuffer.endIndex
            messageBuffer = messageBuffer[newStartIndex..<newEndIndex]
            testIfBufferContainsCompletedMessage()
        }
    }
}
