//
//  ActivityType.swift
//  Traverse
//

import Foundation
import SwiftUI

enum ActivityType: String, Codable, CaseIterable {
    case walking
    case running
    case cycling
    case vehicle
    case stationary
    
    var displayName: String {
        switch self {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .vehicle: return "Driving"
        case .stationary: return "Stationary"
        }
    }
    
    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .vehicle: return "car.fill"
        case .stationary: return "mappin.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .walking: return ColorTheme.walking
        case .running: return ColorTheme.running
        case .cycling: return ColorTheme.cycling
        case .vehicle: return ColorTheme.vehicle
        case .stationary: return ColorTheme.stationary
        }
    }
    
    var isMovement: Bool {
        switch self {
        case .walking, .running, .cycling, .vehicle:
            return true
        case .stationary:
            return false
        }
    }
}

enum ActivityConfidence: String, Codable {
    case low
    case medium
    case high
}

enum PlaceCategory: String, Codable, CaseIterable {
    case home
    case work
    case food
    case shop
    case gym
    case entertainment
    case transit
    case other
    
    var displayName: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        case .food: return "Food & Drink"
        case .shop: return "Shopping"
        case .gym: return "Gym"
        case .entertainment: return "Entertainment"
        case .transit: return "Transit"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .food: return "fork.knife"
        case .shop: return "bag.fill"
        case .gym: return "dumbbell.fill"
        case .entertainment: return "theatermasks.fill"
        case .transit: return "tram.fill"
        case .other: return "mappin.circle.fill"
        }
    }
}
