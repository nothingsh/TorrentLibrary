//
//  TorrentPeerProviderManager.swift
//  
//
//  Created by Wynn Zhang on 7/8/23.
//

import Foundation
import TorrentModel

protocol TorrentPeerProviderDelegate: AnyObject {
    func torrentPeerProvider(_ sender:TorrentPeerProviderManager, newPeers: [TorrentPeerInfo], for clientID: Data)
    func torrentPeerProviderManagerAnnonuceInfo(_ sender: TorrentPeerProviderManager) -> TorrentTrackerManagerAnnonuceInfo
}

class TorrentPeerProviderManager {
    weak var delegate: TorrentPeerProviderDelegate?
    
    var trackerProvider: TorrentTrackerPeerProvider
    var lsdProvider: TorrentLSDPeerProvider
    
    init() throws {
        trackerProvider = TorrentTrackerPeerProvider()
        lsdProvider = try TorrentLSDPeerProvider()
    }
    
    func startPeersProvider(for conf: TorrentTaskConf) {
        trackerProvider.startTrackerPeerProvider(for: conf)
    }
    
    func resumePeersProvider(for conf: TorrentTaskConf) {
        trackerProvider.resumeTrackerPeerProvider(for: conf)
        lsdProvider.resumeLSDPeerProvider(for: conf)
    }
    
    func stopPeersProvider(for conf: TorrentTaskConf) {
        trackerProvider.stopTrackerPeerProvider(for: conf)
        lsdProvider.resumeLSDPeerProvider(for: conf)
    }
    
    func fetchMorePeersImediatly(for conf: TorrentTaskConf) {
        trackerProvider.startPeerProviderImediatly(for: conf)
        lsdProvider.startLSDProviderImediatly(for: conf)
    }
}

extension TorrentPeerProviderManager: TorrentTrackerPeerProviderDelegate {
    func torrentTrackerPeerProvider(_ sender: TorrentTrackerPeerProvider, got newPeers: [TorrentPeerInfo], for clientID: Data) {
        delegate?.torrentPeerProvider(self, newPeers: newPeers, for: clientID)
    }
    
    func torrentTrackerPeerProvider(_ sender: TorrentTrackerPeerProvider) -> TorrentTrackerManagerAnnonuceInfo {
        return delegate?.torrentPeerProviderManagerAnnonuceInfo(self) ?? .EMPTY_INFO
    }
}

extension TorrentPeerProviderManager: TorrentLSDPeerProviderDelegate {
    func torrentLSDPeerProvider(_ sender: TorrentLSDPeerProviderProtocol, got newPeer: TorrentPeerInfo, for clientID: Data) {
        delegate?.torrentPeerProvider(self, newPeers: [newPeer], for: clientID)
    }
}
