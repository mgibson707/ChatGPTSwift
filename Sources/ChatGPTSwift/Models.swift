//
//  File.swift
//  
//
//  Created by Alfian Losari on 02/03/23.
//

import Foundation


/// Model identifier to use for request to OpenAI. Currently only `gpt-3.5-turbo`.
public enum GPTModel: String, Codable, CaseIterable {
    case gpt_3_5_turbo = "gpt-3.5-turbo"
    case gpt_4 = "gpt-4"
    
    public var displayName: String {
        switch self {
        case .gpt_3_5_turbo:
            return "GPT-3.5 Turbo"
        case .gpt_4:
            return "GPT-4"
        }
    }
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
