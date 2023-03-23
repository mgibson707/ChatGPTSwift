//
//  Conversation.swift
//  
//
//  Created by Matt on 3/7/23.
//

import Foundation

public struct Conversation: Codable, Sendable, Equatable, Hashable {
    public private(set) var id: UUID
    /// All messages in the conversation
    public private(set) var messages: [Message]
    public private(set) var lastInteraction: Date
    
    /// Message history excluding system messages
    public var historyList: [Message] {
        messages.filter({$0.role != .system})
    }
    
    public var systemMessage: Message? {
        get{
            messages.first(where: {$0.role == .system})
        }
        mutating set{
            messages.removeAll(where: {$0.role == .system})
            if let newValue {
                messages.insert(newValue, at: 0)
            }
        }
    }
    
    public var title: String {
        let wordsInTitle = 10

        // For empty array
        guard let latestMessage = messages.last else { return "Empty Conversation"}
        
        // For when latest messages is shorter than limit - just return it
        guard latestMessage.content.count > wordsInTitle else { return latestMessage.content }
        
        // Truncate and return latest message content
        return "\(latestMessage.content.firstXWords(wordsInTitle))..."
    }
    
    public init(messages: [Message], uuid: UUID? = nil, lastInteraction: Date? = nil){
        self.messages = messages
        if let uuid {
            self.id = uuid
        } else {
            self.id = UUID() // newly initialized Conversations always create a new id unless one is specified
        }
        if let lastInteraction {
            self.lastInteraction = lastInteraction
        } else {
            self.lastInteraction = Date() // Use now if no last interaction date provided
        }
    }
    
    // Add a new message to the conversation
    public mutating func addMessage(_ message: Message) {
        messages.append(message)
    }
    
    // Delete a message from the conversation
    public mutating func deleteMessage(at index: Int) {
        guard messages.indices.contains(index) else { return }
        messages.remove(at: index)
    }
    
    // Update a message in the conversation
    public mutating func updateMessage(at index: Int, with newMessage: Message) {
        guard messages.indices.contains(index) else { return }
        messages[index] = newMessage
    }
    
    public mutating func addExampleInteraction(userText: String, assistantResponseText: String) {
        self.addMessage(Message(role: .user, content: userText))
        self.addMessage(Message(role: .assistant, content: assistantResponseText))
        self.lastInteraction = Date()
    }
    
    // Computed property for the last message in the conversation
    public var lastMessage: Message? {
        return messages.last
    }
    
     // Computed property for the number of messages in the conversation
    public var messageCount: Int {
        return historyList.count
    }
    
    // Convenience method to check if the conversation contains a specific message
    public func containsMessage(_ message: Message) -> Bool {
        return messages.contains { messsage in
            message == message
        }
    }
}
