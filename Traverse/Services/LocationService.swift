//
//  LocationService.swift
//  Traverse
//

import Foundation
import CoreLocation
import UIKit

@MainActor
@Observable
final class LocationService: NSObject {
    
    // MARK: - Properties
    
    private let locationManager = CLLocationManager()
    
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var currentLocation: CLLocation?
    private(set) var isTracking = false
    
    // Callbacks for the TimelineEngine
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onVisit: ((CLVisit) -> Void)?
    var onSignificantLocationChange: ((CLLocation) -> Void)?
    
    // Battery monitoring
    private var batteryLevel: Float {
        UIDevice.current.batteryLevel
    }
    
    private var isLowPowerMode: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.showsBackgroundLocationIndicator = true
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Authorization
    
    var isAuthorized: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }
    
    var hasAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedAlways
    }
    
    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Tracking Control
    
    func startTracking() {
        guard isAuthorized else { return }
        
        isTracking = true
        
        // Always start visit monitoring (very low battery cost)
        locationManager.startMonitoringVisits()
        
        // Start significant location change monitoring
        locationManager.startMonitoringSignificantLocationChanges()
        
        // Start standard location updates if we have always authorization
        if hasAlwaysAuthorization {
            startStandardLocationUpdates(for: .stationary)
        }
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopMonitoringVisits()
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Adaptive Location Updates
    
    func updateTrackingMode(for activityType: ActivityType) {
        guard isTracking else { return }
        
        // Low battery mode - minimal tracking
        if batteryLevel < 0.20 || isLowPowerMode {
            locationManager.stopUpdatingLocation()
            // Keep visit and significant location monitoring
            return
        }
        
        switch activityType {
        case .stationary:
            // When stationary, we don't need continuous GPS
            locationManager.stopUpdatingLocation()
            
        case .walking, .running:
            startStandardLocationUpdates(for: activityType)
            locationManager.activityType = .fitness
            locationManager.distanceFilter = 10 // meters
            
        case .cycling:
            startStandardLocationUpdates(for: activityType)
            locationManager.activityType = .fitness
            locationManager.distanceFilter = 15 // meters
            
        case .vehicle:
            startStandardLocationUpdates(for: activityType)
            locationManager.activityType = .automotiveNavigation
            locationManager.distanceFilter = 25 // meters
        }
    }
    
    private func startStandardLocationUpdates(for activity: ActivityType) {
        locationManager.desiredAccuracy = activity == .vehicle
            ? kCLLocationAccuracyNearestTenMeters
            : kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - One-time Location Request
    
    func requestCurrentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            let request = SingleLocationRequest(continuation: continuation)
            singleLocationRequest = request
            locationManager.requestLocation()
        }
    }
    
    private var singleLocationRequest: SingleLocationRequest?
    
    private struct SingleLocationRequest {
        let continuation: CheckedContinuation<CLLocation, Error>
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            
            if isAuthorized && !isTracking {
                startTracking()
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            
            // Filter out inaccurate locations
            guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy < 100 else {
                return
            }
            
            currentLocation = location
            
            // Handle single location request
            if let request = singleLocationRequest {
                request.continuation.resume(returning: location)
                singleLocationRequest = nil
                return
            }
            
            // Notify for route tracking
            onLocationUpdate?(location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Task { @MainActor in
            onVisit?(visit)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // Handle single location request failure
            if let request = singleLocationRequest {
                request.continuation.resume(throwing: error)
                singleLocationRequest = nil
            }
            
            print("Location error: \(error.localizedDescription)")
        }
    }
}
