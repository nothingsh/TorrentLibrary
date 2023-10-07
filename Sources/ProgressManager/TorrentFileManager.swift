//
//  TorrentFileManager.swift
//  
//
//  Created by Wynn Zhang on 6/27/23.
//

import Foundation
import TorrentModel

public enum TorrentFileManagerError: Error {
    case unexpectedFileInfo
    case unexpectedFilePath
    case unexpectedFileLength
    case unexpectedPieceIndex
    case unexpectedBlockIndex
    case unexpectedReadingFailure
    case unexpectedFileCreationFailure
}

class TorrentFileManager {
    enum DataFragmentType: Equatable {
        /// block has a piece index
        case block(Int)
        case piece
    }
    
    var streamConfDict: [TorrentTaskConf: FileHandleProtocol] = [:]
    
    func setupFileStreamHandler(for conf: TorrentTaskConf) throws {
        guard let files = conf.info.files else {
            throw TorrentFileManagerError.unexpectedFileInfo
        }
        
        let handles = try files.map {
            let subPath = $0.path.reduce(""){ $0.count == 0 ? $1 : $0 + "/" + $1 }
            let fullPath = conf.rootDirectory + "/" + subPath
            guard let handle = FileHandle(forReadingAtPath: fullPath) else {
                throw TorrentFileManagerError.unexpectedFilePath
            }
            return handle
        }
        
        self.streamConfDict[conf] = try MultiFileHandle(fileHandles: handles)
        try self.prepareRootDirectory(for: conf)
    }
    
    func removeFileStreamHandler(for conf: TorrentTaskConf) {
        streamConfDict.removeValue(forKey: conf)
    }
    
    #if DEBUG
    func setupFileStreamHandler(for conf: TorrentTaskConf, with handles: [FileHandleProtocol]) {
        streamConfDict[conf] = try! MultiFileHandle(fileHandles: handles)
    }
    #endif
    
    func reCheckProgress(for conf: TorrentTaskConf) -> BitField {
        var result = BitField(size: conf.info.pieces.count)
        for (pieceIndex, _) in result {
            autoreleasepool {
                let correctSha1 = conf.info.pieces[pieceIndex]
                let piece = try! readDataFromFiles(at: pieceIndex, for: conf)
                let sha1 = piece.sha1()
                if sha1 == correctSha1 {
                    result.setBit(at: pieceIndex)
                }
            }
        }
        return result
    }
    
    /// write data to files by piece or block
    func writeDataToFiles(
        by type: DataFragmentType = .piece,
        at index: Int,
        with data: Data,
        for conf: TorrentTaskConf
    ) throws {
        let startIndex = calcuateStartOffset(by: type, at: index, for: conf)
        
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            try streamConfDict[conf]?.seek(toOffset: startIndex)
        } else {
            streamConfDict[conf]?.seek(toFileOffset: startIndex)
        }
        
        if #available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *) {
            try streamConfDict[conf]?.write(contentsOf: data)
        } else {
            streamConfDict[conf]?.write(data)
        }
    }
    
    /// read data from files by piece or block
    func readDataFromFiles(
        by type: DataFragmentType = .piece,
        at index: Int,
        for conf: TorrentTaskConf
    ) throws -> Data {
        let startIndex = calcuateStartOffset(by: type, at: index, for: conf)
        let length = try calcuateDataLength(by: type, at: index, for: conf)
        
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            try streamConfDict[conf]?.seek(toOffset: startIndex)
        } else {
            streamConfDict[conf]?.seek(toFileOffset: startIndex)
        }
        
        if #available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *) {
            guard let data = try streamConfDict[conf]?.read(upToCount: Int(length)) else {
                throw TorrentFileManagerError.unexpectedReadingFailure
            }
            return data
        } else {
            return streamConfDict[conf]!.readData(ofLength: Int(length))
        }
    }
    
    private func calcuateStartOffset(
        by type: DataFragmentType,
        at index: Int,
        for conf: TorrentTaskConf
    ) -> UInt64 {
        switch type {
        case .block(let pieceIndex):
            return UInt64(pieceIndex * conf.info.pieceLength) + UInt64(index) * TorrentBlock.BLOCK_SIZE
        case .piece:
            return UInt64(index * conf.info.pieceLength)
        }
    }
    
    private func calcuateDataLength(
        by type: DataFragmentType,
        at index: Int,
        for conf: TorrentTaskConf
    ) throws -> UInt64 {
        switch type {
        case .block(let pieceIndex):
            return try calculateBlockSize(at: index, with: pieceIndex, for: conf)
        case .piece:
            return try calculatePieceSize(at: index, for: conf)
        }
    }
    
    private func calculatePieceSize(
        at index: Int,
        for conf: TorrentTaskConf
    ) throws -> UInt64 {
        guard let fullLength = conf.info.length else {
            throw TorrentFileManagerError.unexpectedFileLength
        }
        
        guard index < conf.info.pieces.count else {
            throw TorrentFileManagerError.unexpectedPieceIndex
        }
        
        if (fullLength % conf.info.pieceLength == 0) || (index < conf.info.pieces.count - 1) {
            return UInt64(conf.info.pieceLength)
        } else {
            return UInt64(fullLength % conf.info.pieceLength)
        }
    }
    
    private func calculateBlockSize(
        at index: Int,
        with pieceIndex: Int,
        for conf: TorrentTaskConf
    ) throws -> UInt64 {
        let pieceSize = try calculatePieceSize(at: pieceIndex, for: conf)
        let blockCount = pieceSize/TorrentBlock.BLOCK_SIZE + (pieceSize%TorrentBlock.BLOCK_SIZE == 0 ? 0 : 1)
        
        guard index < blockCount else {
            throw TorrentFileManagerError.unexpectedBlockIndex
        }
        
        if (pieceSize % TorrentBlock.BLOCK_SIZE == 0) || (index < blockCount - 1) {
            return TorrentBlock.BLOCK_SIZE
        } else {
            return pieceSize % TorrentBlock.BLOCK_SIZE
        }
    }
}

// MARK: Progress load and save

extension TorrentFileManager {
    static func sanitizedFileName(infoHash: Data) -> String {
        let base64EncodedString = infoHash.base64EncodedData().base64EncodedString()
        let sanitizedString = base64EncodedString.replacingOccurrences(of: "/", with: "_")
        return sanitizedString + ".torrentprogress"
    }
    
    static func saveProgressBitfield(infoHash: Data, bitField: BitField) {
        let fileName = sanitizedFileName(infoHash: infoHash)
        let documentsPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory,
                                                                .userDomainMask,
                                                                true)[0] as String
        let documentsUrl = URL(fileURLWithPath: documentsPath, isDirectory: true)
        let fileURL = documentsUrl.appendingPathComponent(fileName, isDirectory: false)
        try? bitField.toData().write(to: fileURL)
    }
    
    static func loadSavedProgressBitfield(infoHash: Data, count: Int) throws -> BitField? {
        let fileName = sanitizedFileName(infoHash: infoHash)
        let documentsPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] as String
        let documentsUrl = URL(fileURLWithPath: documentsPath, isDirectory: true)
        let fileURL = documentsUrl.appendingPathComponent(fileName, isDirectory: false)
        if let data = try? Data(contentsOf: fileURL) {
            return try BitField(data: data, size: count)
        }
        return nil
    }
}

// MARK: File structure

extension TorrentFileManager {
    private func prepareRootDirectory(for conf: TorrentTaskConf) throws {
        let rootDirectory = conf.rootDirectory
        try createDirectoryIfNeeded(directoryPath: rootDirectory)
        
        guard let files = conf.info.files else {
            throw TorrentFileManagerError.unexpectedFileInfo
        }
        
        for file in files {
            let subPath = file.path.reduce(""){ $0.count == 0 ? $1 : $0 + "/" + $1 }
            let fullPath = rootDirectory + "/" + subPath
            try createSubDirectoryIfNeeded(at: fullPath)
            try createEmptyFileIfNeeded(at: fullPath, length: file.length)
        }
    }
    
    private func createSubDirectoryIfNeeded(at path: String) throws {
        let directory = URL(fileURLWithPath: path, isDirectory: false).deletingLastPathComponent()
        try createDirectoryIfNeeded(directoryPath: directory.path)
    }
    
    private func createDirectoryIfNeeded(directoryPath: String) throws {
        if (!FileManager.default.fileExists(atPath: directoryPath)) {
            try FileManager.default.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    private func createEmptyFileIfNeeded(at path: String, length: Int) throws {
        guard !FileManager.default.fileExists(atPath: path) else {
            return
        }
        
        guard FileManager.default.createFile(atPath: path, contents: nil, attributes: nil) else {
            throw TorrentFileManagerError.unexpectedFileCreationFailure
        }
        
        let fileDescriptor: CInt = open(path, O_WRONLY, 0644) // open file for writing
        lseek(fileDescriptor, off_t(length - 1), SEEK_SET) // seek to the last byte ...
        // ... and write a 0 to it
        let bytesPointer = UnsafeMutableRawPointer.allocate(byteCount: 4, alignment: 4)
        bytesPointer.storeBytes(of: 0, as: Int.self)
        write(fileDescriptor, bytesPointer, 1)
        bytesPointer.deallocate()
        
        close(fileDescriptor) // Now we have a file of the correct size we close it
    }
}
