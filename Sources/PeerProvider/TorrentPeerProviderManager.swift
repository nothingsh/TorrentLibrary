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
        // TODO: return progress
        return TorrentTrackerManagerAnnonuceInfo(numberOfBytesRemaining: 0, numberOfBytesUploaded: 0, numberOfBytesDownloaded: 0, numberOfPeersToFetch: 0)
    }
}
