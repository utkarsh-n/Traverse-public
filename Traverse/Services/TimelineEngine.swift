//
//  TimelineEngine.swift
//  Traverse
//

import Foundation
import SwiftData
import CoreLocation
import CoreMotion

@MainActor
@Observable
final class TimelineEngine {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let locationService: LocationService
    private let motionService: MotionService
    private let placeResolver: PlaceResolver
    
    private(set) var currentSegment: TimelineSegment?
    private(set) var currentPlace: PlaceVisit?
    private(set) var isRunning = false
    
    // Minimum segment duration before it gets merged
    private let minimumSegmentDuration: TimeInterval = 120 // 2 minutes
    
    // Last processed timestamps for gap recovery
    private var lastProcessedTimestamp: Date?
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, locationService: LocationService, motionService: MotionService, placeResolver: PlaceResolver) {
        self.modelContext = modelContext
        self.locationService = locationService
        self.motionService = motionService
        self.placeResolver = placeResolver
        
        setupCallbacks()
    }
    
    // MARK: - Setup
    
    private func setupCallbacks() {
        // Activity changes from MotionService
        motionService.onActivityChange = { [weak self] activityType, confidence in
            Task { @MainActor in
                self?.handleActivityChange(activityType, confidence: confidence)
            }
        }
        
        // Location updates for route tracking
        locationService.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                self?.handleLocationUpdate(location)
            }
        }
        
        // Visit events for place detection
        locationService.onVisit = { [weak self] visit in
            Task { @MainActor in
                self?.handleVisit(visit)
            }
        }
        
        // Steps updates
        motionService.onStepsUpdate = { [weak self] steps, distance in
            Task { @MainActor in
                self?.handleStepsUpdate(steps: steps, distance: distance)
            }
        }
    }
    
    // MARK: - Start/Stop
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        locationService.startTracking()
        motionService.startTracking()
        
        // Resume or create initial segment
        resumeOrCreateSegment()
        
        // Perform gap recovery
        Task {
            await performGapRecovery()
        }
    }
    
    func stop() {
        isRunning = false
        locationService.stopTracking()
        motionService.stopTracking()
        
        // End current segment
        if let segment = currentSegment {
            segment.endTime = Date()
        }
        
        // End current place visit
        if let place = currentPlace {
            place.departureTime = Date()
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Activity Handling
    
    private func handleActivityChange(_ newActivity: ActivityType, confidence: ActivityConfidence) {
        let now = Date()
        
        // End current segment if exists
        if let current = currentSegment {
            current.endTime = now
            
            // Check if segment is too short and should be absorbed
            if current.duration < minimumSegmentDuration {
                modelContext.delete(current)
            }
        }
        
        // Handle place transitions
        if newActivity == .stationary {
            // User became stationary - might be arriving at a place
            // Wait for CLVisit to confirm
        } else if currentSegment?.activityType == .stationary {
            // User started moving - end current place visit
            if let place = currentPlace {
                place.departureTime = now
                currentPlace = nil
            }
        }
        
        // Create new segment
        let newSegment = TimelineSegment(
            activityType: newActivity,
            startTime: now,
            confidence: confidence
        )
        modelContext.insert(newSegment)
        currentSegment = newSegment
        
        // Update location tracking mode based on activity
        locationService.updateTrackingMode(for: newActivity)
        
        try? modelContext.save()
        lastProcessedTimestamp = now
    }
    
    // MARK: - Location Handling
    
    private func handleLocationUpdate(_ location: CLLocation) {
        guard let segment = currentSegment, segment.activityType.isMovement else { return }
        
        // Add coordinate to current segment's route
        let point = CoordinatePoint(
            coordinate: location.coordinate,
            timestamp: location.timestamp
        )
        segment.routeCoordinates.append(point)
        modelContext.insert(point)
        
        // Update distance for vehicle/cycling (pedometer handles walking/running)
        if segment.activityType == .vehicle || segment.activityType == .cycling {
            let coordinates = segment.sortedRouteCoordinates.map { $0.coordinate }
            segment.distanceMeters = coordinates.totalDistance
        }
        
        try? modelContext.save()
    }
    
    private func handleVisit(_ visit: CLVisit) {
        let arrivalDate = visit.arrivalDate
        let departureDate = visit.departureDate
        
        // Ignore invalid visits
        guard arrivalDate != .distantPast else { return }
        
        // Check if this is a known place (within clustering distance)
        let existingPlace = findNearbyPlace(to: visit.coordinate, within: 80) // 80 meters
        
        if departureDate == .distantFuture {
            // User just arrived - create or update place visit
            if let existing = existingPlace {
                // Same place - create new visit
                let newVisit = PlaceVisit(
                    coordinate: visit.coordinate,
                    arrivalTime: arrivalDate
                )
                newVisit.name = existing.name
                newVisit.address = existing.address
                newVisit.category = existing.category
                newVisit.isUserLabeled = existing.isUserLabeled
                modelContext.insert(newVisit)
                currentPlace = newVisit
            } else {
                // New place - geocode it
                let newVisit = PlaceVisit(
                    coordinate: visit.coordinate,
                    arrivalTime: arrivalDate
                )
                modelContext.insert(newVisit)
                currentPlace = newVisit
                
                // Resolve place name asynchronously
                Task {
                    await placeResolver.resolvePlaceName(for: newVisit)
                    try? modelContext.save()
                }
            }
        } else {
            // Visit completed - update departure time
            if let current = currentPlace,
               current.distance(to: visit.coordinate) < 80 {
                current.departureTime = departureDate
            }
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Steps Handling
    
    private func handleStepsUpdate(steps: Int, distance: Double?) {
        guard let segment = currentSegment,
              segment.activityType == .walking || segment.activityType == .running else {
            return
        }
        
        segment.steps = steps
        if let distance {
            segment.distanceMeters = distance
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Gap Recovery
    
    private func performGapRecovery() async {
        let now = Date()
        let startOfToday = now.startOfDay
        
        // Determine the gap start time
        let gapStart: Date
        if let lastTimestamp = lastProcessedTimestamp {
            gapStart = lastTimestamp
        } else {
            // First launch today - backfill from start of day
            gapStart = startOfToday
        }
        
        // Don't backfill if gap is too small
        guard now.timeIntervalSince(gapStart) > 60 else { return }
        
        do {
            // Query Core Motion history
            let segments = try await motionService.backfillActivities(from: gapStart, to: now)
            
            for (activityType, startTime, endTime) in segments {
                // Skip very short segments
                guard endTime.timeIntervalSince(startTime) >= minimumSegmentDuration else { continue }
                
                let segment = TimelineSegment(
                    activityType: activityType,
                    startTime: startTime,
                    endTime: endTime,
                    confidence: .medium
                )
                
                // Try to get pedometer data for walking/running
                if activityType == .walking || activityType == .running {
                    if let pedometerData = try? await motionService.queryPedometerData(from: startTime, to: endTime) {
                        segment.steps = pedometerData.numberOfSteps.intValue
                        segment.distanceMeters = pedometerData.distance?.doubleValue
                    }
                }
                
                modelContext.insert(segment)
            }
            
            try? modelContext.save()
            lastProcessedTimestamp = now
            
        } catch {
            print("Gap recovery failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Resume
    
    private func resumeOrCreateSegment() {
        // Try to find an ongoing segment from today
        let startOfToday = Date().startOfDay
        
        let descriptor = FetchDescriptor<TimelineSegment>(
            predicate: #Predicate { segment in
                segment.startTime >= startOfToday && segment.endTime == nil
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        if let ongoingSegment = try? modelContext.fetch(descriptor).first {
            currentSegment = ongoingSegment
            locationService.updateTrackingMode(for: ongoingSegment.activityType)
        } else {
            // Create initial stationary segment
            let segment = TimelineSegment(
                activityType: .stationary,
                startTime: Date(),
                confidence: .low
            )
            modelContext.insert(segment)
            currentSegment = segment
            try? modelContext.save()
        }
        
        // Try to find ongoing place visit
        let placeDescriptor = FetchDescriptor<PlaceVisit>(
            predicate: #Predicate { place in
                place.arrivalTime >= startOfToday && place.departureTime == nil
            },
            sortBy: [SortDescriptor(\.arrivalTime, order: .reverse)]
        )
        
        if let ongoingPlace = try? modelContext.fetch(placeDescriptor).first {
            currentPlace = ongoingPlace
        }
    }
    
    // MARK: - Daily Rollover
    
    func performDailyRollover() {
        let endOfYesterday = Date().startOfDay.addingTimeInterval(-1)
        
        // End all ongoing segments at end of yesterday
        if let segment = currentSegment, segment.startTime < Date().startOfDay {
            segment.endTime = endOfYesterday
            
            // Create new segment for today
            let newSegment = TimelineSegment(
                activityType: segment.activityType,
                startTime: Date().startOfDay,
                confidence: segment.confidence
            )
            modelContext.insert(newSegment)
            currentSegment = newSegment
        }
        
        // End all ongoing place visits at end of yesterday
        if let place = currentPlace, place.arrivalTime < Date().startOfDay {
            place.departureTime = endOfYesterday
            
            // Create new visit for today
            let newPlace = PlaceVisit(
                latitude: place.latitude,
                longitude: place.longitude,
                arrivalTime: Date().startOfDay,
                name: place.name,
                address: place.address,
                category: place.category,
                isUserLabeled: place.isUserLabeled
            )
            modelContext.insert(newPlace)
            currentPlace = newPlace
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Queries
    
    func fetchSegments(for date: Date) -> [TimelineSegment] {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay
        
        let descriptor = FetchDescriptor<TimelineSegment>(
            predicate: #Predicate { segment in
                segment.startTime >= startOfDay && segment.startTime <= endOfDay
            },
            sortBy: [SortDescriptor(\.startTime)]
        )
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func fetchPlaces(for date: Date) -> [PlaceVisit] {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay
        
        let descriptor = FetchDescriptor<PlaceVisit>(
            predicate: #Predicate { place in
                place.arrivalTime >= startOfDay && place.arrivalTime <= endOfDay
            },
            sortBy: [SortDescriptor(\.arrivalTime)]
        )
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func getDaySummary(for date: Date) -> DaySummary {
        DaySummary(
            date: date,
            segments: fetchSegments(for: date),
            places: fetchPlaces(for: date)
        )
    }
    
    // MARK: - Helpers
    
    private func findNearbyPlace(to coordinate: CLLocationCoordinate2D, within meters: Double) -> PlaceVisit? {
        let allPlaces = (try? modelContext.fetch(FetchDescriptor<PlaceVisit>())) ?? []
        
        return allPlaces.first { place in
            place.distance(to: coordinate) < meters
        }
    }
}
