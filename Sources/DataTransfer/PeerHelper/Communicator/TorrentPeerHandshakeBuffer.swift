//
//  TorrentPeerHandshakeBuffer.swift
//  
//
//  Created by Wynn Zhang on 7/1/23.
//

import Foundation

enum TorrentPeerHandshakeBufferError: Error {
    case protocolMismatch
    case infoHashMismatch
    case peerIdMismatch
}

protocol TorrentPeerHandshakeDelegate: AnyObject {
    func peerHandshakeMessageBuffer(_ sender: TorrentPeerHandshakeBuffer, gotBadHandshake error: TorrentPeerHandshakeBufferError)
    func peerHandshakeMessageBuffer(_ sender: TorrentPeerHandshakeBuffer, gotHandshakeWithPeerId peerID: Data, remainingBuffer: Data, onDHT: Bool)
}

class TorrentPeerHandshakeBuffer {
    weak var delegate: TorrentPeerHandshakeDelegate?
    
    let expectedInfoHash: Data
    let expectedPeerID: Data?
    private var handshakeBuffer = Data()
    
    init(infoHash: Data, peerID: Data?) {
        self.expectedInfoHash = infoHash
        self.expectedPeerID = peerID
    }
    
    func appendData(_ data: Data) {
        handshakeBuffer = handshakeBuffer + data
        
        guard handshakeBuffer.count > 0 else { return}
        
        let startIndex = handshakeBuffer.startIndex
        let pstrLen = handshakeBuffer[startIndex]
        
        guard pstrLen == 19 else {
            delegate?.peerHandshakeMessageBuffer(self, gotBadHandshake: .protocolMismatch)
            return
        }
        
        guard handshakeBuffer.count >= 20 else {
            return
        }
        
        let protocolStringBytes = handshakeBuffer[(startIndex+1)..<(startIndex+20)]
        let protocolString = String(data: protocolStringBytes, encoding: .ascii)
        guard protocolString == "BitTorrent protocol" else {
            delegate?.peerHandshakeMessageBuffer(self, gotBadHandshake: .protocolMismatch)
            return
        }
        
        guard handshakeBuffer.count >= 48 else {
            return
        }
        
        let infoHash = handshakeBuffer[(startIndex+28)..<(startIndex+48)]
        
        guard infoHash == expectedInfoHash else {
            delegate?.peerHandshakeMessageBuffer(self, gotBadHandshake: .infoHashMismatch)
            return
        }
        
        guard handshakeBuffer.count >= 68 else {
            return
        }
        
        let peerId = Data(handshakeBuffer[(startIndex+48)..<(startIndex+68)])
        
        guard expectedPeerID == nil || peerId == expectedPeerID else {
            delegate?.peerHandshakeMessageBuffer(self, gotBadHandshake: .peerIdMismatch)
            return
        }
        
        let reservedBytes = Data(handshakeBuffer[(startIndex+20)..<(startIndex+28)])
        let onDHT = (reservedBytes[reservedBytes.startIndex+7] & UInt8(1)) == 1
        let remainingBytes = Data(handshakeBuffer[(startIndex+68)..<handshakeBuffer.endIndex])
        
        delegate?.peerHandshakeMessageBuffer(self, gotHandshakeWithPeerId: peerId, remainingBuffer: remainingBytes, onDHT: onDHT)
    }
}
