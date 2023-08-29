//
//  TorrentProgressManagerTests.swift
//  
//
//  Created by Wynn Zhang on 8/25/23.
//

import XCTest
import TorrentModel
@testable import TorrentLibrary

final class TorrentProgressManagerTests: XCTestCase {
    var fileManager: TorrentFileManager!
    var fileHandle: FileHandleFake!
    var sut: TorrentProgressManager!
    var conf: TorrentTaskConf!
    
    let model: TorrentModel = {
        let path = Bundle.module.path(forResource: "TestText", ofType: "torrent")
        let data = try! Data(contentsOf: URL(fileURLWithPath: path!))
        return try! TorrentModel.decode(data: data)
    }()
    
    let finalData: Data = {
        let path = Bundle.module.path(forResource: "text", ofType: "txt")
        return try! Data(contentsOf: URL(fileURLWithPath: path!))
    }()
    
    let completeBitField: BitField = {
        var result = BitField(size: 1)
        result.setBit(at: 0)
        return result
    }()
    
    override func setUp() {
        super.setUp()
        
        self.conf = TorrentTaskConf(torrent: model, torrentID: TorrentTaskConf.makePeerID())
        
        let data = Data(repeating: 0, count: model.info.length ?? 0)
        fileHandle = FileHandleFake(data: data)
        fileManager = TorrentFileManager()
        
        sut = TorrentProgressManager(fileManager: fileManager, handles: [fileHandle], conf: conf)
    }
    
    func test_canForceReCheck() {
        // Given
        fileHandle.data = finalData
        
        // When
        sut.forceReCheck(for: conf)
        
        // Then
        XCTAssert(sut.getProgress(for: conf)!.complete)
    }
    
    func test_exampleMetaInfoOnlyHas1Piece() {
        XCTAssertEqual(model.info.pieces.count, 1)
    }
    
    func test_canGetNextPieceToDownload() {
        let resultOptional = sut.getNextPieceToDownload(from: completeBitField, for: conf)
        guard let result = resultOptional else {
            XCTFail("Couldn't get a piece to download")
            return
        }
        
        XCTAssertEqual(result.pieceIndex, 0)
        XCTAssertEqual(result.size, model.info.lengthOfPiece(at: 0))
        XCTAssertEqual(result.checksum, model.info.pieces[0])
    }
    
    func test_currentlyDownloadingPieceIsNotReturned() {
        _ = sut.getNextPieceToDownload(from: completeBitField, for: conf)
        let result = sut.getNextPieceToDownload(from: completeBitField, for: conf)
        XCTAssertNil(result)
    }
    
    func test_downloadedPieceIsNotReturned() {
        _ = sut.getNextPieceToDownload(from: completeBitField, for: conf)
        
        let data = Data(repeating: 1, count: model.info.length ?? 0)
        try! sut.setDownloadedPiece(with: data, at: 0, for: conf)
        
        let result = sut.getNextPieceToDownload(from: completeBitField, for: conf)
        XCTAssertNil(result)
    }
    
    func test_pieceReturnedAgainIfLost() {
        _ = sut.getNextPieceToDownload(from: completeBitField, for: conf)
        sut.setLostPiece(at: 0, for: conf)
        let result = sut.getNextPieceToDownload(from: completeBitField, for: conf)
        XCTAssertNotNil(result)
    }
    
    func test_downloadedPieceIsSavedToFile() {
        _ = sut.getNextPieceToDownload(from: completeBitField, for: conf)
        
        let data = Data(repeating: 1, count: model.info.length ?? 0)
        try! sut.setDownloadedPiece(with: data, at: 0, for: conf)
        
        XCTAssertEqual(fileHandle.data, data)
    }
    
    func test_doesNotReturnUnavailablePieces() {
        let emptyBitField = BitField(size: 1)
        let result = sut.getNextPieceToDownload(from: emptyBitField, for: conf)
        XCTAssertNil(result)
    }
}
