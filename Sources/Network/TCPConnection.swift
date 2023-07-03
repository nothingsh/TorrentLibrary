//
//  TCPConnection.swift
//  
//
//  Created by Wynn Zhang on 6/28/23.
//

import Foundation
import CocoaAsyncSocket

protocol TCPConnectionDelegate: AnyObject {
    func tcpConnection(_ sender: TCPConnection, didConnectToHost host: String, port: UInt16)
    func tcpConnection(_ sender: TCPConnection, didRead data: Data, withTag tag: Int)
    func tcpConnection(_ sender: TCPConnection, didWriteDataWithTag tag: Int)
    func tcpConnection(_ sender: TCPConnection, disconnectedWithError error: Error?)
}

class TCPConnection: NSObject {
    private static let defaultTimeOut: TimeInterval = 15
    
    weak var delegate: TCPConnectionDelegate?
    private let socket: GCDAsyncSocket
    
    /// becase tcp packet is sent aynchronously, so the send completion handlers have to be tagged
    private var currentTag: Int = 1000
    private var completionBlocks: [Int : () -> Void] = [:]
    
    init(socket: GCDAsyncSocket = GCDAsyncSocket()) {
        self.socket = socket
        super.init()
        
        socket.delegateQueue = .main
        socket.synchronouslySetDelegate(self)
    }
    
    func connect(to host: String, onPort port: UInt16) throws {
        try socket.connect(toHost: host, onPort: port, withTimeout: Self.defaultTimeOut)
    }
    
    func disconnect() {
        socket.delegate = nil
        socket.disconnect()
    }
    
    func readData(withTimeout timeout: TimeInterval, tag: Int) {
        socket.readData(withTimeout: timeout, tag: tag)
    }
    
    func write(_ data: Data, withTimeout timeout: TimeInterval, tag: Int) {
        write(data, withTimeout: timeout, tag: tag, completion: nil)
    }
    
    func write(_ data: Data, withTimeout timeout: TimeInterval, completion: (() -> Void)?) {
        write(data, withTimeout: timeout, tag: nil, completion: completion)
    }
    
    func write(_ data: Data, withTimeout timeout: TimeInterval, tag: Int? = nil, completion: (()->Void)? = nil) {
        let tag = tag ?? nextTag()
        completionBlocks[tag] = completion
        socket.write(data, withTimeout: timeout, tag: tag)
    }
    
    private func nextTag() -> Int {
        let result = currentTag
        currentTag += 1
        return result
    }
    
    var connectedHost: String? {
        socket.connectedHost
    }
    
    var connectedPort: UInt16? {
        if connectedHost != nil {
            return socket.connectedPort
        } else {
            return nil
        }
    }
    
    var connected: Bool {
        socket.isConnected
    }
}

extension TCPConnection: GCDAsyncSocketDelegate {
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        delegate?.tcpConnection(self, didConnectToHost: host, port: port)
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        delegate?.tcpConnection(self, didRead: data, withTag: tag)
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        /// run completion hander with the `tag`
        completionBlocks[tag]?()
        /// remove the completion handler after running
        completionBlocks[tag] = nil
        delegate?.tcpConnection(self, didWriteDataWithTag: tag)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        delegate?.tcpConnection(self, disconnectedWithError: err)
    }
}
