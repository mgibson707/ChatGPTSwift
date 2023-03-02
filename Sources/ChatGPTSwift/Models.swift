//
//  File.swift
//  
//
//  Created by Alfian Losari on 02/03/23.
//

import Foundation

public enum GPTModel: String, Codable {
    case gpt_3_5_turbo = "gpt-3.5-turbo"
}

public struct Message: Codable {
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
}

public enum MessageRole: String, Codable {
    case system = "system"
    case assistant = "assistant"
    case user = "user"
}

public extension Array where Element == Message {
    
    var contentCount: Int { map { $0.content }.count }
}

struct Request: Codable {
    let model: GPTModel
    let temperature: Double
    let messages: [Message]
    let stream: Bool
    var maxTokens: Int?
    var presence_penalty: Float?
    var frequency_penalty: Float?
    var logit_bias: [Int: Int]?
}

struct ErrorRootResponse: Decodable {
    let error: ErrorResponse
}

struct ErrorResponse: Decodable {
    let message: String
    let type: String?
}

struct CompletionResponse: Decodable {
    let choices: [Choice]
    let usage: Usage?
}

struct Usage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}

struct Choice: Decodable {
    let finishReason: String?
    let message: Message
}

struct StreamCompletionResponse: Decodable {
    let choices: [StreamChoice]
}

struct StreamChoice: Decodable {
    let finishReason: String?
    let delta: StreamMessage
}

struct StreamMessage: Decodable {
    let content: String?
    let role: String?
}
