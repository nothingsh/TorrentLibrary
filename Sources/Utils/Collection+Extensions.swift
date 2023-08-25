//
//  Collection+Extensions.swift
//  
//
//  Created by Wynn Zhang on 8/25/23.
//

import Foundation

struct PseudoRandomizedSequence<Col, Elem>: Sequence
    where Col: Collection, Col.Element == Elem, Col.Index == Int {
    
    fileprivate let orderedSequence: Col
    
    func makeIterator() -> AnyIterator<Elem> {
        
        let length = orderedSequence.count
        let seed = Int(arc4random()) % length
        let increment = 13 // prime as the step
        
        var generatedNumber = seed
        var count = 0
        
        return AnyIterator {
            guard count != length else { return nil }
            count += 1
            generatedNumber = (generatedNumber + increment) % length
            return self.orderedSequence[generatedNumber]
        }
    }
}

extension Collection where Index == Int {
    var pseudoRandomized: PseudoRandomizedSequence<Self, Element> {
        return PseudoRandomizedSequence(orderedSequence: self)
    }
}
