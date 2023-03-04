//
//  ConvoStore.swift
//  ChatShortcut
//
//  Created by Matt on 3/3/23.
//

import Foundation

enum ChatStorageError: Error {
    case noConvoWithProvidedID
    case couldNotSave
}


// Singleton Access to userdefaults
actor ConvoStore: ChatStorage {
    
    //MARK: - ChatStorage
    func openConversationSnapshot(conversationID: UUID) throws -> Conversation {
        guard let convo = getConversationFor(id: conversationID) else {
            throw ChatStorageError.noConvoWithProvidedID
        }
        return convo
    }
    
    func saveConversationSnapshot(conversation: Conversation) {
        try? save(conversation: conversation)
    }
    //MARK: End ChatStorage -
    
    
    static let key: String = "ConvoStore"
    private var defaults = UserDefaults.standard
    
    //TODO: use ~better~ datastore
    var convos: [Conversation] {
        do {
            if let data = defaults.data(forKey: Self.key){
                let convos = try JSONDecoder().decode(Array<Conversation>.self, from: data)
                return convos
            }
        } catch {
            print("ConvoStore Warning! Returning ewmpty store due to JSON decode error.")
        }
        return []
    }
    
    var convoCount: Int {
        convos.count
    }
    
    var mostRecentConvo: Conversation? {
        return convos.last
    }
    
    /// ConvoStore shared singleton instance
    static let shared = ConvoStore()

    // Private Initialization for singleton
    private init() {
    }
    
    func getConvosFor(identifiers: [UUID]) -> [Conversation] {
        return convos.filter({identifiers.contains($0.id)})
    }
    
    func getConversationFor(id: UUID) -> Conversation? {
        return convos.first(where: {$0.id == id})
    }
    
    func getRecentConvos(_ n: Int = 5) -> [Conversation]{
        return convos.sorted(by: {$0.lastInteraction < $1.lastInteraction}).suffix(n)
    }
    
    /// Save a new conversation or update an existing one
    func save(conversation: Conversation) throws {
            // if this is an existing conversation
        if let existingConvoIndex = convos.firstIndex(where: {$0.id == conversation.id}) {
            var updatedConvos = convos
            updatedConvos[existingConvoIndex] = conversation
            //archiver.encode(convos + [conversation], forKey: Self.key)
            defaults.set(try JSONEncoder().encode(updatedConvos), forKey: Self.key)
        } else {
            // if this new a new conversation
            //archiver.encode(convos + [conversation], forKey: Self.key)
            let updatedConvos = convos + [conversation]
            defaults.set(try JSONEncoder().encode(updatedConvos), forKey: Self.key)
        }
    }
    

    func removeAllConvos(){
        print("Deleting all convos...")
        let updatedConvos: [Conversation] = []
        defaults.set(try! JSONEncoder().encode(updatedConvos), forKey: Self.key)
    }
    
    

}
