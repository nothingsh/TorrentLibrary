//
//  TorrentListenerSocket.swift
//  
//
//  Created by Wynn Zhang on 8/24/23.
//

import Foundation
import CocoaAsyncSocket

protocol TorrentListenerSocketDelegate: AnyObject {
    func torrentListenSocket(_ torrentSocket: TorrentListenerSocket, connectedToPeer peer: TorrentPeer)
    func currentProgress(for torrentSocket: TorrentListenerSocket) -> BitField
}

class TorrentListenerSocket: NSObject {
    weak var delegate: TorrentListenerSocketDelegate?
    
    var listenSocket: GCDAsyncSocket!
    let infoHash: Data
    let clientID: Data
    let port: UInt16 = TorrentTrackerManager.DEFAULT_PORT
    
    init(infoHash: Data, clientID: Data) {
        self.infoHash = infoHash
        self.clientID = clientID
        super.init()
        self.listenSocket = GCDAsyncSocket(delegate: self, delegateQueue: .main)
    }
    
    deinit {
        listenSocket.delegate = nil
        listenSocket.disconnect()
    }
    
    func startListening() {
        do {
            try listenSocket.accept(onPort: port)
        } catch _ {
            print("ERROR: Couldn't listen on port to accept incoming peers")
        }
    }
    
    func resumeListening() {
        self.startListening()
    }
    
    func stopListening() {
        listenSocket.disconnect()
    }
}

extension TorrentListenerSocket: GCDAsyncSocketDelegate {
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        guard let delegate = self.delegate else {
            return
        }
        
        let peerInfo = TorrentPeerInfo(ip: newSocket.connectedHost!, port: newSocket.connectedPort)
        let tcpConnection = TCPConnection(socket: newSocket)
        let communicator = TorrentPeerCommunicator(peerInfo: peerInfo, infoHash: infoHash, tcpConnection: tcpConnection)
        let currentProgress = delegate.currentProgress(for: self)
        let peer = TorrentPeer(peerInfo: peerInfo, bitFieldSize: currentProgress.size, communicator: communicator)
        try! peer.connect(withHandshakeData: (clientId: clientID, bitField: currentProgress))
        
        delegate.torrentListenSocket(self, connectedToPeer: peer)
    }
}
