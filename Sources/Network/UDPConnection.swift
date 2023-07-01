//
//  UDPConnection.swift
//  
//
//  Created by Wynn Zhang on 6/28/23.
//

import Foundation
import CocoaAsyncSocket

protocol UDPConnectionDelegate: AnyObject {
    func udpConnection(_ sender: UDPConnection, receivedData data: Data, fromHost host: String)
}

class UDPConnection: NSObject {
    weak var delegate: UDPConnectionDelegate?
    private let socket: GCDAsyncUdpSocket
    
    init(socket: GCDAsyncUdpSocket = GCDAsyncUdpSocket()) {
        self.socket = socket
        super.init()
        
        socket.setDelegate(self)
        socket.setDelegateQueue(.main)
    }
    
    deinit {
        socket.setDelegate(nil)
        socket.close()
    }
    
    func listening(on port: UInt16) throws {
        try socket.bind(toPort: port)
        try socket.beginReceiving()
    }
    
    func send(_ data: Data, toHost host: String, port: UInt16, timeout: TimeInterval) {
        socket.send(data, toHost: host, port: port, withTimeout: timeout, tag: 0)
    }
    
    var localPort: UInt16 {
        socket.localPort()
    }
}

extension UDPConnection: GCDAsyncUdpSocketDelegate {
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        let hostName = InternetHelper.parseSocketIPAddress(from: data) ?? "Unknown host"
        delegate?.udpConnection(self, receivedData: data, fromHost: hostName)
    }
}