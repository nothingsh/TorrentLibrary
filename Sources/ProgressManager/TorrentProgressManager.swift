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
    
    let fileManager: TorrentFileManager
    private(set) var progress: TorrentProgress
    
    var model: TorrentModel {
        return fileManager.model
    }
    
    init(fileManager: TorrentFileManager, progress: TorrentProgress) {
        self.fileManager = fileManager
        self.progress = progress
    }
    
    convenience init(model: TorrentModel, rootDirectory: String) throws {
        let downloadDirectory = rootDirectory + "/" + Self.sensibleDownloadDirectoryName(info: model.info)
        let fileManager = try TorrentFileManager(torrent: model, rootDirectory: downloadDirectory)
        
        let bitFieldSize = model.info.pieces.count
        let progress: TorrentProgress
        if let bitField = try? TorrentFileManager.loadSavedProgressBitfield(infoHash: model.infoHashSHA1, count: bitFieldSize) {
            progress = TorrentProgress(bitField: bitField)
        } else {
            progress = TorrentProgress(size: bitFieldSize)
        }
        
        self.init(fileManager: fileManager, progress: progress)
    }
    
    public func forceReCheck() {
        let bitField = fileManager.reCheckProgress()
        progress = TorrentProgress(bitField: bitField)
        TorrentFileManager.saveProgressBitfield(infoHash: model.infoHashSHA1, bitField: progress.bitField)
    }
    
    func getNextPieceToDownload(from availablePieces: BitField) -> TorrentPieceRequest? {
        guard !progress.complete else { return nil }
        
        for (i, isSet) in availablePieces.lazy.pseudoRandomized where isSet {
            if !progress.hasPiece(i) && !progress.isCurrentlyDownloading(piece: i) {
                progress.setCurrentlyDownloading(piece: i)
                return TorrentPieceRequest(
                    pieceIndex: i,
                    size: model.info.lengthOfPiece(at: i)!,
                    checksum: model.info.pieces[i]
                )
            }
        }
        return nil
    }
    
    func setDownloadedPiece(_ piece: Data, pieceIndex: Int) throws {
        progress.finishedDownloading(piece: pieceIndex)
        try fileManager.writeDataToFiles(at: pieceIndex, with: piece)
        TorrentFileManager.saveProgressBitfield(infoHash: model.infoHashSHA1, bitField: progress.bitField)
    }
    
    func setLostPiece(at index: Int) {
        progress.setLostPiece(index)
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
