//
//  TorrentPieceBuffer.swift
//  
//
//  Created by Wynn Zhang on 7/1/23.
//

import Foundation

/// torrent piece download buffer
class TorrentPieceBuffer {
    let index: Int
    let size: Int
    
    var isComplete: Bool {
        return unusedBlockRequests.count == 0 && pendingRequests.count == 0
    }
    
    var piece: Data? {
        return isComplete ? data : nil
    }
    
    private var data: Data
    private var unusedBlockRequests: [TorrentBlock.Request]
    private var pendingRequests: [TorrentBlock.Request] = []
    
    init(index: Int, size: Int) {
        self.index = index
        self.size = size
        self.data = Data(repeating: 0, count: size)
        
        let blockSize = Int(TorrentBlock.BLOCK_SIZE)
        
        var blockRequests: [TorrentBlock.Request] = []
        for i in 0..<size where i % blockSize == 0 {
            // Last block should be the remaining bytes
            let length: Int = ((i + blockSize) <= size) ? blockSize : (size - i)
            let request = TorrentBlock.Request(piece: index, begin: i, length: length)
            blockRequests.append(request)
        }
        
        self.unusedBlockRequests = blockRequests
    }
    
    func nextDownloadBlock() -> TorrentBlock.Request? {
        guard unusedBlockRequests.count > 0 else { return nil }
        let result = unusedBlockRequests.removeLast()
        pendingRequests.append(result)
        return result
    }
    
    func gotBlock(_ blockData: Data, begin: Int) {
        let request = TorrentBlock.Request(piece: index, begin: begin, length: blockData.count)
        guard let pendingIndex = pendingRequests.firstIndex(of: request) else { return }
        
        let range = begin ..< (begin+blockData.count)
        data.replaceSubrange(range, with: blockData)
        
        pendingRequests.remove(at: pendingIndex)
    }
}
