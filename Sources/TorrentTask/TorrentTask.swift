//
//  TorrentLibrary.swift
//
//
//  Created by Wynn Zhang on 6/26/23.
//

import Foundation
import TorrentModel
import CocoaAsyncSocket

public class TorrentTask {
    public enum Status {
        case started
        case stopped
        case completed
    }
    
    let torrentModel: TorrentModel
    public private(set) var status: Status = .stopped
    let clientID = TorrentPeer.makePeerID()
    
    let listenerSocket: TorrentListenerSocket
    
    let peerManager: TorrentPeerManager
    let peerProvider: TorrentPeerProviderManager
    let progressManager: TorrentProgressManager
    
    // TODO: add a new init to load downloaded torrents
    // save and load cache by file manager
    
    /// for torrent which is added for the first time
    public init(torrentModel: TorrentModel, downloadPath: String) throws {
        self.torrentModel = torrentModel
        self.listenerSocket = TorrentListenerSocket(infoHash: torrentModel.infoHashSHA1, clientID: clientID)
        self.peerProvider = TorrentPeerProviderManager(model: torrentModel, peerID: clientID)
        self.peerManager = TorrentPeerManager(clientID: clientID, infoHash: torrentModel.infoHashSHA1, bitFieldSize: torrentModel.info.pieces.count)
        self.progressManager = try TorrentProgressManager(model: torrentModel, rootDirectory: downloadPath)
        
        self.listenerSocket.delegate = self
        self.peerManager.delegate = self
        self.peerProvider.delegate = self
    }
    
    // Only for Unit Tests
    init(
        model: TorrentModel,
        listenerSocket: TorrentListenerSocket,
        peerManager: TorrentPeerManager,
        peerProviderManager: TorrentPeerProviderManager,
        progressManager: TorrentProgressManager
    ) {
        self.torrentModel = model
        self.listenerSocket = listenerSocket
        self.peerManager = peerManager
        self.peerProvider = peerProviderManager
        self.progressManager = progressManager
        
        self.listenerSocket.delegate = self
        self.peerManager.delegate = self
        self.peerProvider.delegate = self
    }
    
    public var torrentName: String {
        return self.torrentModel.info.name
    }
    
    public var progress: Float {
        return self.progressManager.progress.percentageComplete
    }
    
    public var downloadSpeed: String {
        return self.peerManager.downloadSpeed
    }
    
    public var uploadSpeed: String {
        return self.peerManager.uploadSpeed
    }
    
    public var torrentDataSize: String {
        return self.torrentModel.info.length?.toByteString() ?? "unknown"
    }
    
    public var seeds: Int {
        return self.peerManager.numberOfConnectedSeeds
    }
    
    public var peers: Int {
        return self.peerManager.numberOfConnectedPeers
    }
}

// MARK: API actions

extension TorrentTask {
    /// remove all downloads and progress
    public func deleteTask() {
        
    }
    
    public func startTask() {
        self.listenerSocket.startListening()
        self.peerProvider.startPeersFetching()
        // TODO: need to check if current task is completed
        self.status = progressManager.progress.complete ? .completed : .started
    }
    
    public func stopTask() {
        self.listenerSocket.stopListening()
        self.peerProvider.stopPeersFetching()
        self.peerManager.stopPeersConnection()
        self.status = .stopped
    }
    
    public func resumeTask() {
        self.listenerSocket.resumeListening()
        self.peerProvider.resumePeersFetching()
        self.peerManager.resumePeersConnections()
        self.status = .started
    }
    
    public func getTorrentMagnetLink() -> String {
        return ""
    }
}

// MARK: delegates

extension TorrentTask: TorrentListenerSocketDelegate {
    func torrentListenSocket(_ torrentSocket: TorrentListenerSocket, connectedToPeer peer: TorrentPeer) {
        peerManager.addPeer(peer)
    }
    
    func currentProgress(for torrentSocket: TorrentListenerSocket) -> BitField {
        progressManager.progress.bitField
    }
}

extension TorrentTask: TorrentPeerManagerDelegate {
    func torrentPeerManager(_ sender: TorrentPeerManager, downloadedPieceAtIndex pieceIndex: Int, piece: Data) {
        do {
            try progressManager.setDownloadedPiece(piece, pieceIndex: pieceIndex)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        
        if progressManager.progress.complete {
            self.status = .completed
        }
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, failedToGetPieceAtIndex index: Int) {
        progressManager.setLostPiece(at: index)
    }
    
    func torrentPeerManagerNeedsMorePeers(_ sender: TorrentPeerManager) {
        peerProvider.fetchMorePeersImediatly()
    }
    
    func torrentPeerManagerCurrentBitfieldForHandshake(_ sender: TorrentPeerManager) -> BitField {
        progressManager.progress.bitField
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, nextPieceFromAvailable availablePieces: BitField) -> TorrentPieceRequest? {
        progressManager.getNextPieceToDownload(from: availablePieces)
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, peerRequiresPieceAtIndex index: Int) -> Data? {
        try? progressManager.fileManager.readDataFromFiles(at: index)
    }
}

extension TorrentTask: TorrentPeerProviderDelegate {
    func torrentPeerProvider(_ sender: TorrentPeerProviderManager, newPeers: [TorrentPeerInfo]) {
        peerManager.addPeers(withInfo: newPeers)
    }
    
    func torrentPeerProviderManagerAnnonuceInfo(_ sender: TorrentPeerProviderManager) -> TorrentTrackerManagerAnnonuceInfo {
        return TorrentTrackerManagerAnnonuceInfo(
            numberOfBytesRemaining: progressManager.progress.remaining * torrentModel.info.pieceLength,
            numberOfBytesUploaded: 0,
            numberOfBytesDownloaded: progressManager.progress.downloaded * torrentModel.info.pieceLength,
            numberOfPeersToFetch: peers
        )
    }
}
