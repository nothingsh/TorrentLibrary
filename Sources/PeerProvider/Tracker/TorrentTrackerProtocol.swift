//
//  TorrentTrackerProtocl.swift
//  
//
//  Created by Wynn Zhang on 6/30/23.
//

import Foundation

protocol TorrentTrackerDelegate: AnyObject {
    func torrentTracker(_ sender: TorrentTrackerProtocol, receivedResponse response: TorrentTrackerResponse)
    func torrentTracker(_ sender: TorrentTrackerProtocol, receivedErrorMessage errorMessage: String)
}

protocol TorrentTrackerProtocol: AnyObject {
    var delegate: TorrentTrackerDelegate? { get set }
    
    func announceClient(with peerID: String, port: UInt16, event: TorrentTrackerEvent, infoHash: Data, numberOfBytesRemaining: Int, numberOfBytesUploaded: Int, numberOfBytesDownloaded: Int, numberOfPeersToFetch: Int) throws
}
