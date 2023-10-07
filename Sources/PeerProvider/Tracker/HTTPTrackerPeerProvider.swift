//
//  HTTPTrackerPeerProvider.swift
//  
//
//  Created by Wynn Zhang on 8/31/23.
//

import Foundation

class HTTPTrackerPeerProvider: TorrentTrackerProtocol {
    var delegate: TorrentTrackerDelegate?
    
    private var httpConnectionPool: [HTTPConnectionProtocol]
    private var requestList: [TrackerConnectionRequest]
    private var urlParameters: [String: String]
    
    static let MAX_HTTP_TRACKER_CONNECTION: Int = 10
    
    init(announceURLs: [URL]) {
        let httpConnectionCount = min(announceURLs.count, Self.MAX_HTTP_TRACKER_CONNECTION)
        
        self.httpConnectionPool = []
        self.requestList = announceURLs.map { TrackerConnectionRequest(url: $0) }
        self.urlParameters = [:]
        
        for _ in 0..<httpConnectionCount {
            let httpConnection = HTTPConnection()
            httpConnection.delegate = self
            self.httpConnectionPool.append(httpConnection)
        }
    }
    
    func announceClient(with peerID: String, port: UInt16, event: TorrentTrackerEvent, infoHash: Data, annouceInfo: TrackerAnnonuceInfo) throws {
        // reset requests
        for index in 0..<self.requestList.count {
            self.requestList[index].requested = false
        }
        
        self.urlParameters = [
            "info_hash" : String(urlEncodingData: infoHash),
            "peer_id" : peerID,
            "port" : "\(port)",
            "uploaded" : "\(annouceInfo.numberOfBytesUploaded)",
            "downloaded" : "\(annouceInfo.numberOfBytesDownloaded)",
            "left" : "\(annouceInfo.numberOfBytesRemaining)",
            "compact" : "1",
            "event" : event.name,
            "numwant" : "\(annouceInfo.numberOfPeersToFetch)"
        ]
        
        for index in 0..<self.httpConnectionPool.count {
            let request = self.requestList[index]
            self.httpConnectionPool[index].makeRequest(url: request.url, urlParameters: self.urlParameters)
        }
    }
    
    private func findCleanReuqestAndConnect() -> URL? {
        if let index = self.requestList.firstIndex(where: { $0.requested == false }) {
            return self.requestList[index].url
        } else {
            return nil
        }
    }
    
    private struct TrackerConnectionRequest {
        let url: URL
        var requested: Bool = false
    }
}

extension HTTPTrackerPeerProvider: HTTPConnectionDelegate {
    func httpConnection(_ sender: HTTPConnectionProtocol, url: URL, response: HTTPResponse) {
        // check if data is empty
        guard let data = response.responseData else {
            print("HTTPTrackerPeerProvider: Empty http response data")
            return
        }
        // parse response data
        do {
            if let result = try? TorrentTrackerResponse(bencode: data) {
                delegate?.torrentTracker(self, receivedResponse: result)
            } else if let errorMessage = try TorrentTrackerResponse.parseErrorMessage(data: data) {
                delegate?.torrentTracker(self, receivedErrorMessage: errorMessage)
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        
        // set the url as requested
        if let index = self.requestList.firstIndex(where: { $0.url == url }) {
            self.requestList[index].requested = true
        }
        
        // find the finished http connection
        if let index = self.httpConnectionPool.firstIndex(where: { $0 === sender }) {
            // if still have requests unfullfill
            if let requestURL = findCleanReuqestAndConnect() {
                self.httpConnectionPool[index].makeRequest(url: requestURL, urlParameters: self.urlParameters)
            }
        }
    }
}
