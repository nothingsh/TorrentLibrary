//
//  HTTPConnection.swift
//  
//
//  Created by Wynn Zhang on 6/28/23.
//

import Foundation

struct HTTPResponse {
    let responseData: Data?
    let statusCode: Int
    
    init(responseData: Data? = nil, statusCode: Int = 0) {
        self.responseData = responseData
        self.statusCode = statusCode
    }
}

protocol HTTPConnectionDelegate: AnyObject {
    func httpConnection(_ sender: HTTPConnection, response: HTTPResponse)
}

class HTTPConnection {
    weak var delegate: HTTPConnectionDelegate?
    
    func makeRequest(url: URL, urlParameters: [String: String]? = nil) throws {
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = urlParameters
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }
                var statusCode: Int? = nil
                if let httpResponse = response as? HTTPURLResponse {
                    statusCode = httpResponse.statusCode
                }
                
                let response = HTTPResponse(responseData: data, statusCode: statusCode ?? 0)
                strongSelf.delegate?.httpConnection(strongSelf, response: response)
            }
        }
    }
}
