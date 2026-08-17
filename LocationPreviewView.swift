//
//  LocationPreviewView.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/11/26.
//

import SwiftUI
import MapKit

struct LocationPreviewView: View {
    let location: PostLocation
    @Environment(\.dismiss) var dismiss
    
    @State private var cameraPosition: MapCameraPosition
    @State private var selectedMapStyle = 0 // 0: standard, 1: hybrid, 2: imagery
    
    var mapStyle: MapStyle {
        switch selectedMapStyle {
        case 1: return .hybrid
        case 2: return .imagery
        default: return .standard
        }
    }
    
    init(location: PostLocation) {
        self.location = location
        
        let coordinate = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
        
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Map view
                Map(position: $cameraPosition, interactionModes: .all) {
                    Annotation(location.name, coordinate: CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 40, height: 40)
                                    .shadow(color: .black.opacity(0.3), radius: 4)
                                
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.white)
                                    .font(.title2)
                            }
                            
                            Triangle()
                                .fill(Color.red)
                                .frame(width: 12, height: 8)
                                .offset(y: -2)
                        }
                        .onTapGesture {
                            // Recenter on location when tapping the pin
                            withAnimation {
                                cameraPosition = .region(
                                    MKCoordinateRegion(
                                        center: CLLocationCoordinate2D(
                                            latitude: location.latitude,
                                            longitude: location.longitude
                                        ),
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    )
                                )
                            }
                        }
                    }
                }
                .mapStyle(mapStyle)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                    MapPitchToggle()
                }
                
                // Location details
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.name)
                                .font(.headline)

                            Text("Address")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Map style picker
                    Picker("Map Style", selection: $selectedMapStyle) {
                        Text("Standard").tag(0)
                        Text("Hybrid").tag(1)
                        Text("Imagery").tag(2)
                    }
                    .pickerStyle(.segmented)
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        // Open in Maps
                        Button {
                            openInMaps()
                        } label: {
                            Label("Open in Maps", systemImage: "map")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        // Get Directions
                        Button {
                            getDirections()
                        } label: {
                            Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("Location")
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
    
    private func openInMaps() {
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let mapItem = MKMapItem(location: clLocation, address: nil)
        mapItem.name = location.name
        mapItem.openInMaps(launchOptions: nil)
    }
    
    private func getDirections() {
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let mapItem = MKMapItem(location: clLocation, address: nil)
        mapItem.name = location.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

#Preview {
    LocationPreviewView(location: PostLocation(
        name: "Central Park, New York, NY",
        latitude: 40.7829,
        longitude: -73.9654
    ))
}
