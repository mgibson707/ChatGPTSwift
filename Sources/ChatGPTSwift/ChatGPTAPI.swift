//
//  ChatGPTAPI.swift
//  XCAChatGPT
//
//  Created by Alfian Losari on 01/02/23.
//

import Foundation

public class ChatGPTAPI: @unchecked Sendable {
    public static var defaultSystemMessage: Message = .init(role: .system, content: "You are a helpful assistant")
    var systemMessage: Message
    private var temperature: Double {
        didSet {
            temperature = temperature.clamped(to: 0.0...2.0)
        }
    }
    private let model: GPTModel
    
    private let apiKey: String
    private(set) var historyList = [Message]()
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
        systemPrompt: String? = nil) {
        self.apiKey = apiKey
        self.model = model ?? GPTModel.gpt_3_5_turbo
        self.systemMessage = systemPrompt == nil ? Self.defaultSystemMessage : .init(role: .system, content: systemPrompt!)
        self.temperature = temperature.clamped(to: 0.0...2.0)
    }
    
    public var currentConversation: Conversation {
        Conversation(messages: currentFullMessageHistory)
    }
    
    public var currentFullMessageHistory: [Message] {
        [systemMessage] + historyList
    }
    
    public func loadConversation(conversation: Conversation){
        // TODO: save conversation before overwriting
        
        self.systemMessage = conversation.systemMessage ?? Self.defaultSystemMessage
        self.historyList = conversation.historyList
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
    }
    
    func addExampleInteraction(with exampleUserText: String, exampleResponseText: String) {
        appendToHistoryList(userText: exampleUserText, responseText: exampleResponseText)
    }
    
    func setChatHistoryExamples(to messages: [Message], systemMessage: Message? = nil) {
        self.systemMessage = systemMessage ?? Self.defaultSystemMessage
        self.historyList = messages
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

