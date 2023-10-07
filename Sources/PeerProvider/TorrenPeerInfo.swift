//
//  File.swift
//  
//
//  Created by Wynn Zhang on 6/30/23.
//

import Foundation
import TorrentModel

public enum TorrentPeerInfoError: Error {
    case unexpectedIpAddress
    case unexpectedPort
}

struct TorrentPeerInfo: Equatable {
    let ip: String
    let port: UInt16
    let peerID: Data?
    
    init(ip: String, port: UInt16, id: Data? = nil) {
        self.ip = ip
        self.port = port
        self.peerID = id
    }
    
    init?(dict: [String: Bencode]) throws {
        guard case let .string(ipData) = dict["ip"] else {
            throw BencodeError.unexpectedBencode
        }
        
        guard let ip = try? ipData.toString() else {
            throw BencodeError.unexpectData
        }
        
        guard case let .int(port) = dict["port"] else {
            throw BencodeError.unexpectedBencode
        }
        
        var idData: Data? = nil
        if case let .string(peerIDData) = dict["peer id"] {
            idData = peerIDData
        }
        
        self.ip = ip
        self.port = UInt16(port)
        self.peerID =  idData
    }
    
    static func parsePeers(from data: Data) -> [TorrentPeerInfo] {
        let peersCount = data.count / 6
        var result = [TorrentPeerInfo]()
        
        for peerIndex in 0..<peersCount {
            var ipAddress = ""
            for ipIndex in 0..<4 {
                let index = data.startIndex + 6 * peerIndex + ipIndex
                let ipNumber = Int(data[index])
                ipAddress += (ipIndex == 0 ? "\(ipNumber)" : ".\(ipNumber)")
            }
            
            let portBytesIndex = data.startIndex + 6*peerIndex + 4
            let port = UInt16(data[portBytesIndex]) << 8 + UInt16(data[portBytesIndex+1])
            
            result.append(TorrentPeerInfo(ip: ipAddress, port: port))
        }
        
        return result
    }
}
