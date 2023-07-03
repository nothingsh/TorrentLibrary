//
//  TorrentPieceRequestBuffer.swift
//  
//
//  Created by Wynn Zhang on 7/1/23.
//

import Foundation

struct TorrentPieceRequest {
    let pieceIndex: Int
    let size: Int
    let checksum: Data
}

/// torrent upload piece request
class TorrentPieceRequestBuffer {
    private let data: Data
    let index: Int
    private var blockRequests: [TorrentBlock.Request] = []
    
    var hasBlockRequests: Bool {
        return blockRequests.first != nil
    }
    
    init(data: Data, index: Int) {
        self.data = data
        self.index = index
    }
    
    func addRequest(_ request: TorrentBlock.Request) {
        blockRequests.append(request)
    }
    
    func removeRequest(_ request: TorrentBlock.Request) {
        guard let index = blockRequests.firstIndex(of: request) else { return }
        blockRequests.remove(at: index)
    }
    
    func nextUploadBlock() -> TorrentBlock? {
        guard let request = blockRequests.first else { return nil }
        blockRequests.remove(at: 0)
        
        let begin = data.startIndex + request.begin
        let end = begin + request.length
        let blockData = data[begin..<end]
        
        return TorrentBlock(request: request, data: blockData)
    }
}
