//
//  HashtagStore.swift
//  fsocial
//
//  Created by Mason Earl on 1/11/26.
//

import Foundation
import SwiftUI
import Combine

class HashtagStore: ObservableObject {
    private let storageKey = "com.fsocial.hashtags"
    
    @Published var hashtags: [Hashtag] = []
    @Published var lastSaveError: String?
    
    init() {
        loadHashtags()
        if hashtags.isEmpty {
            hashtags = Hashtag.defaultHashtags
            saveHashtags()
        }
    }
    
    private func loadHashtags() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            hashtags = try JSONDecoder().decode([Hashtag].self, from: data)
            lastSaveError = nil
        } catch {
            lastSaveError = "Could not load hashtags: \(error.localizedDescription)"
        }
    }
    
    private func saveHashtags() {
        do {
            let data = try JSONEncoder().encode(hashtags)
            UserDefaults.standard.set(data, forKey: storageKey)
            lastSaveError = nil
        } catch {
            lastSaveError = "Could not save hashtags: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Hashtag Management
    
    func addHashtag(_ tag: String, category: HashtagCategory = .custom) {
        let cleanTag = tag.hasPrefix("#") ? tag : "#\(tag)"
        guard !hashtags.contains(where: { $0.tag.lowercased() == cleanTag.lowercased() }) else { return }
        
        let hashtag = Hashtag(tag: cleanTag, category: category)
        hashtags.append(hashtag)
        saveHashtags()
    }
    
    func deleteHashtag(_ hashtag: Hashtag) {
        hashtags.removeAll { $0.id == hashtag.id }
        saveHashtags()
    }
    
    func incrementUsage(_ hashtag: Hashtag) {
        if let index = hashtags.firstIndex(where: { $0.id == hashtag.id }) {
            hashtags[index].usageCount += 1
            saveHashtags()
        }
    }
    
    // MARK: - Filtering
    
    func hashtags(for category: HashtagCategory) -> [Hashtag] {
        hashtags.filter { $0.category == category }
    }
    
    var topHashtags: [Hashtag] {
        hashtags.sorted { $0.usageCount > $1.usageCount }.prefix(10).map { $0 }
    }
    
    var recentlyUsed: [Hashtag] {
        hashtags.filter { $0.usageCount > 0 }.sorted { $0.usageCount > $1.usageCount }
    }
    
    // MARK: - Suggestions based on content
    
    func suggestHashtags(for content: String) -> [Hashtag] {
        let lowercased = content.lowercased()
        var suggestions: [Hashtag] = []
        
        // Check for keywords
        let keywordMap: [String: [String]] = [
            "business": ["#entrepreneur", "#smallbusiness", "#business"],
            "entrepreneur": ["#entrepreneur", "#startup", "#founder"],
            "marketing": ["#digitalmarketing", "#marketing", "#socialmedia"],
            "content": ["#contentcreator", "#creator", "#content"],
            "video": ["#video", "#viral", "#fyp"],
            "photo": ["#photography", "#photooftheday", "#instagood"],
            "growth": ["#growth", "#growthhacking", "#viral"],
            "motivation": ["#motivation", "#inspired", "#mindset"],
            "success": ["#success", "#winning", "#goals"],
            "film": ["#film", "#movie", "#cinema"],
            "book": ["#bookstagram", "#reading", "#booklover"],
        ]
        
        for (keyword, tags) in keywordMap {
            if lowercased.contains(keyword) {
                for tag in tags {
                    if let hashtag = hashtags.first(where: { $0.tag.lowercased() == tag.lowercased() }) {
                        if !suggestions.contains(hashtag) {
                            suggestions.append(hashtag)
                        }
                    }
                }
            }
        }
        
        // Add top hashtags if not enough suggestions
        if suggestions.count < 5 {
            for hashtag in topHashtags {
                if !suggestions.contains(hashtag) {
                    suggestions.append(hashtag)
                }
                if suggestions.count >= 5 { break }
            }
        }
        
        return suggestions
    }
}
