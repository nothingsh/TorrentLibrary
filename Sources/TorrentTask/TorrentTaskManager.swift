//
//  TorrentTaskManager.swift
//  
//
//  Created by Wynn Zhang on 8/29/23.
//

import Foundation
import TorrentModel

public enum TorrentTaskManagerError: Error {
    case alreadyHaveCurrentTorrent
}

public enum TorrentTaskStatus {
    case started, stopped, completed, error
}

public class TorrentTaskManager {
    public var torrentList: Array<(conf: TorrentTaskConf, status: TorrentTaskStatus)>

    var listenerSocket: TorrentListenerSocket
    var peerProvider: TorrentPeerProviderManager
    var transferManager: TorrentDataTransferManager
    var progressManager: TorrentProgressManager
    
    public init() {
        self.torrentList = []
        self.listenerSocket = TorrentListenerSocket()
        self.peerProvider = try! TorrentPeerProviderManager()
        self.transferManager = TorrentDataTransferManager()
        self.progressManager = TorrentProgressManager()
        
        self.listenerSocket.delegate = self
        self.peerProvider.delegate = self
        self.transferManager.delegate = self
    }
    
    // add torrent task
    public func setupTorrentTask(torrent: TorrentModel, rootDirectory: String) throws {
        let conf = try createTorrentTaskConf(from: torrent, rootDirectory: rootDirectory)
        
        self.torrentList.append((conf, .started))
        self.peerProvider.setuPeerProvider(for: conf)
        self.transferManager.setupDataTransferManager(for: conf)
        self.progressManager.setupProgressMananger(for: conf)
    }
    
    // stop torrent task
    public func stopTorrentTask(for conf: TorrentTaskConf) {
        self.peerProvider.stopPeersProvider(for: conf)
        self.transferManager.stopDataTransferManager(for: conf)
        
        if let index = self.torrentList.firstIndex(where: { $0.conf == conf}) {
            self.torrentList[index].status = .stopped
        }
    }
    
    public func resumeTorrentTask(for conf: TorrentTaskConf) {
        self.peerProvider.resumePeersProvider(for: conf)
        self.transferManager.resumeDataTransferManager(for: conf)
        
        if let index = self.torrentList.firstIndex(where: { $0.conf == conf}) {
            self.torrentList[index].status = .started
        }
    }
    
    public func removeTorrentTask(for conf: TorrentTaskConf) {
        self.peerProvider.removePeerProvider(for: conf)
        self.transferManager.removeDataTransferManager(for: conf)
        self.progressManager.removeProgressMananger(for: conf)
        
        if let index = self.torrentList.firstIndex(where: { $0.conf == conf}) {
            self.torrentList.remove(at: index)
        }
    }
    
    private func createTorrentTaskConf(from torrent: TorrentModel, rootDirectory: String) throws -> TorrentTaskConf {
        // make sure we don't already have the torrent
        guard !self.torrentList.contains(where: { $0.conf.infoHash == torrent.infoHashSHA1 }) else {
            throw TorrentTaskManagerError.alreadyHaveCurrentTorrent
        }
        // generate a unique peer id
        var peerID = TorrentTaskConf.makePeerID()
        while self.torrentList.contains(where: { $0.conf.id == peerID }) {
            peerID = TorrentTaskConf.makePeerID()
        }
        
        return TorrentTaskConf(torrent: torrent, torrentID: peerID, rootDirectory: rootDirectory)
    }
}

extension TorrentTaskManager {
    /// info about current torrent, like
    public struct TorrentStatusInfo {
        public let name: String
        public let progressPercentage: Float
        public let downloadSpeed: String
        public let uploadSpeed: String
        public let torrentSize: String
        public let seedCount: Int
        public let peerCount: Int
        
        public init(name: String, progressPercentage: Float, torrentSize: String, downloadSpeed: String = "", uploadSpeed: String = "",  seedCount: Int = 0, peerCount: Int = 0) {
            self.name = name
            self.progressPercentage = progressPercentage
            self.downloadSpeed = downloadSpeed
            self.uploadSpeed = uploadSpeed
            self.torrentSize = torrentSize
            self.seedCount = seedCount
            self.peerCount = peerCount
        }
    }
    
    public func getTorrentDownloadInfo(for conf: TorrentTaskConf) -> TorrentStatusInfo {
        let name = conf.info.name
        let torrentSize = conf.info.length?.toByteString() ?? ""
        let progress = progressManager.getProgress(for: conf)!.percentageComplete
        let downloadSpeed = transferManager.getDownloadSpeed(for: conf)
        let uploadSpeed = transferManager.getUploadSpeed(for: conf)
        let seedNumber = transferManager.getSeedsNumber(for: conf)
        let peerNumber = transferManager.getPeerNumber(for: conf)
        
        return TorrentStatusInfo(name: name, progressPercentage: progress, torrentSize: torrentSize, downloadSpeed: downloadSpeed, uploadSpeed: uploadSpeed, seedCount: seedNumber, peerCount: peerNumber)
    }
}

extension TorrentTaskManager: TorrentListenerSocketDelegate {
    func torrentListenSocket(_ torrentSocket: TorrentListenerSocket, connectedToPeer peer: TorrentPeer, for infoHash: Data) {
        if let item = torrentList.first(where: { $0.conf.infoHash == infoHash }) {
            transferManager.addNewPeer(with: peer, for: item.conf)
        }
    }
    
    func getTorrentTaskInfo(for torrentSocket: TorrentListenerSocket, of infoHash: Data) -> (id: Data, progress: BitField)? {
        if let item = torrentList.first(where: { $0.conf.infoHash == infoHash }) {
            let progress = progressManager.getProgress(for: item.conf)
            return (item.conf.id, progress?.bitField ?? .init(size: item.conf.bitFieldSize))
        } else {
            return nil
        }
    }
}

extension TorrentTaskManager: TorrentPeerProviderDelegate {
    func torrentPeerProvider(_ sender: TorrentPeerProviderManager, newPeers: [TorrentPeerInfo], for conf: TorrentTaskConf) {
        if let item = self.torrentList.first(where: { $0.conf == conf }) {
            transferManager.addNewPeers(with: newPeers, for: item.conf)
        }
    }
    
    func torrentPeerProviderManagerAnnonuceInfo(_ sender: TorrentPeerProviderManager, conf: TorrentTaskConf) -> TorrentTrackerManagerAnnonuceInfo {
        guard let progress = progressManager.getProgress(for: conf) else {
            return .EMPTY_INFO
        }
        
        let peersCount = transferManager.getPeerCount(for: conf)
        
        return TorrentTrackerManagerAnnonuceInfo(
            numberOfBytesRemaining: progress.remaining * conf.info.pieceLength,
            numberOfBytesUploaded: 0,
            numberOfBytesDownloaded: progress.downloaded * conf.info.pieceLength,
            numberOfPeersToFetch: peersCount
        )
    }
}

extension TorrentTaskManager: TorrentDataTransferManagerDelegate {
    func torrentDataTransferManager(_ sender: TorrentDataTransferManager, downloadedPieceAtIndex pieceIndex: Int, with piece: Data, for conf: TorrentTaskConf) {
        do {
            try self.progressManager.setDownloadedPiece(with: piece, at: pieceIndex, for: conf)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        
        guard let itemIndex = torrentList.firstIndex(where: { $0.conf == conf }) else {
            return
        }
        
        if progressManager.getProgress(for: self.torrentList[itemIndex].conf)!.complete {
            self.torrentList[itemIndex].status = .completed
        }
    }
    
    func torrentDataTransferManager(_ sender: TorrentDataTransferManager, failedToGetPieceAtIndex index: Int, for conf: TorrentTaskConf) {
        progressManager.setLostPiece(at: index, for: conf)
    }
    
    func torrentDataTransferManagerNeedsMorePeers(_ sender: TorrentDataTransferManager, for conf: TorrentTaskConf) {
        peerProvider.fetchMorePeersImediatly(for: conf)
    }
    
    func torrentDataTransferManagerCurrentBitfieldForHandshake(_ sender: TorrentDataTransferManager, for conf: TorrentTaskConf) -> BitField {
        progressManager.getProgress(for: conf)!.bitField
    }
    
    func torrentDataTransferManager(_ sender: TorrentDataTransferManager, nextPieceFromAvailable availablePieces: BitField, for conf: TorrentTaskConf) -> TorrentPieceRequest? {
        progressManager.getNextPieceToDownload(from: availablePieces, for: conf)
    }
    
    func torrentDataTransferManager(_ sender: TorrentDataTransferManager, peerRequiresPieceAtIndex index: Int, for conf: TorrentTaskConf) -> Data? {
        try? progressManager.fileManager.readDataFromFiles(at: index, for: conf)
    }
}
