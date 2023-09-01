//
//  UDPTrackerPeerProvider.swift
//  
//
//  Created by Wynn Zhang on 8/31/23.
//

import Foundation

class UDPTrackerPeerProvider: TorrentTrackerProtocol {
    var delegate: TorrentTrackerDelegate?
    
    private var udpConnectionPool: [UDPConnectionProtocol]
    private var requestList: [TrackerConnectionRequest]
    private var urlParameters: [String: Data]
    
    static let MAX_UDP_TRACKER_CONNECTION: Int = 10
    static var START_PORT: UInt16 = 3475
    
    init(announceURLs: [URL]) {
        self.urlParameters = [:]
        self.udpConnectionPool = []
        self.requestList = []
        
        self.initializeUDPTracker(announceURLs: announceURLs)
    }
    
    /// setup requests and udp connections
    private func initializeUDPTracker(announceURLs: [URL]) {
        for url in announceURLs {
            var hostString: String? = nil
            if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
                hostString = url.host()
            } else {
                hostString = url.host
            }
            
            // invalid url
            if hostString == nil {
                continue
            }
            
            // parse port
            let port = UInt16(url.port ?? Self.DEFAULT_PORT)
            
            // parse url to ip
            if let host = InternetHelper.getSocketIPAddress(of: hostString!) {
                self.requestList.append(TrackerConnectionRequest(host: host, port: port))
            }
        }
        
        let udpConnectionCount = min(self.requestList.count, Self.MAX_UDP_TRACKER_CONNECTION)
        for _ in 0..<udpConnectionCount {
            let udpConnection = UDPConnection()
            
            var port = Self.START_PORT + 1
            while !self.tryToListen(connection: udpConnection, on: port) {
                port += 1
            }
            
            udpConnection.delegate = self
            self.udpConnectionPool.append(udpConnection)
        }
    }
    
    /// udp tracker announce
    ///
    /// client --> server: try to connect with transaction id
    ///
    /// server --> client: connected and return a connection id
    ///
    /// client --> server: send announce
    ///
    /// server --> client: respond with peers info
    func announceClient(with peerID: String, port: UInt16, event: TorrentTrackerEvent, infoHash: Data, annouceInfo: TrackerAnnonuceInfo) throws {
        for index in 0..<self.requestList.count {
            self.requestList[index].requested = false
            self.requestList[index].transactionID = makeTransactionID()
        }
        
        for index in 0..<self.udpConnectionPool.count {
            self.requestList[index].requested = true
            
            let host = self.requestList[index].host
            let port = self.requestList[index].port
            let transactionID = self.requestList[index].transactionID!
            let payload = self.makeConnectionPayload(with: transactionID)
            let udpConnection = self.udpConnectionPool[index]
            // try to connect
            udpConnection.send(payload, toHost: host, port: port, timeout: Self.TIMEOUT)
        }
        
        self.urlParameters = [
            "infoHash": infoHash,
            "peerID": peerID.data(using: .ascii)!,
            "downloaded": UInt64(annouceInfo.numberOfBytesDownloaded).toData(),
            "remaining": UInt64(annouceInfo.numberOfBytesRemaining).toData(),
            "uploaded": UInt64(annouceInfo.numberOfBytesUploaded).toData(),
            "event": event.udpData,
            "peers": UInt32(annouceInfo.numberOfPeersToFetch).toData(),
            "port": UInt16(port).toData()
        ]
    }
    
    private func tryToListen(connection: UDPConnectionProtocol, on port: UInt16) -> Bool  {
        if connection.localPort != 0 {
            return true
        }
        
        do {
            try connection.listening(on: port)
            Self.START_PORT = port
            return true
        } catch {
            print("Warning: can't listen on \(port) - \(error.localizedDescription)")
            return false
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
    
    /// create a random integer as transaction id
    private func makeTransactionID() -> Data {
        let result = arc4random().toData()
        return result
    }
    
    private func findCleanRequestAndConnection(udpConnection: UDPConnectionProtocol) {
        guard let index = self.requestList.firstIndex(where: { $0.requested == false }) else {
            return
        }
        
        self.requestList[index].transactionID = makeTransactionID()
        let host = self.requestList[index].host
        let port = self.requestList[index].port
        let transactionID = self.requestList[index].transactionID!
        let payload = self.makeConnectionPayload(with: transactionID)
        
        udpConnection.send(payload, toHost: host, port: port, timeout: Self.TIMEOUT)
    }
    
    private static let TIMEOUT: TimeInterval = 10
    private static let DEFAULT_PORT: Int = 80
    
    // magic constant (protocol_id)
    private static let PROTOCOL_ID = (0x41727101980 as UInt64).toData()

    private static let CONNECTION_HEADER = UInt32(0).toData()
    private static let ANNOUNCE_HEADER = UInt32(1).toData()
    private static let ERROR_HEADER = UInt32(3).toData()
    
    private struct TrackerConnectionRequest {
        let host: String
        let port: UInt16
        var requested: Bool = false
        // generate locally
        var transactionID: Data? = nil
        // get from udp tracker server
        var connectionID: Data? = nil
    }
 }

extension UDPTrackerPeerProvider: UDPConnectionDelegate {
    func udpConnection(_ sender: UDPConnectionProtocol, receivedData data: Data, fromHost host: String) {
        let endIndex = data.startIndex + 4
        let header = data[data.startIndex..<endIndex]
        
        switch header {
        case Self.ANNOUNCE_HEADER:
            self.parseAnnounceResponse(sender, with: data, from: host)
            break
        case Self.CONNECTION_HEADER:
            self.parseConnectionResponse(sender, with: data, from: host)
            break
        case Self.ERROR_HEADER:
            self.parseErrorResponse(data, from: host)
            break
        default:
            print("Warning: unexpected torrent UDP trancker response data header")
            break
        }
    }
    
    private func parseConnectionResponse(_ sender: UDPConnectionProtocol, with response: Data, from host: String) {
        let startIndex = response.startIndex + 4
        let midIndex = startIndex + 4
        let endIndex = midIndex + 8
        
        let transactionID = response[startIndex..<midIndex]
        let connectionID = response[midIndex..<endIndex]
        
        guard let index = self.requestList.firstIndex(where: { $0.host == host }) else {
            print("Warning: unexpected udp tracker host")
            return
        }
        
        guard self.requestList[index].transactionID == transactionID else {
            print("Warning: unexpected udp tracker transaction id")
            return
        }
        
        let newTransactionID = self.makeTransactionID()
        self.requestList[index].transactionID = newTransactionID
        
        let request = self.requestList[index]
        let payload = makeAnnouncePayload(transactionID: newTransactionID, connectionID: connectionID)
        
        sender.send(payload, toHost: request.host, port: request.port, timeout: Self.TIMEOUT)
    }
    
    /// create announce payload
    ///
    /// | offset | size | name |
    /// | --- | --- | --- |
    /// | 0 | 8B | connection id |
    /// | 8 | 4B | announce header |
    /// | 12 | 4B | transaction id |
    /// | 16 | 20B | torrent info hash |
    /// | 36 | 20B | peer id |
    /// | 56 | 8B | downloaded bytes |
    /// | 64 | 8B | remaining bytes |
    /// | 72 | 8B | uploaded bytes |
    /// | 80 | 4B | event |
    /// | 84 | 4B | ip |
    /// | 88 | 4B | key |
    /// | 92 | 4B | peer size to fetch |
    /// | 96 | 2B | port |
    private func makeAnnouncePayload(transactionID: Data, connectionID: Data) -> Data {
        var payload = connectionID
        payload += Self.ANNOUNCE_HEADER
        payload += transactionID
        payload += self.urlParameters["infoHash"]!
        payload += self.urlParameters["peerID"]!
        payload += self.urlParameters["downloaded"]!
        payload += self.urlParameters["remaining"]!
        payload += self.urlParameters["uploaded"]!
        payload += self.urlParameters["event"]!
        payload += UInt32(0).toData()    // 84     32-bit integer  IP address      0 // default
        payload += UInt32(0).toData()    // 88     32-bit integer  key             0 // default
        payload += self.urlParameters["peers"]!
        payload += self.urlParameters["port"]!
        
        return payload
    }
    
    private func parseAnnounceResponse(_ sender: UDPConnectionProtocol, with response: Data, from host: String) {
        let indice = [4, 8, 12, 16, 20].map { $0 + response.startIndex }
        let transactionID = response[indice[0]..<indice[1]]
        
        guard let index = self.requestList.firstIndex(where: { $0.host == host }) else {
            print("Warning: unexpected udp tracker host")
            return
        }
        
        guard self.requestList[index].transactionID == transactionID else {
            print("Warning: unexpected udp tracker transaction id")
            return
        }
        
        let interval = response[indice[1]..<indice[2]].toUInt32()
        let leechers = response[indice[2]..<indice[3]].toUInt32()
        let seeders  = response[indice[3]..<indice[4]].toUInt32()
        let peers = TorrentPeerInfo.parsePeers(from: response[indice[4]..<response.count])
        
        let response = TorrentTrackerResponse(peers: peers, numberOfPeersComplete: Int(seeders), numberOfPeersIncomplete: Int(leechers), interval: Int(interval))
        
        self.delegate?.torrentTracker(self, receivedResponse: response)
        
        self.findCleanRequestAndConnection(udpConnection: sender)
    }
    
    private func parseErrorResponse(_ response: Data, from host: String) {
        let startIndex = response.startIndex + 8
        
        if let errorMessage = try? response[startIndex..<response.count].toString() {
            delegate?.torrentTracker(self, receivedErrorMessage: errorMessage)
        }
    }
}
