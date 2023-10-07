//
//  TorrentUDPTracker.swift
//  
//
//  Created by Wynn Zhang on 6/30/23.
//

import Foundation

public enum TorrentUDPTrackerError: Error {
    case unexpectedAnnounceHost
}

class TorrentUDPTracker: TorrentTrackerProtocol {
    weak var delegate: TorrentTrackerDelegate?
    
    let announce: URL
    
    private let udpConnection: UDPConnection
    private var discoveredHostIPAddress: String?
    
    private var pendingAnnounce: ((_ transactionID: Data, _ connectionID: Data) -> Void)?
    private var pendingTransactionID: Data?
    
    init(announceURL: URL, port: UInt16, udpConnection: UDPConnection = UDPConnection()) throws {
        self.announce = announceURL
        self.udpConnection = udpConnection
        
        udpConnection.delegate = self
        try udpConnection.listening(on: port)
    }
    
    func announceClient(with peerID: String, port: UInt16, event: TorrentTrackerEvent, infoHash: Data, annouceInfo: TrackerAnnonuceInfo) throws {
        guard let announceHost = announce.host else {
            throw TorrentUDPTrackerError.unexpectedAnnounceHost
        }
        
        let trackerHost: String?
        if self.discoveredHostIPAddress == nil {
            trackerHost = InternetHelper.getSocketIPAddress(of: announceHost)
            self.discoveredHostIPAddress = trackerHost
        } else {
            trackerHost = self.discoveredHostIPAddress
        }
        
        guard let host = trackerHost else { return }
        let announcePort = UInt16(announce.port ?? 80)
        
        let transactionID = makeTransactionID()
        let payload = makeConnectionPayload(with: transactionID)
        udpConnection.send(payload, toHost: host, port: announcePort, timeout: 10)
        
        pendingAnnounce = { [weak self] responseTransactionID, connectionID in
            guard let strongSelf = self else { return }
            guard responseTransactionID == transactionID else { return }
            
            var payload = connectionID                           // 0      64-bit integer  connection_id
            payload += Self.ANNOUNCE_HEADER                      // 8      32-bit integer  action          1 // announce
            payload += strongSelf.makeTransactionID()            // 12     32-bit integer  transaction_id
            payload += infoHash                                  // 16     20-byte string  info_hash
            payload += peerID.data(using: .ascii)!               // 36     20-byte string  peer_id
            payload += UInt64(annouceInfo.numberOfBytesDownloaded).toData()  // 56     64-bit integer  downloaded
            payload += UInt64(annouceInfo.numberOfBytesRemaining).toData()   // 64     64-bit integer  left
            payload += UInt64(annouceInfo.numberOfBytesUploaded).toData()    // 72     64-bit integer  uploaded
            payload += event.udpData                             // 80     32-bit integer  event
            payload += UInt32(0).toData()                        // 84     32-bit integer  IP address      0 // default
            payload += UInt32(0).toData()                        // 88     32-bit integer  key             0 // default
            payload += UInt32(annouceInfo.numberOfPeersToFetch).toData()     // 92     32-bit integer  num_want       -1 // default
            payload += UInt16(port).toData()                     // 96     16-bit integer  port
            
            strongSelf.udpConnection.send(payload, toHost: host, port: announcePort, timeout: 10)
        }
    }
    
    /// connect request
    ///
    /// | offset | size | name | value |
    /// | :----  | :---- | :------- | :--- |
    /// | 0 | 8B | protocol_id | 0x41727101980 // magic number |
    /// | 8 | 4B | action | 0 // connect |
    /// | 12 | 4B | transaction_id | - |
    /// | 16 | - | - | - |
    private func makeConnectionPayload(with transactionID: Data) -> Data {
        return Self.PROTOCOL_ID + Self.CONNECTION_HEADER + transactionID
    }
    
    private func makeTransactionID() -> Data {
        let result = arc4random().toData()
        pendingTransactionID = result
        return result
    }
    
    var port: UInt16 {
        udpConnection.localPort
    }
    
    private static let DEFAULT_PORT: UInt16 = 80
    
    // magic constant (protocol_id)
    private static let PROTOCOL_ID = (0x41727101980 as UInt64).toData()

    private static let CONNECTION_HEADER = UInt32(0).toData()
    private static let ANNOUNCE_HEADER = UInt32(1).toData()
    private static let ERROR_HEADER = UInt32(3).toData()
}

extension TorrentUDPTracker: UDPConnectionDelegate {
    func udpConnection(_ sender: UDPConnectionProtocol, receivedData data: Data, fromHost host: String) {
        let endIndex = data.startIndex + 4
        let header = data[data.startIndex..<endIndex]
        
        switch header {
        case Self.ANNOUNCE_HEADER:
            parseAnnounceResponse(data)
            break
        case Self.CONNECTION_HEADER:
            parseConnectionResponse(data)
            break
        case Self.ERROR_HEADER:
            parseErrorResponse(data)
            break
        default:
            print("Warning: unexpected torrent UDP trancker response data header")
            break
        }
    }
    
    private func parseConnectionResponse(_ response: Data) {
        let startIndex = response.startIndex + 4, midIndex = startIndex + 4, endIndex = midIndex + 8
        let transactionId = response[startIndex..<midIndex]
        let connectionId = response[midIndex..<endIndex]
        
        pendingAnnounce?(transactionId, connectionId)
        pendingAnnounce = nil
    }
    
    private func parseAnnounceResponse(_ response: Data) {
        let indice = [4, 8, 12, 16, 20].map { $0 + response.startIndex }
        let transactionID = response[indice[0]..<indice[1]]
        guard pendingTransactionID == transactionID else {
            print("Error: unexpected transaction ID")
            return
        }
        
        let interval = response[indice[1]..<indice[2]].toUInt32()
        let leechers = response[indice[2]..<indice[3]].toUInt32()
        let seeders  = response[indice[3]..<indice[4]].toUInt32()
        let peers = TorrentPeerInfo.parsePeers(from: response[indice[4]..<response.count])
        
        let response = TorrentTrackerResponse(peers: peers, numberOfPeersComplete: Int(seeders), numberOfPeersIncomplete: Int(leechers), interval: Int(interval))
        
        self.delegate?.torrentTracker(self, receivedResponse: response)
    }
    
    private func parseErrorResponse(_ response: Data) {
        let startIndex = response.startIndex + 8
        
        if let errorMessage = try? response[startIndex..<response.count].toString() {
            delegate?.torrentTracker(self, receivedErrorMessage: errorMessage)
        }
    }
}
