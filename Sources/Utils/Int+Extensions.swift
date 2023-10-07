//
//  Int+Extensions.swift
//  
//
//  Created by Wynn Zhang on 8/24/23.
//

import Foundation

extension Int {
    /// use byte unit to count integer
    func toByteString() -> String {
        let bytesInKB = 1024
        let bytesInMB = bytesInKB * 1024
        let bytesInGB = bytesInMB * 1024
        let bytesInTB = bytesInGB * 1024
        
        var numberOfBytes: Float = Float(self)
        var unit: String = "B"
        if (self > bytesInTB) {
            numberOfBytes = Float(self) / Float(bytesInTB)
            unit = "TB"
        } else if (self > bytesInGB) {
            numberOfBytes = Float(self) / Float(bytesInGB)
            unit = "GB"
        } else if (self > bytesInMB) {
            numberOfBytes = Float(self) / Float(bytesInMB)
            unit = "MB"
        } else if (self > bytesInKB) {
            numberOfBytes = Float(self) / Float(bytesInKB)
            unit = "KB"
        }
        
        return String(format: "%.2f", numberOfBytes) + " \(unit)"
    }
}
