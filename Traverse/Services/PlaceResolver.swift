//
//  PlaceResolver.swift
//  Traverse
//

import Foundation
import CoreLocation
import MapKit
import SwiftData

@MainActor
@Observable
final class PlaceResolver {
    
    // MARK: - Properties
    
    private let geocoder = CLGeocoder()
    private let modelContext: ModelContext
    
    // Clustering distance for treating coordinates as same place
    private let clusteringDistance: CLLocationDistance = 80 // meters
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Place Resolution
    
    func resolvePlaceName(for place: PlaceVisit) async {
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        
        // First, check if we already have a labeled place nearby
        if let existingPlace = findLabeledPlaceNearby(place.coordinate) {
            place.name = existingPlace.name
            place.address = existingPlace.address
            place.category = existingPlace.category
            return
        }
        
        // Try reverse geocoding
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            if let placemark = placemarks.first {
                // Prefer POI name over address
                if let name = placemark.name, !name.isEmpty,
                   name != placemark.thoroughfare { // Don't use street name as place name
                    place.name = name
                } else if let areasOfInterest = placemark.areasOfInterest, !areasOfInterest.isEmpty {
                    place.name = areasOfInterest[0]
                }
                
                // Build address
                place.address = formatAddress(from: placemark)
                
                // Infer category from placemark
                place.category = inferCategory(from: placemark)
            }
        } catch {
            print("Geocoding failed: \(error.localizedDescription)")
        }
        
        // If no good name from geocoding, try POI search
        if place.name == nil {
            await searchNearbyPOI(for: place)
        }
    }
    
    // MARK: - POI Search
    
    private func searchNearbyPOI(for place: PlaceVisit) async {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "point of interest"
        searchRequest.region = MKCoordinateRegion(
            center: place.coordinate,
            latitudinalMeters: 100,
            longitudinalMeters: 100
        )
        
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            
            // Find the closest POI
            let closest = response.mapItems
                .sorted { item1, item2 in
                    let dist1 = place.distance(to: item1.placemark.coordinate)
                    let dist2 = place.distance(to: item2.placemark.coordinate)
                    return dist1 < dist2
                }
                .first
            
            if let poi = closest,
               place.distance(to: poi.placemark.coordinate) < 50 {
                place.name = poi.name
                
                if place.category == nil {
                    place.category = inferCategory(from: poi)
                }
            }
        } catch {
            print("POI search failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Home/Work Inference
    
    func inferHomeAndWork() async {
        let allPlaces = (try? modelContext.fetch(FetchDescriptor<PlaceVisit>())) ?? []
        
        // Group places by location cluster
        var clusters: [[PlaceVisit]] = []
        
        for place in allPlaces {
            var foundCluster = false
            
            for i in clusters.indices {
                if let first = clusters[i].first,
                   place.distance(to: first.coordinate) < clusteringDistance {
                    clusters[i].append(place)
                    foundCluster = true
                    break
                }
            }
            
            if !foundCluster {
                clusters.append([place])
            }
        }
        
        // Find home: most time spent between 10pm-6am
        var homeCandidate: (cluster: [PlaceVisit], nightTime: TimeInterval)?
        
        // Find work: most time spent on weekday 9am-5pm
        var workCandidate: (cluster: [PlaceVisit], workTime: TimeInterval)?
        
        let calendar = Calendar.current
        
        for cluster in clusters where cluster.count >= 3 {
            var nightTime: TimeInterval = 0
            var workTime: TimeInterval = 0
            
            for visit in cluster {
                let hour = calendar.component(.hour, from: visit.arrivalTime)
                let weekday = calendar.component(.weekday, from: visit.arrivalTime)
                let isWeekday = weekday >= 2 && weekday <= 6
                
                // Night time (10pm - 6am)
                if hour >= 22 || hour < 6 {
                    nightTime += visit.duration
                }
                
                // Work time (weekday 9am - 5pm)
                if isWeekday && hour >= 9 && hour < 17 {
                    workTime += visit.duration
                }
            }
            
            // Update candidates
            if nightTime > (homeCandidate?.nightTime ?? 0) {
                homeCandidate = (cluster, nightTime)
            }
            
            if workTime > (workCandidate?.workTime ?? 0) && cluster != homeCandidate?.cluster {
                workCandidate = (cluster, workTime)
            }
        }
        
        // Label home if found and not already labeled
        if let home = homeCandidate,
           home.nightTime > 3600 * 3, // At least 3 hours of night time
           let unlabeledHome = home.cluster.first(where: { !$0.isUserLabeled && $0.category != .home }) {
            unlabeledHome.category = .home
            unlabeledHome.name = "Home"
        }
        
        // Label work if found and not already labeled
        if let work = workCandidate,
           work.workTime > 3600 * 4, // At least 4 hours of work time
           let unlabeledWork = work.cluster.first(where: { !$0.isUserLabeled && $0.category != .work }) {
            unlabeledWork.category = .work
            unlabeledWork.name = "Work"
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Place Labeling
    
    func labelPlace(_ place: PlaceVisit, name: String, category: PlaceCategory?) {
        place.name = name
        place.isUserLabeled = true
        
        if let category {
            place.category = category
        }
        
        // Update all visits in the same cluster
        let nearbyPlaces = findPlacesInCluster(place.coordinate)
        for nearby in nearbyPlaces where nearby.id != place.id {
            if !nearby.isUserLabeled {
                nearby.name = name
                nearby.category = category
            }
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Visit Count
    
    func visitCount(for coordinate: CLLocationCoordinate2D) -> Int {
        findPlacesInCluster(coordinate).count
    }
    
    // MARK: - Helpers
    
    private func findLabeledPlaceNearby(_ coordinate: CLLocationCoordinate2D) -> PlaceVisit? {
        let allPlaces = (try? modelContext.fetch(FetchDescriptor<PlaceVisit>())) ?? []
        
        return allPlaces.first { place in
            place.isUserLabeled && place.distance(to: coordinate) < clusteringDistance
        }
    }
    
    private func findPlacesInCluster(_ coordinate: CLLocationCoordinate2D) -> [PlaceVisit] {
        let allPlaces = (try? modelContext.fetch(FetchDescriptor<PlaceVisit>())) ?? []
        
        return allPlaces.filter { place in
            place.distance(to: coordinate) < clusteringDistance
        }
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        return components.joined(separator: " ")
    }
    
    private func inferCategory(from placemark: CLPlacemark) -> PlaceCategory? {
        // Try to infer from name or type
        guard let name = placemark.name?.lowercased() else { return nil }
        
        if name.contains("home") || name.contains("house") || name.contains("apartment") {
            return .home
        }
        if name.contains("office") || name.contains("work") {
            return .work
        }
        if name.contains("restaurant") || name.contains("cafe") || name.contains("coffee") ||
           name.contains("bar") || name.contains("food") {
            return .food
        }
        if name.contains("store") || name.contains("shop") || name.contains("mall") ||
           name.contains("market") {
            return .shop
        }
        if name.contains("gym") || name.contains("fitness") {
            return .gym
        }
        if name.contains("station") || name.contains("airport") || name.contains("terminal") {
            return .transit
        }
        
        return nil
    }
    
    private func inferCategory(from mapItem: MKMapItem) -> PlaceCategory? {
        guard let category = mapItem.pointOfInterestCategory else {
            return inferCategory(from: mapItem.placemark)
        }
        
        switch category {
        case .restaurant, .cafe, .bakery, .brewery, .foodMarket:
            return .food
        case .store:
            return .shop
        case .fitnessCenter:
            return .gym
        case .theater, .movieTheater, .nightlife, .museum, .park, .stadium:
            return .entertainment
        case .airport, .publicTransport, .evCharger, .gasStation, .parking:
            return .transit
        default:
            return .other
        }
    }
}
