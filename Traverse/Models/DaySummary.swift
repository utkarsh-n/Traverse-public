//
//  DaySummary.swift
//  Traverse
//

import Foundation

struct DaySummary {
    let date: Date
    let segments: [TimelineSegment]
    let places: [PlaceVisit]
    
    var totalSteps: Int {
        segments.compactMap(\.steps).reduce(0, +)
    }
    
    var totalDistanceMeters: Double {
        segments.compactMap(\.distanceMeters).reduce(0, +)
    }
    
    var walkingDuration: TimeInterval {
        durationForActivity(.walking)
    }
    
    var runningDuration: TimeInterval {
        durationForActivity(.running)
    }
    
    var cyclingDuration: TimeInterval {
        durationForActivity(.cycling)
    }
    
    var vehicleDuration: TimeInterval {
        durationForActivity(.vehicle)
    }
    
    var totalActiveTime: TimeInterval {
        walkingDuration + runningDuration + cyclingDuration + vehicleDuration
    }
    
    func durationForActivity(_ type: ActivityType) -> TimeInterval {
        segments
            .filter { $0.activityType == type }
            .reduce(0) { $0 + $1.duration }
    }
    
    func distanceForActivity(_ type: ActivityType) -> Double {
        segments
            .filter { $0.activityType == type }
            .compactMap(\.distanceMeters)
            .reduce(0, +)
    }
    
    func stepsForActivity(_ type: ActivityType) -> Int {
        segments
            .filter { $0.activityType == type }
            .compactMap(\.steps)
            .reduce(0, +)
    }
    
    var activitiesWithData: [ActivityType] {
        ActivityType.allCases.filter { type in
            type.isMovement && durationForActivity(type) > 0
        }
    }
}
