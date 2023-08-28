//
//  TorrentTaskConf.swift
//  
//
//  Created by Wynn Zhang on 8/27/23.
//

import Foundation
import TorrentModel

struct TorrentTaskConf: Hashable {
    let torrent: TorrentModel
    // A string of length 20 which this downloader uses as its id
    let id: Data
    let idString: String
    
    /// every torrent has a unique torrent id
    init(torrent: TorrentModel, torrentID: Data) {
        self.torrent = torrent
        self.id = torrentID
        self.idString = try! torrentID.toString(using: .utf8)
    }
    
    static let MAX_ACTIVE_TORRENT = 10
    
    static func makePeerID() -> Data {
        var peerID = "-BD0000-"
        
        for _ in 0...11 {
            let asciiCharacters = [" ", "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":", ";", "<", "=", ">", "?", "@", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "[", "\\", "]", "^", "_", "`", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "{", "|", "}", "~"]
            let numberOfAscii = asciiCharacters.count
            let randomIndex = arc4random() % UInt32(numberOfAscii)
            let random = asciiCharacters[Int(randomIndex)]
            peerID += random
        }
        
        return peerID.data(using: .utf8)!
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TorrentTaskConf, rhs: TorrentTaskConf) -> Bool {
        return lhs.torrent.infoHashSHA1 == rhs.torrent.infoHashSHA1 && lhs.idString == rhs.idString
    }
}

extension TorrentTaskConf {
    var infoHash: Data {
        torrent.infoHashSHA1
    }
    
    var info: TorrentModelInfo {
        torrent.info
    }
}
