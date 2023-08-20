//
//  FileHandle.swift
//  
//
//  Created by Wynn Zhang on 6/26/23.
//

import Foundation

public enum FileHanleError: Error {
    case unexpectedRead
    case unexpectedDataLength
}

public protocol FileHandleProtocol {
    var offsetInFile: UInt64 { get }

    func readData(ofLength length: Int) -> Data
    @available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *)
    func read(upToCount count: Int) throws -> Data?
    
    func write(_ data: Data)
    @available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *)
    func write(contentsOf data: Data) throws
    
    func seek(toFileOffset offset: UInt64)
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func seek(toOffset offset: UInt64) throws
    
    func seekToEndOfFile() -> UInt64
    @available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *)
    @discardableResult func seekToEnd() throws -> UInt64
    
    func synchronizeFile()
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func synchronize() throws
}

extension FileHandle: FileHandleProtocol {}

class MultiFileHandle: FileHandleProtocol {
    private struct File {
        let handle: FileHandleProtocol
        let offset: UInt64
        let length: UInt64
    }
    
    private var files: [File]
    private var fileIndex = 0
    private let totalLength: UInt64
    
    private var currentFile: File {
        return files[fileIndex]
    }
    private var currentFileRemaining: UInt64 {
        return currentFile.length - currentFile.handle.offsetInFile
    }
    var offsetInFile: UInt64 {
        return currentFile.offset + currentFile.handle.offsetInFile
    }
    
    init(fileHandles: [FileHandleProtocol]) throws {
        var result = [File]()
        var offset: UInt64 = 0
        
        for handle in fileHandles {
            var length: UInt64 = 0
            if #available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *) {
                length = try handle.seekToEnd()
            } else {
                length = handle.seekToEndOfFile()
            }
            if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.2, *) {
                try handle.seek(toOffset: 0)
            } else {
                handle.seek(toFileOffset: 0)
            }
            result.append(File(handle: handle, offset: offset, length: length))
            offset += length
        }
        
        self.totalLength = offset
        self.files = result
    }
    
    private func processNextFile() throws {
        guard fileIndex < files.count - 1 else {
            return
        }
        fileIndex += 1
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.2, *) {
            try currentFile.handle.seek(toOffset: 0)
        } else {
            currentFile.handle.seek(toFileOffset: 0)
        }
    }
    
    // MARK: - Real Implementation
    
    private func localReadData(length: Int) throws -> Data {
        let endOffset = offsetInFile + UInt64(length)
        
        var result = Data()
        while offsetInFile != endOffset {
            let acutalLength = min(currentFileRemaining, endOffset - offsetInFile)
            var readData: Data?
            if #available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *) {
                readData = try currentFile.handle.read(upToCount: Int(acutalLength))
                guard readData != nil else {
                    throw FileHanleError.unexpectedRead
                }
            } else {
                readData = currentFile.handle.readData(ofLength: Int(acutalLength))
            }
            result += readData!
            if currentFile.handle.offsetInFile == currentFile.length {
                try processNextFile()
            }
        }
        return result
    }
    
    private func localWrite(data: Data) throws {
        var dataOffset = 0
        while dataOffset != data.count {
            let acutalLength = min(Int(currentFileRemaining), data.count - dataOffset)
            let endOffset = dataOffset + acutalLength
            if #available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *) {
                try currentFile.handle.write(contentsOf: data[dataOffset..<endOffset])
            } else {
                currentFile.handle.write(data[dataOffset..<endOffset])
            }
            if currentFile.handle.offsetInFile == currentFile.length {
                try processNextFile()
            }
            dataOffset += acutalLength
        }
    }
    
    private func localSeek(offset: UInt64) throws {
        for i in 0 ..< files.count {
            fileIndex = i
            if (currentFile.offset + currentFile.length) > offset {
                let fileOffset = offset - currentFile.offset
                if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
                    try currentFile.handle.seek(toOffset: fileOffset)
                } else {
                    currentFile.handle.seek(toFileOffset: fileOffset)
                }
                break
            }
        }
    }
    
    private func localSeekToEnd() throws -> UInt64 {
        fileIndex = files.count - 1
        if #available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *) {
            try currentFile.handle.seekToEnd()
        } else {
            _ = currentFile.handle.seekToEndOfFile()
        }
        return offsetInFile
    }
    
    private func localSynchronize() throws {
        for file in files {
            if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
                try file.handle.synchronize()
            } else {
                file.handle.synchronizeFile()
            }
        }
    }
}

// Old version implementation
extension MultiFileHandle {
    /// read specific length of data from current offset.
    /// if the range exceeds the length of current file, then keep reading next file until length is met
    func readData(ofLength length: Int) -> Data {
        try! localReadData(length: length)
    }
    
    func write(_ data: Data) {
        try! localWrite(data: data)
    }
    
    func seek(toFileOffset offset: UInt64) {
        try! localSeek(offset: offset)
    }
    
    /// seek to the end of file array
    func seekToEndOfFile() -> UInt64 {
        try! localSeekToEnd()
    }
    
    func synchronizeFile() {
        try! localSynchronize()
    }
}

// New version implementation
extension MultiFileHandle {
    @available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *)
    func read(upToCount count: Int) throws -> Data? {
        guard count < totalLength - offsetInFile else {
            throw FileHanleError.unexpectedDataLength
        }
        
        return try localReadData(length: count)
    }
    
    @available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *)
    func write(contentsOf data: Data) throws {
        guard data.count < totalLength - offsetInFile else {
            throw FileHanleError.unexpectedDataLength
        }
        
        try localWrite(data: data)
    }
    
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func seek(toOffset offset: UInt64) throws {
        try localSeek(offset: offset)
    }
    
    @available(iOS 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *)
    @discardableResult func seekToEnd() throws -> UInt64 {
        try localSeekToEnd()
    }
    
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func synchronize() throws {
        try localSynchronize()
    }
}
