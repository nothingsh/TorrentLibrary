//
//  BitField.swift
//  
//
//  Created by Wynn Zhang on 6/27/23.
//

import Foundation

public enum BitFieldError: Error {
    case unexpectedByteSize
}

/// a struct contains a array which indicates the download status of torrent data pieces
struct BitField: Equatable {
    var bits: [Bool]
    
    init(size: Int) {
        self.bits = Array<Bool>(repeating: false, count: size)
    }
    
    /// every bit in the data represents the status of a piece
    init(data: Data, size: Int) throws {
        self.init(size: size)
        
        guard data.count == byteCount else {
            throw BitFieldError.unexpectedByteSize
        }
        
        self.initializeBits(data: data)
    }
    
    private mutating func initializeBits(data: Data) {
        for byteIndex in data.indices {
            let byte = data[byteIndex]
            for bitIndex in 0..<8 {
                let index = byteIndex * 8 + bitIndex
                if (index >= size) {
                    break
                }
                
                bits[index] = (byte & BitField.BITMASK[bitIndex]) != 0
            }
        }
    }
    
    mutating func setBit(at index: Int, with value: Bool) {
        bits[index] = value
    }
    
    func checkAvailability(at index: Int) -> Bool {
        return bits[index]
    }
    
    func toData() -> Data {
        var bytes = [UInt8]()
        
        for byteIndex in 0..<byteCount {
            var byte: UInt8 = 0
            for bitIndex in 0..<8 {
                let index = byteIndex * 8 + bitIndex
                byte += (index >= size ? 0 : (bits[index] ? BitField.BITMASK[bitIndex] : 0))
            }
            bytes.append(byte)
        }
        
        return Data(bytes)
    }
    
    var byteCount: Int {
        return size / 8 + (size % 8 == 0 ? 0 : 1)
    }
    
    var complete: Bool {
        return !bits.contains(where: { !$0 })
    }
    
    var progress: Float {
        if bits.count == 0 {
            return 0
        }
        return Float(bits.filter{ $0 }.count) / Float(bits.count)
    }
    
    var size: Int {
        return bits.count
    }
    
    static let BITMASK: [UInt8] = [128, 64, 32, 16, 8, 4, 2, 1]
}
