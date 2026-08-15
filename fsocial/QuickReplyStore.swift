//
//  QuickReplyStore.swift
//  fsocial
//
//  Created by Mason Earl on 1/11/26.
//

import Foundation
import SwiftUI
import Combine

class QuickReplyStore: ObservableObject {
    private let storageKey = "com.fsocial.quickreplies"
    
    @Published var replies: [QuickReply] = []
    @Published var lastSaveError: String?
    
    init() {
        loadReplies()
    }
    
    private func loadReplies() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                replies = try JSONDecoder().decode([QuickReply].self, from: data)
                lastSaveError = nil
            } catch {
                lastSaveError = "Could not load quick replies: \(error.localizedDescription)"
                replies = QuickReply.defaultReplies
            }
        } else {
            replies = QuickReply.defaultReplies
            saveReplies()
        }
    }
    
    private func saveReplies() {
        do {
            let data = try JSONEncoder().encode(replies)
            UserDefaults.standard.set(data, forKey: storageKey)
            lastSaveError = nil
        } catch {
            lastSaveError = "Could not save quick replies: \(error.localizedDescription)"
        }
    }
    
    func replies(for category: ReplyCategory) -> [QuickReply] {
        replies.filter { $0.category == category }
    }
    
    func addReply(_ text: String, category: ReplyCategory = .custom) {
        let reply = QuickReply(text: text, category: category, isDefault: false)
        replies.append(reply)
        saveReplies()
    }
    
    func updateReply(_ reply: QuickReply, newText: String) {
        if let index = replies.firstIndex(where: { $0.id == reply.id }) {
            replies[index].text = newText
            saveReplies()
        }
    }
    
    func deleteReply(_ reply: QuickReply) {
        replies.removeAll { $0.id == reply.id }
        saveReplies()
    }
    
    func resetToDefaults() {
        // Keep custom replies, reset defaults
        let customReplies = replies.filter { !$0.isDefault && $0.category == .custom }
        replies = QuickReply.defaultReplies + customReplies
        saveReplies()
    }
}
