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
}
