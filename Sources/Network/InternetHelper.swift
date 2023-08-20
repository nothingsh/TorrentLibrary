//
//  InternetHelper.swift
//  
//
//  Created by Wynn Zhang on 7/1/23.
//

import Foundation

struct InternetHelper {
    static func parseSocketIPAddress(from addrData: Data) -> String? {
//        let socketAddress = addrData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//            return pointer.load(as: sockaddr_in.self)
//        }
        let socketAddress = addrData.withUnsafeBytes() { (pointer: UnsafePointer<sockaddr_in>) in
            return pointer.pointee
        }
        if let resultCString = inet_ntoa(socketAddress.sin_addr) {
            return String(cString: resultCString)
        } else {
            return nil
        }
    }
    
    static func parseSocketPort(from data: Data) -> UInt16 {
        let socketAddress = data.withUnsafeBytes() { (pointer: UnsafePointer<sockaddr_in>) in
            return pointer.pointee
        }
        return socketAddress.sin_port
    }
    
    static func getSocketIPAddress(of host: String) -> String? {
        guard let hostnameCString = host.cString(using: .ascii), let hostEntry = gethostbyname(hostnameCString)?.pointee, let hostAddressList = hostEntry.h_addr_list?.pointee else {
            return nil
        }
        
        let firstHostAddress = hostAddressList.withMemoryRebound(to: in_addr.self, capacity: 1) { $0.pointee }
        if let resultCString = inet_ntoa(firstHostAddress) {
            return String(cString: resultCString)
        } else {
            return nil
        }
    }
}
