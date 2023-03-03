//
//  UtilityExtensions.swift
//  ChatShortcut
//
//  Created by Matt on 3/2/23.
//

import Foundation

///Extension of Comparable similar to `ClosedRange.clamped(to:_) -> ClosedRange` from standard Swift library.
public extension Comparable {
    
    ///Returns a Comparable type that is limited to the range provided.
    /// Usage:
    ///- `15.clamped(to: 0...10)`  returns 10.
    ///- `3.0.clamped(to: 0.0...10.0)`  returns 3.0.
    ///- `"a".clamped(to: "g"..."y")` returns "g".
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}


extension StringProtocol {
    func firstXWords(_ n: Int) -> SubSequence {
        var endIndex = self.endIndex
        var words = 0
        enumerateSubstrings(in: startIndex..., options: .byWords) { _, range, _, stop in
            words += 1
            if words == n {
                stop = true
                endIndex = range.upperBound
            }
        }
        return self[..<endIndex] }
}
