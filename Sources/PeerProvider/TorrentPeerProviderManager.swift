//
//  TorrentPeerProviderManager.swift
//  
//
//  Created by Wynn Zhang on 7/8/23.
//

import Foundation
import TorrentModel

protocol TorrentPeerProviderDelegate: AnyObject {
    func torrentPeerProvider(_ sender:TorrentPeerProviderManager, newPeers: [TorrentPeerInfo], for conf: TorrentTaskConf)
    func torrentPeerProviderManagerAnnonuceInfo(_ sender: TorrentPeerProviderManager, conf: TorrentTaskConf) -> TorrentTrackerManagerAnnonuceInfo
}

class TorrentPeerProviderManager {
    weak var delegate: TorrentPeerProviderDelegate?
    
    var trackerProvider: TorrentTrackerPeerProvider
    var lsdProvider: TorrentLSDPeerProvider
    
    init() throws {
        trackerProvider = TorrentTrackerPeerProvider()
        lsdProvider = try TorrentLSDPeerProvider()
    }
    
    func setuPeerProvider(for conf: TorrentTaskConf) {
        trackerProvider.setupTrackerPeerProvider(for: conf)
        lsdProvider.setupLSDProvider(taskConf: conf)
    }
    
    func removePeerProvider(for conf: TorrentTaskConf) {
        trackerProvider.removeTrackerPeerProvider(for: conf)
        lsdProvider.removeLSDPeerProvider(for: conf)
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
    func torrentTrackerPeerProvider(_ sender: TorrentTrackerPeerProvider, got newPeers: [TorrentPeerInfo], for conf: TorrentTaskConf) {
        delegate?.torrentPeerProvider(self, newPeers: newPeers, for: conf)
    }
    
    func torrentTrackerPeerProvider(_ sender: TorrentTrackerPeerProvider, for conf: TorrentTaskConf) -> TorrentTrackerManagerAnnonuceInfo {
        return delegate?.torrentPeerProviderManagerAnnonuceInfo(self, conf: conf) ?? .EMPTY_INFO
    }
}

extension TorrentPeerProviderManager: TorrentLSDPeerProviderDelegate {
    func torrentLSDPeerProvider(_ sender: TorrentLSDPeerProviderProtocol, got newPeer: TorrentPeerInfo, for conf: TorrentTaskConf) {
        delegate?.torrentPeerProvider(self, newPeers: [newPeer], for: conf)
    }
}
