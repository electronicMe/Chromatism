//
//  JLToken.swift
//  Chromatism
//
//  Created by Johannes Lund on 2014-07-14.
//  Copyright (c) 2014 anviking. All rights reserved.
//

import UIKit
public class JLToken: JLScope {
    
    var regularExpression: NSRegularExpression
    
    /// Allows you to specify specific tokenTypes for different capture groups. Index 0 means the whole match, following indexes represent capture groups.
    public var tokenTypes: [JLTokenType]
    
    init(regularExpression: NSRegularExpression, tokenTypes: [JLTokenType]) {
        self.regularExpression = regularExpression
        self.tokenTypes = tokenTypes
        super.init()
    }
    
    convenience init(pattern: String, options: NSRegularExpressionOptions, tokenTypes: [JLTokenType]) {
        let expression = NSRegularExpression(pattern: pattern, options: options, error: nil)
        self.init(regularExpression: expression, tokenTypes: tokenTypes)
    }
    
    convenience init(pattern: String, options: NSRegularExpressionOptions, tokenTypes: JLTokenType...) {
        self.init(pattern: pattern, options: options, tokenTypes: tokenTypes)
    }
    
    convenience init(pattern: String, tokenTypes: JLTokenType...) {
        self.init(pattern: pattern, options: .AnchorsMatchLines, tokenTypes: tokenTypes)
    }
    
    convenience init(keywords: [String], tokenTypes: JLTokenType...) {
        let pattern = "\\b(%" + join("|", keywords) + ")\\b"
        self.init(pattern: pattern, options: nil,tokenTypes: tokenTypes)
    }
    
    override func perform(attributedString: NSMutableAttributedString, parentIndexSet: NSIndexSet) {
        indexSet = self.indexSet - parentIndexSet
        parentIndexSet.enumerateRangesUsingBlock({ (range, stop) in
            self.regularExpression.enumerateMatchesInString(attributedString.string, options: nil, range: range, usingBlock: {(result, flags, stop) in
                    self.process(result, attributedString: attributedString)
                })
            })
        
        performSubscopes(attributedString, indexSet: indexSet.mutableCopy() as NSMutableIndexSet)
    }
    
    private func process(result: NSTextCheckingResult, attributedString: NSMutableAttributedString) {
        for (index, type) in enumerate(self.tokenTypes) {
            if let color = self.theme?[type] {
                if result.numberOfRanges > index {
                    let range = result.rangeAtIndex(index)
                    attributedString.addAttribute(NSForegroundColorAttributeName, value: color, range: range)
                    indexSet.addIndexesInRange(range)
                }
            }
        }
    }
    
    override public var description: String {
    return "JLToken"
    }
}
