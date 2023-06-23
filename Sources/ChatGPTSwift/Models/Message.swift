//
//  File.swift
//  
//
//  Created by Matt on 3/7/23.
//

import Foundation

public struct Message: Codable, Sendable, Equatable, Hashable {
    /// Unique ID for Message. The `id` property is not serialized.
    //public let id: UUID = UUID()
    
    public private(set) var lastInteraction: Date = Date() // excluded from uniqueness of struct
    
    public let role: MessageRole
    public let content: String
    
    public var isExample: Bool = false
    
    enum CodingKeys: CodingKey {
        case role
        case content
    }
    
    public init(role: MessageRole, content: String, lastInteraction: Date? = nil) {
        self.role = role
        self.content = content
        self.lastInteraction = lastInteraction ?? Date()
    }
    
    public static func ==(lhs: Message, rhs: Message) -> Bool {
        return
            lhs.content == rhs.content &&
            lhs.role == rhs.role
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(role)
        hasher.combine(content)
    }

    
}

public enum MessageRole: String, Codable, Sendable {
    case system = "system"
    case assistant = "assistant"
    case user = "user"
    case function = "function"
}

public extension Array where Element == Message {
    
    var contentCount: Int { map { $0.content }.count }
}
