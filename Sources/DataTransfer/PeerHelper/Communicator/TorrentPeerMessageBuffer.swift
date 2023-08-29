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
    
    /// message buffer data format is `UInt32 + Data`, previous integer is the data length
    func appendData(_ data: Data) {
        messageBuffer = messageBuffer + data
        testIfBufferContainsCompletedMessage()
    }
    
    func testIfBufferContainsCompletedMessage() {
        guard messageBuffer.count >= 4 else {
            return
        }
        
        let startIndex = messageBuffer.startIndex
        let lengthPrefix = messageBuffer[startIndex..<startIndex+4]
        let expectedLength = Int(UInt32(data: lengthPrefix)) + 4
        
        if messageBuffer.count >= expectedLength {
            let messageEndIndex = messageBuffer.startIndex + expectedLength
            let message = messageBuffer[messageBuffer.startIndex..<messageEndIndex]
            delegate?.peerMessageBuffer(self, gotMessage: message)
            
            let newStartIndex = messageBuffer.startIndex + expectedLength, newEndIndex = messageBuffer.endIndex
            messageBuffer = messageBuffer[newStartIndex..<newEndIndex]
            testIfBufferContainsCompletedMessage()
        }
    }
}
