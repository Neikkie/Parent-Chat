//
//  MapView.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/11/26.
//

import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore
import Contacts

struct MapView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(AppearanceManager.self) var appearanceManager
    @Binding var isTabBarVisible: Bool
    @State private var activities: [Activity] = []
    @State private var savedActivityIds: Set<String> = []
    @State private var isLoading = false
    @State private var locationManager = LocationManager()
    @State private var selectedActivity: Activity?
    @State private var showActivityDetail = false
    @State private var showSettings = false
    @State private var tappedLocation: TappedLocation?
    @State private var showLocationDetail = false
    @State private var searchText = ""
    @State private var selectedFilter: ActivityFilter = .all
    @State private var isPulsing = false
    @State private var showLegend = false
    @State private var selectedCategory: String? = nil
    @State private var selectedAgeGroup: String? = nil
    @State private var showAgeGroupFilter = false
    @State private var nearbyPlacesSearcher = NearbyPlacesSearcher()
    @State private var showNearbyList = false
    @State private var nearbyTab: NearbyTab = .activities
    @State private var selectedNearbyPlace: NearbyPlace?
    @State private var showPlaceSearch = false
    @State private var activitiesListener: ListenerRegistration?
    @State private var savedActivitiesListener: ListenerRegistration?
    
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    
    var categorizedActivities: [String: [Activity]] {
        var categories: [String: [Activity]] = [:]
        for activity in filteredActivities {
            for tag in activity.tags {
                if categories[tag] == nil {
                    categories[tag] = []
                }
                categories[tag]?.append(activity)
            }
        }
        return categories
    }
    
    var filteredActivities: [Activity] {
        var result = activities
        
        // Apply age group filter - PRIORITY FILTER for kid-appropriate areas
        if let ageGroup = selectedAgeGroup {
            result = result.filter { activity in
                activity.ageGroups.contains(ageGroup) || activity.ageGroups.contains("All Ages")
            }
        }
        
        // Apply category filter
        if let category = selectedCategory {
            result = result.filter { $0.tags.contains(category) }
        }
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .free:
            result = result.filter { $0.tags.contains("Free") }
        case .saved:
            result = result.filter { savedActivityIds.contains($0.id ?? "") }
        }
        
        // Apply search
        if !searchText.isEmpty {
            result = result.filter { activity in
                activity.name.localizedCaseInsensitiveContains(searchText) ||
                activity.title.localizedCaseInsensitiveContains(searchText) ||
                activity.location.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var freeActivityCount: Int {
        activities.filter { $0.tags.contains("Free") }.count
    }
    
    var ageGroupActivities: [String: [Activity]] {
        var groups: [String: [Activity]] = [:]
        for activity in activities {
            for ageGroup in activity.ageGroups {
                if groups[ageGroup] == nil {
                    groups[ageGroup] = []
                }
                groups[ageGroup]?.append(activity)
            }
        }
        return groups
    }
    
    var activityAnnotations: [ActivityAnnotation] {
        filteredActivities.compactMap { activity in
            guard let id = activity.id else { return nil }
            return ActivityAnnotation(
                id: id,
                activity: activity,
                coordinate: CLLocationCoordinate2D(
                    latitude: activity.location.latitude,
                    longitude: activity.location.longitude
                )
            )
        }
    }
    
    var displayedActivityAnnotations: [ActivityAnnotation] {
        Array(activityAnnotations.prefix(30))
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                MapReader { proxy in
                    Map(position: $cameraPosition, interactionModes: .all) {
                        UserAnnotation()
                        
                        ForEach(displayedActivityAnnotations) { annotation in
                            Annotation(annotation.activity.name, coordinate: annotation.coordinate) {
                                ActivityMapMarker(
                                    activity: annotation.activity,
                                    isSaved: savedActivityIds.contains(annotation.id)
                                )
                                .onTapGesture {
                                    selectedActivity = annotation.activity
                                    showActivityDetail = true
                                    
                                    // Animate to selected activity
                                    withAnimation {
                                        cameraPosition = .region(
                                            MKCoordinateRegion(
                                                center: annotation.coordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                            )
                                        )
                                    }
                                }
                            }
                        }
                        
                        // Tapped location marker
                        if let tappedLocation = tappedLocation {
                            Annotation("Tapped Location", coordinate: tappedLocation.coordinate) {
                                ZStack {
                                    // Pulsing ring
                                    Circle()
                                        .fill(Color.orange.opacity(0.3))
                                        .frame(width: 50, height: 50)
                                        .scaleEffect(isPulsing ? 1.2 : 1.0)
                                        .opacity(isPulsing ? 0 : 1)
                                    
                                    // Main marker
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.orange, .red],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 30, height: 30)
                                        .shadow(color: .orange.opacity(0.5), radius: 8, x: 0, y: 4)
                                    
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 16, weight: .semibold))
                                        .symbolEffect(.bounce, value: tappedLocation.coordinate.latitude)
                                }
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                                        isPulsing = true
                                    }
                                }
                                .onTapGesture {
                                    showLocationDetail = true
                                    HapticManager.shared.impact(.light)
                                }
                            }
                        }
                    }
                    .onTapGesture { screenCoord in
                        if let coordinate = proxy.convert(screenCoord, from: .local) {
                            handleMapTap(at: coordinate)
                            
                            // Hide tab bar when tapping on map
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isTabBarVisible = false
                            }
                        }
                    }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                        MapPitchToggle()
                    }
                }
                
                // Search and filter bar
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            
                            TextField("Search activities...", text: $searchText)
                                .textFieldStyle(.plain)
                            
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                    HapticManager.shared.selection()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        
                        // Filters button (age group)
                        Button {
                            showAgeGroupFilter = true
                            HapticManager.shared.impact(.light)
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)

                                if selectedAgeGroup != nil {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 2, y: -2)
                                }
                            }
                        }
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        
                        // Nearby list button (merged Activities / Places)
                        Button {
                            nearbyTab = .activities
                            withAnimation {
                                showNearbyList = true
                            }
                            HapticManager.shared.impact(.light)
                        } label: {
                            Image(systemName: "list.bullet.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.purple)
                        }
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Category filter chips
                    if !categorizedActivities.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // All chip — resets every filter
                                CategoryChip(
                                    title: "All",
                                    count: activities.count,
                                    isSelected: selectedCategory == nil && selectedFilter == .all,
                                    icon: "map.fill"
                                ) {
                                    withAnimation {
                                        selectedCategory = nil
                                        selectedFilter = .all
                                    }
                                    HapticManager.shared.selection()
                                }

                                // Saved quick filter
                                CategoryChip(
                                    title: "Saved",
                                    count: savedActivityIds.count,
                                    isSelected: selectedFilter == .saved,
                                    icon: "bookmark.fill"
                                ) {
                                    withAnimation {
                                        selectedFilter = selectedFilter == .saved ? .all : .saved
                                    }
                                    HapticManager.shared.selection()
                                }

                                // Free quick filter
                                CategoryChip(
                                    title: "Free",
                                    count: freeActivityCount,
                                    isSelected: selectedFilter == .free,
                                    icon: "tag.fill"
                                ) {
                                    withAnimation {
                                        selectedFilter = selectedFilter == .free ? .all : .free
                                    }
                                    HapticManager.shared.selection()
                                }
                                
                                ForEach(Array(categorizedActivities.keys.sorted()), id: \.self) { category in
                                    if let activities = categorizedActivities[category] {
                                        CategoryChip(
                                            title: category,
                                            count: activities.count,
                                            isSelected: selectedCategory == category,
                                            icon: iconForCategory(category)
                                        ) {
                                            withAnimation {
                                                selectedCategory = selectedCategory == category ? nil : category
                                            }
                                            HapticManager.shared.selection()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Activity count badge or empty state
                    if !isLoading {
                        if !filteredActivities.isEmpty {
                            HStack {
                                Spacer()
                                Text("\(filteredActivities.count) \(filteredActivities.count == 1 ? "activity" : "activities")")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(.blue.gradient)
                                    )
                                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                                Spacer()
                            }
                            .transition(.scale.combined(with: .opacity))
                        } else if !searchText.isEmpty || selectedFilter != .all || selectedCategory != nil || selectedAgeGroup != nil {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.title)
                                        .foregroundStyle(.secondary)
                                    
                                    Text("No activities found")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("Try adjusting your filters")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                Spacer()
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .animation(.spring(response: 0.3), value: filteredActivities.count)
                
                // Quick actions for tapped location
                if tappedLocation != nil {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 12) {
                            // View Details
                            Button {
                                showLocationDetail = true
                                HapticManager.shared.impact(.light)
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.title2)
                                    Text("Details")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.scale)
                            
                            // Get Directions
                            Button {
                                if let location = tappedLocation {
                                    openDirections(to: location.coordinate)
                                }
                                HapticManager.shared.impact(.light)
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                        .font(.title2)
                                    Text("Directions")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.scale)
                            
                            // Clear marker
                            Button {
                                withAnimation {
                                    tappedLocation = nil
                                }
                                HapticManager.shared.selection()
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                    Text("Clear")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.scale)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                        .padding()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Loading overlay
                if isLoading {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Loading activities...")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(24)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.1), radius: 12)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                
                // Searching indicator
                if nearbyPlacesSearcher.isSearching {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Finding nearby places...")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(24)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.1), radius: 12)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                
                // Show Tab Bar Button
                if !isTabBarVisible {
                    VStack {
                        Spacer()
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isTabBarVisible = true
                            }
                            HapticManager.shared.impact(.light)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.up")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Show Navigation")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 4)
                        }
                        .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Nearby Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showLegend = true
                        HapticManager.shared.selection()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.scale)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        // Search an address / drop a pin
                        Button {
                            showPlaceSearch = true
                            HapticManager.shared.selection()
                        } label: {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.title3)
                        }
                        .buttonStyle(.scale)

                        // My location button
                        Button {
                            withAnimation {
                                cameraPosition = .userLocation(fallback: .automatic)
                            }
                            HapticManager.shared.impact(.light)
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.scale)

                        Button {
                            showSettings = true
                            HapticManager.shared.selection()
                        } label: {
                            Image(systemName: "gear")
                                .font(.title3)
                        }
                        .buttonStyle(.scale)
                    }
                }
            }
            .sheet(isPresented: $showActivityDetail) {
                if let activity = selectedActivity {
                    ActivityDetailSheet(
                        activity: activity,
                        userLocation: locationManager.currentLocation,
                        isSaved: savedActivityIds.contains(activity.id ?? ""),
                        onSave: {
                            Task {
                                await toggleSave(activityId: activity.id ?? "")
                            }
                        }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .large))
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(appearanceManager: appearanceManager)
                    .environment(authManager)
            }
            .sheet(isPresented: $showPlaceSearch) {
                PlaceSearchSheet(
                    locationManager: locationManager,
                    onSelectPlace: { item in selectSearchedPlace(item) },
                    onUseCurrentLocation: { dropPinAtCurrentLocation() }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showLocationDetail) {
                if let tappedLocation = tappedLocation {
                    LocationDetailSheet(
                        tappedLocation: tappedLocation,
                        userLocation: locationManager.currentLocation,
                        onClose: {
                            self.tappedLocation = nil
                        }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .large))
                }
            }
            .sheet(isPresented: $showLegend) {
                LegendSheet()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showNearbyList) {
                NearbyListSheet(
                    tab: $nearbyTab,
                    activities: filteredActivities,
                    places: nearbyPlacesSearcher.nearbyPlaces,
                    savedActivityIds: savedActivityIds,
                    userLocation: locationManager.currentLocation,
                    onSelectActivity: { activity in
                        if let id = activity.id,
                           let annotation = activityAnnotations.first(where: { $0.id == id }) {
                            withAnimation {
                                cameraPosition = .region(
                                    MKCoordinateRegion(
                                        center: annotation.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    )
                                )
                            }
                        }
                        HapticManager.shared.impact(.medium)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAgeGroupFilter) {
                AgeGroupFilterSheet(
                    selectedAgeGroup: $selectedAgeGroup,
                    ageGroupActivities: ageGroupActivities
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedNearbyPlace) { place in
                NearbyPlaceDetailSheet(place: place)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .large))
            }
            .task {
                locationManager.requestPermission()
                locationManager.startUpdatingLocation()
                
                // Seed default activities if needed
                await DefaultActivitiesSeeder.seedActivitiesIfNeeded()
                
                startActivitiesListener()
                startSavedActivitiesListener()
                
                // Search for nearby kid-friendly places (shown on demand via the Nearby list)
                if let location = locationManager.currentLocation {
                    await nearbyPlacesSearcher.searchNearbyPlaces(around: location)
                }
            }
            .onDisappear {
                activitiesListener?.remove()
                activitiesListener = nil
                savedActivitiesListener?.remove()
                savedActivitiesListener = nil
            }
            .onChange(of: locationManager.currentLocation) { oldLocation, newLocation in
                // Update nearby places when location changes significantly
                if let newLocation = newLocation {
                    if let oldLocation = oldLocation {
                        let distance = oldLocation.distance(from: newLocation)
                        // Only search again if moved more than 1km
                        if distance > 1000 {
                            Task {
                                await nearbyPlacesSearcher.searchNearbyPlaces(around: newLocation)
                            }
                        }
                    }
                }
            }
            // Refocus the map to fit the activities whenever the category (or a
            // quick filter) changes, so tapping a pill zooms to those pins.
            .onChange(of: selectedCategory) { _, _ in focusOnFilteredActivities() }
            .onChange(of: selectedFilter) { _, _ in focusOnFilteredActivities() }
        }
    }

    /// Animates the camera to a region that fits every activity currently
    /// passing the filters. No-op when there are none to show.
    private func focusOnFilteredActivities() {
        let coordinates = filteredActivities.map {
            CLLocationCoordinate2D(latitude: $0.location.latitude, longitude: $0.location.longitude)
        }
        guard let region = regionThatFits(coordinates) else { return }
        withAnimation {
            cameraPosition = .region(region)
        }
    }

    /// Builds an `MKCoordinateRegion` that encloses the given coordinates with a
    /// little padding. Returns nil for an empty set.
    private func regionThatFits(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }

        if coordinates.count == 1 {
            return MKCoordinateRegion(
                center: coordinates[0],
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLat = latitudes.min()!, maxLat = latitudes.max()!
        let minLon = longitudes.min()!, maxLon = longitudes.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        // 1.4x padding so pins aren't flush against the edges; floor so a tight
        // cluster still gets a sensible zoom.
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.02),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.02)
        )
        return MKCoordinateRegion(center: center, span: span)
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
            _ = try await FirestoreManager.shared.toggleSaveActivity(activityId: activityId, userId: userId)
        } catch {
            // Revert on error
            if savedActivityIds.contains(activityId) {
                savedActivityIds.remove(activityId)
            } else {
                savedActivityIds.insert(activityId)
            }
            print("Error toggling save: \(error.localizedDescription)")
        }
    }
    
    private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        HapticManager.shared.impact(.medium)
        
        Task {
            // Reverse geocode the tapped coordinate to get location information.
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            var mapItem: MKMapItem? = nil
            if let request = MKReverseGeocodingRequest(location: location) {
                let items = try? await request.mapItems
                mapItem = items?.first
            }

            // Show the location even if reverse geocoding returned nothing.
            withAnimation {
                tappedLocation = TappedLocation(
                    coordinate: coordinate,
                    mapItem: mapItem
                )
            }
        }
    }
    
    /// Drops the location pin at a place chosen from the address/place search,
    /// preserving the searched name, and recenters the map on it.
    private func selectSearchedPlace(_ item: MKMapItem) {
        let coordinate = item.location.coordinate
        withAnimation {
            tappedLocation = TappedLocation(coordinate: coordinate, mapItem: item)
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
        }
        HapticManager.shared.impact(.medium)
    }

    /// Drops the location pin at the user's current location (reverse-geocoded
    /// for an address) and recenters the map on it.
    private func dropPinAtCurrentLocation() {
        guard let location = locationManager.currentLocation else { return }
        handleMapTap(at: location.coordinate)
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
        }
    }

    private func openDirections(to coordinate: CLLocationCoordinate2D) {
        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let mapItem = MKMapItem(location: clLocation, address: nil)
        mapItem.name = tappedLocation?.mapItem?.name ?? "Selected Location"
        
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Sports":
            return "figure.run"
        case "Educational":
            return "book.fill"
        case "Arts & Crafts":
            return "paintpalette.fill"
        case "Music":
            return "music.note"
        case "Food & Drinks":
            return "fork.knife"
        case "Outdoor":
            return "tree.fill"
        case "Indoor":
            return "house.fill"
        case "Free":
            return "tag.fill"
        default:
            return "star.fill"
        }
    }
}

struct ActivityAnnotation: Identifiable {
    let id: String
    let activity: Activity
    let coordinate: CLLocationCoordinate2D
}

struct ActivityMapMarker: View {
    let activity: Activity
    let isSaved: Bool
    
    var isKidFriendly: Bool {
        !activity.ageGroups.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Kid-friendly indicator ring
                if isKidFriendly {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.green.opacity(0.6), .mint.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 48, height: 48)
                }
                
                Circle()
                    .fill(markerColor)
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                Image(systemName: markerIcon)
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .semibold))
                
                // Age badge
                if isKidFriendly && activity.ageGroups.first != "All Ages" {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(ageGroupBadge)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(
                                    Circle()
                                        .fill(.green)
                                )
                                .offset(x: 8, y: 8)
                        }
                    }
                    .frame(width: 40, height: 40)
                }
            }
            
            // Pointer
            Triangle()
                .fill(markerColor)
                .frame(width: 12, height: 8)
                .offset(y: -2)
        }
    }
    
    private var ageGroupBadge: String {
        if let firstAge = activity.ageGroups.first {
            if firstAge.contains("0-1") {
                return "0+"
            } else if firstAge.contains("1-3") {
                return "1+"
            } else if firstAge.contains("3-5") {
                return "3+"
            } else if firstAge.contains("5-12") {
                return "5+"
            } else if firstAge.contains("13-18") {
                return "13+"
            }
        }
        return "✓"
    }
    
    private var markerColor: Color {
        if isSaved {
            return .blue
        }
        
        if activity.tags.contains("Free") {
            return .green
        }
        
        return .red
    }
    
    private var markerIcon: String {
        if activity.tags.contains("Sports") {
            return "figure.run"
        } else if activity.tags.contains("Educational") {
            return "book.fill"
        } else if activity.tags.contains("Arts & Crafts") {
            return "paintpalette.fill"
        } else if activity.tags.contains("Music") {
            return "music.note"
        } else if activity.tags.contains("Food & Drinks") {
            return "fork.knife"
        }
        
        return "figure.play"
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct ActivityDetailSheet: View {
    let activity: Activity
    let userLocation: CLLocation?
    let isSaved: Bool
    let onSave: () -> Void
    
    var distance: String {
        guard let userLocation = userLocation else {
            return ""
        }
        
        let activityLocation = CLLocation(
            latitude: activity.location.latitude,
            longitude: activity.location.longitude
        )
        
        let distanceInMeters = userLocation.distance(from: activityLocation)
        let distanceInMiles = distanceInMeters / 1609.34
        
        if distanceInMiles < 0.1 {
            return "Nearby"
        } else if distanceInMiles < 1 {
            return String(format: "%.1f mi away", distanceInMiles)
        } else {
            return String(format: "%.0f mi away", distanceInMiles)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(activity.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(activity.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        onSave()
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.title2)
                            .foregroundStyle(isSaved ? .blue : .secondary)
                    }
                }
                
                // Location and distance
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.location.name)
                            .font(.subheadline)
                        
                        if !distance.isEmpty {
                            Text(distance)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                Divider()
                
                // Description
                if !activity.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                        
                        Text(activity.description)
                            .font(.body)
                    }
                }
                
                // Age groups
                if !activity.ageGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Age Groups")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(activity.ageGroups, id: \.self) { ageGroup in
                                    Text(ageGroup)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.purple.opacity(0.1))
                                        .foregroundStyle(.purple)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
                
                // Tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(activity.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Contact info
                if let contactInfo = activity.contactInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Contact")
                            .font(.headline)
                        
                        Text(contactInfo)
                            .font(.body)
                    }
                }
                
                // Website
                if let website = activity.website {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Website")
                            .font(.headline)
                        
                        Link(website, destination: URL(string: website) ?? URL(string: "https://example.com")!)
                            .font(.body)
                    }
                }
            }
            .padding()
            .padding(.bottom, 100) // Add extra bottom padding to avoid tab bar overlap
        }
    }
}

struct TappedLocation {
    let coordinate: CLLocationCoordinate2D
    let mapItem: MKMapItem?
}

struct LocationDetailSheet: View {
    let tappedLocation: TappedLocation
    let userLocation: CLLocation?
    let onClose: () -> Void
    
    var distance: String {
        guard let userLocation = userLocation else {
            return ""
        }
        
        let location = CLLocation(
            latitude: tappedLocation.coordinate.latitude,
            longitude: tappedLocation.coordinate.longitude
        )
        
        let distanceInMeters = userLocation.distance(from: location)
        let distanceInMiles = distanceInMeters / 1609.34
        
        if distanceInMiles < 0.1 {
            return "Nearby"
        } else if distanceInMiles < 1 {
            return String(format: "%.1f mi away", distanceInMiles)
        } else {
            return String(format: "%.0f mi away", distanceInMiles)
        }
    }
    
    var formattedAddress: String {
        guard let mapItem = tappedLocation.mapItem else {
            return "Unknown Location"
        }

        if let fullAddress = mapItem.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true),
           !fullAddress.isEmpty {
            return fullAddress
        }
        if let address = mapItem.address?.fullAddress, !address.isEmpty {
            return address
        }
        return mapItem.name ?? "Unknown Location"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with gradient
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                    .shadow(color: .orange.opacity(0.3), radius: 8)
                                
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                            }
                            
                            Spacer()
                        }
                        
                        Text("Location Information")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if !distance.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                                
                                Text(distance)
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.orange.opacity(0.1), .red.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    
                    // Address section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Address", systemImage: "building.2.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text(formattedAddress)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Place details if available
                    if let mapItem = tappedLocation.mapItem {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Place Details", systemImage: "info.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            VStack(alignment: .leading, spacing: 8) {
                                if let city = mapItem.addressRepresentations?.cityName {
                                    DetailRow(label: "City", value: city)
                                }

                                if let region = mapItem.addressRepresentations?.regionName {
                                    DetailRow(label: "Region", value: region)
                                }

                                if let timeZone = mapItem.timeZone {
                                    DetailRow(label: "Time Zone", value: timeZone.identifier)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        // Open in Maps button
                        Button {
                            openInMaps()
                            HapticManager.shared.impact(.light)
                        } label: {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("Open in Maps")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.scale)
                        
                        // Share location button
                        ShareLink(
                            item: createMapLink(),
                            subject: Text("Location"),
                            message: Text("Check out this location")
                        ) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Location")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.scale)
                    }
                }
                .padding()
                .padding(.bottom, 100) // Add extra bottom padding to avoid tab bar overlap
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onClose()
                        HapticManager.shared.selection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private func openInMaps() {
        let coordinate = tappedLocation.coordinate
        
        // Use the reverse-geocoded map item when available; otherwise build a
        // bare map item for the tapped coordinate.
        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let mapItem = tappedLocation.mapItem ?? MKMapItem(location: clLocation, address: nil)
        if mapItem.name == nil {
            mapItem.name = "Tapped Location"
        }

        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    private func createMapLink() -> URL {
        let coordinate = tappedLocation.coordinate
        return URL(string: "https://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)&q=Location")!
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

enum ActivityFilter: String, CaseIterable {
    case all = "All Activities"
    case free = "Free Only"
    case saved = "Saved"
    
    var icon: String {
        switch self {
        case .all:
            return "map.fill"
        case .free:
            return "tag.fill"
        case .saved:
            return "bookmark.fill"
        }
    }
    
    var description: String {
        switch self {
        case .all:
            return "Show all nearby activities"
        case .free:
            return "Show only free activities"
        case .saved:
            return "Show your saved activities"
        }
    }
}

enum NearbyTab: String, CaseIterable {
    case activities = "Activities"
    case places = "Places Nearby"
}

/// Merged bottom sheet that shows the user's nearby activities and MapKit
/// kid-friendly places under one segmented control — replaces the two
/// separate floating panels.
struct NearbyListSheet: View {
    @Binding var tab: NearbyTab
    let activities: [Activity]
    let places: [NearbyPlace]
    let savedActivityIds: Set<String>
    let userLocation: CLLocation?
    let onSelectActivity: (Activity) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $tab) {
                    ForEach(NearbyTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if tab == .activities {
                    if activities.isEmpty {
                        ContentUnavailableView(
                            "No Activities",
                            systemImage: "mappin.slash",
                            description: Text("Try adjusting your filters or search.")
                        )
                    } else {
                        List(activities) { activity in
                            ActivityListRow(
                                activity: activity,
                                isSaved: savedActivityIds.contains(activity.id ?? ""),
                                userLocation: userLocation
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelectActivity(activity)
                                dismiss()
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    if places.isEmpty {
                        ContentUnavailableView(
                            "No Places Found",
                            systemImage: "map",
                            description: Text("We couldn't find kid-friendly places nearby yet.")
                        )
                    } else {
                        List(places) { place in
                            NearbyPlaceRow(place: place)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    place.openInMaps()
                                    HapticManager.shared.impact(.medium)
                                }
                                .listRowInsets(EdgeInsets())
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                        HapticManager.shared.selection()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

/// Compact vertical row for an activity in the merged Nearby list.
struct ActivityListRow: View {
    let activity: Activity
    let isSaved: Bool
    let userLocation: CLLocation?

    private var markerColor: Color {
        if isSaved { return .blue }
        if activity.tags.contains("Free") { return .green }
        return .red
    }

    private var distance: String {
        guard let userLocation else { return "" }
        let loc = CLLocation(latitude: activity.location.latitude, longitude: activity.location.longitude)
        let miles = userLocation.distance(from: loc) / 1609.34
        if miles < 0.1 { return "Nearby" }
        if miles < 1 { return String(format: "%.1f mi", miles) }
        return String(format: "%.0f mi", miles)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(markerColor)
                    .frame(width: 40, height: 40)
                Image(systemName: "figure.play")
                    .foregroundStyle(.white)
                    .font(.subheadline)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(activity.location.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if !distance.isEmpty {
                        Text("• \(distance)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            Spacer()
            if isSaved {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Reusable sheet that lets the user set a location either by searching for an
/// address/place (manual) or by tapping "Use Current Location". Used by the map
/// to drop a pin; mirrors the choice offered in the post composer.
struct PlaceSearchSheet: View {
    @Environment(\.dismiss) var dismiss
    var locationManager: LocationManager
    let onSelectPlace: (MKMapItem) -> Void
    let onUseCurrentLocation: () -> Void

    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Manual address / place search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search address or place...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await runSearch() } }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 12)

                // Current location option
                Button {
                    onUseCurrentLocation()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use Current Location")
                                .fontWeight(.medium)
                            Text("Drop a pin where you are now")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(locationManager.currentLocation == nil)
                .opacity(locationManager.currentLocation == nil ? 0.5 : 1)
                .padding(.horizontal)
                .padding(.top, 8)

                if isSearching {
                    ProgressView("Searching...")
                        .padding(.top, 24)
                    Spacer()
                } else if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { item in
                        Button {
                            onSelectPlace(item)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Unnamed place")
                                        .foregroundStyle(.primary)
                                    if let address = item.address?.shortAddress ?? item.address?.fullAddress {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                } else {
                    Spacer()
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { locationManager.startUpdatingLocation() }
        }
    }

    private func runSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let userLocation = locationManager.currentLocation {
            request.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000
            )
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }
        isSearching = false
    }
}

/// Map legend, shown on demand from the "?" button instead of as a
/// permanently-available overlay.
struct LegendSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Kid-appropriate indicator
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                                .frame(width: 38, height: 38)

                            Circle()
                                .fill(.blue)
                                .frame(width: 32, height: 32)

                            Text("3+")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kid-Appropriate")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Green ring with age badge")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)

                    Divider()

                    LegendItem(color: .blue, icon: "bookmark.fill", title: "Saved Activities", description: "Activities you've saved")
                    LegendItem(color: .green, icon: "tag.fill", title: "Free Activities", description: "No cost to participate")
                    LegendItem(color: .red, icon: "figure.play", title: "Paid Activities", description: "Fee required")
                    LegendItem(color: .orange, icon: "mappin.circle.fill", title: "Tapped Location", description: "Tap anywhere to explore")
                }
                .padding()
            }
            .navigationTitle("Map Legend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                        HapticManager.shared.selection()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct LegendItem: View {
    let color: Color
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                    .shadow(color: color.opacity(0.3), radius: 4)
                
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .font(.system(size: 14, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct CategoryChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [Color(.systemGray6), Color(.systemGray6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .shadow(color: isSelected ? .blue.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.scale)
    }
}

struct ActivityQuickCard: View {
    let activity: Activity
    let isSaved: Bool
    let userLocation: CLLocation?
    let action: () -> Void
    
    var distance: String {
        guard let userLocation = userLocation else {
            return ""
        }
        
        let activityLocation = CLLocation(
            latitude: activity.location.latitude,
            longitude: activity.location.longitude
        )
        
        let distanceInMeters = userLocation.distance(from: activityLocation)
        let distanceInMiles = distanceInMeters / 1609.34
        
        if distanceInMiles < 0.1 {
            return "Nearby"
        } else if distanceInMiles < 1 {
            return String(format: "%.1f mi", distanceInMiles)
        } else {
            return String(format: "%.0f mi", distanceInMiles)
        }
    }
    
    var markerColor: Color {
        if isSaved {
            return .blue
        }
        if activity.tags.contains("Free") {
            return .green
        }
        return .red
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(markerColor)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: activity.tags.contains("Sports") ? "figure.run" :
                                activity.tags.contains("Educational") ? "book.fill" :
                                activity.tags.contains("Arts & Crafts") ? "paintpalette.fill" :
                                activity.tags.contains("Music") ? "music.note" :
                                activity.tags.contains("Food & Drinks") ? "fork.knife" :
                                "figure.play")
                            .foregroundStyle(.white)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    if isSaved {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                }
                
                Text(activity.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(activity.location.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                if !distance.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        
                        Text(distance)
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .fontWeight(.medium)
                    }
                }
                
                if !activity.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(activity.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(12)
            .frame(width: 180)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.scale)
    }
}

struct AgeGroupFilterSheet: View {
    @Binding var selectedAgeGroup: String?
    let ageGroupActivities: [String: [Activity]]
    @Environment(\.dismiss) var dismiss
    
    let ageGroups = [
        ("0-1 years", "Infants", "figure.and.child.holdinghands", "Perfect for babies and crawlers"),
        ("1-3 years", "Toddlers", "figure.walk", "Great for little ones learning to walk"),
        ("3-5 years", "Preschool", "figure.run", "Preschool age activities"),
        ("5-12 years", "School Age", "figure.play", "Elementary school kids"),
        ("13-18 years", "Teens", "figure.skiing.downhill", "Teenage activities"),
        ("All Ages", "All Ages", "figure.2.and.child.holdinghands", "Fun for the whole family")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.green, .mint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "figure.2.and.child.holdinghands")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Kid-Appropriate Areas")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                Text("Filter activities by age group")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [.green.opacity(0.1), .mint.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    
                    // Age groups
                    ForEach(ageGroups, id: \.0) { ageGroup in
                        let (value, title, icon, description) = ageGroup
                        let count = ageGroupActivities[value]?.count ?? 0
                        
                        Button {
                            selectedAgeGroup = selectedAgeGroup == value ? nil : value
                            HapticManager.shared.impact(.light)
                            dismiss()
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: selectedAgeGroup == value ? [.green, .mint] : [Color(.systemGray5), Color(.systemGray5)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: icon)
                                        .foregroundStyle(selectedAgeGroup == value ? .white : .secondary)
                                        .font(.title3)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        
                                        Text("(\(count))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                if selectedAgeGroup == value {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.title3)
                                        .symbolEffect(.bounce, value: selectedAgeGroup)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedAgeGroup == value ? Color.green.opacity(0.05) : Color(.systemGray6).opacity(0.5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedAgeGroup == value ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.scale)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .disabled(count == 0)
                        .opacity(count == 0 ? 0.4 : 1.0)
                    }
                    
                    if selectedAgeGroup != nil {
                        Button {
                            withAnimation {
                                selectedAgeGroup = nil
                            }
                            HapticManager.shared.selection()
                            dismiss()
                        } label: {
                            Text("Clear Filter")
                                .font(.headline)
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.green.opacity(0.1))
                                )
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                        HapticManager.shared.selection()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "park", "national park":
            return "leaf.fill"
        case "museum":
            return "building.columns.fill"
        case "zoo":
            return "pawprint.fill"
        case "aquarium":
            return "drop.fill"
        case "library":
            return "book.fill"
        case "playground":
            return "figure.play"
        case "school":
            return "graduationcap.fill"
        default:
            return "mappin.circle.fill"
        }
    }
}

struct NearbyPlaceRow: View {
    let place: NearbyPlace
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconForCategory(place.category))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(place.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(place.distanceString)
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
            
            Spacer()
            
            // Arrow
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "park", "national park":
            return "leaf.fill"
        case "museum":
            return "building.columns.fill"
        case "zoo":
            return "pawprint.fill"
        case "aquarium":
            return "drop.fill"
        case "library":
            return "book.fill"
        case "playground":
            return "figure.play"
        case "school":
            return "graduationcap.fill"
        default:
            return "mappin.circle.fill"
        }
    }
}

// Extension for rounded corners on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    @Previewable @State var isTabBarVisible = true
    MapView(isTabBarVisible: $isTabBarVisible)
        .environment(AuthenticationManager())
}
