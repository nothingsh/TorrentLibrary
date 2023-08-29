//
//  URL+Extensions.swift
//  
//
//  Created by Wynn Zhang on 7/3/23.
//

import Foundation

extension URL {
    func bySettingScheme(to scheme: String) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        components.scheme = scheme
        return components.url!
    }
    
    func appendingDirectoryPathComponent(with dir: String) -> URL {
        if #available(macOS 11.0, iOS 14.0, watchOS 7.0, *) {
            return self.appendingPathComponent(dir, conformingTo: .directory)
        } else {
            return self.appendingPathComponent(dir, isDirectory: true)
        }
    }
}
