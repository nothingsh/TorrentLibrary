//
//  TorrentBlock.swift
//  
//
//  Created by Wynn Zhang on 7/1/23.
//

import Foundation

struct TorrentBlock: Equatable {
    let request: Request
    let data: Data
    
    init(piece: Int, begin: Int, length: Int, data: Data) {
        self.request = Request(piece: piece, begin: begin, length: length)
        self.data = data
    }
    
    init(request: Request, data: Data) {
        self.request = request
        self.data = data
    }
    
    static func ==(_ lhs: TorrentBlock, _ rhs: TorrentBlock) -> Bool {
        return lhs.request == rhs.request
    }
    
    /// default block size is 16k
    static let BLOCK_SIZE: UInt64 = 1024 * 16
    
    struct Request: Equatable {
        let piece: Int
        let begin: Int
        let length: Int
    }
}
