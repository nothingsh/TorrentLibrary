//
//  TorrentPeerProviderManager.swift
//  
//
//  Created by Wynn Zhang on 7/8/23.
//

import Foundation
import TorrentModel

protocol TorrentPeerProviderProtocol: AnyObject {
    func registerTorrent(with conf: TorrentTaskConf)
    func stopPeersProvider(for conf: TorrentTaskConf)
    func resumePeersProvider(for conf: TorrentTaskConf)
    func removePeerProvider(for conf: TorrentTaskConf)
    func fetchMorePeersImediatly(for conf: TorrentTaskConf)
}

protocol TorrentPeerProviderDelegate: AnyObject {
    func torrentPeerProvider(_ sender:TorrentPeerProvider, newPeers: [TorrentPeerInfo], for conf: TorrentTaskConf)
    func torrentPeerProviderManagerAnnonuceInfo(_ sender: TorrentPeerProvider, conf: TorrentTaskConf) -> TrackerAnnonuceInfo
}

class TorrentPeerProvider: TorrentPeerProviderProtocol {
    static let shared = TorrentPeerProvider()
    
    weak var delegate: TorrentPeerProviderDelegate?
    
    private var trackerProvider: TorrentTrackerPeerProvider
    private var lsdProvider: TorrentLSDPeerProvider
    // var dhtProvider: TorrentDHTPeerProvider
    
    private init() {
        self.trackerProvider = TorrentTrackerPeerProvider()
        self.lsdProvider = TorrentLSDPeerProvider()
        
        self.trackerProvider.delegate = self
        self.lsdProvider.delegate = self
    }
    
    func setupTrackerAnnouncePort(port: UInt16) {
        trackerProvider.setupAnnouncePort(port: port)
    }
    
    func registerTorrent(with conf: TorrentTaskConf) {
        trackerProvider.registerTorrent(with: conf)
        lsdProvider.registerTorrent(with: conf)
    }
    
    func stopPeersProvider(for conf: TorrentTaskConf) {
        trackerProvider.stopTrackerPeerProvider(for: conf)
        lsdProvider.resumeLSDPeerProvider(for: conf)
    }
    
    func resumePeersProvider(for conf: TorrentTaskConf) {
        trackerProvider.resumeTrackerPeerProvider(for: conf)
        lsdProvider.resumeLSDPeerProvider(for: conf)
    }
    
    func removePeerProvider(for conf: TorrentTaskConf) {
        trackerProvider.removeTrackerPeerProvider(for: conf)
        lsdProvider.removeLSDPeerProvider(for: conf)
    }
    
    func fetchMorePeersImediatly(for conf: TorrentTaskConf) {
        trackerProvider.announceTorrent(with: conf)
        lsdProvider.announceTorrent(with: conf)
    }
}

extension TorrentPeerProvider: TorrentTrackerPeerProviderDelegate {
    func torrentTrackerPeerProvider(_ sender: TorrentTrackerPeerProvider, got newPeers: [TorrentPeerInfo], for conf: TorrentTaskConf) {
        delegate?.torrentPeerProvider(self, newPeers: newPeers, for: conf)
    }
    
    func torrentTrackerPeerProvider(_ sender: TorrentTrackerPeerProvider, for conf: TorrentTaskConf) -> TrackerAnnonuceInfo {
        return delegate?.torrentPeerProviderManagerAnnonuceInfo(self, conf: conf) ?? .EMPTY_INFO
    }
}

extension TorrentPeerProvider: TorrentLSDPeerProviderDelegate {
    func torrentLSDPeerProvider(_ sender: TorrentLSDPeerProviderProtocol, got newPeer: TorrentPeerInfo, for conf: TorrentTaskConf) {
        delegate?.torrentPeerProvider(self, newPeers: [newPeer], for: conf)
    }
}
