//
//  TorrentLibrary.swift
//
//
//  Created by Wynn Zhang on 6/26/23.
//

import Foundation
import TorrentModel

public class TorrentTask {
    
    enum Status {
        case started
        case stopped
        case completed
    }
    
    let torrentModel: TorrentModel
    private var status: Status = .stopped
    let clientID = TorrentPeer.makePeerID()
    let port: UInt16 = 6881
    
    let peerManager: TorrentPeerManager
    let trackerManager: TorrentTrackerManager
    let fileManager: TorrentFileManager
    
    public init(torrentModel: TorrentModel, downloadPath: String) throws {
        self.torrentModel = torrentModel
        self.trackerManager = TorrentTrackerManager(torrentModel: torrentModel, clientID: clientID, port: port)
        self.peerManager = TorrentPeerManager(clientID: clientID, infoHash: torrentModel.infoRawData.sha1(), bitFieldSize: torrentModel.info.pieces.count)
        self.fileManager = try TorrentFileManager(torrentInfo: torrentModel.info, rootDirectory: downloadPath)
    }
    
    deinit {
        
    }
    
    public func startTask() {
        
    }
    
    private func startListening(at port: UInt16) {
        
    }
    
    public func stopTask() {
        
    }
    
    public var progress: Double {
        return 0
    }
}

extension TorrentTask: TorrentTrackerManagerDelegate {
    func torrentTrackerManager(_ sender: TorrentTrackerManager, gotNewPeers peers: [TorrentPeerInfo]) {
        peerManager.addPeers(withInfo: peers)
    }
    
    func torrentTrackerManagerAnnonuceInfo(_ sender: TorrentTrackerManager) -> TorrentTrackerManagerAnnonuceInfo {
        // TODO: get progress from file manager
        return TorrentTrackerManagerAnnonuceInfo(numberOfBytesRemaining: 0, numberOfBytesUploaded: 0, numberOfBytesDownloaded: 0, numberOfPeersToFetch: 50)
    }
}

extension TorrentTask: TorrentPeerManagerDelegate {
    func torrentPeerManager(_ sender: TorrentPeerManager, downloadedPieceAtIndex pieceIndex: Int, piece: Data) {
        
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, failedToGetPieceAtIndex index: Int) {
        
    }
    
    func torrentPeerManagerNeedsMorePeers(_ sender: TorrentPeerManager) {
        trackerManager.forceRestart()
        // TODO: add more peers from dht ...
    }
    
    func torrentPeerManagerCurrentBitfieldForHandshake(_ sender: TorrentPeerManager) -> BitField {
        // TODO: maybe use a better way to show download progress
        (try? TorrentFileManager.loadSavedProgressBitfield(infoHash: torrentModel.infoRawData.sha1(), size: torrentModel.info.pieces.count))!
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, nextPieceFromAvailable availablePieces: BitField) -> TorrentPieceRequest? {
        // TODO: next piece request
        return nil
    }
    
    func torrentPeerManager(_ sender: TorrentPeerManager, peerRequiresPieceAtIndex index: Int) -> Data? {
        try? fileManager.readDataFromFiles(by: .piece, at: index)
    }
}
