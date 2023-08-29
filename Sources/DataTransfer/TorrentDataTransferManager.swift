//
//  TorrentDataTransferManager.swift
//  
//
//  Created by Wynn Zhang on 8/29/23.
//

import Foundation

protocol TorrentDataTransferManagerDelegate: AnyObject {
    func torrentPeerManager(_ sender: TorrentDataTransferManager, downloadedPieceAtIndex pieceIndex: Int, with piece: Data, for conf: TorrentTaskConf)
    func torrentPeerManager(_ sender: TorrentDataTransferManager, failedToGetPieceAtIndex index: Int, for conf: TorrentTaskConf)
    func torrentPeerManagerNeedsMorePeers(_ sender: TorrentDataTransferManager, for conf: TorrentTaskConf)
    func torrentPeerManagerCurrentBitfieldForHandshake(_ sender: TorrentDataTransferManager, for conf: TorrentTaskConf) -> BitField
    func torrentPeerManager(_ sender: TorrentDataTransferManager, nextPieceFromAvailable availablePieces: BitField, for conf: TorrentTaskConf) -> TorrentPieceRequest?
    func torrentPeerManager(_ sender: TorrentDataTransferManager, peerRequiresPieceAtIndex index: Int, for conf: TorrentTaskConf) -> Data?
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
    
    func removeDataTransferManager(for conf: TorrentTaskConf) {
        self.peerManagerDict.removeValue(forKey: conf)
    }
}

extension TorrentDataTransferManager: TorrentPeerManagerDelegate {
    func torrentPeerManager(_ sender: TorrentPeerManager, downloadedPieceAtIndex pieceIndex: Int, piece: Data) {
        if let conf = findCorespondTaskConf(sender) {
            delegate?.torrentPeerManager(self, downloadedPieceAtIndex: pieceIndex, with: piece, for: conf)
        }
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, failedToGetPieceAtIndex index: Int) {
        if let conf = findCorespondTaskConf(sender) {
            delegate?.torrentPeerManager(self, failedToGetPieceAtIndex: index, for: conf)
        }
    }
    
    func torrentPeerManagerNeedsMorePeers(_ sender: TorrentPeerManager) {
        if let conf = findCorespondTaskConf(sender) {
            delegate?.torrentPeerManagerNeedsMorePeers(self, for: conf)
        }
    }
    
    func torrentPeerManagerCurrentBitfieldForHandshake(_ sender: TorrentPeerManager) -> BitField {
        if let conf = findCorespondTaskConf(sender), let delegate = self.delegate {
            return delegate.torrentPeerManagerCurrentBitfieldForHandshake(self, for: conf)
        } else {
            fatalError("TorrentDataTransferManager: can get current bitfield for handshake")
        }
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, nextPieceFromAvailable availablePieces: BitField) -> TorrentPieceRequest? {
        if let conf = findCorespondTaskConf(sender) {
            return delegate?.torrentPeerManager(self, nextPieceFromAvailable: availablePieces, for: conf)
        } else {
            return nil
        }
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, peerRequiresPieceAtIndex index: Int) -> Data? {
        if let conf = findCorespondTaskConf(sender) {
            return delegate?.torrentPeerManager(self, peerRequiresPieceAtIndex: index, for: conf)
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
