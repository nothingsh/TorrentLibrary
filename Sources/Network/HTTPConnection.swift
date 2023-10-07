//
//  HTTPConnection.swift
//  
//
//  Created by Wynn Zhang on 6/28/23.
//

import Foundation
import Alamofire

struct HTTPResponse {
    let completed: Bool
    let responseData: Data?
    let statusCode: Int
    
    init(completed: Bool, responseData: Data? = nil, statusCode: Int = 0) {
        self.completed = completed
        self.responseData = responseData
        self.statusCode = statusCode;
    }
    
    init(response: AFDataResponse<Data>) {
        guard let data = response.data,
            let httpResponse = response.response,
            response.error == nil else {
                self.init(completed: false)
                return
        }
        
        self.init(completed: true, responseData: data, statusCode: httpResponse.statusCode)
    }
}

protocol HTTPConnectionProtocol: AnyObject {
    func makeRequest(url: URL, urlParameters: [String: String]?)
}

protocol HTTPConnectionDelegate: AnyObject {
    func httpConnection(_ sender: HTTPConnectionProtocol, url: URL, response: HTTPResponse)
}

class HTTPConnection: HTTPConnectionProtocol {
    weak var delegate: HTTPConnectionDelegate?
    
    let encoding = ParameterEncodingFixer()
    
    func makeRequest(url: URL, urlParameters: [String: String]? = nil) {
        AF.request(url, parameters: urlParameters, encoding: encoding)
            .responseData { [weak self] response in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.delegate?.httpConnection(strongSelf, url: url, response: HTTPResponse(response: response))
            }
    }
    
    #if DEBUG
    func makeRequest(url: URL, urlParameters: [String: String]? = nil, completion: @escaping (HTTPResponse)->Void) {
        AF.request(url, parameters: urlParameters, encoding: encoding)
            .responseData { response in
                completion(HTTPResponse(response: response))
            }
    }
    #endif
    
    class ParameterEncodingFixer: ParameterEncoding {
        func encode(_ requestConvertable: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
            
            let urlEncoding = URLEncoding()
            
            guard parameters != nil else {
                return try urlEncoding.encode(requestConvertable, with: nil)
            }
            
            var newParameters = parameters
            newParameters!.removeValue(forKey: "info_hash")
            
            var result = try urlEncoding.encode(requestConvertable, with: newParameters)
            
            if let infoHash: String = parameters?["info_hash"] as? String {
                let newURL = result.url!.absoluteString + "&info_hash=" + infoHash
                result.url = URL(string: newURL)
            }
            
            return result;
        }
    }
}
