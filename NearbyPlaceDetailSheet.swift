//
//  NearbyPlaceDetailSheet.swift
//  Parent Chat
//
//  Created by Claude Code on 4/21/26.
//

import SwiftUI
import MapKit

struct NearbyPlaceDetailSheet: View {
    let place: NearbyPlace
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(place.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(place.category)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                    
                    Divider()
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        PlaceActionButton(
                            icon: "location.fill",
                            title: "Directions",
                            color: .blue
                        ) {
                            place.openInMaps()
                            HapticManager.shared.impact(.medium)
                        }
                        
                        if let phone = place.mapItem.phoneNumber {
                            PlaceActionButton(
                                icon: "phone.fill",
                                title: "Call",
                                color: .green
                            ) {
                                if let url = URL(string: "tel://\(phone.filter { $0.isNumber })") {
                                    UIApplication.shared.open(url)
                                    HapticManager.shared.impact(.medium)
                                }
                            }
                        }
                        
                        if let url = place.mapItem.url {
                            PlaceActionButton(
                                icon: "safari.fill",
                                title: "Website",
                                color: .purple
                            ) {
                                UIApplication.shared.open(url)
                                HapticManager.shared.impact(.medium)
                            }
                        }
                        
                        PlaceActionButton(
                            icon: "square.and.arrow.up",
                            title: "Share",
                            color: .orange
                        ) {
                            sharePlace()
                            HapticManager.shared.impact(.light)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    Divider()
                    
                    // Information Section
                    VStack(alignment: .leading, spacing: 16) {
                        // Distance
                        InfoRow(
                            icon: "location.circle.fill",
                            title: "Distance",
                            value: place.distanceString,
                            color: .blue
                        )
                        
                        // Address
                        if let address = formattedAddress {
                            InfoRow(
                                icon: "mappin.circle.fill",
                                title: "Address",
                                value: address,
                                color: .red
                            )
                        }
                        
                        // Phone
                        if let phone = place.mapItem.phoneNumber {
                            InfoRow(
                                icon: "phone.circle.fill",
                                title: "Phone",
                                value: phone,
                                color: .green
                            )
                        }
                        
                        // Category type
                        InfoRow(
                            icon: "tag.circle.fill",
                            title: "Type",
                            value: place.category,
                            color: .orange
                        )
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    Divider()
                    
                    // Map Preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: place.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))) {
                            Annotation(place.name, coordinate: place.coordinate) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.cyan, .blue],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: iconForCategory(place.category))
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(height: 200)
                        .cornerRadius(12)
                        .allowsHitTesting(false)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .background(Color(.systemBackground))
                    
                    // Extra padding at bottom for tab bar
                    Color.clear
                        .frame(height: 120)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
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
    
    private var formattedAddress: String? {
        let placemark = place.mapItem.placemark
        
        var components: [String] = []
        
        if let street = placemark.thoroughfare {
            if let number = placemark.subThoroughfare {
                components.append("\(number) \(street)")
            } else {
                components.append(street)
            }
        }
        
        if let city = placemark.locality {
            components.append(city)
        }
        
        if let state = placemark.administrativeArea {
            components.append(state)
        }
        
        if let zip = placemark.postalCode {
            components.append(zip)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    private func sharePlace() {
        let coordinate = place.coordinate
        let url = URL(string: "https://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)&q=\(place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
        
        let activityController = UIActivityViewController(
            activityItems: [place.name, url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityController, animated: true)
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

struct PlaceActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
}

#Preview {
    @Previewable @State var place = NearbyPlace(
        mapItem: MKMapItem(),
        distance: 1000
    )
    
    NearbyPlaceDetailSheet(place: place)
}
