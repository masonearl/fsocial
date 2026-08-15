//
//  SidebarView.swift
//  fsocial
//
//  Created by Mason Earl on 1/11/26.
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedPlatform: Platform
    @ObservedObject var replyStore: QuickReplyStore
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject var draftStore: DraftStore
    @ObservedObject var historyStore: HistoryStore
    @ObservedObject var aiService: AIService
    @Binding var viewMode: ViewMode
    var currentCoordinator: WebViewCoordinator?
    var onReplySelected: (String) -> Void
    
    @State private var showingAddReply = false
    @State private var newReplyText = ""
    @State private var editingReply: QuickReply?
    @State private var editText = ""
    @State private var showingAPIKeySheet = false
    
    // Collapsible sections
    @AppStorage("sidebar.smartRepliesCollapsed") private var smartRepliesCollapsed = false
    @AppStorage("sidebar.quickRepliesCollapsed") private var quickRepliesCollapsed = false
    @AppStorage("sidebar.platformsCollapsed") private var platformsCollapsed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo
            logoSection
            
            Divider()
                .background(Color.appBorder)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // View Mode Toggle
                    viewModeSection
                    
                    Divider()
                        .background(Color.appBorder)
                    
                    // Content based on view mode
                    switch viewMode {
                    case .browser:
                        platformsSection
                        
                        Divider()
                            .background(Color.appBorder)
                        
                        aiRepliesSection
                        
                        Divider()
                            .background(Color.appBorder)
                        
                        quickRepliesSection
                        
                    case .scheduler:
                        upcomingPostsSection
                        
                    case .composer:
                        draftsPreviewSection
                        
                    case .insights:
                        insightsPreviewSection
                        
                    case .settings:
                        EmptyView()
                    }
                }
                .padding(.vertical, AppDimensions.padding)
            }
            
            Divider()
                .background(Color.appBorder)
            
            // Bottom button based on view mode
            switch viewMode {
            case .browser:
                addReplyButton
            case .scheduler:
                schedulerStatsSection
            case .composer:
                composerStatsSection
            case .insights:
                insightsStatsSection
            case .settings:
                settingsInfoSection
            }
        }
        .frame(width: AppDimensions.sidebarWidth)
        .background(Color.appBackground)
        .sheet(isPresented: $showingAddReply) {
            addReplySheet
        }
        .sheet(item: $editingReply) { reply in
            editReplySheet(reply: reply)
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            apiKeySheet
        }
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .cornerRadius(6)
            
            Text("fsocial")
                .font(AppTypography.title)
                .foregroundStyle(Color.appText)
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewMode = .settings
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(viewMode == .settings ? Color.appAccent : Color.appTextMuted)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(AppDimensions.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - View Mode Section
    private var viewModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VIEW")
                .font(AppTypography.sectionLabel)
                .foregroundStyle(Color.appTextMuted)
                .padding(.horizontal, AppDimensions.padding)
            
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ViewModeButton(
                        title: "Platforms",
                        icon: "globe",
                        isSelected: viewMode == .browser
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = .browser
                        }
                    }
                    
                    ViewModeButton(
                        title: "Calendar",
                        icon: "calendar",
                        isSelected: viewMode == .scheduler
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = .scheduler
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    ViewModeButton(
                        title: "Create",
                        icon: "square.and.pencil",
                        isSelected: viewMode == .composer
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = .composer
                        }
                    }
                    
                    ViewModeButton(
                        title: "Insights",
                        icon: "chart.bar.fill",
                        isSelected: viewMode == .insights
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = .insights
                        }
                    }
                }
            }
            .padding(.horizontal, AppDimensions.padding)
        }
    }
    
    // MARK: - Platforms Section
    private var platformsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsible Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    platformsCollapsed.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: platformsCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appTextMuted)
                        .frame(width: 12)
                    
                    Text("PLATFORMS")
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appTextMuted)
                    
                    Spacer()
                    
                    // Show current platform when collapsed
                    if platformsCollapsed {
                        Image(systemName: selectedPlatform.iconName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppDimensions.padding)

            if !platformsCollapsed {
                ForEach(Platform.allCases) { platform in
                    PlatformButton(
                        platform: platform,
                        isSelected: selectedPlatform == platform
                    ) {
                        selectedPlatform = platform
                    }
                }
            }
        }
    }
    
    // MARK: - AI Replies Section
    private var aiRepliesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsible Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    smartRepliesCollapsed.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: smartRepliesCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appTextMuted)
                        .frame(width: 12)
                    
                    Text("SMART REPLIES")
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appTextMuted)

                    Spacer()

                    if !smartRepliesCollapsed {
                        if aiService.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 16, height: 16)
                        } else {
                            Button {
                                generateSmartReplies()
                            } label: {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.appAccent)
                            }
                            .buttonStyle(.plain)
                            .help("Generate AI replies based on current content")
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppDimensions.padding)
            
            if !smartRepliesCollapsed {
                if !aiService.hasAPIKey {
                    // No API key configured
                    Button {
                        showingAPIKeySheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 11))
                            Text("Setup AI Provider")
                                .font(AppTypography.body)
                        }
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, AppDimensions.padding)
                    }
                    .buttonStyle(.plain)
                } else if aiService.suggestedReplies.isEmpty {
                    // No suggestions yet
                    VStack(spacing: 4) {
                        Text("Click sparkles to analyze")
                            .font(AppTypography.body)
                            .foregroundStyle(Color.appTextMuted)
                        Text("current page content")
                            .font(AppTypography.sectionLabel)
                            .foregroundStyle(Color.appTextMuted.opacity(0.7))
                    }
                    .padding(.horizontal, AppDimensions.padding)
                } else {
                    // Show AI suggestions
                    ForEach(aiService.suggestedReplies, id: \.self) { reply in
                        AIReplyRow(text: reply) {
                            onReplySelected(reply)
                        }
                    }
                }
            }
            
            if let error = aiService.lastError {
                Text(error)
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, AppDimensions.padding)
            }
        }
    }
    
    private func generateSmartReplies() {
        currentCoordinator?.extractPageContent { content in
            if !content.isEmpty {
                aiService.generateReplies(for: content, platform: selectedPlatform)
            }
        }
    }
    
    // MARK: - API Key Sheet
    @State private var apiKeyInput = ""

    private var apiKeySheet: some View {
        VStack(spacing: 16) {
            Text("AI Provider Setup")
                .font(AppTypography.title)
                .foregroundStyle(Color.appText)

            Text("Choose your AI provider and enter your API key.")
                .font(AppTypography.body)
                .foregroundStyle(Color.appTextMuted)
                .multilineTextAlignment(.center)
            
            // Provider Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("PROVIDER")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
                
                ForEach(AIProvider.allCases) { provider in
                    ProviderButton(
                        provider: provider,
                        isSelected: aiService.selectedProvider == provider,
                        hasKey: aiService.hasKey(for: provider)
                    ) {
                        aiService.setProvider(provider)
                        apiKeyInput = aiService.getAPIKey() ?? ""
                    }
                }
            }
            .frame(width: 340)
            
            Divider()
            
            // API Key Input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(aiService.selectedProvider.keyLabel.uppercased())
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appTextMuted)
                    
                    Spacer()
                    
                    Link("Get Key", destination: URL(string: aiService.selectedProvider.setupURL)!)
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appAccent)
                }
                
                if aiService.selectedProvider == .ollama {
                    TextField(aiService.selectedProvider.keyPlaceholder, text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField(aiService.selectedProvider.keyPlaceholder, text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .frame(width: 340)

            HStack {
                Button("Cancel") {
                    apiKeyInput = ""
                    showingAPIKeySheet = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appTextMuted)

                Spacer()

                Button("Save") {
                    if !apiKeyInput.isEmpty {
                        if aiService.saveAPIKey(apiKeyInput) {
                            apiKeyInput = ""
                            showingAPIKeySheet = false
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
            }
            .frame(width: 340)

            if let error = aiService.lastError {
                Text(error)
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.red)
                    .frame(width: 340, alignment: .leading)
            }

            if aiService.hasAPIKey {
                Divider()

                Button("Remove API Key for \(aiService.selectedProvider.rawValue)") {
                    aiService.clearAPIKey()
                    apiKeyInput = ""
                }
                .foregroundStyle(Color.red)
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Color.appBackground)
    }
    
    // MARK: - Quick Replies Section
    private var quickRepliesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Collapsible Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    quickRepliesCollapsed.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: quickRepliesCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appTextMuted)
                        .frame(width: 12)
                    
                    Text("QUICK REPLIES")
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appTextMuted)
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppDimensions.padding)

            if !quickRepliesCollapsed {
                ForEach(ReplyCategory.allCases) { category in
                    ReplyCategorySection(
                        category: category,
                        replies: replyStore.replies(for: category),
                        onReplySelected: onReplySelected,
                        onEdit: { reply in
                            editText = reply.text
                            editingReply = reply
                        },
                        onDelete: { reply in
                            replyStore.deleteReply(reply)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Upcoming Posts Section
    private var upcomingPostsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UPCOMING")
                .font(AppTypography.sectionLabel)
                .foregroundStyle(Color.appTextMuted)
                .padding(.horizontal, AppDimensions.padding)
            
            if scheduleStore.upcomingPosts.isEmpty {
                Text("No upcoming posts")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.appTextMuted)
                    .padding(.horizontal, AppDimensions.padding)
            } else {
                ForEach(scheduleStore.upcomingPosts.prefix(5)) { post in
                    UpcomingPostRow(post: post)
                }
                
                if scheduleStore.upcomingPosts.count > 5 {
                    Text("+\(scheduleStore.upcomingPosts.count - 5) more")
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appTextMuted)
                        .padding(.horizontal, AppDimensions.padding)
                }
            }
            
            // Today's posts
            if !scheduleStore.todaysPosts.isEmpty {
                Divider()
                    .background(Color.appBorder)
                    .padding(.vertical, 8)
                
                Text("TODAY")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appAccent)
                    .padding(.horizontal, AppDimensions.padding)
                
                ForEach(scheduleStore.todaysPosts) { post in
                    UpcomingPostRow(post: post, isToday: true)
                }
            }
        }
    }
    
    // MARK: - Add Reply Button
    private var addReplyButton: some View {
        Button {
            showingAddReply = true
        } label: {
            HStack {
                Image(systemName: "plus")
                Text("Add reply")
            }
            .font(AppTypography.bodyMedium)
            .foregroundStyle(Color.appAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppDimensions.padding)
        }
        .buttonStyle(.plain)
        .background(Color.appBackground)
    }
    
    // MARK: - Scheduler Stats Section
    private var schedulerStatsSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(scheduleStore.upcomingPosts.count)")
                    .font(AppTypography.title)
                    .foregroundStyle(Color.appText)
                Text("Scheduled")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(scheduleStore.todaysPosts.count)")
                    .font(AppTypography.title)
                    .foregroundStyle(Color.appAccent)
                Text("Today")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
            }
        }
        .padding(AppDimensions.padding)
        .background(Color.appBackground)
    }
    
    // MARK: - Drafts Preview Section
    private var draftsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SAVED DRAFTS")
                .font(AppTypography.sectionLabel)
                .foregroundStyle(Color.appTextMuted)
                .padding(.horizontal, AppDimensions.padding)
            
            if draftStore.drafts.isEmpty {
                Text("No saved drafts")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.appTextMuted)
                    .padding(.horizontal, AppDimensions.padding)
            } else {
                ForEach(draftStore.drafts.prefix(5)) { draft in
                    SidebarDraftRow(draft: draft) {
                        draftStore.loadDraft(draft)
                    }
                }
                
                if draftStore.drafts.count > 5 {
                    Text("+\(draftStore.drafts.count - 5) more")
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appTextMuted)
                        .padding(.horizontal, AppDimensions.padding)
                }
            }
        }
    }
    
    // MARK: - Composer Stats Section
    private var composerStatsSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(draftStore.drafts.count)")
                    .font(AppTypography.title)
                    .foregroundStyle(Color.appText)
                Text("Drafts")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(draftStore.currentDraft.media.count)")
                    .font(AppTypography.title)
                    .foregroundStyle(Color.appAccent)
                Text("Media")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
            }
        }
        .padding(AppDimensions.padding)
        .background(Color.appBackground)
    }
    
    // MARK: - Insights Preview Section
    private var insightsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK STATS")
                .font(AppTypography.sectionLabel)
                .foregroundStyle(Color.appTextMuted)
                .padding(.horizontal, AppDimensions.padding)
            
            VStack(spacing: 8) {
                InsightStatRow(label: "Total Posts", value: "\(historyStore.totalPosts)", icon: "doc.text.fill")
                InsightStatRow(label: "This Week", value: "\(historyStore.postsThisWeek)", icon: "calendar")
                InsightStatRow(label: "This Month", value: "\(historyStore.postsThisMonth)", icon: "calendar.badge.clock")
                
                if let bestDay = historyStore.bestPerformingDay {
                    InsightStatRow(label: "Best Day", value: bestDay, icon: "star.fill")
                }
            }
            .padding(.horizontal, AppDimensions.padding)
            
            if !historyStore.platformBreakdown.isEmpty {
                Divider()
                    .background(Color.appBorder)
                    .padding(.vertical, 4)
                
                Text("TOP PLATFORMS")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
                    .padding(.horizontal, AppDimensions.padding)
                
                VStack(spacing: 4) {
                    ForEach(historyStore.platformBreakdown.prefix(3), id: \.0) { platform, count in
                        HStack {
                            Image(systemName: platform.iconName)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.appAccent)
                            Text(platform.rawValue)
                                .font(AppTypography.body)
                                .foregroundStyle(Color.appText)
                            Spacer()
                            Text("\(count)")
                                .font(AppTypography.bodyMedium)
                                .foregroundStyle(Color.appAccent)
                        }
                        .padding(.horizontal, AppDimensions.padding)
                    }
                }
            }
        }
    }
    
    // MARK: - Insights Stats Section
    private var insightsStatsSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(historyStore.totalPosts)")
                    .font(AppTypography.title)
                    .foregroundStyle(Color.appText)
                Text("Total Posts")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", historyStore.averagePostsPerWeek))
                    .font(AppTypography.title)
                    .foregroundStyle(Color.appAccent)
                Text("Avg/Week")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
            }
        }
        .padding(AppDimensions.padding)
        .background(Color.appBackground)
    }
    
    // MARK: - Settings Info Section
    private var settingsInfoSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(aiService.selectedProvider.rawValue.components(separatedBy: " ").first ?? "None")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(Color.appText)
                Text("AI Provider")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(Color.appAccent)
                Text("Version")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
            }
        }
        .padding(AppDimensions.padding)
        .background(Color.appBackground)
    }

    // MARK: - Add Reply Sheet
    private var addReplySheet: some View {
        VStack(spacing: 16) {
            Text("Add Quick Reply")
                .font(AppTypography.title)
                .foregroundStyle(Color.appText)
            
            TextEditor(text: $newReplyText)
                .font(AppTypography.body)
                .foregroundColor(Color.appText)
                .frame(height: 80)
                .padding(10)
                .background(Color.appSecondary)
                .cornerRadius(AppDimensions.borderRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDimensions.borderRadius)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
            
            HStack {
                Button("Cancel") {
                    newReplyText = ""
                    showingAddReply = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appTextMuted)
                
                Spacer()
                
                Button("Add") {
                    if !newReplyText.isEmpty {
                        replyStore.addReply(newReplyText)
                        newReplyText = ""
                        showingAddReply = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
                .disabled(newReplyText.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 350)
        .background(Color.appBackground)
    }
    
    // MARK: - Edit Reply Sheet
    private func editReplySheet(reply: QuickReply) -> some View {
        VStack(spacing: 16) {
            Text("Edit Reply")
                .font(AppTypography.title)
                .foregroundStyle(Color.appText)
            
            TextEditor(text: $editText)
                .font(AppTypography.body)
                .foregroundColor(Color.appText)
                .frame(height: 80)
                .padding(10)
                .background(Color.appSecondary)
                .cornerRadius(AppDimensions.borderRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDimensions.borderRadius)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
            
            HStack {
                Button("Cancel") {
                    editingReply = nil
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appTextMuted)
                
                Spacer()
                
                Button("Save") {
                    if !editText.isEmpty {
                        replyStore.updateReply(reply, newText: editText)
                        editingReply = nil
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
                .disabled(editText.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 350)
        .background(Color.appBackground)
    }
}

// MARK: - View Mode Button
struct ViewModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(AppTypography.body)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.appTextMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.appAccent : Color.appSecondary)
            .cornerRadius(AppDimensions.borderRadius)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Upcoming Post Row
struct UpcomingPostRow: View {
    let post: ScheduledPost
    var isToday: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(post.formattedDate)
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(isToday ? Color.appAccent : Color.appTextMuted)
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(post.platforms.prefix(3)) { platform in
                        Image(systemName: platform.iconName)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.appTextMuted)
                    }
                }
            }
            
            Text(post.content)
                .font(AppTypography.body)
                .foregroundStyle(Color.appText)
                .lineLimit(2)
        }
        .padding(.horizontal, AppDimensions.padding)
        .padding(.vertical, 6)
    }
}

// MARK: - Platform Button
struct PlatformButton: View {
    let platform: Platform
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isSelected ? Color.appAccent : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.appAccent : Color.appTextMuted, lineWidth: 1)
                    )
                
                Image(systemName: platform.iconName)
                    .foregroundStyle(isSelected ? Color.appAccent : Color.appTextMuted)
                
                Text(platform.rawValue)
                    .font(AppTypography.body)
                    .foregroundStyle(isSelected ? Color.appText : Color.appTextMuted)
                
                Spacer()
            }
            .padding(.horizontal, AppDimensions.padding)
            .padding(.vertical, 6)
            .background(
                isSelected ? Color.appAccent.opacity(0.1) :
                    (isHovered ? Color.appSecondary : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Reply Category Section
struct ReplyCategorySection: View {
    let category: ReplyCategory
    let replies: [QuickReply]
    let onReplySelected: (String) -> Void
    let onEdit: (QuickReply) -> Void
    let onDelete: (QuickReply) -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Category Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.appTextMuted)
                        .frame(width: 12)
                    
                    Text(category.rawValue)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(Color.appText)
                    
                    Spacer()
                    
                    Text("\(replies.count)")
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appTextMuted)
                }
                .padding(.horizontal, AppDimensions.padding)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            
            // Replies
            if isExpanded {
                ForEach(replies) { reply in
                    QuickReplyRow(
                        reply: reply,
                        onSelect: { onReplySelected(reply.text) },
                        onEdit: { onEdit(reply) },
                        onDelete: { onDelete(reply) }
                    )
                }
            }
        }
    }
}

// MARK: - Quick Reply Row
struct QuickReplyRow: View {
    let reply: QuickReply
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .foregroundStyle(Color.appTextMuted)
                
                Text(reply.text)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.appTextMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if isHovered && !reply.isDefault {
                    HStack(spacing: 4) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.appTextMuted)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.appTextMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, AppDimensions.padding)
            .padding(.leading, 12)
            .padding(.vertical, 4)
            .background(isHovered ? Color.appSecondary : Color.clear)
            .cornerRadius(AppDimensions.borderRadius)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Sidebar Draft Row
struct SidebarDraftRow: View {
    let draft: DraftPost
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.previewText)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.appText)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(draft.formattedDate)
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appTextMuted)
                    
                    if !draft.media.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "photo")
                                .font(.system(size: 10))
                            Text("\(draft.media.count)")
                                .font(AppTypography.sectionLabel)
                        }
                        .foregroundStyle(Color.appTextMuted)
                    }
                }
            }
            .padding(.horizontal, AppDimensions.padding)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Color.appSecondary : Color.clear)
            .cornerRadius(AppDimensions.borderRadius)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Insight Stat Row
struct InsightStatRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.appAccent)
                .frame(width: 20)
            
            Text(label)
                .font(AppTypography.body)
                .foregroundStyle(Color.appTextMuted)
            
            Spacer()
            
            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(Color.appText)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AI Reply Row
struct AIReplyRow: View {
    let text: String
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appAccent)
                
                Text(text)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.appText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, AppDimensions.padding)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Color.appAccent.opacity(0.1) : Color.clear)
            .cornerRadius(AppDimensions.borderRadius)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Provider Button
struct ProviderButton: View {
    let provider: AIProvider
    let isSelected: Bool
    let hasKey: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Color.white : Color.appAccent)
                    .frame(width: 20)
                
                Text(provider.rawValue)
                    .font(AppTypography.body)
                    .foregroundStyle(isSelected ? Color.white : Color.appText)
                
                Spacer()
                
                if hasKey {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? Color.white : Color.green)
                }
                
                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.appAccent : Color.appSecondary)
            .cornerRadius(AppDimensions.borderRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.borderRadius)
                    .stroke(isSelected ? Color.appAccent : Color.appBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
