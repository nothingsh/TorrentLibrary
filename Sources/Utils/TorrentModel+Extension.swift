//
//  File.swift
//  
//
//  Created by Wynn Zhang on 7/13/23.
//

import Foundation
import TorrentModel

extension TorrentModelInfo {
    func lengthOfPiece(at index: Int) -> Int? {
        guard let fullLength = length else {
            return nil
        }
        
        if index == pieces.count - 1 {
            return fullLength % pieceLength
        } else if index < pieces.count - 1 {
            return pieceLength
        } else {
            return nil
        }
    }
}

extension TorrentModel {
    var infoHashSHA1: Data {
        self.infoRawData.sha1()
    }
}
