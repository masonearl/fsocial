//
//  ScheduleStore.swift
//  fsocial
//
//  Created by Mason Earl on 1/11/26.
//

import Foundation
import SwiftUI
import UserNotifications
import Combine
import AppKit

class ScheduleStore: ObservableObject {
    private let storageKey = "com.fsocial.scheduledposts"
    
    @Published var posts: [ScheduledPost] = []
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var lastSaveError: String?
    @Published var lastNotificationError: String?
    
    var notificationsDenied: Bool {
        switch notificationStatus {
        case .denied, .restricted:
            return true
        case .authorized, .provisional, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
    
    init() {
        loadPosts()
        refreshNotificationStatus()
        requestNotificationPermission()
    }
    
    private func loadPosts() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            posts = try JSONDecoder().decode([ScheduledPost].self, from: data)
            lastSaveError = nil
        } catch {
            lastSaveError = "Could not load scheduled posts: \(error.localizedDescription)"
        }
    }
    
    private func savePosts() {
        do {
            let data = try JSONEncoder().encode(posts)
            UserDefaults.standard.set(data, forKey: storageKey)
            lastSaveError = nil
        } catch {
            lastSaveError = "Could not save scheduled posts: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Filtering
    
    var upcomingPosts: [ScheduledPost] {
        posts.filter { !$0.isPosted && !$0.isPast }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }
    
    var todaysPosts: [ScheduledPost] {
        posts.filter { $0.isToday && !$0.isPosted }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }
    
    var pastPosts: [ScheduledPost] {
        posts.filter { $0.isPast || $0.isPosted }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }
    
    func posts(for date: Date) -> [ScheduledPost] {
        posts.filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }
    
    // MARK: - CRUD Operations
    
    func addPost(content: String, platforms: [Platform], scheduledDate: Date, notes: String = "") {
        let post = ScheduledPost(
            content: content,
            platforms: platforms,
            scheduledDate: scheduledDate,
            notes: notes
        )
        posts.append(post)
        savePosts()
        scheduleNotification(for: post)
    }
    
    func updatePost(_ post: ScheduledPost, content: String, platforms: [Platform], scheduledDate: Date, notes: String) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            cancelNotification(for: posts[index])
            posts[index].content = content
            posts[index].platforms = platforms
            posts[index].scheduledDate = scheduledDate
            posts[index].notes = notes
            savePosts()
            scheduleNotification(for: posts[index])
        }
    }
    
    func markAsPosted(_ post: ScheduledPost) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].isPosted = true
            savePosts()
            cancelNotification(for: post)
        }
    }
    
    func deletePost(_ post: ScheduledPost) {
        cancelNotification(for: post)
        posts.removeAll { $0.id == post.id }
        savePosts()
    }
    
    // MARK: - Notifications
    
    func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.lastNotificationError = error.localizedDescription
                } else {
                    self.lastNotificationError = nil
                }
                self.notificationStatus = granted ? .authorized : .denied
                self.refreshNotificationStatus()
            }
        }
    }
    
    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func scheduleNotification(for post: ScheduledPost) {
        guard notificationStatus == .authorized || notificationStatus == .provisional || notificationStatus == .notDetermined else {
            lastNotificationError = "Notifications are disabled. Enable them in System Settings to get post reminders."
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Time to post!"
        content.body = String(post.content.prefix(100)) + (post.content.count > 100 ? "..." : "")
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: post.scheduledDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: post.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.lastNotificationError = "Failed to schedule reminder: \(error.localizedDescription)"
                } else {
                    self.lastNotificationError = nil
                }
            }
        }
    }
    
    private func cancelNotification(for post: ScheduledPost) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [post.id.uuidString])
    }
    
    // MARK: - Calendar Helpers
    
    func hasPostsOnDate(_ date: Date) -> Bool {
        posts.contains { Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) }
    }
    
    var datesWithPosts: Set<DateComponents> {
        Set(posts.map { Calendar.current.dateComponents([.year, .month, .day], from: $0.scheduledDate) })
    }
}
