//
//  TorrentTaskConf.swift
//  
//
//  Created by Wynn Zhang on 8/27/23.
//

import Foundation
import TorrentModel

/// basic info for a torrent task
struct TorrentTaskConf: Hashable {
    let torrent: TorrentModel
    // A string of length 20 which this downloader uses as its id
    let id: Data
    let idString: String
    /// url for torrent download directory
    let rootURL: URL
    
    /// each torrent will have a unique torrentID
    ///
    /// - Parameter torrentID: a unique local peer id for every torrent
    /// - Parameter rootDirectory: if nil or a invalid path, then use download folder as root directory
    init(torrent: TorrentModel, torrentID: Data, rootDirectory: String? = nil) {
        self.torrent = torrent
        self.id = torrentID
        self.idString = try! torrentID.toString(using: .utf8)
        
        let sensibleDirectoryName = Self.sensibleDownloadDirectoryName(info: torrent.info)
        if let rootDir = rootDirectory, let url = URL(string: rootDir) {
            self.rootURL = url.appendingDirectoryPathComponent(with: sensibleDirectoryName)
        } else {
            let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            self.rootURL = downloadsDir.appendingDirectoryPathComponent(with: sensibleDirectoryName)
        }
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
    
    static func sensibleDownloadDirectoryName(info: TorrentModelInfo) -> String {
        guard let files = info.files else {
            return info.name
        }
        
        if files.count > 1 {
            return info.name
        } else {
            let url = URL(fileURLWithPath: info.name, isDirectory: false).deletingPathExtension()
            return url.lastPathComponent
        }
    }
}

extension TorrentTaskConf {
    var infoHash: Data {
        torrent.infoHashSHA1
    }
    
    var info: TorrentModelInfo {
        torrent.info
    }
    
    var rootDirectory: String {
        rootURL.absoluteString
    }
}
