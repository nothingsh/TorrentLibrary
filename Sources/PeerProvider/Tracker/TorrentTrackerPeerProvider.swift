//
//  TorrentTrackerPeerProvider.swift
//  
//
//  Created by Wynn Zhang on 7/3/23.
//

import Foundation
import TorrentModel

struct TorrentTrackerManagerAnnonuceInfo {
    let numberOfBytesRemaining: Int
    let numberOfBytesUploaded: Int
    let numberOfBytesDownloaded: Int
    let numberOfPeersToFetch: Int
}

protocol TorrentTrackerManagerDelegate: AnyObject {
    func torrentTrackerManager(_ sender: TorrentTrackerPeerProvider, gotNewPeers peers: [TorrentPeerInfo])
    func torrentTrackerManagerAnnonuceInfo(_ sender: TorrentTrackerPeerProvider) -> TorrentTrackerManagerAnnonuceInfo
}

class TorrentTrackerPeerProvider {
    weak var delegate: TorrentTrackerManagerDelegate?
    
    let trackers: [TorrentTrackerProtocol]
    
    let torrentModel: TorrentModel
    let clientID: String
    let port: UInt16
    
    static let DEFAULT_PORT: UInt16 = 6881
    
    var announceTimeInterval: TimeInterval = 600
    private lazy var announceTimer: Timer = {
        return Timer.scheduledTimer(timeInterval: self.announceTimeInterval, target: self, selector: #selector(announce), userInfo: nil, repeats: true)
    }()
    
    init(torrentModel: TorrentModel, peerID: Data) {
        self.torrentModel = torrentModel
        self.clientID = String(data: peerID, encoding: .utf8)!
        self.port = Self.DEFAULT_PORT
        self.trackers = TorrentTrackerPeerProvider.createTrackers(from: torrentModel)
        
        for tracker in trackers {
            tracker.delegate = self
        }
    }
        
    private static func createTrackers(from model: TorrentModel) -> [TorrentTrackerProtocol] {
        let announceList = model.announceList
        let flatAnnounceList = announceList.flatMap { return $0 }
        
        var lastPortNumberUsed: UInt16 = 3475
        var result: [TorrentTrackerProtocol] = []
        
        for urlString in flatAnnounceList {
            if let url = URL(string: urlString) {
                if url.scheme == "http" || url.scheme == "https" {
                    let tracker = TorrentHTTPTracker(announce: url.bySettingScheme(to: "https"))
                    result.append(tracker)
                } else if url.scheme == "udp" {
                    do {
                        let tracker = try TorrentUDPTracker(announceURL: url, port: lastPortNumberUsed)
                        result.append(tracker)
                        
                        // TODO: Support sharing the listening port for all udp trackers
                        lastPortNumberUsed += 1
                    } catch {
                        print("Error: unable to create udp tracker: \(urlString)")
                    }
                }
            } else {
                print("Error: unable to parse announce list item: \(urlString)")
            }
        }
        return result
    }
    
    func start() {
        forceRestart()
    }
    
    func forceRestart() {
        announceTimer.fire()
    }
    
    @objc private func announce() throws {
        guard let delegate = delegate else { return }
        
        let announceInfo = delegate.torrentTrackerManagerAnnonuceInfo(self)
        for tracker in trackers {
            try tracker.announceClient(with: clientID, port: port, event: .started, infoHash: torrentModel.infoRawData.sha1(), numberOfBytesRemaining: announceInfo.numberOfBytesRemaining, numberOfBytesUploaded: announceInfo.numberOfBytesUploaded, numberOfBytesDownloaded: announceInfo.numberOfBytesDownloaded, numberOfPeersToFetch: announceInfo.numberOfPeersToFetch)
        }
    }
}

extension TorrentTrackerPeerProvider: TorrentTrackerDelegate {
    func torrentTracker(_ sender: TorrentTrackerProtocol, receivedResponse response: TorrentTrackerResponse) {
        delegate?.torrentTrackerManager(self, gotNewPeers: response.peers)
    }
    
    func torrentTracker(_ sender: TorrentTrackerProtocol, receivedErrorMessage errorMessage: String) {
        print("Error: Tracker error occurred: \(errorMessage)")
    }
}