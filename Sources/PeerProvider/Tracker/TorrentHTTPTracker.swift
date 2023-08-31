//
//  TorrentHTTPTracker.swift
//  
//
//  Created by Wynn Zhang on 6/30/23.
//

import Foundation

class TorrentHTTPTracker: TorrentTrackerProtocol {
    weak var delegate: TorrentTrackerDelegate?
    
    let announce: URL
    let connection: HTTPConnection
    
    init(announce: URL, connection: HTTPConnection = HTTPConnection()) {
        self.announce = announce
        self.connection = connection
        self.connection.delegate = self
    }
    
    func announceClient(with peerID: String, port: UInt16, event: TorrentTrackerEvent, infoHash: Data, annouceInfo: TrackerAnnonuceInfo) throws {
        let parameter = [
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
        
        connection.makeRequest(url: announce, urlParameters: parameter)
    }
}

extension TorrentHTTPTracker: HTTPConnectionDelegate {
    func httpConnection(_ sender: HTTPConnectionProtocol, url: URL, response: HTTPResponse) {
        if let data = response.responseData {
            do {
                if let result = try? TorrentTrackerResponse(bencode: data) {
                    delegate?.torrentTracker(self, receivedResponse: result)
                } else if let errorMessage = try TorrentTrackerResponse.parseErrorMessage(data: data) {
                    delegate?.torrentTracker(self, receivedErrorMessage: errorMessage)
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}
