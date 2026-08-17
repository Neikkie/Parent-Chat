//
//  NearbyPlaceModel.swift
//  Parent Chat
//
//  Created by Claude Code on 4/21/26.
//

import Foundation
import MapKit
import Observation

struct NearbyPlace: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    let distance: CLLocationDistance
    
    var name: String {
        mapItem.name ?? "Unknown Place"
    }
    
    var category: String {
        if let category = mapItem.pointOfInterestCategory {
            return categoryDisplayName(for: category)
        }
        return "Place"
    }
    
    var coordinate: CLLocationCoordinate2D {
        mapItem.placemark.coordinate
    }
    
    var distanceString: String {
        let distanceInMiles = distance / 1609.34
        if distanceInMiles < 0.1 {
            return "Nearby"
        } else if distanceInMiles < 1 {
            return String(format: "%.1f mi", distanceInMiles)
        } else {
            return String(format: "%.1f mi", distanceInMiles)
        }
    }
    
    private func categoryDisplayName(for category: MKPointOfInterestCategory) -> String {
        switch category {
        case .park:
            return "Park"
        case .museum:
            return "Museum"
        case .zoo:
            return "Zoo"
        case .aquarium:
            return "Aquarium"
        case .library:
            return "Library"
        case .nationalPark:
            return "National Park"
        case .school:
            return "School"
        default:
            return "Place"
        }
    }
    
    func openInMaps() {
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

@Observable
class NearbyPlacesSearcher {
    var nearbyPlaces: [NearbyPlace] = []
    var isSearching = false
    
    private let kidFriendlyCategories: [MKPointOfInterestCategory] = [
        .park,
        .museum,
        .zoo,
        .aquarium,
        .library,
        .nationalPark,
        .school
    ]
    
    @MainActor
    func searchNearbyPlaces(around location: CLLocation, radius: CLLocationDistance = 5000) async {
        isSearching = true
        defer { isSearching = false }
        
        var allPlaces: [NearbyPlace] = []
        
        // Search for each category
        for category in kidFriendlyCategories {
            let request = MKLocalSearch.Request()
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: radius,
                longitudinalMeters: radius
            )
            
            let search = MKLocalSearch(request: request)
            
            do {
                let response = try await search.start()
                
                for item in response.mapItems {
                    let itemLocation = CLLocation(
                        latitude: item.placemark.coordinate.latitude,
                        longitude: item.placemark.coordinate.longitude
                    )
                    let distance = location.distance(from: itemLocation)
                    
                    let place = NearbyPlace(mapItem: item, distance: distance)
                    allPlaces.append(place)
                }
            } catch {
                print("❌ Search failed for \(category): \(error.localizedDescription)")
            }
        }
        
        // Remove duplicates based on name and location
        let uniquePlaces = removeDuplicates(from: allPlaces)
        
        // Sort by distance
        nearbyPlaces = uniquePlaces.sorted { $0.distance < $1.distance }
        
        print("✅ Found \(nearbyPlaces.count) nearby kid-friendly places")
    }
    
    private func removeDuplicates(from places: [NearbyPlace]) -> [NearbyPlace] {
        var seen = Set<String>()
        var unique: [NearbyPlace] = []
        
        for place in places {
            let key = "\(place.name)-\(place.coordinate.latitude)-\(place.coordinate.longitude)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(place)
            }
        }
        
        return unique
    }
}
