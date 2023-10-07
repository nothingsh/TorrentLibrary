//
//  TorrentTrackerManager.swift
//  
//
//  Created by Wynn Zhang on 7/3/23.
//

import Foundation
import TorrentModel

struct TrackerAnnonuceInfo {
    let numberOfBytesRemaining: Int
    let numberOfBytesUploaded: Int
    let numberOfBytesDownloaded: Int
    let numberOfPeersToFetch: Int
    
    static let EMPTY_INFO = TrackerAnnonuceInfo(numberOfBytesRemaining: 0, numberOfBytesUploaded: 0, numberOfBytesDownloaded: 0, numberOfPeersToFetch: 0)
}

protocol TorrentTrackerManagerDelegate: AnyObject {
    func torrentTrackerManager(_ sender: TorrentTrackerManager, gotNewPeers peers: [TorrentPeerInfo])
    func torrentTrackerManagerAnnonuceInfo(_ sender: TorrentTrackerManager) -> TrackerAnnonuceInfo
}

class TorrentTrackerManager {
    weak var delegate: TorrentTrackerManagerDelegate?
    
    let trackers: [TorrentTrackerProtocol]
    
    let torrentConf: TorrentTaskConf
    /// the port to communicate with udp tracker
    let port: UInt16
    
    /// port for incoming peer connection, announced to all tracker
    static let DEFAULT_PORT: UInt16 = 6881
    
    var announceTimeInterval: TimeInterval = 600
    // private weak var announceTimer: Timer?
    private lazy var announceTimer: Timer = {
        return Timer.scheduledTimer(timeInterval: self.announceTimeInterval,
                                    target: self,
                                    selector: #selector(announce),
                                    userInfo: nil,
                                    repeats: true)
    }()
    
    init(torrentConf: TorrentTaskConf, port: UInt16) {
        self.torrentConf = torrentConf
        self.port = port
        self.trackers = TorrentTrackerManager.createTrackers(from: torrentConf.torrent, port: self.port)
        
        for tracker in trackers {
            tracker.delegate = self
        }
    }
    
    /// only for unit test
    #if DEBUG
    init(torrentConf: TorrentTaskConf, port: UInt16 = TorrentTrackerManager.DEFAULT_PORT, trackers: [TorrentTrackerProtocol]) {
        self.torrentConf = torrentConf
        self.port = port
        self.trackers = trackers
    }
    #endif
        
    private static func createTrackers(from model: TorrentModel, port: UInt16) -> [TorrentTrackerProtocol] {
        let announceList = model.announceList
        let flatAnnounceList = announceList.flatMap { return $0 }
        
        var result: [TorrentTrackerProtocol] = []
        
        var currentPort = port
        for urlString in flatAnnounceList {
            if let url = URL(string: urlString) {
                if url.scheme == "http" || url.scheme == "https" {
                    let tracker = TorrentHTTPTracker(announce: url.bySettingScheme(to: "https"))
                    result.append(tracker)
                } else if url.scheme == "udp" {
                    do {
                        // TODO: each tracker will create a new socket, and the created sockets can't listen to the same port, so we either create one socket for all or assign each one a socket
                        let tracker = try TorrentUDPTracker(announceURL: url, port: currentPort)
                        result.append(tracker)
                        
                        currentPort += 1
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
    
    func resumeTrackersAccess() {
        forceRestart()
    }
    
    func stopTrackersAccess() {
        announceTimer.invalidate()
    }
    
    func forceRestart() {
        announceTimer.fire()
        // try? self.announce()
    }
    
    @objc private func announce() throws {
        guard let delegate = delegate else { return }
        
        let announceInfo = delegate.torrentTrackerManagerAnnonuceInfo(self)
        for tracker in trackers {
            try tracker.announceClient(with: torrentConf.idString, port: Self.DEFAULT_PORT, event: .started, infoHash: torrentConf.infoHash, annouceInfo: announceInfo)
        }
    }
}

extension TorrentTrackerManager: TorrentTrackerDelegate {
    func torrentTracker(_ sender: TorrentTrackerProtocol, receivedResponse response: TorrentTrackerResponse) {
        delegate?.torrentTrackerManager(self, gotNewPeers: response.peers)
    }
    
    func torrentTracker(_ sender: TorrentTrackerProtocol, receivedErrorMessage errorMessage: String) {
        print("Error: Tracker error occurred: \(errorMessage)")
    }
}
