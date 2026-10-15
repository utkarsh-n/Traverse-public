//
//  Extensions.swift
//  Traverse
//

import Foundation
import CoreLocation

// MARK: - Date Extensions

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
    
    var dayDisplayString: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: self)
        }
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }
    
    var shortTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: self)
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    var formattedDuration: String {
        let minutes = Int(self / 60)
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
    
    var shortDuration: String {
        let minutes = Int(self / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

// MARK: - Double Extensions (Distance)

extension Double {
    private static var useMetricUnits: Bool {
        UserDefaults.standard.bool(forKey: "useMetricUnits")
    }
    
    var formattedDistance: String {
        if Double.useMetricUnits {
            if self < 1000 {
                return String(format: "%.0f m", self)
            }
            return String(format: "%.1f km", self / 1000)
        } else {
            // Convert meters to feet/miles
            let feet = self * 3.28084
            if feet < 5280 {
                return String(format: "%.0f ft", feet)
            }
            let miles = self / 1609.34
            return String(format: "%.1f mi", miles)
        }
    }
    
    var formattedDistanceShort: String {
        if Double.useMetricUnits {
            if self < 1000 {
                return String(format: "%.0fm", self)
            }
            return String(format: "%.1fkm", self / 1000)
        } else {
            let miles = self / 1609.34
            if miles < 0.1 {
                let feet = self * 3.28084
                return String(format: "%.0fft", feet)
            }
            return String(format: "%.1fmi", miles)
        }
    }
    
    var formattedSpeed: String {
        if Double.useMetricUnits {
            return String(format: "%.1f km/h", self)
        } else {
            // Convert km/h to mph
            let mph = self * 0.621371
            return String(format: "%.1f mph", mph)
        }
    }
}

// MARK: - Int Extensions (Steps)

extension Int {
    var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - CLLocationCoordinate2D Extensions

extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
}

// MARK: - Array Extensions

extension Array where Element == CLLocationCoordinate2D {
    var totalDistance: CLLocationDistance {
        guard count > 1 else { return 0 }
        var total: CLLocationDistance = 0
        for i in 1..<count {
            total += self[i - 1].distance(to: self[i])
        }
        return total
    }
}

extension Array where Element == CoordinatePoint {
    var coordinates: [CLLocationCoordinate2D] {
        map { $0.coordinate }
    }
    
    var totalDistance: CLLocationDistance {
        coordinates.totalDistance
    }
}
