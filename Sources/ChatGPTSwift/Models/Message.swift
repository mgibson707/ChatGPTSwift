//
//  File.swift
//  
//
//  Created by Matt on 3/7/23.
//

import Foundation

public struct Message: Codable, Equatable, Sendable {
    /// Unique ID for Message. The `id` property is not serialized.
    public let id: UUID = UUID()
    
    public let role: MessageRole
    public let content: String
    
    enum CodingKeys: CodingKey {
        case role
        case content
    }
    
    public init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
    }
    
    public static func ==(lhs: Message, rhs: Message) -> Bool {
        return
            lhs.content == rhs.content &&
            lhs.role == rhs.role
    }

    
}

public enum MessageRole: String, Codable, Sendable {
    case system = "system"
    case assistant = "assistant"
    case user = "user"
}

public extension Array where Element == Message {
    
    var contentCount: Int { map { $0.content }.count }
}
