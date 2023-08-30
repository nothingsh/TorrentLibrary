//
//  TorrentTrackerPeerProvider.swift
//  
//
//  Created by Wynn Zhang on 8/28/23.
//

import Foundation

public enum TorrentTrackerPeerProviderError: Error {
    case noValidPortLeft
}

protocol TorrentTrackerPeerProviderDelegate: AnyObject {
    func torrentTrackerPeerProvider(_ sender: TorrentTrackerPeerProvider, got newPeers: [TorrentPeerInfo], for conf: TorrentTaskConf)
    func torrentTrackerPeerProvider(_ sender: TorrentTrackerPeerProvider, for conf: TorrentTaskConf) -> TorrentTrackerManagerAnnonuceInfo
}

class TorrentTrackerPeerProvider {
    typealias TrackerManagerInfo = (manager: TorrentTrackerManager, port: UInt16)
    
    static let START_PORT: UInt16 = 3475
    
    let portRange: Range<UInt16>
    var trackerMangerDict: [TorrentTaskConf: TrackerManagerInfo]
    
    weak var delegate: TorrentTrackerPeerProviderDelegate?
    
    init() {
        let largest_port = Self.START_PORT + UInt16(TorrentTaskConf.MAX_ACTIVE_TORRENT)
        self.portRange = Self.START_PORT..<largest_port
        self.trackerMangerDict = [:]
    }
    
    func setupTrackerPeerProvider(for conf: TorrentTaskConf) {
        let unusedPort = try! findUnusedPort()
        let manager = TorrentTrackerManager(torrentConf: conf, port: unusedPort)
        trackerMangerDict[conf] = (manager, unusedPort)
    }
    
    func stopTrackerPeerProvider(for conf: TorrentTaskConf) {
        trackerMangerDict[conf]?.manager.stopTrackersAccess()
    }
    
    func resumeTrackerPeerProvider(for conf: TorrentTaskConf) {
        trackerMangerDict[conf]?.manager.resumeTrackersAccess()
    }
    
    func startPeerProviderImediatly(for conf: TorrentTaskConf) {
        trackerMangerDict[conf]?.manager.forceRestart()
    }
    
    func removeTrackerPeerProvider(for conf: TorrentTaskConf) {
        self.stopTrackerPeerProvider(for: conf)
        trackerMangerDict.removeValue(forKey: conf)
    }
    
    private func findUnusedPort() throws -> UInt16 {
        for port in self.portRange {
            if !trackerMangerDict.values.contains(where: { $0.port == port }) {
                return port
            }
        }
        
        throw TorrentTrackerPeerProviderError.noValidPortLeft
    }
}

extension TorrentTrackerPeerProvider: TorrentTrackerManagerDelegate {
    func torrentTrackerManager(_ sender: TorrentTrackerManager, gotNewPeers peers: [TorrentPeerInfo]) {
        for (key, value) in trackerMangerDict {
            if value.manager === sender {
                delegate?.torrentTrackerPeerProvider(self, got: peers, for: key)
            }
        }
    }
    
    func torrentTrackerManagerAnnonuceInfo(_ sender: TorrentTrackerManager) -> TorrentTrackerManagerAnnonuceInfo {
        for (key, value) in trackerMangerDict {
            if value.manager === sender {
                return delegate?.torrentTrackerPeerProvider(self, for: key) ?? .EMPTY_INFO
            }
        }
        return .EMPTY_INFO
    }
}
