//
//  HTTPConnectionTests.swift
//  
//
//  Created by Wynn Zhang on 8/20/23.
//

import XCTest
import OHHTTPStubsSwift
@testable import TorrentLibrary
import OHHTTPStubs

class HTTPConnectionDelegateStub: HTTPConnectionDelegate {
    func httpConnection(_ sender: HTTPConnectionProtocol, url: URL, response: TorrentLibrary.HTTPResponse) {
        
    }
}

final class HTTPConnectionTests: XCTestCase {
    let host = "test.com"
    let url = URL(string: "https://test.com")!
    let urlParameters = ["foo": "bar", "hello": "world!"]
    let statusCode: Int32 = 123
    let responseData = Data([1,2,3,4])
    
    var connection: HTTPConnection!
    var delegateStub: HTTPConnectionDelegateStub!
    
    override func setUp() {
        super.setUp()
        
        OHHTTPStubsSwift.stub { [weak self] request in
            guard let host = self?.host, let urlParameters = self?.urlParameters else {
                return false
            }
            
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let urlParametersInRequest: [String: String]
                
            if let queryItems = components.queryItems {
                let elements = queryItems.map({ ($0.name, $0.value) })
                urlParametersInRequest = Dictionary(uniqueKeysWithValues: elements) as! [String : String]
            } else {
                urlParametersInRequest = [:]
            }
            
            return (components.host == host && urlParametersInRequest == urlParameters)
        } response: { [weak self] request in
            HTTPStubsResponse(data: self!.responseData, statusCode: self!.statusCode, headers: nil)
        }
        
        connection = HTTPConnection()
        delegateStub = HTTPConnectionDelegateStub()
        connection.delegate = delegateStub
    }
    
    func test_failedRequest() {
        let expectation = self.expectation(description: "Completion closure invoked")
        
        connection.makeRequest(url: URL(string: "www.baidu.com")!) { response in
            XCTAssertFalse(response.completed)
            XCTAssertNil(response.responseData)
            XCTAssertEqual(response.statusCode , 0)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 0.1)
    }
    
    func test_canMakeRequest() {
        let expectation = self.expectation(description: "Completion closure invoked")
        
        connection.makeRequest(url: url, urlParameters: urlParameters) { response in
            XCTAssert(response.completed)
            XCTAssertEqual(response.responseData, self.responseData)
            XCTAssertEqual(response.statusCode, Int(self.statusCode))
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
}
