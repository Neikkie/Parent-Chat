//
//  AddPostView.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/6/26.
//

import SwiftUI
import FirebaseAuth
import PhotosUI
import MapKit
import CoreLocation
import CoreTransferable
import UniformTypeIdentifiers
import AVFoundation

struct AddPostView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthenticationManager.self) var authManager

    @State private var postContent = ""
    @State private var isPosting = false
    @State private var errorMessage: String?

    // Moderation soft-flag flow
    @State private var showModerationAlert = false
    @State private var pendingMatchedTerm: String?

    // Image / video moderation. Explicit (nudity/sensitive) content is a hard
    // block — this is the Apple / child-safety compliance boundary and stays.
    // Photos of people (including children) are permitted.
    @State private var showImageRejectedAlert = false
    @State private var rejectedImageCount = 0
    @State private var showSensitiveContentNudge = false
    @AppStorage("sca_nudge_shown") private var scaNudgeShown = false

    private let maxCharacters = 500

    // Client-side video limits (kept in sync with the Storage rules cap).
    private let maxVideoBytes: Int64 = 200 * 1024 * 1024
    private let maxVideoSeconds: Double = 60
    @State private var showVideoLimitAlert = false
    
    // Media selection
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var selectedVideos: [SelectedVideo] = []
    @State private var showImagePicker = false
    
    // Location
    @State private var locationManager = LocationManager()
    @State private var selectedLocation: PostLocation?
    @State private var showLocationPicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // User info
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(authManager.userProfile?.username ?? authManager.currentUser?.displayName ?? "User")
                                .font(.headline)
                            Text(authManager.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Update content
                    VStack(alignment: .trailing, spacing: 4) {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $postContent)
                                .frame(minHeight: 150)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(postContent.count > maxCharacters ? Color.red : Color(.systemGray4), lineWidth: 1)
                                )
                                .onChange(of: postContent) { _, newValue in
                                    if newValue.count > maxCharacters {
                                        postContent = String(newValue.prefix(maxCharacters))
                                    }
                                }

                            if postContent.isEmpty {
                                Text("Share a parent update, tip, or local find...")
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 12)
                                    .padding(.top, 16)
                                    .allowsHitTesting(false)
                            }
                        }

                        Text("\(postContent.count)/\(maxCharacters)")
                            .font(.caption)
                            .foregroundStyle(postContent.count > Int(Double(maxCharacters) * 0.9) ? .orange : .secondary)
                    }
                    .padding(.horizontal)
                    
                    // Selected media preview (images + videos)
                    if !selectedImages.isEmpty || !selectedVideos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Button {
                                            selectedImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .red)
                                                .font(.title3)
                                        }
                                        .padding(4)
                                    }
                                }

                                ForEach(selectedVideos) { video in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: video.thumbnail)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                Image(systemName: "play.circle.fill")
                                                    .font(.title)
                                                    .foregroundStyle(.white)
                                                    .shadow(radius: 2)
                                            )

                                        Button {
                                            selectedVideos.removeAll { $0.id == video.id }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .red)
                                                .font(.title3)
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Selected location
                    if let location = selectedLocation {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(location.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            Button {
                                selectedLocation = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Action buttons
                    HStack(spacing: 20) {
                        // Add photo / video button
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("Photo/Video", systemImage: "photo.on.rectangle")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        .disabled(selectedImages.count + selectedVideos.count >= 5)
                        
                        // Add location button
                        Button {
                            showLocationPicker = true
                        } label: {
                            Label("Location", systemImage: "location")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundStyle(.orange)
                        Text("Safety notice: Don't upload explicit, harmful, or illegal content. Posts are moderated and can be reported.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Character count
                    Text("\(postContent.count) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                    
                    if isPosting {
                        ProgressView("Uploading...")
                            .padding()
                    }
                }
            }
            .navigationTitle("Share Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") {
                        Task {
                            await createPost()
                        }
                    }
                    .disabled(!hasPostableContent || isPosting)
                }
            }
            .photosPicker(isPresented: $showImagePicker, selection: $selectedPhotos, maxSelectionCount: 5, matching: .any(of: [.images, .videos]))
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(selectedLocation: $selectedLocation, locationManager: locationManager)
            }
            .onChange(of: selectedPhotos) { oldValue, newValue in
                Task {
                    await loadPhotos()
                }
            }
            .disabled(isPosting)
            .modifier(moderationAlerts)
        }
    }

    private var moderationAlerts: some ViewModifier {
        ModerationAlertsModifier(
            showModerationAlert: $showModerationAlert,
            pendingMatchedTerm: $pendingMatchedTerm,
            showImageRejectedAlert: $showImageRejectedAlert,
            rejectedImageCount: $rejectedImageCount,
            showVideoLimitAlert: $showVideoLimitAlert,
            showSensitiveContentNudge: $showSensitiveContentNudge,
            scaNudgeShown: $scaNudgeShown,
            performPost: { matched in await performPost(matchedTerm: matched) }
        )
    }
    
    private func loadPhotos() async {
        selectedImages.removeAll()
        selectedVideos.removeAll()
        var rejectedSensitive = 0
        var oversizeSkipped = false

        // Show the iOS Settings nudge the first time a user with the system
        // toggle off tries to pick media.
        if !scaNudgeShown && !ImageModerationManager.sensitiveAnalysisAvailable {
            showSensitiveContentNudge = true
        }

        for item in selectedPhotos {
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }

            if isVideo {
                // Import the video to a stable temp file. Explicit content is a
                // hard block; photos of people (incl. children) are allowed.
                guard let movie = try? await item.loadTransferable(type: MovieFile.self) else { continue }

                // Enforce the size / length limits before the (costly) scan.
                let attrs = try? FileManager.default.attributesOfItem(atPath: movie.url.path)
                let sizeBytes = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
                let durationSeconds = (try? await AVURLAsset(url: movie.url).load(.duration))?.seconds ?? 0
                if sizeBytes > maxVideoBytes || durationSeconds > maxVideoSeconds {
                    oversizeSkipped = true
                    try? FileManager.default.removeItem(at: movie.url)
                    continue
                }

                let result = await ImageModerationManager.moderateVideo(at: movie.url)
                if result.isSensitive {
                    rejectedSensitive += 1
                    continue
                }
                let thumbnail = result.thumbnail ?? UIImage(systemName: "video.fill") ?? UIImage()
                selectedVideos.append(SelectedVideo(url: movie.url, thumbnail: thumbnail))
            } else {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { continue }

                let result = await ImageModerationManager.moderate(image)
                if result.isSensitive {
                    rejectedSensitive += 1
                    continue
                }
                selectedImages.append(image)
            }
        }

        if rejectedSensitive > 0 {
            rejectedImageCount = rejectedSensitive
            showImageRejectedAlert = true
            HapticManager.shared.notification(.warning)
        }

        if oversizeSkipped {
            showVideoLimitAlert = true
            HapticManager.shared.notification(.warning)
        }
    }
    
    private var hasPostableContent: Bool {
        !postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !selectedImages.isEmpty
            || !selectedVideos.isEmpty
    }

    private func createPost() async {
        guard hasPostableContent else { return }
        let trimmedContent = postContent.trimmingCharacters(in: .whitespacesAndNewlines)

        if let matchedTerm = ContentModerationManager.firstMatchedBlockedTerm(in: trimmedContent) {
            pendingMatchedTerm = matchedTerm
            showModerationAlert = true
            return
        }

        await performPost(matchedTerm: nil)
    }

    private func performPost(matchedTerm: String?) async {
        guard let user = authManager.currentUser else { return }
        let trimmedContent = postContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasPostableContent else { return }

        isPosting = true
        errorMessage = nil

        do {
            var postMedia: [PostMedia] = []

            // Upload images to Firebase Storage.
            for image in selectedImages {
                let imageURL = try await StorageManager.shared.uploadImage(image, userId: user.uid)
                postMedia.append(PostMedia(url: imageURL, type: .image))

                // Defensive audit log — double-check at upload time for the
                // moderation log. Both face detection and sensitive-content
                // analysis are recorded.
                let result = await ImageModerationManager.moderate(image)
                try? await FirestoreManager.shared.logImageUpload(
                    userId: user.uid,
                    imageUrl: imageURL,
                    hasDetectedFace: result.hasFace
                )
            }

            // Upload videos to Firebase Storage (with a generated thumbnail).
            for video in selectedVideos {
                let uploaded = try await StorageManager.shared.uploadVideo(video.url, userId: user.uid)
                postMedia.append(PostMedia(url: uploaded.videoURL, type: .video, thumbnailUrl: uploaded.thumbnailURL))

                let hasFace = await ImageModerationManager.containsAnyFace(video.thumbnail)
                try? await FirestoreManager.shared.logImageUpload(
                    userId: user.uid,
                    imageUrl: uploaded.videoURL,
                    hasDetectedFace: hasFace
                )
            }

            let userName = authManager.publicDisplayName
            try await FirestoreManager.shared.createPost(
                content: trimmedContent,
                userId: user.uid,
                userName: userName,
                userProfileImageUrl: authManager.userProfile?.profileImageUrl,
                media: postMedia.isEmpty ? nil : postMedia,
                location: selectedLocation
            )

            // Soft-flag for moderator review if the content matched a guideline term.
            if let matchedTerm {
                try? await FirestoreManager.shared.flagContent(
                    contentType: "post",
                    contentId: nil,
                    postId: nil,
                    userId: user.uid,
                    userName: userName,
                    matchedTerm: matchedTerm,
                    content: trimmedContent
                )
            }

            dismiss()
        } catch {
            errorMessage = "Failed to create post: \(error.localizedDescription)"
            isPosting = false
        }
    }
}

// Splits the four moderation/safety alerts out of AddPostView's body so the
// Swift type-checker doesn't time out.
private struct ModerationAlertsModifier: ViewModifier {
    @Binding var showModerationAlert: Bool
    @Binding var pendingMatchedTerm: String?
    @Binding var showImageRejectedAlert: Bool
    @Binding var rejectedImageCount: Int
    @Binding var showVideoLimitAlert: Bool
    @Binding var showSensitiveContentNudge: Bool
    @Binding var scaNudgeShown: Bool
    let performPost: (String) async -> Void

    func body(content: Content) -> some View {
        content
            .alert("Content May Violate Guidelines", isPresented: $showModerationAlert) {
                Button("Edit", role: .cancel) {
                    pendingMatchedTerm = nil
                }
                Button("Post Anyway", role: .destructive) {
                    let term = pendingMatchedTerm ?? "unknown"
                    pendingMatchedTerm = nil
                    Task { await performPost(term) }
                }
            } message: {
                Text("Your post contains language that may violate our community guidelines. You can edit it before posting, or post anyway — our team will review it.")
            }
            .alert("Photo Not Allowed", isPresented: $showImageRejectedAlert) {
                Button("OK", role: .cancel) {
                    rejectedImageCount = 0
                }
            } message: {
                Text(rejectedImageCount == 1
                     ? "An item you selected was flagged as containing sensitive content and removed."
                     : "\(rejectedImageCount) items you selected were flagged as containing sensitive content and removed.")
            }
            .alert("Video Too Large", isPresented: $showVideoLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Videos must be under 60 seconds and 200 MB. One or more videos you selected were skipped.")
            }
            .alert("Improve Photo Safety", isPresented: $showSensitiveContentNudge) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    scaNudgeShown = true
                }
                Button("Not Now", role: .cancel) {
                    scaNudgeShown = true
                }
            } message: {
                Text("Turn on \"Sensitive Content Warning\" in iOS Settings → Privacy & Security to let Parent Chat block explicit photos before they're posted. This is optional but recommended.")
            }
    }
}

// A video the user picked in the composer: the imported local file plus a
// thumbnail frame used for the preview and face-detection attestation.
struct SelectedVideo: Identifiable {
    let id = UUID()
    let url: URL
    let thumbnail: UIImage
}

// Transferable wrapper so a picked video can be imported to a stable temp file
// URL. PhotosPickerItem hands back a short-lived file, so we copy it out.
struct MovieFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

// Location Picker View
struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLocation: PostLocation?
    @State var locationManager: LocationManager

    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var isLoadingLocation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar — manual input
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search for a place...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await runSearch() }
                        }
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

                if isSearching {
                    ProgressView("Searching...")
                        .padding(.top, 24)
                } else if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { item in
                        Button {
                            useSearchResult(item)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Unnamed place")
                                        .foregroundStyle(.primary)
                                    if let address = item.placemark.title {
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
                    VStack(spacing: 16) {
                        if locationManager.authorizationStatus == .notDetermined {
                            VStack(spacing: 16) {
                                Image(systemName: "location.circle")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.blue)
                                Text("Location Access")
                                    .font(.headline)
                                Text("Allow Parent Chat to access your location to tag where you are. You can also type a place above.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                Button("Allow Location Access") {
                                    locationManager.requestPermission()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.top, 32)
                        } else if locationManager.authorizationStatus == .denied {
                            VStack(spacing: 12) {
                                Image(systemName: "location.slash")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.red)
                                Text("Location Access Denied")
                                    .font(.headline)
                                Text("You can still type a place above to tag it.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding(.top, 32)
                        } else if let location = locationManager.currentLocation {
                            Button {
                                Task { await useCurrentLocation(location) }
                            } label: {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundStyle(.blue)
                                    VStack(alignment: .leading) {
                                        Text("Use Current Location")
                                            .font(.headline)
                                        Text("Use detected address")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            .padding(.top, 16)
                        } else if isLoadingLocation {
                            ProgressView("Getting your location...")
                                .padding(.top, 32)
                        }

                        Spacer()
                    }
                    .onAppear {
                        locationManager.startUpdatingLocation()
                    }
                    .onDisappear {
                        locationManager.stopUpdatingLocation()
                    }
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
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

    private func useSearchResult(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        let displayName = item.name ?? item.placemark.title ?? "Selected location"
        selectedLocation = PostLocation(
            name: displayName,
            latitude: coord.latitude,
            longitude: coord.longitude
        )
        HapticManager.shared.notification(.success)
        dismiss()
    }

    private func useCurrentLocation(_ location: CLLocation) async {
        isLoadingLocation = true
        
        do {
            let locationName = try await locationManager.getLocationName(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            selectedLocation = PostLocation(
                name: locationName,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            dismiss()
        } catch {
            print("Error getting location name: \(error.localizedDescription)")
        }
        
        isLoadingLocation = false
    }
}

#Preview {
    AddPostView()
        .environment(AuthenticationManager())
}
