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

public struct Conversation: Codable {
    public private(set) var id: UUID = UUID()
    public private(set) var messages: [Message]
    
    var historyList: [Message] {
        messages.filter({$0.role != .system})
    }
    
    var systemMessage: Message? {
        get{
            messages.first(where: {$0.role == .system})
        }
        set{
            messages.removeAll(where: {$0.role == .system})
            if let newValue {
                messages.insert(newValue, at: 0)
            }
        }
    }
    
    init(messages: [Message], uuid: UUID? = nil){
        self.messages = messages
        if let uuid {
            self.id = uuid
        }
    }
    
    // Add a new message to the conversation
    mutating func addMessage(_ message: Message) {
        messages.append(message)
    }
    
    // Delete a message from the conversation
    mutating func deleteMessage(at index: Int) {
        guard messages.indices.contains(index) else { return }
        messages.remove(at: index)
    }
    
    // Update a message in the conversation
    mutating func updateMessage(at index: Int, with newMessage: Message) {
        guard messages.indices.contains(index) else { return }
        messages[index] = newMessage
    }
    
    // Convenience method to get the last message in the conversation
    func getLastMessage() -> Message? {
        return messages.last
    }
    
    // Convenience method to get the number of messages in the conversation
    func getMessageCount() -> Int {
        return messages.count
    }
    
    // Convenience method to check if the conversation contains a specific message
    func containsMessage(_ message: Message) -> Bool {
        return messages.contains { messsage in
            message == message
        }
    }
}

public struct Message: Codable, Equatable {
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
