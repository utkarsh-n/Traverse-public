//
//  StorylineView.swift
//  Traverse
//

import SwiftUI
import SwiftData
import Combine

struct StorylineView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var selectedSegment: TimelineSegment?
    @State private var selectedPlace: PlaceVisit?
    @State private var showingDayMap = false
    @State private var showingSettings = false
    

    
    // Live update timer
    @State private var refreshTrigger = false
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    // Queries
    @Query private var allSegments: [TimelineSegment]
    @Query private var allPlaces: [PlaceVisit]
    
    // Computed day summary
    private var daySummary: DaySummary {
        let startOfDay = selectedDate.startOfDay
        let endOfDay = selectedDate.endOfDay
        
        let segments = allSegments.filter { segment in
            segment.startTime >= startOfDay && segment.startTime <= endOfDay
        }.sorted { $0.startTime < $1.startTime }
        
        let places = allPlaces.filter { place in
            place.arrivalTime >= startOfDay && place.arrivalTime <= endOfDay
        }.sorted { $0.arrivalTime < $1.arrivalTime }
        
        return DaySummary(date: selectedDate, segments: segments, places: places)
    }
    
    // Timeline items (merged and sorted)
    private var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        
        for place in daySummary.places {
            items.append(.place(place))
        }
        
        for segment in daySummary.segments where segment.activityType.isMovement {
            items.append(.segment(segment))
        }
        
        return items.sorted { $0.startTime < $1.startTime }
    }
    
    // Earliest date with data
    private var earliestDate: Date {
        let allDates = allSegments.map(\.startTime) + allPlaces.map(\.arrivalTime)
        return allDates.min() ?? Date()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar with settings and map
            topBar
            
            // Date selector
            DaySelectorView(
                selectedDate: $selectedDate,
                earliestDate: earliestDate
            )
            .padding(.vertical, 8)
            
            // Activity bubbles
            ActivityBubblesRow(summary: daySummary)
                .padding(.vertical, 16)
            
            // Progressive fade instead of divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            ColorTheme.background.opacity(0),
                            ColorTheme.background.opacity(0.5),
                            ColorTheme.background
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 20)
                .blur(radius: 8)
            
            // Timeline content
            if timelineItems.isEmpty {
                emptyState
            } else {
                timelineList
            }
        }
        .background(ColorTheme.background)
        .preferredColorScheme(.dark)
        .sheet(item: $selectedSegment) { segment in
            ActivityDetailView(segment: segment)
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailView(place: place)
        }
        .sheet(isPresented: $showingDayMap) {
            DayMapView(summary: daySummary)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onReceive(refreshTimer) { _ in
            if selectedDate.isToday {
                refreshTrigger.toggle()
            }
        }
        .id(refreshTrigger) // Force refresh
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTheme.secondaryText)
            }
            
            Spacer()
            
            Button {
                showingDayMap = true
            } label: {
                Image(systemName: "map")
                    .font(.system(size: 18))
            }
            .buttonStyle(.glassProminent)
            .tint(ColorTheme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "figure.walk")
                .font(.system(size: 48))
                .foregroundStyle(ColorTheme.accent)
            
            Text(selectedDate.isToday
                 ? "Your day will appear here as you move around."
                 : "No activity recorded for this day.")
                .font(.system(size: 15))
                .foregroundStyle(ColorTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Timeline List
    
    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                    switch item {
                    case .place(let place):
                        PlaceCardRow(place: place) {
                            selectedPlace = place
                        }
                        .padding(.vertical, 4)
                        
                    case .segment(let segment):
                        TimelineSegmentRow(
                            segment: segment,
                            isLast: index == timelineItems.count - 1
                        ) {
                            selectedSegment = segment
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Preview

#Preview {
    StorylineView()
        .modelContainer(for: [TimelineSegment.self, PlaceVisit.self, CoordinatePoint.self], inMemory: true)
}
