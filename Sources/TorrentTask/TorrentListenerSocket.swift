//
//  TorrentListenerSocket.swift
//  
//
//  Created by Wynn Zhang on 8/24/23.
//

import Foundation
import CocoaAsyncSocket

protocol TorrentListenerSocketDelegate: AnyObject {
    func torrentListenSocket(_ torrentSocket: TorrentListenerSocket, connectedToPeer peer: TorrentPeer, for infoHash: Data)
    func getTorrentTaskInfo(for torrentSocket: TorrentListenerSocket, of infoHash: Data) -> (id: Data, progress: BitField)?
}

/// Listen for incoming BitTorrent connection from remote peers who try to join the swarm that has the specific torrent info hash
class TorrentListenerSocket: NSObject {
    weak var delegate: TorrentListenerSocketDelegate?
    
    var listenSocket: GCDAsyncSocket!
    static let LISTEN_PORT_RANGE = Range<UInt16>(6881...6889)
    
    var acceptedSockets: [GCDAsyncSocket] = []
    
    override init() {
        super.init()
        self.listenSocket = GCDAsyncSocket(delegate: self, delegateQueue: .main)
    }
    
    deinit {
        listenSocket.delegate = nil
        listenSocket.disconnect()
    }
    
    func startListening() {
        for port in Self.LISTEN_PORT_RANGE {
            if tryToListen(on: port) {
                break
            }
            
            if port == Self.LISTEN_PORT_RANGE.upperBound {
                print("Error: Can't find proper port to listening!")
            }
        }
    }
    
    private func tryToListen(on port: UInt16) -> Bool {
        do {
            try listenSocket.accept(onPort: port)
            return true
        } catch _ {
            return false
        }
    }
    
    func resumeListening() {
        self.startListening()
    }
    
    func stopListening() {
        listenSocket.disconnect()
    }
    
    var port: UInt16 {
        listenSocket.localPort
    }
}

extension TorrentListenerSocket: GCDAsyncSocketDelegate {
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        self.acceptedSockets.append(newSocket)
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        // make sure current socket is connected
        guard let item = self.acceptedSockets.first(where: { $0 == sock }) else {
            return
        }
        // make sure we can parse handshake data from the read data
        guard let infoHash = parseHandshakeInfo(received: data) else {
            return
        }
        // make sure we have the torrent
        guard let taskInfo = delegate?.getTorrentTaskInfo(for: self, of: infoHash) else {
            return
        }
        
        let peerInfo = TorrentPeerInfo(ip: item.connectedHost!, port: item.connectedPort)
        let tcpConnection = TCPConnection(socket: item)
        let communicator = TorrentPeerCommunicator(peerInfo: peerInfo, infoHash: infoHash, tcpConnection: tcpConnection)
        let peer = TorrentPeer(peerInfo: peerInfo, bitFieldSize: taskInfo.progress.size, communicator: communicator)
        try? peer.connect(withHandshakeData: (clientId: taskInfo.id, bitField: taskInfo.progress))
        
        delegate?.torrentListenSocket(self, connectedToPeer: peer, for: infoHash)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        if let index = self.acceptedSockets.firstIndex(of: sock) {
            self.acceptedSockets.remove(at: index)
        }
    }
    
    /// parse income data, check if it's bittorrent handshake
    ///
    /// - Parameter data: data received from incoming connection
    ///
    /// - Returns: the remote peer interested torrent's info hash
    private func parseHandshakeInfo(received data: Data) -> Data? {
        guard data.count >= 48 else {
            return nil
        }
        
        let startIndex = data.startIndex
        
        // check protocol
        let protocolStringBytes = data[(startIndex+1)..<(startIndex+20)]
        let protocolString = String(data: protocolStringBytes, encoding: .ascii)
        guard protocolString == "BitTorrent protocol" else {
            return nil
        }
        
        let infoHash = data[(startIndex+28)..<(startIndex+48)]
        return infoHash
    }
}
