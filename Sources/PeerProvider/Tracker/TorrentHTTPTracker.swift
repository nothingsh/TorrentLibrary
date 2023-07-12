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
    }
    
    func announceClient(with peerID: String, port: UInt16, event: TorrentTrackerEvent, infoHash: Data, numberOfBytesRemaining: Int, numberOfBytesUploaded: Int, numberOfBytesDownloaded: Int, numberOfPeersToFetch: Int) throws {
        let parameter = [
            "info_hash" : infoHash.base64EncodedString(),
            "peer_id" : peerID,
            "port" : "\(port)",
            "uploaded" : "\(numberOfBytesUploaded)",
            "downloaded" : "\(numberOfBytesDownloaded)",
            "left" : "\(numberOfBytesRemaining)",
            "compact" : "1",
            "event" : event.name,
            "numwant" : "\(numberOfPeersToFetch)"
        ]
        
        try connection.makeRequest(url: announce, urlParameters: parameter) { [weak self] response in
            guard let weakSelf = self else {
                return
            }
            
            if let data = response.responseData {
                do {
                    if let result = try? TorrentTrackerResponse(bencode: data) {
                        weakSelf.delegate?.torrentTracker(weakSelf, receivedResponse: result)
                    } else if let errorMessage = try TorrentTrackerResponse.parseErrorMessage(data: data) {
                        weakSelf.delegate?.torrentTracker(weakSelf, receivedErrorMessage: errorMessage)
                    }
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
}
