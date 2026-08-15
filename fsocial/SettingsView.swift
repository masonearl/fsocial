//
//  SettingsView.swift
//  fsocial
//
//  Created by Mason Earl on 1/12/26.
//

import SwiftUI
import Combine
import AppKit

struct SettingsView: View {
    @ObservedObject var aiService: AIService
    @ObservedObject var updateChecker: UpdateChecker
    
    @State private var showingAPIKeySheet = false
    @State private var apiKeyInput = ""
    @State private var selectedProviderForSetup: AIProvider = .claude
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("Settings")
                    .font(AppTypography.title)
                    .foregroundStyle(Color.appText)
                    .padding(.bottom, 8)
                
                // Updates Section
                updatesSection
                
                Divider()
                    .background(Color.appBorder)
                
                // AI Provider Section
                aiProviderSection
                
                Divider()
                    .background(Color.appBorder)
                
                // About Section
                aboutSection
            }
            .padding(AppDimensions.padding * 2)
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showingAPIKeySheet) {
            apiKeySheet
        }
    }
    
    // MARK: - Updates Section
    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UPDATES")
                .font(AppTypography.sectionLabel)
                .foregroundStyle(Color.appTextMuted)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Version")
                            .font(AppTypography.body)
                            .foregroundStyle(Color.appText)
                        Text(versionLabel)
                            .font(AppTypography.sectionLabel)
                            .foregroundStyle(Color.appTextMuted)
                    }
                    
                    Spacer()
                    
                    if updateChecker.isAppStoreDistribution {
                        Text("Mac App Store")
                            .font(AppTypography.sectionLabel)
                            .foregroundStyle(Color.appTextMuted)
                    } else if updateChecker.updateAvailable {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("New Version Available")
                                .font(AppTypography.body)
                                .foregroundStyle(Color.appSuccess)
                            Text("v\(updateChecker.latestVersion)")
                                .font(AppTypography.sectionLabel)
                                .foregroundStyle(Color.appSuccess)
                        }
                    }
                }
                
                if updateChecker.isAppStoreDistribution {
                    Text("Updates are delivered through the Mac App Store. This build does not download or install DMG updates.")
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appTextMuted)
                    
                    Button {
                        updateChecker.openAppStorePage()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bag.fill")
                                .font(.system(size: 12))
                            Text("Open in App Store")
                                .font(AppTypography.body)
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.appAccent)
                        .cornerRadius(AppDimensions.borderRadius)
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 12) {
                        Button {
                            updateChecker.checkForUpdates()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                                Text("Check for Updates")
                                    .font(AppTypography.body)
                            }
                            .foregroundStyle(Color.appAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.appSecondary)
                            .cornerRadius(AppDimensions.borderRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppDimensions.borderRadius)
                                    .stroke(Color.appBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        if updateChecker.updateAvailable {
                            if updateChecker.isDownloading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("\(Int(updateChecker.downloadProgress * 100))%")
                                        .font(AppTypography.body)
                                        .foregroundStyle(Color.appAccent)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            } else {
                                Button {
                                    updateChecker.downloadAndInstall()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.system(size: 12))
                                        Text("Download & Install")
                                            .font(AppTypography.body)
                                    }
                                    .foregroundStyle(Color.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.appAccent)
                                    .cornerRadius(AppDimensions.borderRadius)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.appSecondary.opacity(0.3))
            .cornerRadius(AppDimensions.borderRadius)
        }
    }
    
    private var versionLabel: String {
        let marketing = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(marketing) (\(build))"
    }
    
    // MARK: - AI Provider Section
    private var aiProviderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI PROVIDER")
                .font(AppTypography.sectionLabel)
                .foregroundStyle(Color.appTextMuted)
            
            VStack(alignment: .leading, spacing: 12) {
                // Current provider
                HStack {
                    Image(systemName: aiService.selectedProvider.iconName)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appAccent)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(aiService.selectedProvider.rawValue)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(Color.appText)
                        Text(aiService.hasAPIKey ? "API key configured" : "No API key")
                            .font(AppTypography.sectionLabel)
                            .foregroundStyle(aiService.hasAPIKey ? Color.appSuccess : Color.appTextMuted)
                    }
                    
                    Spacer()
                    
                    Button {
                        selectedProviderForSetup = aiService.selectedProvider
                        showingAPIKeySheet = true
                    } label: {
                        Text(aiService.hasAPIKey ? "Change" : "Setup")
                            .font(AppTypography.body)
                            .foregroundStyle(Color.appAccent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.appSecondary)
                .cornerRadius(AppDimensions.borderRadius)
                
                // All providers
                Text("Available Providers")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
                    .padding(.top, 8)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                    ForEach(AIProvider.allCases) { provider in
                        ProviderCard(
                            provider: provider,
                            isSelected: aiService.selectedProvider == provider,
                            hasKey: aiService.hasKey(for: provider)
                        ) {
                            aiService.setProvider(provider)
                            if !aiService.hasKey(for: provider) {
                                selectedProviderForSetup = provider
                                showingAPIKeySheet = true
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.appSecondary.opacity(0.3))
            .cornerRadius(AppDimensions.borderRadius)
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ABOUT")
                .font(AppTypography.sectionLabel)
                .foregroundStyle(Color.appTextMuted)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("fsocial")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(Color.appText)
                    Spacer()
                }
                
                Text("Manage all your social media platforms in one place.")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.appTextMuted)
                
                HStack(spacing: 16) {
                    Button {
                        if let url = URL(string: "mailto:hi@masonearl.com") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 11))
                            Text("Support")
                        }
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appAccent)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        if let url = URL(string: "https://github.com/masonearl/fsocial") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 11))
                            Text("GitHub")
                        }
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appAccent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                
                Text("Made by Mason Earl")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
            }
            .padding(16)
            .background(Color.appSecondary.opacity(0.3))
            .cornerRadius(AppDimensions.borderRadius)
        }
    }
    
    // MARK: - API Key Sheet
    private var apiKeySheet: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Setup \(selectedProviderForSetup.rawValue)")
                    .font(AppTypography.title)
                    .foregroundStyle(Color.appText)
                Spacer()
                Button {
                    showingAPIKeySheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.appTextMuted)
                }
                .buttonStyle(.plain)
            }
            
            // Provider selection
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AIProvider.allCases) { provider in
                        Button {
                            selectedProviderForSetup = provider
                            apiKeyInput = aiService.hasKey(for: provider) ? "********" : ""
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: provider.iconName)
                                    .font(.system(size: 12))
                                Text(provider.rawValue.components(separatedBy: " ").first ?? "")
                                    .font(AppTypography.body)
                                if aiService.hasKey(for: provider) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.appSuccess)
                                }
                            }
                            .foregroundStyle(selectedProviderForSetup == provider ? Color.white : Color.appTextMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedProviderForSetup == provider ? Color.appAccent : Color.appSecondary)
                            .cornerRadius(AppDimensions.borderRadius)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // API Key input
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedProviderForSetup.keyLabel)
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
                
                HStack {
                    TextField(selectedProviderForSetup.keyPlaceholder, text: $apiKeyInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color.appText)
                        .padding(12)
                        .background(Color.appSecondary)
                        .cornerRadius(AppDimensions.borderRadius)
                    
                    if aiService.hasKey(for: selectedProviderForSetup) {
                        Button {
                            let previousProvider = aiService.selectedProvider
                            aiService.setProvider(selectedProviderForSetup)
                            aiService.clearAPIKey()
                            aiService.setProvider(previousProvider)
                            apiKeyInput = ""
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.red)
                                .padding(12)
                                .background(Color.appSecondary)
                                .cornerRadius(AppDimensions.borderRadius)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Get API key link
                Button {
                    if let url = URL(string: selectedProviderForSetup.setupURL) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                        Text("Get API key from \(selectedProviderForSetup.rawValue.components(separatedBy: " ").first ?? "")")
                    }
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Save button
            Button {
                if !apiKeyInput.isEmpty && apiKeyInput != "********" {
                    let previousProvider = aiService.selectedProvider
                    aiService.setProvider(selectedProviderForSetup)
                    let saved = aiService.saveAPIKey(apiKeyInput)
                    aiService.setProvider(previousProvider)
                    if saved {
                        showingAPIKeySheet = false
                    }
                } else {
                    showingAPIKeySheet = false
                }
            } label: {
                Text("Save")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appAccent)
                    .cornerRadius(AppDimensions.borderRadius)
            }
            .buttonStyle(.plain)
            
            if let error = aiService.lastError {
                Text(error)
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(width: 450, height: 420)
        .background(Color.appBackground)
        .onAppear {
            aiService.lastError = nil
        }
    }
}

// MARK: - Provider Card
struct ProviderCard: View {
    let provider: AIProvider
    let isSelected: Bool
    let hasKey: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Color.appAccent : Color.appTextMuted)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.rawValue.components(separatedBy: " ").first ?? "")
                        .font(AppTypography.body)
                        .foregroundStyle(Color.appText)
                    
                    if hasKey {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8))
                            Text("Configured")
                        }
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appSuccess)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.appAccent)
                }
            }
            .padding(12)
            .background(isSelected ? Color.appAccent.opacity(0.1) : Color.appSecondary)
            .cornerRadius(AppDimensions.borderRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.borderRadius)
                    .stroke(isSelected ? Color.appAccent : Color.appBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
