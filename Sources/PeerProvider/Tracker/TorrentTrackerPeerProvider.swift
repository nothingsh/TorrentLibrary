//
//  TorrentTrackerPeerProvider.swift
//  
//
//  Created by Wynn Zhang on 8/28/23.
//

import Foundation
import TorrentModel

public enum TorrentTrackerPeerProviderError: Error {
    case noValidPortLeft
}

protocol TorrentTrackerPeerProviderDelegate: AnyObject {
    func torrentTrackerPeerProvider(_ sender: TorrentTrackerPeerProvider, got newPeers: [TorrentPeerInfo], for conf: TorrentTaskConf)
    func torrentTrackerPeerProvider(_ sender: TorrentTrackerPeerProvider, for conf: TorrentTaskConf) -> TrackerAnnonuceInfo
}

class TorrentTrackerPeerProvider {
    private let announcePort: UInt16
    private var taskTrackers: [TaskTracker]
    private var announceIndex: Int
    
    weak var delegate: TorrentTrackerPeerProviderDelegate?
    
    static let ANNOUNCE_INTERVAL: TimeInterval = 600
    // private weak var announceTimer: Timer?
    private lazy var announceTimer: Timer = { [unowned self] in
        return Timer.scheduledTimer(timeInterval: Self.ANNOUNCE_INTERVAL,
                                    target: self,
                                    selector: #selector(self.announceTasks),
                                    userInfo: nil,
                                    repeats: true)
    }()
    
    init(listenOn port: UInt16) {
        self.announcePort = port
        self.taskTrackers = []
        self.announceIndex = 0
    }
    
    /// registered torrent will be announced repeatly
    @objc func announceTasks() {
        guard let delegate = delegate else { return }
        
        guard let task = self.findFirstValidTask() else {
            return
        }
        
        let announceInfo = delegate.torrentTrackerPeerProvider(self, for: task.conf)
        for tracker in task.trackers {
            do {
                try tracker.announceClient(with: task.peerIDString, port: self.announcePort, event: .started, infoHash: task.infoHash, annouceInfo: announceInfo)
            } catch {
                print("Error: unable to announce tracker: \(tracker)")
            }
        }
        
        self.announceIndex += 1
    }
    
    private func findFirstValidTask() -> TaskTracker? {
        // make sure there is valid tasks
        guard self.taskTrackers.contains(where: { $0.isVaild }) else {
            return nil
        }
        
        self.announceIndex = self.announceIndex % self.taskTrackers.count
        while(!self.taskTrackers[self.announceIndex].isVaild) {
            self.announceIndex = (self.announceIndex + 1) % self.taskTrackers.count
        }
        
        return self.taskTrackers[self.announceIndex]
    }
    
    func announceTorrent(with conf: TorrentTaskConf) {
        guard let delegate = delegate else { return }
        
        guard let task = self.taskTrackers.first(where: { $0.conf == conf }) else {
            return
        }
        
        let announceInfo = delegate.torrentTrackerPeerProvider(self, for: task.conf)
        for tracker in task.trackers {
            do {
                try tracker.announceClient(with: task.peerIDString, port: self.announcePort, event: .started, infoHash: task.infoHash, annouceInfo: announceInfo)
            } catch {
                print("Error: unable to announce tracker: \(tracker)")
            }
        }
    }
    
    func registerTorrent(with conf: TorrentTaskConf) {
        let trackers = self.createTracker(torrent: conf.torrent)
        let task = TaskTracker(conf: conf, trackers: trackers)
        
        self.taskTrackers.append(task)
        self.announceTorrent(with: conf)
    }
    
    private func createTracker(torrent: TorrentModel) -> [TorrentTrackerProtocol] {
        let announceList = torrent.announceList
        let flatAnnounceList = announceList.flatMap { return $0 }
        
        var httpURLs: [URL] = []
        var udpURLs: [URL] = []
        
        for urlString in flatAnnounceList {
            guard let url = URL(string: urlString) else {
                print("Warning: can't parse tracker url string to URL - \(urlString)")
                continue
            }
            
            if url.scheme == "http" || url.scheme == "https" {
                httpURLs.append(url)
            } else {
                udpURLs.append(url)
            }
        }
        
        let httpTracker = HTTPTrackerPeerProvider(announceURLs: httpURLs)
        let udpTracker = UDPTrackerPeerProvider(announceURLs: udpURLs)
        
        return [httpTracker, udpTracker]
    }
    
    func stopTrackerPeerProvider(for conf: TorrentTaskConf) {
        if let index = self.taskTrackers.firstIndex(where: { $0.conf == conf }) {
            self.taskTrackers[index].isVaild = false
        }
    }
    
    func resumeTrackerPeerProvider(for conf: TorrentTaskConf) {
        if let index = self.taskTrackers.firstIndex(where: { $0.conf == conf }) {
            self.taskTrackers[index].isVaild = true
            self.announceTorrent(with: conf)
        }
    }
    
    func removeTrackerPeerProvider(for conf: TorrentTaskConf) {
        if let index = self.taskTrackers.firstIndex(where: { $0.conf == conf }) {
            self.taskTrackers.remove(at: index)
        }
    }
    
    private struct TaskTracker {
        let conf: TorrentTaskConf
        var isVaild: Bool = true
        var trackers: [TorrentTrackerProtocol] = []
        
        var peerIDString: String {
            conf.idString
        }
        
        var infoHash: Data {
            conf.infoHash
        }
    }
}

extension TorrentTrackerPeerProvider: TorrentTrackerDelegate {
    func torrentTracker(_ sender: TorrentTrackerProtocol, receivedResponse response: TorrentTrackerResponse) {
        for task in self.taskTrackers {
            for tracker in task.trackers {
                if tracker === sender {
                    delegate?.torrentTrackerPeerProvider(self, got: response.peers, for: task.conf)
                }
            }
        }
    }
    
    func torrentTracker(_ sender: TorrentTrackerProtocol, receivedErrorMessage errorMessage: String) {
        print("Error: Tracker error occurred: \(errorMessage)")
    }
}
