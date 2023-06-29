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

class HTTPConnection {
    func makeRequest(url: URL, urlParameters: [String: String]? = nil, completion: @escaping (HTTPResponse)->Void) throws {
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = urlParameters
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                var statusCode: Int? = nil
                if let httpResponse = response as? HTTPURLResponse {
                    statusCode = httpResponse.statusCode
                }
                completion(HTTPResponse(responseData: data, statusCode: statusCode ?? 0))
            }
        }
    }
}
