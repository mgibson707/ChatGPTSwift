import XCTest
@testable import ChatGPTSwift
var api: ChatGPTAPI!

final class ChatGPTSwiftTests: XCTestCase {
    
    override class func setUp() {
        api = ChatGPTAPI(apiKey: Constants.openAIAPIKey)
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
        
        wait(for: [exp])
    }
    
    func testStream() async throws {
        let stream = try await api.sendMessageStream(text: "What is ChatGPT?")
        var accumulatedText = ""
        for try await chunk in stream {
            accumulatedText += chunk
            print(accumulatedText)
        }
    }
}
