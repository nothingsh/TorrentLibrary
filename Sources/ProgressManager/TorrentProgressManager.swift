//
//  TorrentProgressManager.swift
//  
//
//  Created by Wynn Zhang on 8/25/23.
//

import Foundation
import TorrentModel

struct TorrentProgress {
    private(set) var bitField: BitField
    private var piecesBeingDownloaded: [Int] = []
    
    private(set) var downloaded: Int = 0
    
    var remaining: Int {
        return bitField.size - downloaded
    }
    
    var complete: Bool {
        return downloaded == bitField.size
    }
    
    var percentageComplete: Float {
        return Float(downloaded) / Float(bitField.size)
    }
    
    init(size: Int) {
        self.bitField = BitField(size: size)
    }
    
    init(bitField: BitField) {
        self.bitField = bitField
        for (_, isSet) in bitField where isSet {
            downloaded += 1
        }
    }
    
    func isCurrentlyDownloading(piece: Int) -> Bool {
        return piecesBeingDownloaded.contains(piece)
    }
    
    func hasPiece(_ index: Int) -> Bool {
        return bitField.checkAvailability(at: index)
    }
    
    mutating func setCurrentlyDownloading(piece: Int) {
        piecesBeingDownloaded.append(piece)
    }
    
    mutating func setLostPiece(_ piece: Int) {
        if let index = piecesBeingDownloaded.firstIndex(of: piece) {
            piecesBeingDownloaded.remove(at: index)
        }
    }
    
    mutating func finishedDownloading(piece: Int) {
        if let index = piecesBeingDownloaded.firstIndex(of: piece) {
            piecesBeingDownloaded.remove(at: index)
            downloaded += 1
            bitField.setBit(at: piece)
        }
    }
}

class TorrentProgressManager {
    private let fileManager: TorrentFileManager
    private var progressDict: [TorrentTaskConf: TorrentProgress]
    
    init() {
        self.fileManager = TorrentFileManager()
        self.progressDict = [:]
    }
    
    #if DEBUG
    init(fileManager: TorrentFileManager, handles: [FileHandleProtocol], conf: TorrentTaskConf) {
        self.fileManager = fileManager
        self.progressDict = [:]
        
        self.progressDict[conf] = TorrentProgress(size: conf.info.pieces.count)
        self.fileManager.setupFileStreamHandler(for: conf, with: handles)
    }
    #endif
    
    func setupProgressMananger(for conf: TorrentTaskConf) {
        let progress: TorrentProgress
        
        let bitFieldSize = conf.info.pieces.count
        if let bitField = try? TorrentFileManager.loadSavedProgressBitfield(infoHash: conf.infoHash, count: bitFieldSize) {
            progress = TorrentProgress(bitField: bitField)
        } else {
            progress = TorrentProgress(size: bitFieldSize)
        }
        
        self.progressDict[conf] = progress
        
        try? self.fileManager.setupFileStreamHandler(for: conf)
    }
    
    func removeProgressMananger(for conf: TorrentTaskConf) {
        self.progressDict.removeValue(forKey: conf)
        self.fileManager.removeFileStreamHandler(for: conf)
    }
    
    func forceReCheck(for conf: TorrentTaskConf) {
        let bitField = fileManager.reCheckProgress(for: conf)
        
        let progress = TorrentProgress(bitField: bitField)
        self.progressDict[conf] = progress
        TorrentFileManager.saveProgressBitfield(infoHash: conf.infoHash, bitField: progress.bitField)
    }
    
    func getNextPieceToDownload(from availablePieces: BitField, for conf: TorrentTaskConf) -> TorrentPieceRequest? {
        guard progressDict[conf] != nil, !(progressDict[conf]!).complete else {
            return nil
        }
        
        for (i, isSet) in availablePieces.lazy.pseudoRandomized where isSet {
            if !(progressDict[conf]!).hasPiece(i) && !(progressDict[conf]!).isCurrentlyDownloading(piece: i) {
                (progressDict[conf]!).setCurrentlyDownloading(piece: i)
                return TorrentPieceRequest(
                    pieceIndex: i,
                    size: conf.info.lengthOfPiece(at: i)!,
                    checksum: conf.info.pieces[i]
                )
            }
        }
        return nil
    }
    
    func setDownloadedPiece(with piece: Data, at pieceIndex: Int, for conf: TorrentTaskConf) throws {
        guard progressDict[conf] != nil else {
            return
        }
        
        (progressDict[conf]!).finishedDownloading(piece: pieceIndex)
        try fileManager.writeDataToFiles(at: pieceIndex, with: piece, for: conf)
        TorrentFileManager.saveProgressBitfield(infoHash: conf.infoHash, bitField: (progressDict[conf]!).bitField)
    }
    
    func setLostPiece(at index: Int, for conf: TorrentTaskConf) {
        (progressDict[conf]!).setLostPiece(index)
    }
    
    func getProgress(for conf: TorrentTaskConf) -> TorrentProgress? {
        return progressDict[conf]
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
