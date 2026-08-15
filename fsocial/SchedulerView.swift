//
//  SchedulerView.swift
//  fsocial
//
//  Created by Mason Earl on 1/11/26.
//

import SwiftUI

struct SchedulerView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @State private var selectedDate = Date()
    @State private var showingAddPost = false
    @State private var editingPost: ScheduledPost?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            if scheduleStore.notificationsDenied || scheduleStore.lastNotificationError != nil || scheduleStore.lastSaveError != nil {
                notificationBanner
            }
            
            Divider()
                .background(Color.appBorder)
            
            // Content
            HStack(spacing: 0) {
                // Calendar
                calendarSection
                    .frame(width: 300)
                
                Divider()
                    .background(Color.appBorder)
                
                // Posts list
                postsSection
            }
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showingAddPost) {
            AddPostSheet(scheduleStore: scheduleStore, selectedDate: selectedDate)
        }
        .sheet(item: $editingPost) { post in
            EditPostSheet(scheduleStore: scheduleStore, post: post)
        }
        .onAppear {
            scheduleStore.refreshNotificationStatus()
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Text("Content Calendar")
                .font(AppTypography.title)
                .foregroundStyle(Color.appText)
            
            Spacer()
            
            Button {
                showingAddPost = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Schedule Post")
                }
                .font(AppTypography.bodyMedium)
                .foregroundStyle(Color.appText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.appAccent)
                .cornerRadius(AppDimensions.borderRadius)
            }
            .buttonStyle(.plain)
        }
        .padding(AppDimensions.padding)
        .background(Color.appBackground)
    }
    
    private var notificationBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(Color.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                if scheduleStore.notificationsDenied {
                    Text("Notifications are off")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(Color.appText)
                    Text("Reminders won’t fire until notifications are allowed for fsocial.")
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appTextMuted)
                }
                
                if let error = scheduleStore.lastNotificationError {
                    Text(error)
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.orange)
                }
                
                if let error = scheduleStore.lastSaveError {
                    Text(error)
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.red)
                }
            }
            
            Spacer()
            
            if scheduleStore.notificationsDenied {
                Button("Open Settings") {
                    scheduleStore.openNotificationSettings()
                }
                .font(AppTypography.sectionLabel)
                .foregroundStyle(Color.appAccent)
                .buttonStyle(.plain)
                
                Button("Retry") {
                    scheduleStore.requestNotificationPermission()
                }
                .font(AppTypography.sectionLabel)
                .foregroundStyle(Color.appAccent)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppDimensions.padding)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
    }
    
    // MARK: - Calendar Section
    private var calendarSection: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.appText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(monthYearString)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(Color.appText)
                
                Spacer()
                
                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.appText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppDimensions.padding)
            
            // Day headers
            HStack(spacing: 0) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appTextMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            isToday: Calendar.current.isDateInToday(date),
                            hasEvents: scheduleStore.hasPostsOnDate(date)
                        ) {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
            .padding(.horizontal, 8)
            
            Spacer()
            
            // Today button
            Button {
                withAnimation {
                    selectedDate = Date()
                }
            } label: {
                Text("Today")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(Color.appAccent)
            }
            .buttonStyle(.plain)
            .padding(.bottom, AppDimensions.padding)
        }
        .padding(.top, AppDimensions.padding)
        .background(Color.appBackground)
    }
    
    // MARK: - Posts Section
    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDateString)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(Color.appText)
                .padding(.horizontal, AppDimensions.padding)
                .padding(.top, AppDimensions.padding)
            
            let postsForDate = scheduleStore.posts(for: selectedDate)
            
            if postsForDate.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.appTextMuted.opacity(0.5))
                    Text("No posts scheduled")
                        .font(AppTypography.body)
                        .foregroundStyle(Color.appTextMuted)
                    Button {
                        showingAddPost = true
                    } label: {
                        Text("Schedule a post")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(Color.appAccent)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(postsForDate) { post in
                            ScheduledPostRow(
                                post: post,
                                onEdit: { editingPost = post },
                                onMarkPosted: { scheduleStore.markAsPosted(post) },
                                onDelete: { scheduleStore.deletePost(post) }
                            )
                        }
                    }
                    .padding(.horizontal, AppDimensions.padding)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSecondary.opacity(0.3))
    }
    
    // MARK: - Helpers
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
    }
    
    private var daysInMonth: [Date?] {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
        let monthRange = calendar.range(of: .day, in: .month, for: selectedDate)!
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }
        
        // Fill remaining cells
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
}

// MARK: - Calendar Day View
struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(AppTypography.body)
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Color.appAccent : Color.appText))
                
                if hasEvents {
                    Circle()
                        .fill(isSelected ? Color.white : Color.appAccent)
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: AppDimensions.borderRadius)
                    .fill(isSelected ? Color.appAccent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scheduled Post Row
struct ScheduledPostRow: View {
    let post: ScheduledPost
    let onEdit: () -> Void
    let onMarkPosted: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Time and platforms
            HStack {
                Text(post.formattedTime)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(Color.appAccent)
                
                Spacer()
                
                HStack(spacing: 4) {
                    ForEach(post.platforms) { platform in
                        Image(systemName: platform.iconName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appTextMuted)
                    }
                }
            }
            
            // Content
            Text(post.content)
                .font(AppTypography.body)
                .foregroundStyle(Color.appText)
                .lineLimit(3)
            
            // Notes
            if !post.notes.isEmpty {
                Text(post.notes)
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
                    .lineLimit(1)
            }
            
            // Actions
            if isHovered {
                HStack(spacing: 12) {
                    Button("Edit") { onEdit() }
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appAccent)
                    
                    if !post.isPosted {
                        Button("Mark Posted") { onMarkPosted() }
                            .font(AppTypography.sectionLabel)
                            .foregroundStyle(Color.appSuccess)
                    }
                    
                    Button("Delete") { onDelete() }
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.red.opacity(0.8))
                    
                    Spacer()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppDimensions.padding)
        .background(Color.appSecondary)
        .cornerRadius(AppDimensions.borderRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.borderRadius)
                .stroke(post.isPosted ? Color.appSuccess.opacity(0.3) : Color.appBorder, lineWidth: 1)
        )
        .opacity(post.isPosted ? 0.6 : 1)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Add Post Sheet
struct AddPostSheet: View {
    let scheduleStore: ScheduleStore
    let selectedDate: Date
    
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var selectedPlatforms: Set<Platform> = []
    @State private var scheduledTime = Date()
    @State private var notes = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Schedule Post")
                .font(AppTypography.title)
                .foregroundStyle(Color.appText)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("CONTENT")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
                
                TextEditor(text: $content)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.appText)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color.appSecondary)
                    .cornerRadius(AppDimensions.borderRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.borderRadius)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
            }
            
            // Platforms
            VStack(alignment: .leading, spacing: 4) {
                Text("PLATFORMS")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(Platform.allCases) { platform in
                        PlatformToggle(
                            platform: platform,
                            isSelected: selectedPlatforms.contains(platform)
                        ) {
                            if selectedPlatforms.contains(platform) {
                                selectedPlatforms.remove(platform)
                            } else {
                                selectedPlatforms.insert(platform)
                            }
                        }
                    }
                }
            }
            
            // Date & Time
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DATE & TIME")
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appTextMuted)
                    
                    DatePicker("", selection: $scheduledTime, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .colorScheme(.dark)
                }
                Spacer()
            }
            
            // Notes
            VStack(alignment: .leading, spacing: 4) {
                Text("NOTES (optional)")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
                
                TextField("Add notes...", text: $notes)
                    .textFieldStyle(.plain)
                    .font(AppTypography.body)
                    .padding(8)
                    .background(Color.appSecondary)
                    .cornerRadius(AppDimensions.borderRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.borderRadius)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
            }
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appTextMuted)
                
                Spacer()
                
                Button("Schedule") {
                    scheduleStore.addPost(
                        content: content,
                        platforms: Array(selectedPlatforms),
                        scheduledDate: scheduledTime,
                        notes: notes
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
                .disabled(content.isEmpty || selectedPlatforms.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 450)
        .background(Color.appBackground)
        .onAppear {
            // Set initial time to selected date with current time
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: Date())
            scheduledTime = calendar.date(bySettingHour: timeComponents.hour ?? 12,
                                          minute: timeComponents.minute ?? 0,
                                          second: 0,
                                          of: selectedDate) ?? selectedDate
        }
    }
}

// MARK: - Edit Post Sheet
struct EditPostSheet: View {
    let scheduleStore: ScheduleStore
    let post: ScheduledPost
    
    @Environment(\.dismiss) private var dismiss
    @State private var content: String
    @State private var selectedPlatforms: Set<Platform>
    @State private var scheduledTime: Date
    @State private var notes: String
    
    init(scheduleStore: ScheduleStore, post: ScheduledPost) {
        self.scheduleStore = scheduleStore
        self.post = post
        _content = State(initialValue: post.content)
        _selectedPlatforms = State(initialValue: Set(post.platforms))
        _scheduledTime = State(initialValue: post.scheduledDate)
        _notes = State(initialValue: post.notes)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Post")
                .font(AppTypography.title)
                .foregroundStyle(Color.appText)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("CONTENT")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
                
                TextEditor(text: $content)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.appText)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color.appSecondary)
                    .cornerRadius(AppDimensions.borderRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.borderRadius)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
            }
            
            // Platforms
            VStack(alignment: .leading, spacing: 4) {
                Text("PLATFORMS")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(Platform.allCases) { platform in
                        PlatformToggle(
                            platform: platform,
                            isSelected: selectedPlatforms.contains(platform)
                        ) {
                            if selectedPlatforms.contains(platform) {
                                selectedPlatforms.remove(platform)
                            } else {
                                selectedPlatforms.insert(platform)
                            }
                        }
                    }
                }
            }
            
            // Date & Time
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DATE & TIME")
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(Color.appTextMuted)
                    
                    DatePicker("", selection: $scheduledTime, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .colorScheme(.dark)
                }
                Spacer()
            }
            
            // Notes
            VStack(alignment: .leading, spacing: 4) {
                Text("NOTES (optional)")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(Color.appTextMuted)
                
                TextField("Add notes...", text: $notes)
                    .textFieldStyle(.plain)
                    .font(AppTypography.body)
                    .padding(8)
                    .background(Color.appSecondary)
                    .cornerRadius(AppDimensions.borderRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.borderRadius)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
            }
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appTextMuted)
                
                Spacer()
                
                Button("Save") {
                    scheduleStore.updatePost(
                        post,
                        content: content,
                        platforms: Array(selectedPlatforms),
                        scheduledDate: scheduledTime,
                        notes: notes
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
                .disabled(content.isEmpty || selectedPlatforms.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 450)
        .background(Color.appBackground)
    }
}

// MARK: - Platform Toggle
struct PlatformToggle: View {
    let platform: Platform
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: platform.iconName)
                    .font(.system(size: 12))
                Text(platform.rawValue)
                    .font(AppTypography.body)
            }
            .foregroundStyle(isSelected ? Color.white : Color.appTextMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
