//
//  DraftStore.swift
//  fsocial
//
//  Created by Mason Earl on 1/11/26.
//

import Foundation
import SwiftUI
import Combine
import AppKit

class DraftStore: ObservableObject {
    private let storageKey = "com.fsocial.drafts"
    private let mediaFolderName = "DraftMedia"
    
    @Published var drafts: [DraftPost] = []
    @Published var currentDraft: DraftPost = DraftPost()
    @Published var lastSaveError: String?
    
    init() {
        loadDrafts()
        createMediaFolderIfNeeded()
    }
    
    private var mediaFolderURL: URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return appSupport?.appendingPathComponent("fsocial/\(mediaFolderName)")
    }
    
    private func createMediaFolderIfNeeded() {
        guard let folderURL = mediaFolderURL else { return }
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }
    
    private func loadDrafts() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            drafts = try JSONDecoder().decode([DraftPost].self, from: data)
            lastSaveError = nil
        } catch {
            lastSaveError = "Could not load drafts: \(error.localizedDescription)"
        }
    }
    
    private func saveDrafts() {
        do {
            let data = try JSONEncoder().encode(drafts)
            UserDefaults.standard.set(data, forKey: storageKey)
            lastSaveError = nil
        } catch {
            lastSaveError = "Could not save drafts: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Draft Management
    
    func saveDraft() {
        guard !currentDraft.isEmpty else { return }
        
        currentDraft.updatedAt = Date()
        
        if let index = drafts.firstIndex(where: { $0.id == currentDraft.id }) {
            drafts[index] = currentDraft
        } else {
            drafts.insert(currentDraft, at: 0)
        }
        saveDrafts()
    }
    
    func loadDraft(_ draft: DraftPost) {
        currentDraft = draft
    }
    
    func deleteDraft(_ draft: DraftPost) {
        // Delete associated media files
        for media in draft.media {
            deleteMediaFile(media)
        }
        drafts.removeAll { $0.id == draft.id }
        saveDrafts()
    }
    
    func newDraft() {
        currentDraft = DraftPost()
    }
    
    func clearCurrentDraft() {
        // Delete media files from current draft
        for media in currentDraft.media {
            deleteMediaFile(media)
        }
        currentDraft = DraftPost()
    }
    
    // MARK: - Media Management
    
    func addMedia(from url: URL) -> MediaItem? {
        guard let folderURL = mediaFolderURL else { return nil }
        
        let fileName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension.lowercased()
        let isVideo = ["mp4", "mov", "m4v", "avi", "mkv"].contains(fileExtension)
        
        let mediaItem = MediaItem(
            fileName: fileName,
            fileExtension: fileExtension,
            isVideo: isVideo
        )
        
        // Copy file to app's media folder
        let destinationURL = folderURL.appendingPathComponent("\(mediaItem.id.uuidString).\(fileExtension)")
        
        do {
            // Access security-scoped resource if needed
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            currentDraft.media.append(mediaItem)
            currentDraft.updatedAt = Date()
            return mediaItem
        } catch {
            print("Failed to copy media: \(error)")
            return nil
        }
    }
    
    func removeMedia(_ media: MediaItem) {
        deleteMediaFile(media)
        currentDraft.media.removeAll { $0.id == media.id }
        currentDraft.updatedAt = Date()
    }
    
    private func deleteMediaFile(_ media: MediaItem) {
        guard let folderURL = mediaFolderURL else { return }
        let fileURL = folderURL.appendingPathComponent("\(media.id.uuidString).\(media.fileExtension)")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func mediaURL(for media: MediaItem) -> URL? {
        guard let folderURL = mediaFolderURL else { return nil }
        return folderURL.appendingPathComponent("\(media.id.uuidString).\(media.fileExtension)")
    }
    
    func loadImage(for media: MediaItem) -> NSImage? {
        guard !media.isVideo, let url = mediaURL(for: media) else { return nil }
        return NSImage(contentsOf: url)
    }
    
    // MARK: - Post Actions
    
    func copyContentToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentDraft.content, forType: .string)
    }
    
    func openMediaInFinder(_ media: MediaItem) {
        guard let url = mediaURL(for: media) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
