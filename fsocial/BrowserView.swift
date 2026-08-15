//
//  BrowserView.swift
//  fsocial
//
//  Created by Mason Earl on 1/11/26.
//

import SwiftUI

struct BrowserView: View {
    let platform: Platform
    @ObservedObject var coordinator: WebViewCoordinator
    
    @State private var urlText: String = ""
    @StateObject private var automationStore = LinkedInAutomationStore()
    @State private var showAutomationPanel = true
    @State private var newInterest = ""
    @State private var newKeyword = ""
    @State private var showingAddInterest = false
    @State private var showingAddKeyword = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Browser Controls
            browserControls
            
            // LinkedIn Automation Panel (only for LinkedIn)
            if platform == .linkedin {
                Divider()
                    .background(Color.appBorder)
                
                automationPanel
            }
            
            Divider()
                .background(Color.appBorder)
            
            // WebView
            ZStack {
                WebView(url: platform.url, coordinator: coordinator)
                    .background(Color.appSecondary)
                
                if let loadError = coordinator.loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.orange)
                        Text("Page failed to load")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(Color.appText)
                        Text(loadError)
                            .font(AppTypography.sectionLabel)
                            .foregroundStyle(Color.appTextMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button {
                            coordinator.clearLoadError()
                            coordinator.reload()
                        } label: {
                            Text("Try Again")
                                .font(AppTypography.bodyMedium)
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.appAccent)
                                .cornerRadius(AppDimensions.borderRadius)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground.opacity(0.92))
                }
            }
        }
        .background(Color.appBackground)
        .onChange(of: coordinator.currentURL) { newURL in
            urlText = newURL?.absoluteString ?? platform.url.absoluteString
        }
        .onAppear {
            urlText = platform.url.absoluteString
        }
    }
    
    private var browserControls: some View {
        HStack(spacing: 8) {
            // Navigation Buttons
            HStack(spacing: 4) {
                BrowserButton(
                    icon: "chevron.left",
                    isEnabled: coordinator.canGoBack
                ) {
                    coordinator.goBack()
                }
                
                BrowserButton(
                    icon: "chevron.right",
                    isEnabled: coordinator.canGoForward
                ) {
                    coordinator.goForward()
                }
                
                BrowserButton(
                    icon: coordinator.isLoading ? "xmark" : "arrow.clockwise",
                    isEnabled: true
                ) {
                    coordinator.reload()
                }
                
                BrowserButton(
                    icon: "house",
                    isEnabled: true
                ) {
                    coordinator.goHome(url: platform.url)
                }
            }
            
            // URL Bar
            HStack {
                if coordinator.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appTextMuted)
                }
                
                TextField("URL", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.appText)
                    .onSubmit {
                        var urlString = urlText
                        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                            urlString = "https://" + urlString
                        }
                        coordinator.loadURL(urlString)
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.appSecondary)
            .cornerRadius(AppDimensions.borderRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.borderRadius)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
        }
        .padding(AppDimensions.padding)
        .background(Color.appBackground)
    }
    
    // MARK: - Automation Panel
    private var automationPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation {
                        showAutomationPanel.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showAutomationPanel ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                        Text("LinkedIn Automation")
                            .font(AppTypography.bodyMedium)
                    }
                    .foregroundStyle(Color.appText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if coordinator.automationRunning || automationStore.isRunning {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Running...")
                            .font(AppTypography.sectionLabel)
                            .foregroundStyle(Color.appAccent)
                    }
                } else {
                    Toggle("", isOn: $automationStore.isEnabled)
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)
                        .onChange(of: automationStore.isEnabled) { enabled in
                            automationStore.saveSettings()
                        }
                }
            }
            .padding(AppDimensions.padding)
            .background(Color.appSecondary.opacity(0.5))
            
            // Panel Content
            if showAutomationPanel {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Stats
                        if automationStore.connectionsMade > 0 {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(automationStore.connectionsMade)")
                                        .font(AppTypography.title)
                                        .foregroundStyle(Color.appAccent)
                                    Text("Connections Made")
                                        .font(AppTypography.sectionLabel)
                                        .foregroundStyle(Color.appTextMuted)
                                }
                                
                                Spacer()
                                
                                if let lastRun = automationStore.lastRunDate {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Last Run")
                                            .font(AppTypography.sectionLabel)
                                            .foregroundStyle(Color.appTextMuted)
                                        Text(lastRun, style: .relative)
                                            .font(AppTypography.body)
                                            .foregroundStyle(Color.appText)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.appSecondary.opacity(0.3))
                            .cornerRadius(AppDimensions.borderRadius)
                        }
                        
                        // Interests Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("INTERESTS")
                                    .font(AppTypography.sectionLabel)
                                    .foregroundStyle(Color.appTextMuted)
                                
                                Spacer()
                                
                                Button {
                                    showingAddInterest = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.appAccent)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if automationStore.interests.isEmpty {
                                Text("No interests added")
                                    .font(AppTypography.body)
                                    .foregroundStyle(Color.appTextMuted)
                                    .padding(.vertical, 4)
                            } else {
                                WrappingHStack(items: automationStore.interests, spacing: 6) { interest in
                                    InterestTag(text: interest) {
                                        automationStore.removeInterest(interest)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.appSecondary.opacity(0.3))
                        .cornerRadius(AppDimensions.borderRadius)
                        
                        // Keywords Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("KEYWORDS")
                                    .font(AppTypography.sectionLabel)
                                    .foregroundStyle(Color.appTextMuted)
                                
                                Spacer()
                                
                                Button {
                                    showingAddKeyword = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.appAccent)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if automationStore.keywords.isEmpty {
                                Text("No keywords added")
                                    .font(AppTypography.body)
                                    .foregroundStyle(Color.appTextMuted)
                                    .padding(.vertical, 4)
                            } else {
                                WrappingHStack(items: automationStore.keywords, spacing: 6) { keyword in
                                    InterestTag(text: keyword) {
                                        automationStore.removeKeyword(keyword)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.appSecondary.opacity(0.3))
                        .cornerRadius(AppDimensions.borderRadius)
                        
                        // Settings
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SETTINGS")
                                .font(AppTypography.sectionLabel)
                                .foregroundStyle(Color.appTextMuted)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Max Connections per Session")
                                        .font(AppTypography.body)
                                        .foregroundStyle(Color.appText)
                                    Spacer()
                                    TextField("", value: $automationStore.maxConnectionsPerSession, format: .number)
                                        .textFieldStyle(.plain)
                                        .font(AppTypography.body)
                                        .foregroundStyle(Color.appText)
                                        .frame(width: 60)
                                        .padding(6)
                                        .background(Color.appSecondary)
                                        .cornerRadius(AppDimensions.borderRadius)
                                        .onChange(of: automationStore.maxConnectionsPerSession) { _ in
                                            automationStore.saveSettings()
                                        }
                                }
                                
                                HStack {
                                    Text("Delay Between Actions (seconds)")
                                        .font(AppTypography.body)
                                        .foregroundStyle(Color.appText)
                                    Spacer()
                                    TextField("", value: $automationStore.delayBetweenActions, format: .number)
                                        .textFieldStyle(.plain)
                                        .font(AppTypography.body)
                                        .foregroundStyle(Color.appText)
                                        .frame(width: 60)
                                        .padding(6)
                                        .background(Color.appSecondary)
                                        .cornerRadius(AppDimensions.borderRadius)
                                        .onChange(of: automationStore.delayBetweenActions) { _ in
                                            automationStore.saveSettings()
                                        }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.appSecondary.opacity(0.3))
                        .cornerRadius(AppDimensions.borderRadius)
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            if coordinator.automationRunning || automationStore.isRunning {
                                Button {
                                    coordinator.stopLinkedInAutomation()
                                    automationStore.isRunning = false
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 12))
                                        Text("Stop")
                                            .font(AppTypography.bodyMedium)
                                    }
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.red)
                                    .cornerRadius(AppDimensions.borderRadius)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    startAutomation()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 12))
                                        Text("Start Automation")
                                            .font(AppTypography.bodyMedium)
                                    }
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(automationStore.isEnabled ? Color.appAccent : Color.appTextMuted.opacity(0.5))
                                    .cornerRadius(AppDimensions.borderRadius)
                                }
                                .buttonStyle(.plain)
                                .disabled(!automationStore.isEnabled)
                            }
                            
                            Button {
                                automationStore.resetStats()
                            } label: {
                                Text("Reset Stats")
                                    .font(AppTypography.body)
                                    .foregroundStyle(Color.appTextMuted)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .background(Color.appSecondary)
                                    .cornerRadius(AppDimensions.borderRadius)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if let error = automationStore.errorMessage {
                            Text(error)
                                .font(AppTypography.sectionLabel)
                                .foregroundStyle(Color.red)
                                .padding(.top, 4)
                        }
                    }
                    .padding(AppDimensions.padding)
                }
                .frame(maxHeight: 300)
            }
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showingAddInterest) {
            AddItemSheet(
                title: "Add Interest",
                placeholder: "e.g., Software Engineering",
                onAdd: { interest in
                    automationStore.addInterest(interest)
                    showingAddInterest = false
                }
            )
        }
        .sheet(isPresented: $showingAddKeyword) {
            AddItemSheet(
                title: "Add Keyword",
                placeholder: "e.g., React, Python, AI",
                onAdd: { keyword in
                    automationStore.addKeyword(keyword)
                    showingAddKeyword = false
                }
            )
        }
    }
    
    private func startAutomation() {
        guard !automationStore.isRunning && !coordinator.automationRunning else { return }
        
        automationStore.isRunning = true
        automationStore.errorMessage = nil
        
        coordinator.startLinkedInAutomation(
            interests: automationStore.interests,
            keywords: automationStore.keywords,
            maxConnections: automationStore.maxConnectionsPerSession,
            delay: automationStore.delayBetweenActions
        ) { [weak automationStore] count, error in
            DispatchQueue.main.async {
                automationStore?.isRunning = false
                if let error = error {
                    automationStore?.errorMessage = error
                } else {
                    automationStore?.connectionsMade += count
                    automationStore?.lastRunDate = Date()
                    automationStore?.saveSettings()
                }
            }
        }
    }
}

// MARK: - Interest Tag
struct InterestTag: View {
    let text: String
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(AppTypography.body)
                .foregroundStyle(Color.appText)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextMuted)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.appSecondary)
        .cornerRadius(AppDimensions.borderRadius)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Wrapping HStack (macOS 12.0 compatible)
struct WrappingHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let content: (Item) -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(wrapItems(), id: \.id) { row in
                HStack(spacing: spacing) {
                    ForEach(row.items, id: \.self) { item in
                        content(item)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private func wrapItems() -> [WrappingRow<Item>] {
        var rows: [WrappingRow<Item>] = []
        var currentRow = WrappingRow<Item>(id: 0, items: [])
        var currentWidth: CGFloat = 0
        let maxWidth: CGFloat = 250 // Approximate width for the panel
        
        for item in items {
            // Estimate item width (rough approximation)
            let itemWidth: CGFloat = 80 // Approximate tag width
            
            if currentWidth + itemWidth > maxWidth && !currentRow.items.isEmpty {
                rows.append(currentRow)
                currentRow = WrappingRow<Item>(id: rows.count, items: [])
                currentWidth = 0
            }
            
            currentRow.items.append(item)
            currentWidth += itemWidth + spacing
        }
        
        if !currentRow.items.isEmpty {
            rows.append(currentRow)
        }
        
        return rows.isEmpty ? [WrappingRow<Item>(id: 0, items: [])] : rows
    }
    
    private struct WrappingRow<RowItem: Hashable>: Identifiable {
        let id: Int
        var items: [RowItem]
    }
}

// MARK: - Add Item Sheet
struct AddItemSheet: View {
    let title: String
    let placeholder: String
    let onAdd: (String) -> Void
    
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(AppTypography.title)
                .foregroundStyle(Color.appText)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AppTypography.body)
                .foregroundStyle(Color.appText)
                .padding(12)
                .background(Color.appSecondary)
                .cornerRadius(AppDimensions.borderRadius)
                .onSubmit {
                    if !text.isEmpty {
                        onAdd(text)
                    }
                }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appTextMuted)
                
                Spacer()
                
                Button("Add") {
                    if !text.isEmpty {
                        onAdd(text)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
                .disabled(text.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 350)
        .background(Color.appBackground)
    }
}

// MARK: - Browser Button
struct BrowserButton: View {
    let icon: String
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isEnabled ? Color.appText : Color.appTextMuted.opacity(0.5))
                .frame(width: 28, height: 28)
                .background(
                    isHovered && isEnabled ?
                    Color.appSecondary :
                        Color.clear
                )
                .cornerRadius(AppDimensions.borderRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDimensions.borderRadius)
                        .stroke(
                            isHovered && isEnabled ? Color.appBorderHover : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Toast View
struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(AppTypography.bodyMedium)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.appSuccess)
            .cornerRadius(AppDimensions.borderRadius)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Toast Modifier
struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let duration: Double
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                VStack {
                    Spacer()
                    ToastView(message: message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 40)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isShowing)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        withAnimation {
                            isShowing = false
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, duration: Double = 1.5) -> some View {
        modifier(ToastModifier(isShowing: isShowing, message: message, duration: duration))
    }
}
