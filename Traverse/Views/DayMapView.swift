//
//  DayMapView.swift
//  Traverse
//

import SwiftUI
import MapKit

struct DayMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationService.self) private var locationService
    let summary: DaySummary
    
    @State private var position: MapCameraPosition = .automatic
    
    private var allCoordinates: [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        
        // Add all segment routes
        for segment in summary.segments {
            coords.append(contentsOf: segment.sortedRouteCoordinates.map { $0.coordinate })
        }
        
        // Add all place locations
        for place in summary.places {
            coords.append(place.coordinate)
        }
        
        return coords
    }
    
    private var initialPosition: MapCameraPosition {
        // If we have coordinates from today's activities, show those
        if !allCoordinates.isEmpty {
            let latitudes = allCoordinates.map { $0.latitude }
            let longitudes = allCoordinates.map { $0.longitude }
            
            let minLat = latitudes.min() ?? 0
            let maxLat = latitudes.max() ?? 0
            let minLon = longitudes.min() ?? 0
            let maxLon = longitudes.max() ?? 0
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let latDelta = max(0.01, (maxLat - minLat) * 1.5)
            let lonDelta = max(0.01, (maxLon - minLon) * 1.5)
            
            return .region(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            ))
        }
        
        // Otherwise, use current location if available
        if let currentLocation = locationService.currentLocation {
            return .region(MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
        
        // Fallback to user location
        return .userLocation(fallback: .automatic)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Map
                Map(position: $position) {
                    // Show user location
                    UserAnnotation()
                    
                    // Draw routes for each segment
                    ForEach(summary.segments, id: \.id) { segment in
                        let coords = segment.sortedRouteCoordinates.map { $0.coordinate }
                        if coords.count > 1 {
                            MapPolyline(coordinates: coords)
                                .stroke(segment.activityType.color, lineWidth: 4)
                        }
                    }
                    
                    // Place markers
                    ForEach(summary.places, id: \.id) { place in
                        Annotation(place.displayName, coordinate: place.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(ColorTheme.cardBackground)
                                    .frame(width: 28, height: 28)
                                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                                
                                Circle()
                                    .fill(place.category?.color ?? ColorTheme.accent)
                                    .frame(width: 22, height: 22)
                                
                                Image(systemName: place.category?.icon ?? "mappin.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .ignoresSafeArea(edges: .top)
                .onAppear {
                    position = initialPosition
                }
                
                // Location button
                VStack {
                    HStack {
                        Spacer()
                        
                        Button {
                            centerOnUserLocation()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                                .padding(12)
                                .glassEffect(.regular.tint(.blue).interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                        .padding(.top, 60)
                    }
                    
                    Spacer()
                }
                
                // Stats overlay
                statsOverlay
            }
            .navigationTitle(summary.date.dayDisplayString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(ColorTheme.accent)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - Actions
    
    private func centerOnUserLocation() {
        withAnimation {
            if let currentLocation = locationService.currentLocation {
                position = .region(MKCoordinateRegion(
                    center: currentLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            } else {
                position = .userLocation(fallback: .automatic)
            }
        }
    }
    
    // MARK: - Stats Overlay
    
    private var statsOverlay: some View {
        VStack(spacing: 12) {
            // Date
            Text(summary.date.dayDisplayString)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTheme.secondaryText)
            
            // Stats row
            HStack(spacing: 24) {
                statItem(
                    value: summary.totalSteps.formattedSteps,
                    label: "steps",
                    color: ColorTheme.walking
                )
                
                Divider()
                    .frame(height: 30)
                    .background(ColorTheme.secondaryText.opacity(0.3))
                
                statItem(
                    value: summary.totalDistanceMeters.formattedDistanceShort,
                    label: "distance",
                    color: ColorTheme.cycling
                )
                
                Divider()
                    .frame(height: 30)
                    .background(ColorTheme.secondaryText.opacity(0.3))
                
                statItem(
                    value: summary.totalActiveTime.shortDuration,
                    label: "active",
                    color: ColorTheme.running
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .glassEffect(in: .rect(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(ColorTheme.secondaryText)
        }
    }
}

// MARK: - Preview

#Preview {
    DayMapView(summary: DaySummary(
        date: Date(),
        segments: [
            TimelineSegment(
                activityType: .walking,
                startTime: Date().addingTimeInterval(-7200),
                endTime: Date().addingTimeInterval(-3600),
                steps: 4231,
                distanceMeters: 3200
            )
        ],
        places: [
            PlaceVisit(
                latitude: 37.7749,
                longitude: -122.4194,
                arrivalTime: Date().addingTimeInterval(-10800),
                departureTime: Date().addingTimeInterval(-7200),
                name: "Home",
                category: .home
            ),
            PlaceVisit(
                latitude: 37.7849,
                longitude: -122.4094,
                arrivalTime: Date().addingTimeInterval(-3600),
                name: "Coffee Shop",
                category: .food
            )
        ]
    ))
    .environment(LocationService())
}
