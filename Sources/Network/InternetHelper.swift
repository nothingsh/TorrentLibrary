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
    
    /// Turn a url host string into a ip address string
    static func getSocketIPAddress(of host: String) -> String? {
        guard let hostEntry = host.withCString({gethostbyname($0)}) else {
            return nil
        }
        
        guard hostEntry.pointee.h_length > 0 else {
            return nil
        }
        
        var addr = in_addr()
        memcpy(&addr.s_addr, hostEntry.pointee.h_addr_list[0], Int(hostEntry.pointee.h_length))
        
        guard let remoteIPAsC = inet_ntoa(addr) else {
            return nil
        }
        
        return String.init(cString: remoteIPAsC)
    }
}
