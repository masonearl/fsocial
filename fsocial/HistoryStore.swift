//
//  HistoryStore.swift
//  fsocial
//
//  Created by Mason Earl on 1/11/26.
//

import Foundation
import SwiftUI
import Combine

class HistoryStore: ObservableObject {
    private let storageKey = "com.fsocial.postHistory"
    
    @Published var posts: [PostedContent] = []
    @Published var lastSaveError: String?
    
    init() {
        loadPosts()
    }
    
    private func loadPosts() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            posts = try JSONDecoder().decode([PostedContent].self, from: data)
            lastSaveError = nil
        } catch {
            lastSaveError = "Could not load post history: \(error.localizedDescription)"
        }
    }
    
    private func savePosts() {
        do {
            let data = try JSONEncoder().encode(posts)
            UserDefaults.standard.set(data, forKey: storageKey)
            lastSaveError = nil
        } catch {
            lastSaveError = "Could not save post history: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Post Management
    
    func addPost(_ content: String, platforms: [Platform], mediaCount: Int = 0, hashtags: [String] = []) {
        let post = PostedContent(
            content: content,
            platforms: platforms,
            postedAt: Date(),
            mediaCount: mediaCount,
            hashtags: hashtags
        )
        posts.insert(post, at: 0)
        savePosts()
    }
    
    func deletePost(_ post: PostedContent) {
        posts.removeAll { $0.id == post.id }
        savePosts()
    }
    
    func clearHistory() {
        posts.removeAll()
        savePosts()
    }
    
    // MARK: - Analytics
    
    var totalPosts: Int {
        posts.count
    }
    
    var postsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return posts.filter { $0.postedAt > weekAgo }.count
    }
    
    var postsThisMonth: Int {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return posts.filter { $0.postedAt > monthAgo }.count
    }
    
    func postsForPlatform(_ platform: Platform) -> [PostedContent] {
        posts.filter { $0.platforms.contains(platform) }
    }
    
    var platformBreakdown: [(Platform, Int)] {
        var counts: [Platform: Int] = [:]
        for post in posts {
            for platform in post.platforms {
                counts[platform, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }
    
    var mostUsedHashtags: [(String, Int)] {
        var counts: [String: Int] = [:]
        for post in posts {
            for tag in post.hashtags {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }
    
    var postsPerDayOfWeek: [String: Int] {
        var counts: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        
        for post in posts {
            let day = formatter.string(from: post.postedAt)
            counts[day, default: 0] += 1
        }
        return counts
    }
    
    var bestPerformingDay: String? {
        postsPerDayOfWeek.max(by: { $0.value < $1.value })?.key
    }
    
    var averagePostsPerWeek: Double {
        guard let firstPost = posts.last else { return 0 }
        let weeks = max(1, Calendar.current.dateComponents([.weekOfYear], from: firstPost.postedAt, to: Date()).weekOfYear ?? 1)
        return Double(posts.count) / Double(weeks)
    }
}
