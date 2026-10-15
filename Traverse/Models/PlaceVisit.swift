//
//  PlaceVisit.swift
//  Traverse
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class PlaceVisit {
    @Attribute(.unique) var id: UUID
    var latitude: Double
    var longitude: Double
    var arrivalTime: Date
    var departureTime: Date?
    var name: String?
    var address: String?
    var categoryRaw: String?
    var isUserLabeled: Bool
    
    var category: PlaceCategory? {
        get {
            guard let raw = categoryRaw else { return nil }
            return PlaceCategory(rawValue: raw)
        }
        set {
            categoryRaw = newValue?.rawValue
        }
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var isOngoing: Bool {
        departureTime == nil
    }
    
    var duration: TimeInterval {
        let end = departureTime ?? Date()
        return end.timeIntervalSince(arrivalTime)
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
    
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        if let address = address, !address.isEmpty {
            return address
        }
        return "Unknown Place"
    }
    
    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        arrivalTime: Date,
        departureTime: Date? = nil,
        name: String? = nil,
        address: String? = nil,
        category: PlaceCategory? = nil,
        isUserLabeled: Bool = false
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.name = name
        self.address = address
        self.categoryRaw = category?.rawValue
        self.isUserLabeled = isUserLabeled
    }
    
    convenience init(coordinate: CLLocationCoordinate2D, arrivalTime: Date) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude, arrivalTime: arrivalTime)
    }
    
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
}
