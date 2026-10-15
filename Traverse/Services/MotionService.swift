//
//  MotionService.swift
//  Traverse
//

import Foundation
import CoreMotion

@MainActor
@Observable
final class MotionService {
    
    // MARK: - Properties
    
    private let motionActivityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    
    private(set) var currentActivity: ActivityType = .stationary
    private(set) var currentConfidence: ActivityConfidence = .low
    private(set) var isTracking = false
    
    // Debounce state
    private var pendingActivity: ActivityType?
    private var pendingActivityStartTime: Date?
    private let debounceInterval: TimeInterval = 12 // seconds
    
    // Callbacks
    var onActivityChange: ((ActivityType, ActivityConfidence) -> Void)?
    var onStepsUpdate: ((Int, Double?) -> Void)? // steps, distance
    
    // MARK: - Authorization
    
    static var isActivityAvailable: Bool {
        CMMotionActivityManager.isActivityAvailable()
    }
    
    static var isPedometerAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }
    
    var authorizationStatus: CMAuthorizationStatus {
        CMMotionActivityManager.authorizationStatus()
    }
    
    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }
    
    // MARK: - Tracking Control
    
    func startTracking() {
        // Skip if motion activity is not available (e.g., simulator)
        guard Self.isActivityAvailable else {
            print("Motion activity not available on this device")
            isTracking = true // Still mark as tracking so the app flow continues
            return
        }
        
        isTracking = true
        startActivityUpdates()
        startPedometerUpdates()
    }
    
    /// Request authorization by performing a quick query
    /// This triggers the permission dialog without starting continuous updates
    func requestAuthorization() async {
        guard Self.isActivityAvailable else { return }
        
        // Query a small time range to trigger the permission dialog
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        
        _ = try? await queryActivities(from: oneHourAgo, to: now)
    }
    
    func stopTracking() {
        isTracking = false
        
        guard Self.isActivityAvailable else { return }
        
        motionActivityManager.stopActivityUpdates()
        pedometer.stopUpdates()
    }
    
    // MARK: - Activity Updates
    
    private func startActivityUpdates() {
        guard Self.isActivityAvailable else { return }
        
        motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            
            Task { @MainActor in
                self.processActivity(activity)
            }
        }
    }
    
    private func processActivity(_ activity: CMMotionActivity) {
        let detectedType = mapActivityType(from: activity)
        let confidence = mapConfidence(from: activity.confidence)
        
        // If it's the same as current, reset pending state
        if detectedType == currentActivity {
            pendingActivity = nil
            pendingActivityStartTime = nil
            return
        }
        
        // If we're already pending on this activity, check debounce
        if detectedType == pendingActivity, let startTime = pendingActivityStartTime {
            if Date().timeIntervalSince(startTime) >= debounceInterval {
                // Debounce period passed - commit the change
                commitActivityChange(detectedType, confidence: confidence)
            }
            // Otherwise keep waiting
        } else {
            // New pending activity
            pendingActivity = detectedType
            pendingActivityStartTime = Date()
        }
    }
    
    private func commitActivityChange(_ newActivity: ActivityType, confidence: ActivityConfidence) {
        currentActivity = newActivity
        currentConfidence = confidence
        pendingActivity = nil
        pendingActivityStartTime = nil
        
        onActivityChange?(newActivity, confidence)
    }
    
    private func mapActivityType(from activity: CMMotionActivity) -> ActivityType {
        // Priority order: transport modes over stationary
        // At a red light, automotive + stationary can both be true
        if activity.automotive {
            return .vehicle
        }
        if activity.cycling {
            return .cycling
        }
        if activity.running {
            return .running
        }
        if activity.walking {
            return .walking
        }
        if activity.stationary {
            return .stationary
        }
        // Unknown - keep current state
        return currentActivity
    }
    
    private func mapConfidence(from confidence: CMMotionActivityConfidence) -> ActivityConfidence {
        switch confidence {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        @unknown default: return .medium
        }
    }
    
    // MARK: - Pedometer Updates
    
    private func startPedometerUpdates() {
        guard Self.isPedometerAvailable else { return }
        
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            
            Task { @MainActor in
                let steps = data.numberOfSteps.intValue
                let distance = data.distance?.doubleValue
                self.onStepsUpdate?(steps, distance)
            }
        }
    }
    
    // MARK: - Historical Queries
    
    func queryActivities(from startDate: Date, to endDate: Date) async throws -> [CMMotionActivity] {
        guard Self.isActivityAvailable else { return [] }
        
        return try await withCheckedThrowingContinuation { continuation in
            motionActivityManager.queryActivityStarting(from: startDate, to: endDate, to: .main) { activities, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: activities ?? [])
                }
            }
        }
    }
    
    func queryPedometerData(from startDate: Date, to endDate: Date) async throws -> CMPedometerData? {
        guard Self.isPedometerAvailable else { return nil }
        
        return try await withCheckedThrowingContinuation { continuation in
            pedometer.queryPedometerData(from: startDate, to: endDate) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }
    }
    
    // MARK: - Backfill Support
    
    /// Query historical activities and group them into segments
    func backfillActivities(from startDate: Date, to endDate: Date) async throws -> [(ActivityType, Date, Date)] {
        guard Self.isActivityAvailable else { return [] }
        
        let activities = try await queryActivities(from: startDate, to: endDate)
        
        guard !activities.isEmpty else { return [] }
        
        var segments: [(ActivityType, Date, Date)] = []
        var currentSegmentType: ActivityType?
        var segmentStart: Date?
        
        for activity in activities.sorted(by: { $0.startDate < $1.startDate }) {
            let activityType = mapActivityType(from: activity)
            
            if activityType != currentSegmentType {
                // End previous segment
                if let type = currentSegmentType, let start = segmentStart {
                    segments.append((type, start, activity.startDate))
                }
                
                // Start new segment
                currentSegmentType = activityType
                segmentStart = activity.startDate
            }
        }
        
        // Close final segment
        if let type = currentSegmentType, let start = segmentStart {
            segments.append((type, start, endDate))
        }
        
        return segments
    }
}
