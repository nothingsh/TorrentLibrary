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
    enum Status {
        case started
        case stopped
        case completed
    }
    
    let torrentModel: TorrentModel
    private var status: Status = .stopped
    let clientID = TorrentPeer.makePeerID()
    
    var listenSocket: GCDAsyncSocket!
    
    let peerManager: TorrentPeerManager
    let peerProvider: TorrentPeerProviderManager
    let fileManager: TorrentFileManager
    
    public init(torrentModel: TorrentModel, downloadPath: String) throws {
        self.torrentModel = torrentModel
        self.peerProvider = TorrentPeerProviderManager(model: torrentModel, peerID: clientID)
        self.peerManager = TorrentPeerManager(clientID: clientID, infoHash: torrentModel.infoHashSHA1, bitFieldSize: torrentModel.info.pieces.count)
        self.fileManager = try TorrentFileManager(torrent: torrentModel, rootDirectory: downloadPath)
        
        self.peerManager.delegate = self
        self.peerProvider.delegate = self
    }
    
    deinit {
        
    }
    
    private func startListening(at port: UInt16) {
        
    }
    
    public var progress: Float {
        return fileManager.bitField.progress
    }
    
    public var downloadSpeed: Float {
        return 0
    }
    
    public var uploadSpeed: Float {
        return 0
    }
}

// MARK: API action

extension TorrentTask {
    /// remove all downloads and progress
    public func deleteTask() {
        
    }
    
    public func startTask() {
        
    }
    
    public func stopTask() {
        
    }
    
    public func renameTorrent() {
        
    }
    
    public func reDownload() {
        
    }
    
    public func getTorrentMagnetLink() -> String {
        return ""
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
        peerProvider.fetchMorePeers()
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
