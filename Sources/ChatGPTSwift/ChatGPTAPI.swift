//
//  ChatGPTAPI.swift
//  XCAChatGPT
//
//  Created by Alfian Losari on 01/02/23.
//

import Foundation

public protocol ChatStorage: Actor {
    func openConversationSnapshot(conversationID: UUID) throws -> Conversation
    func saveConversationSnapshot(conversation: Conversation)
}

public class ChatGPTAPI: @unchecked Sendable {
    weak public private(set) var storage: ChatStorage?
    public static var defaultSystemMessage: Message = .init(role: .system, content: "You are a helpful assistant")
    
    public private(set) var systemMessage: Message
    public private(set) var historyList = [Message]()
    public private(set) var lastInteraction: Date
    public private(set) var conversationID: UUID?
    
    // MARK: Computed Message Log Properties
    public var currentFullMessageHistory: [Message] {
        [systemMessage] + historyList
    }
    
    public var currentConversationSnapshot: Conversation {
        Conversation(messages: self.currentFullMessageHistory, uuid: self.conversationID, lastInteraction: self.lastInteraction)
    }
   
    // MARK: - Model Params
    private var temperature: Double {
        didSet {
            temperature = temperature.clamped(to: 0.0...2.0)
        }
    }
    private let model: GPTModel
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
        temperature: Double = 0.8,
        systemPrompt: String? = nil,
        storage: ChatStorage) {
        self.apiKey = apiKey
        self.model = model ?? GPTModel.gpt_3_5_turbo
        self.systemMessage = systemPrompt == nil ? Self.defaultSystemMessage : .init(role: .system, content: systemPrompt!)
        self.temperature = temperature.clamped(to: 0.0...2.0)
        self.storage = storage
        self.lastInteraction = Date()
    }
    

    /// Prepares for saving then calls save on ChatStorage with up to date Conversation
    public func saveConversation() async throws {
        // Ensure there is an ID to associate with this convo
        if self.conversationID == nil {
            self.conversationID = UUID()
            print("Assigned ID to conversation: \(self.conversationID!.uuidString)")
        }
        self.lastInteraction = Date() // Mark time of save as last interaction
        guard let storage = storage else { throw "no storage"}

        // Save the conversation to ChatStorage
        Task {
            let snapshot = currentConversationSnapshot
            await storage.saveConversationSnapshot(conversation: snapshot)
            print("Saved conversation \(snapshot.id)")
        }
    }
    
    /// Prepares to load a conversation by optionally saving the existing conversation. Gets conversation from ChatStorage by id and loads the conversation into the interface.
    public func loadConversation(with id: UUID, savingExistingConvo: Bool = true) async throws {
        if savingExistingConvo {
            try await self.saveConversation()
        }
        guard let storage = storage else { throw "no storage"}
        
        Task {
            let convoToLoad = try await storage.openConversationSnapshot(conversationID: id)
            await MainActor.run {
                self.load(conversation: convoToLoad)
            }
        }

    }
    
    private func load(conversation: Conversation){
        self.systemMessage = conversation.systemMessage ?? Self.defaultSystemMessage
        self.historyList = conversation.historyList
        self.lastInteraction = conversation.lastInteraction
        self.conversationID = conversation.id
    }
    
    private func generateMessages(from text: String, history: [Message]) -> [Message] {
        var messages = [systemMessage] + historyList + [Message(role: .user, content: text)]
        if messages.contentCount > (4000 * 4) {
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
        self.historyList.append(Message(role: .user, content: userText))
        self.historyList.append(Message(role: .assistant, content: responseText))
        self.lastInteraction = Date()
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
    
    
    public func sendMessageStream(text: String) async throws -> AsyncThrowingStream<String, Error> {
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
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func sendMessage(text: String) async throws -> String {
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
            return responseText
        } catch {
            throw error
        }
    }
    
    public func deleteHistoryList() {
        self.historyList.removeAll()
    }
}

