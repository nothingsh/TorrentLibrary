//
//  TorrentPeerCommunicator.swift
//  
//
//  Created by Wynn Zhang on 7/1/23.
//

import Foundation

protocol TorrentPeerCommunicatorDelegate: AnyObject {
    func peerConnected(_ sender: TorrentPeerCommunicator)
    func peerLost(_ sender: TorrentPeerCommunicator)
    
    func peerSentHandshake(_ sender: TorrentPeerCommunicator, sentHandshakeWithPeerId peerId: Data, onDHT: Bool)
    func peerSentKeepAlive(_ sender: TorrentPeerCommunicator)
    func peerBecameChoked(_ sender: TorrentPeerCommunicator)
    func peerBecameUnchoked(_ sender: TorrentPeerCommunicator)
    func peerBecameInterested(_ sender: TorrentPeerCommunicator)
    func peerBecameUninterested(_ sender: TorrentPeerCommunicator)
    func peer(_ sender: TorrentPeerCommunicator, hasPiece piece: Int)
    func peer(_ sender: TorrentPeerCommunicator, hasBitFieldData bitFieldData: Data)
    func peer(_ sender: TorrentPeerCommunicator, requestedPiece index: Int, begin: Int, length: Int)
    func peer(_ sender: TorrentPeerCommunicator, sentPiece index: Int, begin: Int, block: Data)
    func peer(_ sender: TorrentPeerCommunicator, cancelledRequestedPiece index: Int, begin: Int, length: Int)
    func peer(_ sender: TorrentPeerCommunicator, onDHTPort port:Int)
    
    func peerSentMalformedMessage(_ sender: TorrentPeerCommunicator)
}

class TorrentPeerCommunicator {
    enum Message: String, CaseIterable {
        case choke, unchoke, interested, notInterested, have, bitfield, request, piece, cancel, port
        
        var stringValue: String {
            return self.rawValue
        }
        
        var uInt8Value: UInt8 {
            return UInt8(Message.allCases.firstIndex(of: self)!)
        }
        
        init?(_ uInt8: UInt8) {
            guard 0 <= uInt8 && uInt8 < UInt8(Message.allCases.count) else {
               return nil
            }
            self = Message.allCases[Int(uInt8)]
        }
    }
    
    let defaultTimeout: TimeInterval = 10
    
    weak var delegate: TorrentPeerCommunicatorDelegate?
    
    var connected: Bool {
        return connection.connected
    }
    
    private let peerInfo: TorrentPeerInfo
    private let connection: TCPConnection
    
    fileprivate let infoHash: Data
    
    fileprivate var handshakeReceived = false
    fileprivate let handshakeMessageBuffer: TorrentPeerHandshakeBuffer
    fileprivate let messageBuffer: TorrentPeerMessageBuffer
    
    init(peerInfo: TorrentPeerInfo, infoHash: Data, tcpConnection: TCPConnection = TCPConnection()) {
        self.peerInfo = peerInfo
        self.connection = tcpConnection
        self.infoHash = infoHash
        self.handshakeMessageBuffer = TorrentPeerHandshakeBuffer(infoHash: infoHash, peerID: peerInfo.peerID)
        self.messageBuffer = TorrentPeerMessageBuffer()
        
        self.connection.delegate = self
        self.handshakeMessageBuffer.delegate = self
        self.messageBuffer.delegate = self
        
        self.connection.readData(withTimeout: -1, tag: 0)
    }
    
    func connect() throws {
        try connection.connect(to: peerInfo.ip, onPort: peerInfo.port)
    }
    
    // MARK: - Writing messages

    func sendHandshake(for clientID: Data, _ completion: (()->Void)? = nil) {
        print("Info: Send handshake")
        
        let protocolString = "BitTorrent protocol"
        let protocolStringLength = UInt8(protocolString.count)
        
        /// protocol string length, protocol string, 8 reserved bytes, info_hash, peer_id of the current user
        let payload = protocolStringLength.toData() +
                    protocolString.data(using: .ascii)! +
                    Data([0,0,0,0,0,0,0,0]) +
                    infoHash +
                    clientID
        
        connection.write(payload, withTimeout: defaultTimeout, completion: completion)
    }
    
    func sendKeepAlive(_ completion: (()->Void)? = nil) {
        print("Info: sendKeepAlive")
        /// 0 length message
        let keepAlivePayload = Data([0, 0, 0, 0])
        connection.write(keepAlivePayload, withTimeout: defaultTimeout, completion: completion)
    }
    
    func sendChoke(_ completion: (()->Void)? = nil) {
        print("Info: Send choke")
        
        let payload = makePayload(forMessage: .choke)
        connection.write(payload, withTimeout: defaultTimeout, completion: completion)
    }
    
    func sendUnchoke(_ completion: (()->Void)? = nil) {
        print("Info: Send Unchoke")
        
        let payload = makePayload(forMessage: .unchoke)
        connection.write(payload, withTimeout: defaultTimeout, completion: completion)
    }
    
    func sendInterested(_ completion: (()->Void)? = nil) {
        print("Info: Send Interested")
        
        let payload = makePayload(forMessage: .interested)
        connection.write(payload, withTimeout: defaultTimeout, completion: completion)
    }
    
    func sendNotInterested(_ completion: (()->Void)? = nil) {
        print("Info: Send not interested")
        
        let payload = makePayload(forMessage: .notInterested)
        connection.write(payload, withTimeout: defaultTimeout, completion: completion)
    }
    
    func sendHavePiece(at index: Int, _ completion: (()->Void)? = nil) {
        print("Info: Send have piece")
        
        let data = UInt32(index).toData()
        let payload = makePayload(forMessage: .have, data: data)
        connection.write(payload, withTimeout: defaultTimeout, completion: completion)
    }
    
    func sendBitField(_ bitField: BitField, _ completion: (()->Void)? = nil) {
        print("Info: Send Bit Field")
        
        let data = bitField.toData()
        let payload = makePayload(forMessage: .bitfield, data: data)
        connection.write(payload, withTimeout: defaultTimeout, completion: completion)
    }
    
    func sendRequest(fromPieceAtIndex index: Int, begin: Int, length: Int, _ completion: (()->Void)? = nil) {
        print("Info: Send Request for piece at index: \(index) begin: \(begin)")
        
        let data = UInt32(index).toData() + UInt32(begin).toData() + UInt32(length).toData()
        let payload = makePayload(forMessage: .request, data: data)
        connection.write(payload, withTimeout: defaultTimeout, completion: completion)
    }
    
    func sendPiece(fromPieceAtIndex index: Int, begin: Int, block: Data, _ completion: (()->Void)? = nil) {
        print("Info: Send Piece index: \(index) begin: \(begin)")
        
        let data = UInt32(index).toData() + UInt32(begin).toData() + block
        let payload = makePayload(forMessage: .piece, data: data)
        connection.write(payload, withTimeout: defaultTimeout, completion: completion)
    }
    
    func sendCancel(forPieceAtIndex index: Int, begin: Int, length: Int, _ completion: (()->Void)? = nil) {
        print("Info: Send Cancel for piece at index: \(index) begin: \(begin)")
        
        let data = UInt32(index).toData() + UInt32(begin).toData() + UInt32(length).toData()
        let payload = makePayload(forMessage: .cancel, data: data)
        connection.write(payload, withTimeout: defaultTimeout, completion: completion)
    }
    
    func sendPort(_ listenPort: UInt16, _ completion: (()->Void)? = nil) {
        // TODO: implement with DHT peer discovery
    }
    
    // MARK -
    
    func makePayload(forMessage message: Message, data: Data? = nil) -> Data {
        let data = data ?? Data()
        let length = UInt32(data.count + 1)
        return length.toData() + message.uInt8Value.toData() + data
    }
}

// MARK: - Reading messages

extension TorrentPeerCommunicator: TCPConnectionDelegate {
    func tcpConnection(_ sender: TCPConnection, didConnectToHost host: String, port: UInt16) {
        delegate?.peerConnected(self)
        connection.readData(withTimeout: -1, tag: 0)
    }
    
    func tcpConnection(_ sender: TCPConnection, didRead data: Data, withTag tag: Int) {
        if !handshakeReceived {
            handshakeMessageBuffer.appendData(data)
        } else {
            messageBuffer.appendData(data)
        }
        
        connection.readData(withTimeout: -1, tag: 0)
    }
    
    func tcpConnection(_ sender: TCPConnection, didWriteDataWithTag tag: Int) {
        
    }
    
    func tcpConnection(_ sender: TCPConnection, disconnectedWithError error: Error?) {
        // This was in my previous implementation, not sure why - never used:
        // let connectionWasRefused = (error == nil) || error.code == 61
        delegate?.peerLost(self)
    }
}

// MARK: Handle Handshake

extension TorrentPeerCommunicator: TorrentPeerHandshakeDelegate {
    func peerHandshakeMessageBuffer(_ sender: TorrentPeerHandshakeBuffer, gotBadHandshake error: TorrentPeerHandshakeBufferError) {
        delegate?.peerSentMalformedMessage(self)
    }
    
    func peerHandshakeMessageBuffer(_ sender: TorrentPeerHandshakeBuffer, gotHandshakeWithPeerId peerID: Data, remainingBuffer: Data, onDHT: Bool) {
        handshakeReceived = true
        delegate?.peerSentHandshake(self, sentHandshakeWithPeerId: peerID, onDHT: onDHT)
        messageBuffer.appendData(remainingBuffer)
    }
}

// MARK: Handle Message Buffer

extension TorrentPeerCommunicator: TorrentPeerMessageBufferDelegate {
    func peerMessageBuffer(_ sender: TorrentPeerMessageBuffer, gotMessage data: Data) {
        guard data.count > 4 else {
            print("Info: Got keep alive")
            delegate?.peerSentKeepAlive(self)
            return
        }
        
        guard let message = Message(data[data.startIndex + 4]) else {
            print("Info: Peer sent malformed message")
            delegate?.peerSentMalformedMessage(self)
            return
        }
        
        print("Info: Got Message from peer: \(message.stringValue)")
        
        switch message {
        case .choke:
            delegate?.peerBecameChoked(self)
            break
        case .unchoke:
            delegate?.peerBecameUnchoked(self)
            break
        case .interested:
            delegate?.peerBecameInterested(self)
            break
        case .notInterested:
            delegate?.peerBecameUninterested(self)
            break
        case .have:
            processHasPieceMessage(data)
            break
        case .bitfield:
            processBitFieldMessage(data)
            break
        case .request:
            processRequestMessage(data)
            break
        case .piece:
            processSentPieceMessage(data)
            break
        case .cancel:
            processCancelRequestMessage(data)
            break
        case .port:
            // TODO: implement with DHT peer discovery
            return
        }
    }
    
    private func processHasPieceMessage(_ message: Data) {
        let startIndex = message.startIndex + 5, endIndex = message.startIndex + 9
        
        do {
            let pieceIndex = Int(try UInt32(data: message[startIndex..<endIndex]))
            delegate?.peer(self, hasPiece: pieceIndex)
        } catch {
            print("Error: unable to process has piece message - \(error.localizedDescription)")
        }
    }
    
    private func processBitFieldMessage(_ message: Data) {
        let startIndex = message.startIndex + 5, endIndex = message.endIndex
        let bitFieldData = message[startIndex..<endIndex]
        delegate?.peer(self, hasBitFieldData: bitFieldData)
    }
    
    private func processRequestMessage(_ message: Data) {
        let index0 = message.startIndex + 5, index1 = message.startIndex + 9
        let index2 = message.startIndex + 13, index3 = message.startIndex + 17
        
        do {
            let pieceIndex = Int(try UInt32(data: message[index0..<index1]))
            let begin = Int(try UInt32(data: message[index1..<index2]))
            let length = Int(try UInt32(data: message[index2..<index3]))
            delegate?.peer(self, requestedPiece: pieceIndex, begin: begin, length: length)
        } catch {
            print("Error: unable to process requst message - \(error.localizedDescription)")
        }
    }
    
    private func processSentPieceMessage(_ message: Data) {
        let index0 = message.startIndex + 5, index1 = message.startIndex + 9, index2 = message.startIndex + 13
        
        do {
            let pieceIndex = Int(try UInt32(data: message[index0..<index1]))
            let begin = Int(try UInt32(data: message[index1..<index2]))
            let block = message[index2..<message.endIndex]
            delegate?.peer(self, sentPiece: pieceIndex, begin: begin, block: block)
        } catch {
            print("Error: unable to process sent piece message - \(error.localizedDescription)")
        }
    }
    
    private func processCancelRequestMessage(_ message: Data) {
        let index0 = message.startIndex + 5, index1 = message.startIndex + 9
        let index2 = message.startIndex + 13, index3 = message.startIndex + 17
        
        do {
            let pieceIndex = Int(try UInt32(data: message[index0..<index1]))
            let begin = Int(try UInt32(data: message[index1..<index2]))
            let length = Int(try UInt32(data: message[index2..<index3]))
            delegate?.peer(self, cancelledRequestedPiece: pieceIndex, begin: begin, length: length)
        } catch {
            print("Error: unable to process cancel request message - \(error.localizedDescription)")
        }
    }
}

