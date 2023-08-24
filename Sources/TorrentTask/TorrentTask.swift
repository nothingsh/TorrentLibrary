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
    
    var listenSocket: TorrentListenSocket
    
    let peerManager: TorrentPeerManager
    let peerProvider: TorrentPeerProviderManager
    let fileManager: TorrentFileManager
    
    // TODO: add a new init to load downloaded torrents
    // save and load cache by file manager
    
    /// for torrent which is added for the first time
    public init(torrentModel: TorrentModel, downloadPath: String) throws {
        self.torrentModel = torrentModel
        self.listenSocket = TorrentListenSocket(infoHash: torrentModel.infoHashSHA1, clientID: clientID)
        self.peerProvider = TorrentPeerProviderManager(model: torrentModel, peerID: clientID)
        self.peerManager = TorrentPeerManager(clientID: clientID, infoHash: torrentModel.infoHashSHA1, bitFieldSize: torrentModel.info.pieces.count)
        self.fileManager = try TorrentFileManager(torrent: torrentModel, rootDirectory: downloadPath)
        
        self.listenSocket.delegate = self
        self.peerManager.delegate = self
        self.peerProvider.delegate = self
    }
    
    public var torrentName: String {
        return self.torrentModel.info.name
    }
    
    public var progress: Float {
        return self.fileManager.bitField.progress
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
        self.listenSocket.startListening()
        self.peerProvider.startPeersFetching()
        // TODO: need to check if current task is completed
        self.status = .started
    }
    
    public func stopTask() {
        self.listenSocket.stopListening()
        self.peerProvider.stopPeersFetching()
        self.peerManager.stopPeersConnection()
        self.status = .stopped
    }
    
    public func resumeTask() {
        self.listenSocket.resumeListening()
        self.peerProvider.resumePeersFetching()
        self.peerManager.resumePeersConnections()
        self.status = .started
    }
    
    public func getTorrentMagnetLink() -> String {
        return ""
    }
}

// MARK: delegates

extension TorrentTask: TorrentListenSocketDelegate {
    func torrentListenSocket(_ torrentSocket: TorrentListenSocket, connectedToPeer peer: TorrentPeer) {
        peerManager.addPeer(peer)
    }
    
    func currentProgress(for torrentSocket: TorrentListenSocket) -> BitField {
        fileManager.bitField
    }
}

extension TorrentTask: TorrentPeerManagerDelegate {
    func torrentPeerManager(_ sender: TorrentPeerManager, downloadedPieceAtIndex pieceIndex: Int, piece: Data) {
        do {
            try fileManager.writeDataToFiles(at: pieceIndex, with: piece)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, failedToGetPieceAtIndex index: Int) {
        
    }
    
    func torrentPeerManagerNeedsMorePeers(_ sender: TorrentPeerManager) {
        peerProvider.fetchMorePeersImediatly()
    }
    
    func torrentPeerManagerCurrentBitfieldForHandshake(_ sender: TorrentPeerManager) -> BitField {
        fileManager.bitField
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, nextPieceFromAvailable availablePieces: BitField) -> TorrentPieceRequest? {
        fileManager.nextPieceDownloadRequest()
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, peerRequiresPieceAtIndex index: Int) -> Data? {
        try? fileManager.readDataFromFiles(by: .piece, at: index)
    }
}

extension TorrentTask: TorrentPeerProviderDelegate {
    func torrentPeerProvider(_ sender: TorrentPeerProviderManager, newPeers: [TorrentPeerInfo]) {
        peerManager.addPeers(withInfo: newPeers)
    }
}
