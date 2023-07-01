//
//  TorrentTrackerResponse.swift
//  
//
//  Created by Wynn Zhang on 6/30/23.
//

import Foundation
import TorrentModel

enum TorrentTrackerEvent: UInt32 {
    case none = 0, completed, started, stopped
    
    var name: String {
        switch self {
        case .none: return "none"
        case .started: return "started"
        case .stopped: return "stopped"
        case .completed: return "completed"
        }
    }
    
    var udpData: Data {
        return self.rawValue.toData()
    }
}

struct TorrentTrackerResponse {
    let peers: [TorrentPeerInfo]
    /// number of seeders
    let numberOfPeersComplete: Int
    /// number of leechers
    let numberOfPeersIncomplete: Int
    
    let trackerID: Data?
    
    let interval: Int
    let minimumInterval: Int
    
    let warning: String?
    
    init(peers: [TorrentPeerInfo],
         numberOfPeersComplete: Int = 0,
         numberOfPeersIncomplete: Int = 0,
         trackerID: Data? = nil,
         interval: Int = 60,
         minimumInterval: Int = 0,
         warning: String? = nil) {
        
        self.peers = peers
        self.numberOfPeersComplete = numberOfPeersComplete
        self.numberOfPeersIncomplete = numberOfPeersIncomplete
        self.trackerID = trackerID
        self.interval = interval
        self.minimumInterval = minimumInterval
        self.warning = warning
    }
    
    init(bencode data: Data) throws {
        guard case .dict(let dictionary) = try BDecoder().decode(data: data) else {
            throw BencodeError.unexpectData
        }
        
        guard case let .int(numberOfPeersComplete) = dictionary["complete"],
              case let .int(numberOfPeersIncomplete) = dictionary["incomplete"],
              case let .int(interval) = dictionary["interval"] else {
            throw BencodeError.unexpectedBencode
        }
        
        if case let .string(binaryData) = dictionary["peers"] {
            self.peers = TorrentPeerInfo.parsePeers(from: binaryData)
        } else {
            guard case let .list(peersDictList) = dictionary["peers"] else {
                throw BencodeError.unexpectedBencode
            }
            
            self.peers = try peersDictList.compactMap({ bencode in
                guard case let .dict(peersInfoDict) = bencode else {
                    throw BencodeError.unexpectedBencode
                }
                return try TorrentPeerInfo(dict: peersInfoDict)
            })
        }
        
        var trackerID: Data? = nil
        if case let .string(trackerIDData) = dictionary["tracker id"] {
            trackerID = trackerIDData
        }
        
        var minimumInterval: Int = 0
        if case let .int(minInterval) = dictionary["min interval"] {
            minimumInterval = minInterval
        }
        
        var warning: String? = nil
        if case let .string(warningData) = dictionary["warning message"], let warningMessage = try? warningData.toString() {
            warning = warningMessage
        }
        
        self.numberOfPeersComplete = numberOfPeersComplete
        self.numberOfPeersIncomplete = numberOfPeersIncomplete
        self.trackerID = trackerID
        self.interval = interval
        self.minimumInterval = minimumInterval
        self.warning = warning
    }
    
    static func parseErrorMessage(data: Data) throws -> String? {
        guard case let .dict(dictionary) = try BDecoder().decode(data: data) else {
            throw BencodeError.unexpectData
        }
        
        if case let .string(messageData) = dictionary["failure reason"] {
            guard let message = try? messageData.toString() else {
                throw BencodeError.unexpectData
            }
            return message
        } else {
            return nil
        }
    }
}
