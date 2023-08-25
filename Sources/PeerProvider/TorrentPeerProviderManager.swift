//
//  TorrentPeerProviderManager.swift
//  
//
//  Created by Wynn Zhang on 7/8/23.
//

import Foundation
import TorrentModel

protocol TorrentPeerProviderDelegate: AnyObject {
    func torrentPeerProvider(_ sender:TorrentPeerProviderManager, newPeers: [TorrentPeerInfo])
    func torrentPeerProviderManagerAnnonuceInfo(_ sender: TorrentPeerProviderManager) -> TorrentTrackerManagerAnnonuceInfo
}

class TorrentPeerProviderManager {
    weak var delegate: TorrentPeerProviderDelegate?
    
    var trackerManager: TorrentTrackerPeerProvider
    
    init(model: TorrentModel, peerID: Data) {
        trackerManager = TorrentTrackerPeerProvider(torrentModel: model, peerID: peerID)
        trackerManager.delegate = self
    }
    
    func startPeersFetching() {
        trackerManager.startTrackersAccess()
    }
    
    func resumePeersFetching() {
        trackerManager.resumeTrackersAccess()
    }
    
    func stopPeersFetching() {
        trackerManager.stopTrackersAccess()
    }
    
    func fetchMorePeersImediatly() {
        trackerManager.forceRestart()
    }
}

extension TorrentPeerProviderManager: TorrentTrackerPeerProviderDelegate {
    func torrentTrackerManager(_ sender: TorrentTrackerPeerProvider, gotNewPeers peers: [TorrentPeerInfo]) {
        delegate?.torrentPeerProvider(self, newPeers: peers)
    }
    
    func torrentTrackerManagerAnnonuceInfo(_ sender: TorrentTrackerPeerProvider) -> TorrentTrackerManagerAnnonuceInfo {
        return delegate?.torrentPeerProviderManagerAnnonuceInfo(self) ?? .EMPTY_INFO
    }
}
