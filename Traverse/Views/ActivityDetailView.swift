//
//  ActivityDetailView.swift
//  Traverse
//

import SwiftUI
import MapKit

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationService.self) private var locationService
    let segment: TimelineSegment
    
    @State private var position: MapCameraPosition = .automatic
    
    private var routeCoordinates: [CLLocationCoordinate2D] {
        segment.sortedRouteCoordinates.map { $0.coordinate }
    }
    
    private var initialPosition: MapCameraPosition {
        guard !routeCoordinates.isEmpty else {
            // Use current location if no route
            if let currentLocation = locationService.currentLocation {
                return .region(MKCoordinateRegion(
                    center: currentLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
            return .userLocation(fallback: .automatic)
        }
        
        let latitudes = routeCoordinates.map { $0.latitude }
        let longitudes = routeCoordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.3),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.3)
        )
        
        return .region(MKCoordinateRegion(center: center, span: span))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Map
                    mapView
                        .frame(height: 280)
                    
                    // Stats card
                    statsCard
                        .padding(20)
                }
            }
            .background(ColorTheme.background)
            .navigationTitle(segment.activityType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(ColorTheme.accent)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - Map View
    
    @ViewBuilder
    private var mapView: some View {
        if routeCoordinates.isEmpty {
            // No route data
            ZStack {
                ColorTheme.cardBackground
                
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 32))
                        .foregroundStyle(ColorTheme.secondaryText)
                    
                    Text("No route recorded")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTheme.secondaryText)
                }
            }
        } else {
            Map(position: $position) {
                // Route polyline
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(segment.activityType.color, lineWidth: 4)
                
                // Start marker
                if let start = routeCoordinates.first {
                    Annotation("Start", coordinate: start) {
                        Circle()
                            .fill(segment.activityType.color)
                            .frame(width: 12, height: 12)
                            .overlay {
                                Circle()
                                    .stroke(ColorTheme.cardBackground, lineWidth: 2)
                            }
                    }
                }
                
                // End marker
                if let end = routeCoordinates.last, routeCoordinates.count > 1 {
                    Annotation("End", coordinate: end) {
                        Circle()
                            .fill(segment.activityType.color)
                            .frame(width: 12, height: 12)
                            .overlay {
                                Circle()
                                    .stroke(ColorTheme.cardBackground, lineWidth: 2)
                            }
                            .overlay {
                                Circle()
                                    .fill(ColorTheme.cardBackground)
                                    .frame(width: 4, height: 4)
                            }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onAppear {
                position = initialPosition
            }
        }
    }
    
    // MARK: - Stats Card
    
    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Activity header
            HStack(spacing: 8) {
                Image(systemName: segment.activityType.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(segment.activityType.color)
                
                Text(segment.activityType.displayName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ColorTheme.primaryText)
            }
            
            Divider()
                .background(ColorTheme.secondaryText.opacity(0.3))
            
            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Duration
                statItem(
                    title: "Duration",
                    value: segment.durationFormatted,
                    icon: "clock"
                )
                
                // Distance
                if let distance = segment.distanceMeters, distance > 0 {
                    statItem(
                        title: "Distance",
                        value: distance.formattedDistance,
                        icon: "arrow.left.and.right"
                    )
                }
                
                // Steps (for walking/running)
                if let steps = segment.steps, steps > 0 {
                    statItem(
                        title: "Steps",
                        value: steps.formattedSteps,
                        icon: "figure.walk"
                    )
                }
                
                // Average speed
                if let speed = segment.averageSpeedKmh, speed > 0 {
                    statItem(
                        title: "Avg. Speed",
                        value: speed.formattedSpeed,
                        icon: "speedometer"
                    )
                }
            }
            
            Divider()
                .background(ColorTheme.secondaryText.opacity(0.3))
            
            // Time range
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTheme.secondaryText)
                    Text(segment.startTime.timeString)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ColorTheme.primaryText)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(ColorTheme.secondaryText)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("End")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTheme.secondaryText)
                    
                    if segment.isOngoing {
                        Text("In progress")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(segment.activityType.color)
                    } else if let end = segment.endTime {
                        Text(end.timeString)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(ColorTheme.primaryText)
                    }
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        }
    }
    
    private func statItem(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(segment.activityType.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTheme.secondaryText)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTheme.primaryText)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ActivityDetailView(
        segment: TimelineSegment(
            activityType: .walking,
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            steps: 4231,
            distanceMeters: 3200
        )
    )
    .environment(LocationService())
}
