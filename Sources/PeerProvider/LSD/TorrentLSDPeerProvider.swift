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
    func torrentLSDPeerProvider(_ sender: TorrentLSDPeerProviderProtocol, got newPeer: TorrentPeerInfo, for clientID: Data)
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
    
    /// tag represents the task' status
    var taskConfs: Array<(conf: TorrentTaskConf, status: Bool)> = []
    var taskIndex = 0
    
    init(udpConnection: UDPConnectionProtocol = UDPConnection()) throws {
        self.udpConnection = udpConnection
        
        self.udpConnection.delegate = self
        try self.udpConnection.listening(on: LSDAnnounce.LSD_LISTEN_PORT)
    }
    
    func setupLSDProvider(taskConf: TorrentTaskConf) {
        self.taskConfs.append((conf: taskConf, status: true))
    }
    
    @objc func announceClient() {
        let annouceConf = self.taskConfs[self.taskIndex].conf
        
        let infoHashes = self.taskConfs.filter({ $0.status }).map({ $0.conf.infoHash.hexEncodedString })
        let announceInfo = LSDAnnounce(infoHashes: infoHashes, cookie: annouceConf.idString)
        let announceData = announceInfo.announceString().data(using: LSDAnnounce.ENCODING)!
        
        udpConnection.send(announceData, toHost: LSDAnnounce.LSD_IPv4_HOST, port: Self.LSD_PORT, timeout: 10)
    }
    
    func announceTorrent(for conf: TorrentTaskConf) {
        if let index = self.taskConfs.firstIndex(where: { $0.conf == conf }) {
            if self.taskConfs[index].status {
                let announceInfo = LSDAnnounce(infoHashes: [conf.infoHash.hexEncodedString], cookie: conf.idString)
                let announceData = announceInfo.announceString().data(using: LSDAnnounce.ENCODING)!
                
                udpConnection.send(announceData, toHost: LSDAnnounce.LSD_IPv4_HOST, port: Self.LSD_PORT, timeout: 10)
            }
        }
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
    
    func startLSDProviderImediatly(for conf: TorrentTaskConf) {
        self.announceTorrent(for: conf)
    }
}

extension TorrentLSDPeerProvider: UDPConnectionDelegate {
    func udpConnection(_ sender: UDPConnectionProtocol, receivedData data: Data, fromHost host: String) {
        if let announceInfo = try? LSDAnnounce(data: data) {
            #if DEBUG
            if let port = UInt16(announceInfo.port) {
                if let index = self.taskConfs.firstIndex(where: { $0.conf.infoHash.hexEncodedString == announceInfo.infoHashes[0] }) {
                    let peerInfo = TorrentPeerInfo(ip: host, port: port)
                    delegate?.torrentLSDPeerProvider(self, got: peerInfo, for: self.taskConfs[index].conf.id)
                }
            }
            #else
            // filter out own announces if it receives them via multicast loopback by checking cookie
            if !self.taskConfs.contains(where: { $0.conf.idString == announceInfo.cookie }) {
                if let port = UInt16(announceInfo.port) {
                    for infoHashString in announceInfo.infoHashes {
                        // filter torrents that we have
                        if let index = self.taskConfs.firstIndex(where: { $0.conf.infoHash.hexEncodedString == infoHashString }) {
                            let peerInfo = TorrentPeerInfo(ip: host, port: port)
                            delegate?.torrentLSDPeerProvider(self, got: peerInfo, for: self.taskConfs[index].conf.id)
                        }
                    }
                }
            }
            #endif
        }
    }
}
