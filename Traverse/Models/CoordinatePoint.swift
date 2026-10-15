//
//  CoordinatePoint.swift
//  Traverse
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class CoordinatePoint {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    
    var segment: TimelineSegment?
    
    init(latitude: Double, longitude: Double, timestamp: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }
    
    convenience init(coordinate: CLLocationCoordinate2D, timestamp: Date) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude, timestamp: timestamp)
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
