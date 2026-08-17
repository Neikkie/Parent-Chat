//
//  ActivitiesView.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/11/26.
//

import SwiftUI
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

struct ActivitiesView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(AppearanceManager.self) var appearanceManager
    @State private var activities: [Activity] = []
    @State private var savedActivityIds: Set<String> = []
    @State private var isLoading = false
    @State private var locationManager = LocationManager()
    @State private var selectedActivity: Activity?
    @State private var showActivityDetail = false
    @State private var showSettings = false
    @State private var saveErrorMessage: String?
    @State private var savedActivitiesListener: ListenerRegistration?
    @State private var activitiesListener: ListenerRegistration?
    
    // Filters
    @State private var selectedTab: FilterTab = .all
    @State private var selectedAgeGroups: Set<String> = []
    @State private var selectedTags: Set<String> = []
    @State private var showFilters = false
    
    enum FilterTab: String, CaseIterable {
        case all = "All"
        case saved = "Saved"
        case nearby = "Nearby"
    }
    
    var filteredActivities: [Activity] {
        var filtered = activities
        
        // Tab filter
        switch selectedTab {
        case .all:
            break
        case .saved:
            filtered = filtered.filter { activity in
                if let id = activity.id {
                    return savedActivityIds.contains(id)
                }
                return false
            }
        case .nearby:
            if let userLocation = locationManager.currentLocation {
                filtered = filtered.filter { activity in
                    let activityLocation = CLLocation(
                        latitude: activity.location.latitude,
                        longitude: activity.location.longitude
                    )
                    let distance = userLocation.distance(from: activityLocation)
                    return distance < 16093 // 10 miles in meters
                }
            }
        }
        
        // Age group filter
        if !selectedAgeGroups.isEmpty {
            filtered = filtered.filter { activity in
                !Set(activity.ageGroups).isDisjoint(with: selectedAgeGroups)
            }
        }
        
        // Tags filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { activity in
                !Set(activity.tags).isDisjoint(with: selectedTags)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(FilterTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation {
                                    selectedTab = tab
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: tabIcon(for: tab))
                                    Text(tab.rawValue)
                                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedTab == tab ? Color.blue : Color(.systemGray6))
                                .foregroundStyle(selectedTab == tab ? .white : .primary)
                                .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                
                // Filter chips
                if !selectedAgeGroups.isEmpty || !selectedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(selectedAgeGroups), id: \.self) { ageGroup in
                                FilterChip(text: ageGroup, color: .purple) {
                                    selectedAgeGroups.remove(ageGroup)
                                }
                            }
                            
                            ForEach(Array(selectedTags), id: \.self) { tag in
                                FilterChip(text: tag, color: .orange) {
                                    selectedTags.remove(tag)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                }
                
                Divider()
                
                // Activities list
                if isLoading {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(0..<3) { _ in
                                ActivityCardSkeleton()
                            }
                        }
                        .padding()
                    }
                } else if filteredActivities.isEmpty {
                    Spacer()
                    EmptyStateView(tab: selectedTab)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(filteredActivities.enumerated()), id: \.element.id) { index, activity in
                                if let activityId = activity.id {
                                    ActivityCardView(
                                        activity: activity,
                                        userLocation: locationManager.currentLocation,
                                        isSaved: savedActivityIds.contains(activityId),
                                        onSave: {
                                            Task {
                                                await toggleSave(activityId: activityId)
                                            }
                                        },
                                        onTap: {
                                            selectedActivity = activity
                                            showActivityDetail = true
                                        }
                                    )
                                    .padding(.horizontal)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                                        removal: .opacity
                                    ))
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.05), value: filteredActivities.count)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        HapticManager.shared.impact(.light)
                        await loadActivities()
                    }
                }
            }
            .navigationTitle("Activities")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .font(.title3)
                    }
                    .buttonStyle(.scale)
                }
            }
            .sheet(isPresented: $showFilters) {
                FiltersView(
                    selectedAgeGroups: $selectedAgeGroups,
                    selectedTags: $selectedTags
                )
            }
            .sheet(isPresented: $showActivityDetail) {
                if let activity = selectedActivity {
                    ActivityDetailView(
                        activity: activity,
                        userLocation: locationManager.currentLocation,
                        onRated: {
                            await loadActivities()
                        }
                    )
                    .environment(authManager)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(appearanceManager: appearanceManager)
                    .environment(authManager)
            }
            .task {
                startActivitiesListener()
                startSavedActivitiesListener()
                locationManager.requestPermission()
                locationManager.startUpdatingLocation()
            }
            .alert("Save Failed", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Could not save this activity.")
            }
            .onDisappear {
                savedActivitiesListener?.remove()
                savedActivitiesListener = nil
                activitiesListener?.remove()
                activitiesListener = nil
            }
        }
    }
    
    private func tabIcon(for tab: FilterTab) -> String {
        switch tab {
        case .all: return "square.grid.2x2"
        case .saved: return "bookmark.fill"
        case .nearby: return "location.fill"
        }
    }
    
    private func loadActivities() async {
        isLoading = true
        
        do {
            print("🔍 Fetching activities from Firestore...")
            activities = try await FirestoreManager.shared.fetchActivities()
            print("✅ Successfully loaded \(activities.count) activities")
            
            if let userId = authManager.currentUser?.uid {
                let savedActivities = try await FirestoreManager.shared.fetchSavedActivities(userId: userId)
                savedActivityIds = Set(savedActivities.compactMap { $0.id })
                print("✅ Loaded \(savedActivityIds.count) saved activities")
            }
        } catch {
            print("❌ Error loading activities: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func startActivitiesListener() {
        activitiesListener?.remove()
        isLoading = true
        activitiesListener = FirestoreManager.shared.listenToActivities { updated in
            DispatchQueue.main.async {
                activities = updated
                isLoading = false
            }
        } onError: { _ in
            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }

    private func startSavedActivitiesListener() {
        guard let userId = authManager.currentUser?.uid else { return }
        savedActivitiesListener?.remove()
        savedActivitiesListener = FirestoreManager.shared.listenToSavedActivityIds(userId: userId) { ids in
            DispatchQueue.main.async {
                savedActivityIds = ids
            }
        }
    }
    
    private func toggleSave(activityId: String) async {
        guard let userId = authManager.currentUser?.uid else { return }
        
        // Optimistic update
        if savedActivityIds.contains(activityId) {
            savedActivityIds.remove(activityId)
        } else {
            savedActivityIds.insert(activityId)
        }
        
        do {
            let nowSaved = try await FirestoreManager.shared.toggleSaveActivity(activityId: activityId, userId: userId)
            if nowSaved {
                savedActivityIds.insert(activityId)
            } else {
                savedActivityIds.remove(activityId)
            }
        } catch {
            // Revert on error
            if savedActivityIds.contains(activityId) {
                savedActivityIds.remove(activityId)
            } else {
                savedActivityIds.insert(activityId)
            }
            saveErrorMessage = error.localizedDescription
        }
    }
}

struct FilterChip: View {
    let text: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .foregroundStyle(color)
        .cornerRadius(12)
    }
}

struct EmptyStateView: View {
    let tab: ActivitiesView.FilterTab
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [iconColor.opacity(0.2), iconColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: emptyIcon)
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [iconColor, iconColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text(emptyTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    private var iconColor: Color {
        switch tab {
        case .all: return .blue
        case .saved: return .orange
        case .nearby: return .green
        }
    }
    
    private var emptyIcon: String {
        switch tab {
        case .all: return "tray"
        case .saved: return "bookmark.slash"
        case .nearby: return "location.slash"
        }
    }
    
    private var emptyTitle: String {
        switch tab {
        case .all: return "No Activities Yet"
        case .saved: return "No Saved Activities"
        case .nearby: return "No Nearby Activities"
        }
    }
    
    private var emptyMessage: String {
        switch tab {
        case .all: return "Check back later for new activities in your area!"
        case .saved: return "Tap the bookmark icon on activities to save them for later"
        case .nearby: return "No activities found within 10 miles of your location"
        }
    }
}

struct FiltersView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedAgeGroups: Set<String>
    @Binding var selectedTags: Set<String>
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Age Groups") {
                    ForEach(AgeGroup.allCases, id: \.self) { ageGroup in
                        Toggle(ageGroup.rawValue, isOn: Binding(
                            get: { selectedAgeGroups.contains(ageGroup.rawValue) },
                            set: { isOn in
                                if isOn {
                                    selectedAgeGroups.insert(ageGroup.rawValue)
                                } else {
                                    selectedAgeGroups.remove(ageGroup.rawValue)
                                }
                            }
                        ))
                    }
                }
                
                Section("Tags") {
                    ForEach(ActivityTag.allCases, id: \.self) { tag in
                        Toggle(tag.rawValue, isOn: Binding(
                            get: { selectedTags.contains(tag.rawValue) },
                            set: { isOn in
                                if isOn {
                                    selectedTags.insert(tag.rawValue)
                                } else {
                                    selectedTags.remove(tag.rawValue)
                                }
                            }
                        ))
                    }
                }
                
                Section {
                    Button("Clear All Filters") {
                        selectedAgeGroups.removeAll()
                        selectedTags.removeAll()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ActivitiesView()
        .environment(AuthenticationManager())
}
