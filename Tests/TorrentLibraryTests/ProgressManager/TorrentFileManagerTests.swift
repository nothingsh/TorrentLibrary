//
//  TorrentFileManagerTests.swift
//  
//
//  Created by Wynn Zhang on 8/25/23.
//

import XCTest
import TorrentModel
@testable import TorrentLibrary

final class TorrentFileManagerTests: XCTestCase {
    let model: TorrentModel = {
        let path = Bundle.module.path(forResource: "BigTorrentTest", ofType: "torrent")
        let data = try! Data(contentsOf: URL(fileURLWithPath: path!))
        return try! TorrentModel.decode(data: data)
    }()
    
    let piece1: Data = {
        let path = Bundle.module.path(forResource: "Data", ofType: "bin")
        return try! Data(contentsOf: URL(fileURLWithPath: path!))
    }()
    
    var fileHandle: FileHandleFake!
    var sut: TorrentFileManager!
    
    override func setUp() {
        super.setUp()
        
        fileHandle = FileHandleFake(data: Data(repeating: 0, count: model.info.length ?? 0))
        sut = TorrentFileManager(torrent: model, rootDirectory: "/", fileHandles: [fileHandle])
    }
    
    func test_canSetPiece() {
        // Given
        let pieceLength = model.info.pieceLength
        
        // When
        try! sut.writeDataToFiles(at: 1, with: piece1)
        
        // Then
        XCTAssertEqual(fileHandle.data.correctingIndicies[pieceLength..<pieceLength*2], piece1)
    }
    
    func test_canGetPiece() {
        // Given
        try! sut.writeDataToFiles(at: 1, with: piece1)
        
        // When
        let result = try! sut.readDataFromFiles(at: 1)
        
        // Then
        XCTAssertEqual(result, piece1)
    }
}
