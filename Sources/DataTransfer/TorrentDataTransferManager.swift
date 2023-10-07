//
//  TorrentDataTransferManager.swift
//  
//
//  Created by Wynn Zhang on 8/29/23.
//

import Foundation

protocol TorrentDataTransferManagerDelegate: AnyObject {
    func torrentDataTransferManager(_ sender: TorrentDataTransferManager, downloadedPieceAtIndex pieceIndex: Int, with piece: Data, for conf: TorrentTaskConf)
    func torrentDataTransferManager(_ sender: TorrentDataTransferManager, failedToGetPieceAtIndex index: Int, for conf: TorrentTaskConf)
    func torrentDataTransferManagerNeedsMorePeers(_ sender: TorrentDataTransferManager, for conf: TorrentTaskConf)
    func torrentDataTransferManagerCurrentBitfieldForHandshake(_ sender: TorrentDataTransferManager, for conf: TorrentTaskConf) -> BitField
    func torrentDataTransferManager(_ sender: TorrentDataTransferManager, nextPieceFromAvailable availablePieces: BitField, for conf: TorrentTaskConf) -> TorrentPieceRequest?
    func torrentDataTransferManager(_ sender: TorrentDataTransferManager, peerRequiresPieceAtIndex index: Int, for conf: TorrentTaskConf) -> Data?
}

class TorrentDataTransferManager {
    weak var delegate: TorrentDataTransferManagerDelegate?
    var peerManagerDict: [TorrentTaskConf: TorrentPeerManager]
    
    init() {
        self.peerManagerDict = [:]
    }
    
    func setupDataTransferManager(for conf: TorrentTaskConf) {
        let manager = TorrentPeerManager(conf: conf)
        manager.delegate = self
        self.peerManagerDict[conf] = manager
    }
    
    func stopDataTransferManager(for conf: TorrentTaskConf) {
        self.peerManagerDict[conf]?.stopPeersConnection()
    }
    
    func resumeDataTransferManager(for conf: TorrentTaskConf) {
        self.peerManagerDict[conf]?.resumePeersConnections()
    }
    
    func removeDataTransferManager(for conf: TorrentTaskConf) {
        self.peerManagerDict.removeValue(forKey: conf)
    }
    
    func addNewPeer(with peer: TorrentPeer, for conf: TorrentTaskConf) {
        self.peerManagerDict[conf]?.addPeer(peer)
    }
    
    func addNewPeers(with peersInfo: [TorrentPeerInfo], for conf: TorrentTaskConf) {
        self.peerManagerDict[conf]?.addPeers(withInfo: peersInfo)
    }
    
    func getPeerCount(for conf: TorrentTaskConf) -> Int {
        let manager = peerManagerDict[conf]
        return manager?.peers.count ?? 0
    }
    
    func getDownloadSpeed(for conf: TorrentTaskConf) -> String {
        return peerManagerDict[conf]?.downloadSpeed ?? ""
    }
    
    func getUploadSpeed(for conf: TorrentTaskConf) -> String {
        return peerManagerDict[conf]?.uploadSpeed ?? ""
    }
    
    func getSeedsNumber(for conf: TorrentTaskConf) -> Int {
        return peerManagerDict[conf]?.numberOfConnectedSeeds ?? 0
    }
    
    func getPeerNumber(for conf: TorrentTaskConf) -> Int {
        return peerManagerDict[conf]?.numberOfConnectedPeers ?? 0
    }
}

extension TorrentDataTransferManager: TorrentPeerManagerDelegate {
    func torrentPeerManager(_ sender: TorrentPeerManager, downloadedPieceAtIndex pieceIndex: Int, piece: Data) {
        if let conf = findCorespondTaskConf(sender) {
            delegate?.torrentDataTransferManager(self, downloadedPieceAtIndex: pieceIndex, with: piece, for: conf)
        }
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, failedToGetPieceAtIndex index: Int) {
        if let conf = findCorespondTaskConf(sender) {
            delegate?.torrentDataTransferManager(self, failedToGetPieceAtIndex: index, for: conf)
        }
    }
    
    func torrentPeerManagerNeedsMorePeers(_ sender: TorrentPeerManager) {
        if let conf = findCorespondTaskConf(sender) {
            delegate?.torrentDataTransferManagerNeedsMorePeers(self, for: conf)
        }
    }
    
    func torrentPeerManagerCurrentBitfieldForHandshake(_ sender: TorrentPeerManager) -> BitField {
        if let conf = findCorespondTaskConf(sender), let delegate = self.delegate {
            return delegate.torrentDataTransferManagerCurrentBitfieldForHandshake(self, for: conf)
        } else {
            fatalError("TorrentDataTransferManager: can get current bitfield for handshake")
        }
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, nextPieceFromAvailable availablePieces: BitField) -> TorrentPieceRequest? {
        if let conf = findCorespondTaskConf(sender) {
            return delegate?.torrentDataTransferManager(self, nextPieceFromAvailable: availablePieces, for: conf)
        } else {
            return nil
        }
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, peerRequiresPieceAtIndex index: Int) -> Data? {
        if let conf = findCorespondTaskConf(sender) {
            return delegate?.torrentDataTransferManager(self, peerRequiresPieceAtIndex: index, for: conf)
        } else {
            return nil
        }
    }
    
    private func findCorespondTaskConf(_ sender: TorrentPeerManager) -> TorrentTaskConf? {
        for (key, value) in self.peerManagerDict {
            if value === sender {
                return key
            }
        }
        return nil
    }
}
