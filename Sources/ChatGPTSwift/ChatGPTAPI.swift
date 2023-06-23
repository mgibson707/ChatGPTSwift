//
//  ChatGPTAPI.swift
//  XCAChatGPT
//
//  Created by Alfian Losari on 01/02/23.
//

import Foundation
import Combine
import SwiftUI

public protocol ChatStorage: Actor {
    func openConversationSnapshot(conversationID: UUID) async throws -> Conversation
    func saveConversationSnapshot(conversation: Conversation) async
}

public class ChatGPTAPI {
    weak public private(set) var storage: ChatStorage?
    public static var defaultSystemMessage: Message = .init(role: .system, content: "You are a helpful assistant")
    
    public private(set) var systemMessage: Message
    public private(set) var historyList = [Message]() {
        // When the messages are updates, send the update to the publishing Pipeline
        didSet {
            DispatchQueue.main.async {
                print("History list set to \(self.historyList.count) items: \(self.historyList)")
                self.publishingPipeline.send(self.historyList)
            }
        }
    }
    

    public private(set) var lastInteraction: Date
    public private(set) var conversationID: UUID?
    
    lazy private var publishingPipeline = { CurrentValueSubject<[Message], Never>(self.historyList) }()
    
    lazy public private(set) var messagesPublisher: AnyPublisher<[Message], Never> = {
        self.publishingPipeline.removeDuplicates().eraseToAnyPublisher()
    }()
    
    // MARK: Computed Message Log Properties
    public var currentFullMessageHistory: [Message] {
        [systemMessage] + historyList
    }
    
    public var currentConversationSnapshot: Conversation {
        Conversation(messages: self.currentFullMessageHistory, uuid: self.conversationID, lastInteraction: self.lastInteraction)
    }
    
    public var newDuplicateConversationSnapshot: Conversation {
        Conversation(messages: self.currentFullMessageHistory, uuid: UUID(), lastInteraction: Date())
    }
   
    // MARK: - Model Params
    private var temperature: Double {
        didSet {
            temperature = temperature.clamped(to: 0.0...2.0)
        }
    }
    public var model: GPTModel
    private let apiKey: String

    // MARK: - Network Helpers
    private let urlSession = URLSession.shared
    private var urlRequest: URLRequest {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        headers.forEach {  urlRequest.setValue($1, forHTTPHeaderField: $0) }
        return urlRequest
    }
    
    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "YYYY-MM-dd"
        return df
    }()
    
    private let jsonDecoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return jsonDecoder
    }()
    
    private var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]
    }
    
    public init(apiKey: String,
        model: GPTModel? = nil,
        temperature: Double = 0.1,
        systemPrompt: String? = nil,
        storage: ChatStorage? = nil) {
        
        // TODO: make it so that a new convo without id isnt created every new invocation
        self.apiKey = apiKey
        self.model = model ?? GPTModel.gpt_3_5_turbo
        self.systemMessage = systemPrompt == nil ? Self.defaultSystemMessage : .init(role: .system, content: systemPrompt!)
        self.temperature = temperature.clamped(to: 0.0...2.0)
        self.storage = storage == nil ? SimpleConvoStore.shared : storage
        self.lastInteraction = Date()
    }
    
    
    // MARK: - Save
    
    /// Prepares for saving then calls save on ChatStorage with up to date Conversation
    public func saveConversation() async throws {
        
        if self.historyList.count == 0 && self.currentFullMessageHistory == [Self.defaultSystemMessage]  {
            return
        }
        
        // Ensure there is an ID to associate with this convo
        if self.conversationID == nil {
            self.conversationID = UUID()
            print("Assigned ID to conversation: \(self.conversationID!.uuidString)")
        }
        self.lastInteraction = Date() // Mark time of save as last interaction
        guard let storage = storage else { throw "no storage"}

        // Save the conversation to ChatStorage
        let snapshot = currentConversationSnapshot
        await storage.saveConversationSnapshot(conversation: snapshot)
        print("Saved conversation \(snapshot.id)")
    }
    
    // MARK: - Load
    
    /// Prepares to load a conversation by optionally saving the existing conversation. Gets conversation from ChatStorage by id and loads the conversation into the interface.
    @MainActor public func loadConversation(with id: UUID, savingExistingConvo: Bool = true) async throws {
        if savingExistingConvo {
            // ignore request to save the default convo to avoid creating many duplicates 
                try await self.saveConversation()
        }
        guard let storage = storage else { throw "no storage"}
        
        let convoToLoad = try await storage.openConversationSnapshot(conversationID: id)
        self.load(conversation: convoToLoad)
        print("Loaded Conversation \(convoToLoad.id.uuidString)")

    }
    
    @MainActor public func loadConversation(_ conversation: Conversation, savingExistingConvo: Bool = true) async throws {
        if savingExistingConvo {
            // ignore request to save the default convo to avoid creating many duplicates
                try await self.saveConversation()
        }
        
        self.load(conversation: conversation)
        print("Loaded Conversation \(conversation.id.uuidString)")

    }
    
    @MainActor private func load(conversation: Conversation){
        withAnimation(.easeInOut) {
            self.systemMessage = conversation.systemMessage ?? Self.defaultSystemMessage
            self.historyList = conversation.historyList
            self.lastInteraction = conversation.lastInteraction
            self.conversationID = conversation.id
        }

    }
    
    // MARK: - Chat Methods
    
    private func generateMessages(from text: String, history: [Message]) -> [Message] {
        var messages = [systemMessage] + historyList + [Message(role: .user, content: text)]
        if messages.contentCount > (3200 * 4) {
            messages = generateMessages(from: text, history: Array(historyList.dropFirst()) )
        }
        return messages
    }
    
    private func jsonBody(text: String, stream: Bool = true) throws -> Data {
        let request = Request(model: model,
                        temperature: temperature,
                        messages: generateMessages(from: text, history: self.historyList),
                        stream: stream)
        return try JSONEncoder().encode(request)
    }
    
    private func appendToHistoryList(userText: String, responseText: String) {
        self.lastInteraction = Date()
        self.historyList.append(Message(role: .user, content: userText))
        self.historyList.append(Message(role: .assistant, content: responseText))
    }
    
    func addExampleInteraction(with exampleUserText: String, exampleResponseText: String) {
        appendToHistoryList(userText: exampleUserText, responseText: exampleResponseText)
    }
    
    func setChatHistoryExamples(to messages: [Message], systemMessage: Message? = nil) {
        self.systemMessage = systemMessage ?? Self.defaultSystemMessage
        self.historyList = messages
        self.lastInteraction = Date()
    }
    
    func setTemperature(to newTemperature: Double) {
        self.temperature = newTemperature.clamped(to: 0.0...2.0)
    }
    
    public func indexFor(message: Message) -> Int? {
        return historyList.firstIndex(of: message)
    }
    
    public func updateMessage(at index: Int, with newMessage: Message) -> Bool {
        guard (historyList.startIndex..<historyList.endIndex).contains(index) else {
            return false
        }
        historyList[index] = newMessage
        return true
    }
    
    public func sendMessageStream(text: String, overwritingMessageAt index: Int? = nil, savingInteraction: Bool = true) async throws -> AsyncThrowingStream<String, Error> {
        if let index {
            try await removeMessagesStartingWith(messageAt: index)
        }
        
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try jsonBody(text: text)
        let (result, response) = try await urlSession.bytes(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw "Invalid response"
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            var errorText = ""
            for try await line in result.lines {
               errorText += line
            }
            if let data = errorText.data(using: .utf8), let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                errorText = "\n\(errorResponse.message)"
            }
            throw "Bad Response: \(httpResponse.statusCode). \(errorText)"
        }
        
        return AsyncThrowingStream<String, Error> {  continuation in
            Task(priority: .userInitiated) { [weak self] in
                do {
                    var responseText = ""
                    for try await line in result.lines {
                        if line.hasPrefix("data: "),
                           let data = line.dropFirst(6).data(using: .utf8),
                           let response = try? self?.jsonDecoder.decode(StreamCompletionResponse.self, from: data),
                           let text = response.choices.first?.delta.content {
                            responseText += text
                            continuation.yield(text)
                        }
                    }
                    self?.appendToHistoryList(userText: text, responseText: responseText)
                    if savingInteraction {
                        try await self?.saveConversation()
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func sendMessage(text: String, overwritingMessageAt index: Int? = nil, savingInteraction: Bool = true) async throws -> String {
        if let index {
            try await removeMessagesStartingWith(messageAt: index)
        }
        
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try jsonBody(text: text, stream: false)
        
        let dataResponse = try await urlSession.data(for: urlRequest)
        let data: Data = dataResponse.0
        let response: URLResponse = dataResponse.1
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw "Invalid response"
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            var error = "Bad Response: \(httpResponse.statusCode)"
            if let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                error.append("\n\(errorResponse.message)")
            }
            throw error
        }
        
        do {
            let completionResponse = try self.jsonDecoder.decode(CompletionResponse.self, from: data)
            let responseText = completionResponse.choices.first?.message.content ?? ""
            self.appendToHistoryList(userText: text, responseText: responseText)
            if savingInteraction {
                try await self.saveConversation()
            }
            return responseText
        } catch {
            throw error
        }
    }
    
    public func deleteHistoryList() {
        self.historyList.removeAll()
    }
    
    public func setHistoryList(to newHistoryList: [Message]) async throws {
        await MainActor.run{
//            withAnimation {
                self.historyList = newHistoryList
//            }
        }
        try await self.saveConversation()
        
    }
    
    public func setSystemPrompt(to newSystemPrompt: String) async throws {
        guard !newSystemPrompt.isEmpty else {
            throw "Setting empty system prompt"
        }
        
        await MainActor.run {
            self.systemMessage = Message(role: .system, content: newSystemPrompt)
        }
        try await self.saveConversation()
        
    }
    
    public func removeMessagesStartingWith(messageAt index: Int) async throws {
        

        
        try await MainActor.run {
            //print(historyList.indices.upperBound)
            //self.historyList.removeSubrange(index...historyList.count - 1)
            guard historyList.indices.contains(index) else {
                throw "removeMessagesStartingWith recieved out of bounds index which was rejected."
            }
            
            
            let dropLast = historyList.count - index
            print("History list count: \(historyList.count) | Index: \(index) | Dropping last \(dropLast)")
            self.historyList = self.historyList.dropLast(dropLast)
        }
        try await self.saveConversation()
    }

}

