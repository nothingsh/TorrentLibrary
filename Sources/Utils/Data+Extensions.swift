//
//  Data+Extensions.swift
//  
//
//  Created by Wynn Zhang on 6/30/23.
//

import Foundation
import CommonCrypto

extension Data {
    func toUInt8() -> UInt8 {
        return self[0]
    }
    
    func toUInt16(bigEndian: Bool = true) -> UInt16 {
        let result: UInt16 = self.withUnsafeBytes { $0.pointee }
        return bigEndian ? result.bigEndian : result
    }
    
    func toUInt32(bigEndian: Bool = true) -> UInt32 {
        let result: UInt32 = self.withUnsafeBytes { $0.pointee }
        return bigEndian ? result.bigEndian : result
    }
    
    func toUInt64(bigEndian: Bool = true) -> UInt64 {
        let result: UInt64 = self.withUnsafeBytes { $0.pointee }
        return bigEndian ? result.bigEndian : result
    }
    
    func sha1() -> Data {
        let outputLength = Int(CC_SHA1_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CC_SHA1((self as NSData).bytes, CC_LONG(self.count), &digest)
        return Data(bytes: digest, count: outputLength)
    }
    
    var hexEncodedString: String {
        return self.map { String(format: "%02hhX", $0) }.joined()
    }
}

extension UInt8 {
    func toData() -> Data {
        return Data([self])
    }
    
    init(data: Data) {
        self = data.toUInt8()
    }
    
    init(bits: (Bool, Bool, Bool, Bool, Bool, Bool, Bool, Bool)) {
        var result: UInt8 = 0
        result += bits.7 ? 1 : 0
        result += bits.6 ? 2 : 0
        result += bits.5 ? 4 : 0
        result += bits.4 ? 8 : 0
        result += bits.3 ? 16 : 0
        result += bits.2 ? 32 : 0
        result += bits.1 ? 64 : 0
        result += bits.0 ? 128 : 0
        self = result
    }
}

extension UInt16 {
    func toData(bigEndian: Bool = true) -> Data {
        var copy = bigEndian ? self.bigEndian : self
        let pointer = withUnsafeBytes(of: &copy) { return $0.baseAddress }
        return Data(bytes: pointer!, count: 2)
    }
    
    init(data: Data, bigEndian: Bool = true) {
        self = data.toUInt16()
    }
}

extension UInt32 {
    func toData(bigEndian: Bool = true) -> Data {
        var copy = bigEndian ? self.bigEndian : self
        let pointer = withUnsafeBytes(of: &copy) { return $0.baseAddress }
        return Data(bytes: pointer!, count: 4)
    }
    
    init(data: Data, bigEndian: Bool = true) {
        self = data.toUInt32()
    }
}

extension UInt64 {
    func toData(bigEndian: Bool = true) -> Data {
        var copy = bigEndian ? self.bigEndian : self
        let pointer = withUnsafeBytes(of: &copy) { return $0.baseAddress }
        return Data(bytes: pointer!, count: 8)
    }
    
    init(data: Data, bigEndian: Bool = true) {
        self = data.toUInt64()
    }
}
