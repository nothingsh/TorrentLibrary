//
//  UDPConnection.swift
//  
//
//  Created by Wynn Zhang on 6/28/23.
//

import Foundation
import CocoaAsyncSocket

protocol UDPConnectionProtocol: AnyObject {
    var delegate: UDPConnectionDelegate? { set get }
    
    var localPort: UInt16 { get }
    func listening(on port: UInt16) throws
    func send(_ data: Data, toHost host: String, port: UInt16, timeout: TimeInterval)
}

protocol UDPConnectionDelegate: AnyObject {
    func udpConnection(_ sender: UDPConnectionProtocol, receivedData data: Data, fromHost host: String)
}

class UDPConnection: NSObject, UDPConnectionProtocol {
    weak var delegate: UDPConnectionDelegate?
    private let socket: GCDAsyncUdpSocket
    
    init(socket: GCDAsyncUdpSocket = GCDAsyncUdpSocket()) {
        self.socket = socket
        super.init()
        
        socket.setDelegate(self)
        // keep delegate queue in main thread
        socket.synchronouslySetDelegateQueue(.main)
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
        let hostName = InternetHelper.parseSocketIPAddress(from: address) ?? "Unknown host"
        delegate?.udpConnection(self, receivedData: data, fromHost: hostName)
    }
}
