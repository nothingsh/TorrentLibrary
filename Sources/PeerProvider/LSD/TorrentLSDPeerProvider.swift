//
//  TorrentLSDPeerProvider.swift
//  
//
//  Created by Wynn Zhang on 8/26/23.
//

import Foundation

enum TorrentLSDPeerProviderError: Error {
    case unexpectedAnnounceData
    case unexpectedAnnounceContent
}

struct LSDAnnounce {
    static let ENCODING: String.Encoding = .utf16
    static let HEADER = "BT-SEARCH * HTTP/1.1\r\n"
    
    let host: String
    let port: String
    let infoHash: String
    let cookie: String?
    
    init(host: String, port: String, infoHash: String, cookie: String?) {
        self.host = host
        self.port = port
        self.infoHash = infoHash
        self.cookie = cookie
    }
    
    init(data: Data) throws {
        guard let announceString = String(data: data, encoding: LSDAnnounce.ENCODING) else {
            throw TorrentLSDPeerProviderError.unexpectedAnnounceData
        }
        
        let announceArray = announceString.split(omittingEmptySubsequences: true, whereSeparator: { $0 == "\r\n" })
        
        var announceDict = [String: String]()
        for subString in announceArray {
            let newString = String(subString)
            let pairs = newString.split(whereSeparator: { $0 == ":" })
            
            if pairs.count == 2 {
                let key = String(pairs[0])
                let values = pairs[1].split(whereSeparator: { $0 == " " })
                if values.count == 1 {
                    let value = String(values[0])
                    announceDict[key] = value
                }
            }
        }
        
        guard let host = announceDict["Host"] else {
            throw TorrentLSDPeerProviderError.unexpectedAnnounceContent
        }
        
        guard let port = announceDict["Port"] else {
            throw TorrentLSDPeerProviderError.unexpectedAnnounceContent
        }
        
        guard let infoHash = announceDict["Infohash"] else {
            throw TorrentLSDPeerProviderError.unexpectedAnnounceContent
        }
        
        var cookie: String?
        if let cookieContent = announceDict["cookie"] {
            cookie = cookieContent
        }
        
        self.init(host: host, port: port, infoHash: infoHash, cookie: cookie)
    }
    
    func announceString() -> String {
        let hostStr = "Host: \(host)\r\n"
        let portStr = "Port: \(port)\r\n"
        let infoHashStr = "Infohash: \(infoHash)\r\n"
        let cookieStr = (cookie == nil) ? "" : "cookie: \(cookie!)\r\n"
        let endStr = "\r\n\r\n"
        
        return LSDAnnounce.HEADER + hostStr + portStr + infoHashStr + cookieStr + endStr
    }
}

protocol TorrentLSDPeerProviderProtocol: AnyObject {
    func announceClient()
}

protocol TorrentLSDPeerProviderDelegate: AnyObject {
    func torrentLSDPeerProvider(_ sender: TorrentLSDPeerProviderProtocol, got newPeer: TorrentPeerInfo, with infoHash: String, for clientID: String?)
}

/// local service discovery
class TorrentLSDPeerProvider: TorrentLSDPeerProviderProtocol {
    weak var delegate: TorrentLSDPeerProviderDelegate?
    
    private let udpConnection: UDPConnectionProtocol
    private let peerID: String
    private let infoHash: Data
    private let announceTimeInterval: TimeInterval = 300
    
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
    
    init(clientID: Data, infoHash: Data, udpConnection: UDPConnectionProtocol = UDPConnection()) throws {
        self.peerID = "dt-client" + String(urlEncodingData: clientID)
        // sha1 of info raw data
        self.infoHash = infoHash
        self.udpConnection = udpConnection
        
        self.udpConnection.delegate = self
        try self.udpConnection.listening(on: Self.LSD_PORT)
    }
    
    @objc func announceClient() {
        let infoHashString = String(urlEncodingData: self.infoHash)
        let announceInfo = LSDAnnounce(host: Self.LSD_IPv4_HOST, port: String(Self.LSD_PORT), infoHash: infoHashString, cookie: peerID)
        let announceData = announceInfo.announceString().data(using: LSDAnnounce.ENCODING)!
        
        udpConnection.send(announceData, toHost: Self.LSD_IPv4_HOST, port: Self.LSD_PORT, timeout: 10)
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
                delegate?.torrentLSDPeerProvider(self, got: peerInfo, with: announceInfo.infoHash, for: announceInfo.cookie)
            }
            #else
            // filter out own announces if it receives them via multicast loopback by checking cookie
            if announceInfo.cookie != self.peerID {
                if let port = UInt16(announceInfo.port) {
                    let peerInfo = TorrentPeerInfo(ip: host, port: port)
                    delegate?.torrentLSDPeerProvider(self, got: peerInfo, with: announceInfo.infoHash, for: announceInfo.cookie)
                }
            }
            #endif
        }
    }
}
