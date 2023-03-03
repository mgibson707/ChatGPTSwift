import XCTest
@testable import ChatGPTSwift
var api: ChatGPTAPI!

class TestStorage: ChatStorage {
    func openConversationSnapshot(conversationID: UUID) -> ChatGPTSwift.Conversation {
        //unimplemented
        return Conversation(messages: [])
    }
    
    func saveConversationSnapshot(conversation: ChatGPTSwift.Conversation) {
        //unimplemented
    }
}

final class ChatGPTSwiftTests: XCTestCase {

    
    
    override class func setUp() {
        api = ChatGPTAPI(apiKey: Constants.openAIAPIKey, storage: TestStorage())
    }
    
    @MainActor func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        
        //let api = ChatGPTAPI(apiKey: Constants.openAIAPIKey)
        let exp = expectation(description: "Get response")
        Task {
            do {
                let response = try await api.sendMessage(text: "What is ChatGPT?")
                print(response)
                exp.fulfill()
            } catch {
                print(error.localizedDescription)
                XCTFail(error.localizedDescription)
                exp.fulfill()
            }
        }
        
        wait(for: [exp], timeout: 15)
    }
    
    func testStream() async throws {
        let stream = try await api.sendMessageStream(text: "What is ChatGPT?")
        var accumulatedText = ""
        for try await chunk in stream {
            accumulatedText += chunk
            print(accumulatedText)
        }
    }
    
    func testEncoding() throws {
        let testReq = Request(model: .gpt_3_5_turbo, temperature: 0.8, messages: [.init(role: .system, content: "You are a chatbot"), .init(role: .user, content: "tell me about chatbot history")], stream: true, maxTokens: 256)
        let encoded = try JSONEncoder().encode(testReq)
        let encodedJSONString = String(data: encoded, encoding: .utf8) ?? "JSON couldn't be converted to string"
        print(encodedJSONString)
        
    }
}
