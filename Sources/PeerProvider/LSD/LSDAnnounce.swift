//
//  LSDAnnounce.swift
//  
//
//  Created by Wynn Zhang on 8/28/23.
//

import Foundation

struct LSDAnnounce {
    static let ENCODING: String.Encoding = .utf16
    static let HEADER = "BT-SEARCH * HTTP/1.1\r\n"
    
    // broadcast address and port in LAN
    static let LSD_IPv6_HOST = "ff15::efc0:988f"
    static let LSD_IPv4_HOST = "239.192.152.143"
    
    let host: String
    let port: UInt16
    let infoHashes: [String]
    let cookie: String?
    
    /// Local Service Discovery (LSD) provides a SSDP-like (http over udp-multicast) mechanism to announce the presence in specific swarms to local neighbors.
    ///
    /// - Parameter host: specifying the multicast group to which the announce is sent
    /// - Parameter port: on which the bittorrent client is listening in base-10, ascii
    /// - Parameter infoHash: hex-encoded (40 character) infohash, An announce may contain multiple, consecutive Infohash headers to announce the participation in more than one torrent.
    /// - Parameter cookie: opaque value, allowing the sending client to filter out its own announces if it receives them via multicast loopback
    init(host: String = Self.LSD_IPv4_HOST, port: UInt16, infoHashes: [String], cookie: String?) {
        self.host = host
        self.port = port
        self.infoHashes = infoHashes
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
        
        guard let portString = announceDict["Port"], let port = UInt16(portString) else {
            throw TorrentLSDPeerProviderError.unexpectedAnnounceContent
        }
        
        guard let infoHashesString = announceDict["Infohash"] else {
            throw TorrentLSDPeerProviderError.unexpectedAnnounceContent
        }
        
        let infoHashLength = 40
        guard infoHashesString.count % infoHashLength == 0 else {
            throw TorrentLSDPeerProviderError.unexpectedInfoHashesLength
        }
        
        var infoHashes: [String] = []
        for index in 0..<infoHashesString.count/infoHashLength {
            let startIndex = infoHashesString.index(infoHashesString.startIndex, offsetBy: index * infoHashLength)
            let endIndex = infoHashesString.index(infoHashesString.startIndex, offsetBy: (index + 1) * infoHashLength)
            infoHashes.append(String(infoHashesString[startIndex..<endIndex]))
        }
        
        var cookie: String?
        if let cookieContent = announceDict["cookie"] {
            cookie = cookieContent
        }
        
        self.init(host: host, port: port, infoHashes: infoHashes, cookie: cookie)
    }
    
    func announceString() -> String {
        let hostStr = "Host: \(host)\r\n"
        let portStr = "Port: \(port)\r\n"
        let infoHashStr = "Infohash: \(infoHashesString)\r\n"
        let cookieStr = (cookie == nil) ? "" : "cookie: \(cookie!)\r\n"
        let endStr = "\r\n\r\n"
        
        return LSDAnnounce.HEADER + hostStr + portStr + infoHashStr + cookieStr + endStr
    }
    
    func toData() -> Data? {
        return self.announceString().data(using: Self.ENCODING)
    }
    
    var infoHashesString: String {
        infoHashes.reduce("", {$0 + $1})
    }
}
