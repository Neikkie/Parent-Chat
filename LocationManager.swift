//
//  LocationManager.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/6/26.
//

import Foundation
import CoreLocation
import MapKit

@MainActor
@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // Get location name from coordinates
    func getLocationName(latitude: Double, longitude: Double) async throws -> String {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        
        if let placemark = placemarks.first {
            var components: [String] = []
            
            if let name = placemark.name {
                components.append(name)
            }
            if let locality = placemark.locality {
                components.append(locality)
            }
            if let administrativeArea = placemark.administrativeArea {
                components.append(administrativeArea)
            }
            
            return components.joined(separator: ", ")
        }
        
        return "Unknown Location"
    }
    
    // CLLocationManagerDelegate methods
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            currentLocation = locations.last
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
