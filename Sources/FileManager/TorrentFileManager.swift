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
    enum DataFragmentType {
        /// block has a piece index
        case block(Int)
        case piece
    }
    
    private let torrentInfo: TorrentModelInfo
    private let rootDirectory: String
    private let fileHandle: FileHandleProtocol
    
    init(torrentInfo: TorrentModelInfo, rootDirectory: String) throws {
        self.torrentInfo = torrentInfo
        self.rootDirectory = rootDirectory
        
        guard let files = torrentInfo.files else {
            throw TorrentFileManagerError.unexpectedFileInfo
        }
        
        let handles = try files.map {
            let subPath = $0.path.reduce(""){ $0.count == 0 ? $1 : $0 + "/" + $1 }
            let fullPath = rootDirectory + "/" + subPath
            guard let handle = FileHandle(forReadingAtPath: fullPath) else {
                throw TorrentFileManagerError.unexpectedFilePath
            }
            return handle
        }
        
        self.fileHandle = try MultiFileHandle(fileHandles: handles)
    }
    
    /// write data to files by piece or block
    func writeDataToFiles(by type: DataFragmentType, at index: Int, with data: Data) throws {
        let startIndex = calcuateStartOffset(by: type, at: index)
        
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            try fileHandle.seek(toOffset: startIndex)
        } else {
            fileHandle.seek(toFileOffset: startIndex)
        }
        
        if #available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *) {
            try fileHandle.write(contentsOf: data)
        } else {
            fileHandle.write(data)
        }
    }
    
    /// read data from files by piece or block
    func readDataFromFiles(by type: DataFragmentType, at index: Int) throws -> Data {
        let startIndex = calcuateStartOffset(by: type, at: index)
        let length = try calcuateDataLength(by: type, at: index)
        
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            try fileHandle.seek(toOffset: startIndex)
        } else {
            fileHandle.seek(toFileOffset: startIndex)
        }
        
        if #available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *) {
            guard let data = try fileHandle.read(upToCount: Int(length)) else {
                throw TorrentFileManagerError.unexpectedReadingFailure
            }
            return data
        } else {
            return fileHandle.readData(ofLength: Int(length))
        }
    }
    
    private func calcuateStartOffset(by type: DataFragmentType, at index: Int) -> UInt64 {
        switch type {
        case .block(let pieceIndex):
            return UInt64(pieceIndex * torrentInfo.pieceLength) + UInt64(index) * TorrentBlock.BLOCK_SIZE
        case .piece:
            return UInt64(index * torrentInfo.pieceLength)
        }
    }
    
    private func calcuateDataLength(by type: DataFragmentType, at index: Int) throws -> UInt64 {
        switch type {
        case .block(let pieceIndex):
            return try calculateBlockSize(at: index, with: pieceIndex)
        case .piece:
            return try calculatePieceSize(at: index)
        }
    }
    
    private func calculatePieceSize(at index: Int) throws -> UInt64 {
        guard let fullLength = torrentInfo.length else {
            throw TorrentFileManagerError.unexpectedFileLength
        }
        
        guard index < torrentInfo.pieces.count else {
            throw TorrentFileManagerError.unexpectedPieceIndex
        }
        
        if (fullLength % torrentInfo.pieceLength == 0) || (index < torrentInfo.pieces.count - 1) {
            return UInt64(torrentInfo.pieceLength)
        } else {
            return UInt64(fullLength % torrentInfo.pieceLength)
        }
    }
    
    private func calculateBlockSize(at index: Int, with pieceIndex: Int) throws -> UInt64 {
        let pieceSize = try calculatePieceSize(at: pieceIndex)
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

// MARK: Todo - need to reconstruct

extension TorrentFileManager {
    public static func prepareRootDirectory(_ rootDirectory: String,
                                            forTorrentMetaInfo metaInfo: TorrentModelInfo) throws {
        try createDirectoryIfNeeded(directoryPath: rootDirectory)
        
        guard let files = metaInfo.files else {
            throw TorrentFileManagerError.unexpectedFileInfo
        }
        
        for file in files {
            let subPath = file.path.reduce(""){ $0.count == 0 ? $1 : $0 + "/" + $1 }
            let fullPath = rootDirectory + "/" + subPath
            try createSubDirectoryIfNeeded(at: fullPath)
            try createEmptyFileIfNeeded(at: fullPath, length: file.length)
        }
    }
    
    private static func createSubDirectoryIfNeeded(at path: String) throws {
        let directory = URL(fileURLWithPath: path, isDirectory: false).deletingLastPathComponent()
        try createDirectoryIfNeeded(directoryPath: directory.path)
    }
    
    private static func createDirectoryIfNeeded(directoryPath: String) throws {
        if (!FileManager.default.fileExists(atPath: directoryPath)) {
            try FileManager.default.createDirectory(atPath: directoryPath,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        }
    }
    
    private static func createEmptyFileIfNeeded(at path: String, length: Int) throws {
        
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

extension TorrentFileManager {
    private static func sanitizedFileName(from infoHash: Data) -> String {
        let base64EncodedString = infoHash.base64EncodedData().base64EncodedString()
        let sanitizedString = base64EncodedString.replacingOccurrences(of: "/", with: "_")
        return sanitizedString + ".torrentprogress"
    }
    
    static func saveProgressBitfield(_ bitfield: BitField, infoHash: Data) {
        let fileName = sanitizedFileName(from: infoHash)
        let documentsPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory,
                                                                .userDomainMask,
                                                                true)[0] as String
        let documentsUrl = URL(fileURLWithPath: documentsPath, isDirectory: true)
        let fileURL = documentsUrl.appendingPathComponent(fileName, isDirectory: false)
        try? bitfield.toData().write(to: fileURL)
    }
    
    static func loadSavedProgressBitfield(infoHash: Data, size: Int) throws -> BitField? {
        let fileName = sanitizedFileName(from: infoHash)
        let documentsPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory,
                                                                .userDomainMask,
                                                                true)[0] as String
        let documentsUrl = URL(fileURLWithPath: documentsPath, isDirectory: true)
        let fileURL = documentsUrl.appendingPathComponent(fileName, isDirectory: false)
        if let data = try? Data(contentsOf: fileURL) {
            return try BitField(data: data, size: size)
        }
        return nil
    }
}
