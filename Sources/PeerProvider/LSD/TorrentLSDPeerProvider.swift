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
    func torrentLSDPeerProvider(_ sender: TorrentLSDPeerProviderProtocol, got newPeer: TorrentPeerInfo, with infoHashes: [String], for clientID: String?)
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
    
    // broadcast address and port in LAN
    static let LSD_IPv6_HOST = "ff15::efc0:988f"
    static let LSD_IPv4_HOST = "239.192.152.143"
    static let LSD_PORT: UInt16 = 6771
    
    /// tag represents the task' status
    var taskConfs: Array<(conf: TorrentTaskConf, status: Bool)> = []
    var taskIndex = 0
    
    init(udpConnection: UDPConnectionProtocol = UDPConnection()) throws {
        self.udpConnection = udpConnection
        
        self.udpConnection.delegate = self
        try self.udpConnection.listening(on: Self.LSD_PORT)
    }
    
    func setupLSDProvider(taskConf: TorrentTaskConf) {
        self.taskConfs.append((conf: taskConf, status: true))
    }
    
    /// announce torrent tasks one by one with 2 minites interval
    @objc func announceClient() {
        let annouceConf = self.taskConfs[self.taskIndex].conf
        
        let infoHashes = self.taskConfs.filter({ $0.status }).map({ $0.conf.idString })
        let announceInfo = LSDAnnounce(host: Self.LSD_IPv4_HOST, port: String(Self.LSD_PORT), infoHashes: infoHashes, cookie: annouceConf.idString)
        let announceData = announceInfo.announceString().data(using: LSDAnnounce.ENCODING)!
        
        udpConnection.send(announceData, toHost: Self.LSD_IPv4_HOST, port: Self.LSD_PORT, timeout: 10)
    }
    
    func stopLSDPeerProvider(for conf: TorrentTaskConf) {
        if let index = self.taskConfs.firstIndex(where: { $0.conf == conf }) {
            self.taskConfs[index].status = false
        }
    }
    
    func resumeLSDPeerProvider(for conf: TorrentTaskConf) {
        if let index = self.taskConfs.firstIndex(where: { $0.conf == conf }) {
            self.taskConfs[index].status = true
        }
    }
    
    func removeLSDPeerProvider(for conf: TorrentTaskConf) {
        if let index = self.taskConfs.firstIndex(where: { $0.conf == conf }) {
            self.taskConfs.remove(at: index)
        }
    }
    
    func forceReannounce() {
        announceTimer.fire()
    }
}

extension TorrentLSDPeerProvider: UDPConnectionDelegate {
    func udpConnection(_ sender: UDPConnectionProtocol, receivedData data: Data, fromHost host: String) {
        if let announceInfo = try? LSDAnnounce(data: data) {
            #if DEBUG
            if let port = UInt16(announceInfo.port) {
                let peerInfo = TorrentPeerInfo(ip: host, port: port)
                delegate?.torrentLSDPeerProvider(self, got: peerInfo, with: announceInfo.infoHashes, for: announceInfo.cookie)
            }
            #else
            // filter out own announces if it receives them via multicast loopback by checking cookie
            if !self.taskConfs.contains(where: { $0.conf.idString == announceInfo.cookie }) {
                // make sure we need these torrent
                let needInfoHashes = announceInfo.infoHashes.filter { infoHash in
                    self.taskConfs.contains(where: { $0.conf.infoHash.hexEncodedString == infoHash })
                }
                if let port = UInt16(announceInfo.port), needInfoHashes.count != 0 {
                    let peerInfo = TorrentPeerInfo(ip: host, port: port)
                    delegate?.torrentLSDPeerProvider(self, got: peerInfo, with: announceInfo.infoHashes, for: announceInfo.cookie)
                }
            }
            #endif
        }
    }
}
