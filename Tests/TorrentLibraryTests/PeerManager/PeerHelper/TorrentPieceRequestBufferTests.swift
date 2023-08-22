//
//  TorrentPieceRequestBufferTests.swift
//  
//
//  Created by Wynn Zhang on 8/22/23.
//

import XCTest
@testable import TorrentLibrary

final class TorrentPieceRequestBufferTests: XCTestCase {
    let data = Data(repeating: 1, count: 10) + Data(repeating: 2, count: 10)
    let index = 123
    
    func test_hasNoPendingRequestsOnInit() {
        let sut = TorrentPieceRequestBuffer(data: data, index: index)
        XCTAssertFalse(sut.hasBlockRequests)
        XCTAssertNil(sut.nextUploadBlock())
    }
    
    func test_nextUploadBlockReturnsCorrectData() {
        let sut = TorrentPieceRequestBuffer(data: data, index: index)
        
        let request = TorrentBlock.Request(piece: index, begin: 5, length: 10)
        sut.addRequest(request)
        
        let result = sut.nextUploadBlock()
        XCTAssertNotNil(result, "Result shouldn't be nil")
        if let result = result {
            XCTAssertEqual(result.request.begin, 5)
            XCTAssertEqual(result.request.length, 10)
            XCTAssertEqual(result.request.piece, index)
            
            let expected = Data([ 1, 1, 1, 1, 1,
                                         2, 2, 2, 2, 2])
            XCTAssertEqual(result.data, expected)
        }
    }
    
    func test_cannotGetUploadBlockTwice() {
        let sut = TorrentPieceRequestBuffer(data: data, index: index)
        
        let request = TorrentBlock.Request(piece: index, begin: 5, length: 10)
        sut.addRequest(request)
        
        _ = sut.nextUploadBlock()
        let result = sut.nextUploadBlock()
        
        XCTAssertNil(result)
    }
    
    func test_canRemoveBlockRequest() {
        let sut = TorrentPieceRequestBuffer(data: data, index: index)
        
        let request = TorrentBlock.Request(piece: index, begin: 5, length: 10)
        sut.addRequest(request)
        sut.removeRequest(request)
        
        let result = sut.nextUploadBlock()
        XCTAssertNil(result, "Result should be nil")
    }
}
