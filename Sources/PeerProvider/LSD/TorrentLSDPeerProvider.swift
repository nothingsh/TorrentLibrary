//
//  TorrentLSDPeerProvider.swift
//  
//
//  Created by Wynn Zhang on 8/26/23.
//

import Foundation

enum TorrentLSDPeerProviderError: Error {
    case unexpectedAnnounceData
    case unexpectedInfoHashesLength
    case unexpectedAnnounceContent
}

protocol TorrentLSDPeerProviderProtocol: AnyObject {
    func announceClient()
}

protocol TorrentLSDPeerProviderDelegate: AnyObject {
    func torrentLSDPeerProvider(_ sender: TorrentLSDPeerProviderProtocol, got newPeer: TorrentPeerInfo, for conf: TorrentTaskConf)
}

/// local service discovery
class TorrentLSDPeerProvider: TorrentLSDPeerProviderProtocol {
    weak var delegate: TorrentLSDPeerProviderDelegate?
    
    private let udpConnection: UDPConnectionProtocol
    private let announceTimeInterval: TimeInterval = 120
    
    private lazy var announceTimer: Timer = { [unowned self] in
        return Timer.scheduledTimer(timeInterval: self.announceTimeInterval,
                                    target: self,
                                    selector: #selector(announceClient),
                                    userInfo: nil,
                                    repeats: true)
    }()
    
    /// broadcast port
    static let LSD_PORT: UInt16 = 6771
    static let TIME_OUT: TimeInterval = 10
    
    private var tasks: Array<TaskStatus>
    private var cookie: UUID
    
    init(udpConnection: UDPConnectionProtocol = UDPConnection()) {
        self.udpConnection = udpConnection
        self.tasks = []
        self.cookie = UUID()
        
        self.udpConnection.delegate = self
        self.listen()
    }
    
    private func listen() {
        var port = Self.LSD_PORT
        
        while !tryToListen(on: port) && port < 10000 {
            port += 1
        }
    }
    
    private func tryToListen(on port: UInt16) -> Bool {
        if self.localPort != 0 {
            return true
        }
        
        do {
            try self.udpConnection.listening(on: port)
            return false
        } catch {
            print("Warnning: listen on port \(port) failed - \(error.localizedDescription)")
            return true
        }
    }
    
    private var localPort: UInt16 {
        self.udpConnection.localPort
    }
    
    // MARK: Open Actions
    
    /// register torrent for local service discovery
    func registerTorrent(with conf: TorrentTaskConf) {
        self.tasks.append(TaskStatus(conf: conf))
        
        self.announceTorrent(with: conf)
    }
    
    /// announce all valid torrent to lsd multicast group
    @objc func announceClient() {
        let infoHashes = self.tasks
            .filter({ $0.isValid })
            .map({ $0.hexInfoHash })
        
        let announceInfo = LSDAnnounce(port: self.localPort, infoHashes: infoHashes, cookie: self.cookie.uuidString)
        let announceData = announceInfo.announceString().data(using: LSDAnnounce.ENCODING)!
        
        udpConnection.send(announceData, toHost: LSDAnnounce.LSD_IPv4_HOST, port: Self.LSD_PORT, timeout: Self.TIME_OUT)
    }
    
    /// announce task directory, get called when registered or resumed
    func announceTorrent(with conf: TorrentTaskConf) {
        guard let task = self.tasks.first(where: { $0.conf == conf }) else {
            return
        }
        
        guard task.isValid else {
            return
        }
        
        let announce = LSDAnnounce(port: self.localPort, infoHashes: [task.hexInfoHash], cookie: self.cookie.uuidString)
        
        guard let payload = announce.toData() else {
            print("Error: failed to convert lsd string to data")
            return
        }
        
        udpConnection.send(payload, toHost: LSDAnnounce.LSD_IPv4_HOST, port: Self.LSD_PORT, timeout: Self.TIME_OUT)
    }
    
    func stopLSDPeerProvider(for conf: TorrentTaskConf) {
        if let index = self.tasks.firstIndex(where: { $0.conf == conf }) {
            self.tasks[index].isValid = false
        }
    }
    
    func resumeLSDPeerProvider(for conf: TorrentTaskConf) {
        if let index = self.tasks.firstIndex(where: { $0.conf == conf }) {
            self.tasks[index].isValid = true
        }
        
        self.announceTorrent(with: conf)
    }
    
    func removeLSDPeerProvider(for conf: TorrentTaskConf) {
        if let index = self.tasks.firstIndex(where: { $0.conf == conf }) {
            self.tasks.remove(at: index)
        }
    }
    
    private struct TaskStatus {
        let conf: TorrentTaskConf
        var isValid: Bool = true
        
        var hexInfoHash: String {
            conf.infoHash.hexEncodedString
        }
    }
    
    #if DEBUG
    var taskCount: Int {
        self.tasks.count
    }
    
    func getTaskStatus(at index: Int) -> Bool {
        return self.tasks[index].isValid
    }
    #endif
}

extension TorrentLSDPeerProvider: UDPConnectionDelegate {
    func udpConnection(_ sender: UDPConnectionProtocol, receivedData data: Data, fromHost host: String) {
        guard let announceInfo = try? LSDAnnounce(data: data) else {
            print("Error: unexpected lsd announce data")
            return
        }
#if DEBUG
        if let index = self.tasks.firstIndex(where: { $0.hexInfoHash == announceInfo.infoHashes.first }) {
            let peerInfo = TorrentPeerInfo(ip: host, port: announceInfo.port)
            delegate?.torrentLSDPeerProvider(self, got: peerInfo, for: self.tasks[index].conf)
        }
#else
        // filter out own announces if it receives them via multicast loopback by checking cookie
        guard !self.tasks.contains(where: { $0.conf.idString == announceInfo.cookie }) else {
            return
        }
        
        for infoHashString in announceInfo.infoHashes {
            // filter torrents that we have
            if let index = self.tasks.firstIndex(where: { $0.conf.infoHash.hexEncodedString == infoHashString }) {
                let peerInfo = TorrentPeerInfo(ip: host, port: announceInfo.port)
                delegate?.torrentLSDPeerProvider(self, got: peerInfo, for: self.tasks[index].conf)
            }
        }
#endif
    }
}
