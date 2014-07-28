//
//  JLNestedToken.swift
//  Chromatism
//
//  Created by Johannes Lund on 2014-07-21.
//  Copyright (c) 2014 anviking. All rights reserved.
//

import UIKit

public class JLNestedScope: JLScope {
    var incrementingToken: JLTokenizer.Token
    var decrementingToken: JLTokenizer.Token
    
    var tokenType: JLTokenType
    var hollow: Bool
    
    init(incrementingToken: JLTokenizer.Token, decrementingToken: JLTokenizer.Token, tokenType: JLTokenType, hollow: Bool) {
        self.incrementingToken = incrementingToken
        self.decrementingToken = decrementingToken
        self.hollow = hollow
        self.tokenType = tokenType
        super.init()
        multiline = true
    }
    
    func perform(indexSet: NSIndexSet, tokens: [JLTokenizer.TokenResult]) {
        self.indexSet = NSMutableIndexSet()
        func tokensClosestToRange(range: NSRange) -> (previous: JLTokenizer.TokenResult?, next: JLTokenizer.TokenResult?) {
            if tokens.count == 0 { return (nil, nil) }
            var previousToken: JLTokenizer.TokenResult? = tokens[tokens.startIndex]
            var nextToken: JLTokenizer.TokenResult?
            
            for token in tokens {
                if token.range.location < range.location {
                    previousToken = token
                } else if token.range.end > range.end {
                    nextToken = token
                    break
                }
            }
            
            return (previousToken, nextToken)
        }
        func surroundingTokenPair(range: NSRange) -> (incrementingToken: JLTokenizer.TokenResult, decrementingToken: JLTokenizer.TokenResult)? {
            let tokens = tokensClosestToRange(range)
            if let previousToken = tokens.previous {
                if let nextToken = tokens.next {
                    if previousToken.token.delta > 0 && nextToken.token.delta < 0 {
                        return (previousToken, nextToken)
                    }
                }
            }
            return nil
        }
        
        indexSet.enumerateRangesUsingBlock { (range, _) in
            if let (start, end) = surroundingTokenPair(range) {
                self.process(start, decrementingToken: end, attributedString: self.attributedString)
            }
        }
        
        var incrementingTokens = Dictionary<Int, JLTokenizer.TokenResult>()
        var depth = 0
        for result in tokens {
            if result.token.delta > 0 {
                incrementingTokens[depth] = result
            } else if let start = incrementingTokens[depth + result.token.delta] {
                process(start, decrementingToken: result, attributedString: attributedString)
            }
            depth += result.token.delta
        }
    }
    
    private func process(incrementingToken: JLTokenizer.TokenResult, decrementingToken: JLTokenizer.TokenResult, attributedString: NSMutableAttributedString) {
        
        if incrementingToken.token === self.incrementingToken && decrementingToken.token === self.decrementingToken {
            let range = rangeForTokens(incrementingToken, decrementingToken: decrementingToken)
            if let color = self.theme?[tokenType] {
                if range.location >= 0 && range.end <= attributedString.length {
                    attributedString.addAttribute(NSForegroundColorAttributeName, value: color, range: range)
                    indexSet += range
                }
            }
        }
    }
    
    override func invalidateAttributesInIndexes(indexSet: NSIndexSet) {
        self.indexSet -= indexSet
    }
    
    func rangeForTokens(incrementingToken: JLTokenizer.TokenResult, decrementingToken: JLTokenizer.TokenResult) -> NSRange {
        if self.hollow {
            return NSRange(incrementingToken.range.end ..< decrementingToken.range.start)
        } else {
            return NSRange(incrementingToken.range.start ..< decrementingToken.range.end)
        }
    }
}

extension NSRange {
    var end: Int {
    return location + length
    }
    
    var start: Int {
    return location
    }
}

public func ==(lhs: JLTokenizer.Token, rhs: JLTokenizer.Token) -> Bool {
    return (lhs.expression.pattern == rhs.expression.pattern && lhs.delta == rhs.delta)
}


extension NSIndexSet {
    func containsAnyIndexesInRange(range: NSRange) -> Bool {
        for index in range.start ..< range.end {
            if self.containsIndex(index) {
                return true
            }
        }
        return false
    }
}