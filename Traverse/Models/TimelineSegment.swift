//
//  TimelineSegment.swift
//  Traverse
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class TimelineSegment {
    @Attribute(.unique) var id: UUID
    var activityTypeRaw: String
    var startTime: Date
    var endTime: Date?
    var steps: Int?
    var distanceMeters: Double?
    var confidenceRaw: String
    
    @Relationship(deleteRule: .cascade, inverse: \CoordinatePoint.segment)
    var routeCoordinates: [CoordinatePoint] = []
    
    var activityType: ActivityType {
        get { ActivityType(rawValue: activityTypeRaw) ?? .stationary }
        set { activityTypeRaw = newValue.rawValue }
    }
    
    var confidence: ActivityConfidence {
        get { ActivityConfidence(rawValue: confidenceRaw) ?? .medium }
        set { confidenceRaw = newValue.rawValue }
    }
    
    var isOngoing: Bool {
        endTime == nil
    }
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    var durationFormatted: String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hr"
            }
            return "\(hours) hr \(remainingMinutes) min"
        }
    }
    
    var distanceFormatted: String {
        guard let distance = distanceMeters else { return "" }
        let km = distance / 1000.0
        if km < 1.0 {
            return String(format: "%.0f m", distance)
        }
        return String(format: "%.1f km", km)
    }
    
    var averageSpeedKmh: Double? {
        guard let distance = distanceMeters, duration > 0 else { return nil }
        let hours = duration / 3600.0
        return (distance / 1000.0) / hours
    }
    
    init(
        id: UUID = UUID(),
        activityType: ActivityType,
        startTime: Date,
        endTime: Date? = nil,
        steps: Int? = nil,
        distanceMeters: Double? = nil,
        confidence: ActivityConfidence = .medium
    ) {
        self.id = id
        self.activityTypeRaw = activityType.rawValue
        self.startTime = startTime
        self.endTime = endTime
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.confidenceRaw = confidence.rawValue
    }
    
    var sortedRouteCoordinates: [CoordinatePoint] {
        routeCoordinates.sorted { $0.timestamp < $1.timestamp }
    }
}
