//
//  File.swift
//  
//
//  Created by Wynn Zhang on 8/20/23.
//

import Foundation
import TorrentLibrary

class FileHandleFake: FileHandleProtocol {
    var data: Data
    private var currentOffset: Int = 0
    var offsetInFile: UInt64 {
        return UInt64(currentOffset)
    }
    
    init(data: Data) {
        self.data = data
        self.currentOffset = data.startIndex
    }
    
    func readData(ofLength length: Int) -> Data {
        let beginOffset = currentOffset
        currentOffset += length
        return data[beginOffset ..< currentOffset]
    }
    
    func read(upToCount count: Int) throws -> Data? {
        let beginOffset = currentOffset
        currentOffset += count
        return data[beginOffset ..< currentOffset]
    }
    
    func write(_ data: Data) {
        let beginOffset = currentOffset
        currentOffset += data.count
        self.data[beginOffset ..< currentOffset] = data
    }
    
    func write(contentsOf data: Data) throws {
        let beginOffset = currentOffset
        currentOffset += data.count
        self.data[beginOffset ..< currentOffset] = data
    }
    
    func seek(toFileOffset offset: UInt64) {
        currentOffset = data.startIndex + Int(offset)
    }
    
    func seek(toOffset offset: UInt64) throws {
        currentOffset = data.startIndex + Int(offset)
    }
    
    func seekToEndOfFile() -> UInt64 {
        currentOffset = data.endIndex
        return offsetInFile
    }
    
    func seekToEnd() throws -> UInt64 {
        currentOffset = data.endIndex
        return offsetInFile
    }
    
    var synchronizeFileCalled = false
    
    func synchronizeFile() {
        synchronizeFileCalled = true
    }
    
    func synchronize() throws {
        synchronizeFileCalled = true
    }
}
