//
//  File.swift
//  
//
//  Created by Matt on 3/22/23.
//

import Foundation

enum SimpleChatStorageError: Error {
    case noConvoWithProvidedID
    case couldNotSave
}


/// A VERY basic persistence implementation abusing UserDefaults.
/// Effectivly just a wrapper global actor for singleton sccess to userdefaults
@globalActor actor SimpleConvoStore: ChatStorage, ObservableObject {
    
    // MARK: - ChatStorage Protocol
    func openConversationSnapshot(conversationID: UUID) async throws -> Conversation {
        guard let convo = await SimpleConvoStore.getConversationFor(id: conversationID) else {
            throw SimpleChatStorageError.noConvoWithProvidedID
        }
        return convo
    }

    func saveConversationSnapshot(conversation: Conversation) async {
        try? SimpleConvoStore.save(conversation: conversation)
    }
    // MARK: end -

    /// UserDefaults (standard) key for the array of Conversations stored by ConvoStore
    static let key: String = "ConvoStore"
    
    static private var defaults = UserDefaults.standard
    
    static var convos: [Conversation] {
        if let data = defaults.data(forKey: Self.key),
        let convos = try? JSONDecoder().decode(Array<Conversation>.self, from: data) {
            return convos.sorted(by: {$0.lastInteraction < $1.lastInteraction })
        }
        return []
    }
    
    /// Current number of Conversations stored by ConvoStore
    static var convoCount: Int {
        convos.count
    }
    
    static var mostRecentConvo: Conversation? {
        return convos.last
    }

    /// ConvoStore shared singleton instance
    static let shared = SimpleConvoStore()

    // Private Initialization for singleton
    private init() {
    }

    static func getConvosFor(identifiers: [UUID]) async -> [Conversation] {
        return convos.filter({identifiers.contains($0.id)})
    }

    static func getConversationFor(id: UUID) async -> Conversation? {
        return convos.first(where: {$0.id == id})
    }

    static func getRecentConvos(_ n: Int = 5) async -> [Conversation]{
        return convos.sorted(by: {$0.lastInteraction < $1.lastInteraction}).suffix(n)
    }

    /// Save a new conversation or update an existing one
    static func save(conversation: Conversation) throws {
        
            // if this is an existing conversation
        if let existingConvoIndex = convos.firstIndex(where: {$0.id == conversation.id}) {
            var updatedConvos = convos
            updatedConvos[existingConvoIndex] = conversation
            defaults.set(try JSONEncoder().encode(updatedConvos), forKey: Self.key)
        } else {
            // if this new a new conversation
            let updatedConvos = convos + [conversation]
            defaults.set(try JSONEncoder().encode(updatedConvos), forKey: Self.key)
        }
    }


    static func removeAllConvos(){
        print("Deleting all convos...")
        let updatedConvos: [Conversation] = []
        defaults.set(try! JSONEncoder().encode(updatedConvos), forKey: Self.key)
    }



}
