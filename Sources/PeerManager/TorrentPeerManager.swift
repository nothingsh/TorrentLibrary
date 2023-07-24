//
//  TorrentPeerManager.swift
//  
//
//  Created by Wynn Zhang on 7/1/23.
//

import Foundation

protocol TorrentPeerManagerDelegate: AnyObject {
    func torrentPeerManager(_ sender: TorrentPeerManager, downloadedPieceAtIndex pieceIndex: Int, piece: Data)
    func torrentPeerManager(_ sender: TorrentPeerManager, failedToGetPieceAtIndex index: Int)
    func torrentPeerManagerNeedsMorePeers(_ sender: TorrentPeerManager)
    func torrentPeerManagerCurrentBitfieldForHandshake(_ sender: TorrentPeerManager) -> BitField
    func torrentPeerManager(_ sender: TorrentPeerManager, nextPieceFromAvailable availablePieces: BitField) -> TorrentPieceRequest?
    func torrentPeerManager(_ sender: TorrentPeerManager, peerRequiresPieceAtIndex index: Int) -> Data?
}

class TorrentPeerManager {
    var maximumNumberOfConnectedPeers = 20 // variable for testing
    var minimumNumberOfConnectedPeers = 5  // variable for testing
    let maximumNumberOfPiecesPerPeer = 2
    
    weak var delegate: TorrentPeerManagerDelegate?
    
    let clientID: Data
    let infoHash: Data
    let bitFieldSize: Int
    
    private(set) var peers: [TorrentPeer] = []
    var numberOfConnectedPeers: Int {
        return peers.filter({ $0.connected }).count
    }
    var numberOfConnectedSeeds: Int {
        return peers.filter({ $0.connected && $0.currentProgress.complete }).count
    }
    
    private(set) var downloadSpeedTracker: NetworkSpeedTrackable!
    
    init(clientID: Data, infoHash: Data, bitFieldSize: Int) {
        self.clientID = clientID
        self.infoHash = infoHash
        self.bitFieldSize = bitFieldSize
        self.downloadSpeedTracker = CombinedNetworkSpeedTracker { [unowned self] in
            return self.peers.map { $0.downloadSpeedTracker }
        }
    }
    
    // Exposed for testing
    var peerFactory = TorrentPeer.init(peerInfo: infoHash: bitFieldSize:)
    
    func addPeers(withInfo peerInfos: [TorrentPeerInfo]) {
        let newPeers = peerInfos.map { (peerInfo: TorrentPeerInfo) -> TorrentPeer in
            let result = peerFactory(peerInfo, infoHash, bitFieldSize)
            return result
        }
        peers.append(contentsOf: newPeers)
        connectToPeersIfNeeded(peers: newPeers)
    }
    
    func addPeer(_ peer: TorrentPeer) {
        peer.delegate = self
        peers.append(peer)
    }
    
    fileprivate func connectToPeersIfNeeded(peers: [TorrentPeer]) {
        
        guard let delegate = delegate else { return }
        
        let max = maximumNumberOfConnectedPeers - numberOfConnectedPeers
        let numberToConnectTo = min(max, peers.count)
        
        let bitField = delegate.torrentPeerManagerCurrentBitfieldForHandshake(self)
        let peersToConnectTo = peers[0 ..< numberToConnectTo]
        connectToPeers(peersToConnectTo, bitField: bitField)
        if numberOfConnectedPeers < minimumNumberOfConnectedPeers {
            delegate.torrentPeerManagerNeedsMorePeers(self)
        }
    }
    
    // Using sequence to allow array slices
    private func connectToPeers<T: Sequence>(_ peers: T, bitField: BitField) where T.Element == TorrentPeer {
        for peer in peers {
            peer.delegate = self
            do {
                try peer.connect(withHandshakeData: (clientId: clientID, bitField: bitField))
            } catch let error {
                print("Unable to create new TCP socket. Error: \(error)")
            }
        }
    }
}

extension TorrentPeerManager: TorrentPeerDelegate {
    private var disconnectedPeers: [TorrentPeer] {
        return peers.filter { !$0.connected }
    }
    
    func peerHasNewAvailablePieces(_ sender: TorrentPeer) {
        if sender.numberOfPiecesDownloading < maximumNumberOfPiecesPerPeer {
            requestNextPiece(from: sender)
        }
    }
    
    func peerLost(_ sender: TorrentPeer) {
        guard let index = peers.firstIndex(where: { $0 === sender }) else { return }
        peers.remove(at: index)
        connectToPeersIfNeeded(peers: disconnectedPeers)
        print("Info: Lost Peer: \(sender.peerInfo.ip):\(sender.peerInfo.port)")
    }
    
    func peer(_ sender: TorrentPeer, gotPieceAtIndex index: Int, piece: Data) {
        delegate?.torrentPeerManager(self, downloadedPieceAtIndex: index, piece: piece)
        requestNextPiece(from: sender)
        // TODO: send have to peers
    }
    
    func peer(_ sender: TorrentPeer, failedToGetPieceAtIndex index: Int) {
        delegate?.torrentPeerManager(self, failedToGetPieceAtIndex: index)
    }
    
    func peer(_ sender: TorrentPeer, requestedPieceAtIndex index: Int) -> Data? {
        return delegate?.torrentPeerManager(self, peerRequiresPieceAtIndex: index)
    }
    
    // MARK: -
    
    private func requestNextPiece(from peer: TorrentPeer) {
        if let pieceRequest = delegate?.torrentPeerManager(self, nextPieceFromAvailable: peer.currentProgress) {
            peer.downloadPiece(atIndex: pieceRequest.pieceIndex, size: pieceRequest.size)
        }
    }
}
