//
//  UDPConnectionTests.swift
//  
//
//  Created by Wynn Zhang on 8/19/23.
//

import XCTest
import CocoaAsyncSocket
@testable import TorrentLibrary

class GCDAsyncUdpSocketStub: GCDAsyncUdpSocket {
    weak var _delegate: GCDAsyncUdpSocketDelegate?
    
    override func delegate() -> GCDAsyncUdpSocketDelegate? {
        return _delegate
    }
    
    override func setDelegate(_ delegate: GCDAsyncUdpSocketDelegate?) {
        _delegate = delegate
    }
    
    var bindToPortCalled = false
    var bindToPortParameter: UInt16?
    override func bind(toPort port: UInt16) throws {
        bindToPortCalled = true
        bindToPortParameter = port
    }
    
    var beginReceivingCalled = false
    override func beginReceiving() throws {
        beginReceivingCalled = true
    }
    
    var _delegateQueue: DispatchQueue?
    
    override func delegateQueue() -> DispatchQueue? {
        return _delegateQueue
    }
    
    override func synchronouslySetDelegateQueue(_ delegateQueue: DispatchQueue?) {
        _delegateQueue = delegateQueue
    }
    
    var closeCalled = false
    override func close() {
        closeCalled = true
    }
    
    var sendCalled = false
    var sendParameters: (data: Data, host: String, port: UInt16, timeout: TimeInterval, tag: Int)?
    override func send(_ data: Data, toHost host: String, port: UInt16, withTimeout timeout: TimeInterval, tag: Int) {
        sendCalled = true
        sendParameters = (data, host, port, timeout, tag)
    }
}

class UDPConnectionDelegateTestingStub: UDPConnectionDelegate {
    var receivedDataCalled = false
    var receivedDataParameters: (sender: UDPConnectionProtocol, data: Data, host: String)?
    func udpConnection(_ sender: UDPConnectionProtocol, receivedData data: Data, fromHost host: String) {
        receivedDataCalled = true
        receivedDataParameters = (sender, data, host)
    }
}

final class UDPConnectionTests: XCTestCase {
    var socket: GCDAsyncUdpSocketStub!
    var delegate: UDPConnectionDelegateTestingStub!
    var sut: UDPConnection!
    
    override func setUp() {
        super.setUp()
        
        socket = GCDAsyncUdpSocketStub()
        delegate = UDPConnectionDelegateTestingStub()
        sut = UDPConnection(socket: socket)
        sut.delegate = delegate
    }
    
    func test_isSocketDelegate() {
        XCTAssert(socket._delegate === sut)
        XCTAssert(socket._delegateQueue === DispatchQueue.main)
    }
    
    func test_canStartListeningOnPort() {
        let port: UInt16 = 123
        try! sut.listening(on: port)
        
        XCTAssert(socket.bindToPortCalled)
        XCTAssertEqual(socket.bindToPortParameter, port)
        XCTAssert(socket.beginReceivingCalled)
    }
    
    func test_socketClosedOnDeinit() {
        sut = nil
        XCTAssert(socket.closeCalled)
    }
    
    // MARK: - Receiving data
    
    func test_canRecieveData() {
        // 127.0.0.1:27002
        let addressData = Data([16,2,122,105,127,0,0,1,0,0,0,0,0,0,0,0])
        let packetData = Data([1,2,3])
        
        sut.udpSocket(socket, didReceive: packetData, fromAddress: addressData, withFilterContext: nil)
        
        XCTAssert(delegate.receivedDataCalled)
        XCTAssert(delegate.receivedDataParameters?.sender as AnyObject === sut)
        XCTAssertEqual(delegate.receivedDataParameters?.data, packetData)
        XCTAssertEqual(delegate.receivedDataParameters?.host, "127.0.0.1")
    }
    
    // MARK: - Sending data
    
    func test_canSendData() {
        let data = Data([1,2,3])
        let host = "127.0.0.1"
        let port: UInt16 = 3475
        let timeout: TimeInterval = 10
        
        sut.send(data, toHost: host, port: port, timeout: timeout)
        
        XCTAssert(socket.sendCalled)
        XCTAssertEqual(socket.sendParameters!.data, data)
        XCTAssertEqual(socket.sendParameters!.host, host)
        XCTAssertEqual(socket.sendParameters!.port, port)
        XCTAssertEqual(socket.sendParameters!.timeout, timeout)
    }
}
