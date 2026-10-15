//
//  TestDataView.swift
//  Traverse

import SwiftUI
import SwiftData
import CoreLocation

struct TestDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var testEvents: [TestEvent] = [
        TestEvent(placeName: "Home", placeIcon: "house.fill", activityType: .walking, activityDuration: 15, latitude: 37.7749, longitude: -122.4194),
        TestEvent(placeName: "Work", placeIcon: "building.2.fill", activityType: .cycling, activityDuration: 25, latitude: 37.7849, longitude: -122.4094),
        TestEvent(placeName: "Coffee Shop", placeIcon: "cup.and.saucer.fill", activityType: .vehicle, activityDuration: 10, latitude: 37.7649, longitude: -122.4294),
        TestEvent(placeName: "Restaurant", placeIcon: "fork.knife", activityType: .walking, activityDuration: 20, latitude: 37.7549, longitude: -122.4394)
    ]
    
    @State private var showingAddEvent = false
    @State private var editingEvent: TestEvent?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($testEvents) { $event in
                        TestEventRow(event: $event)
                            .listRowBackground(ColorTheme.cardBackground)
                    }
                    .onDelete(perform: deleteEvents)
                    .onMove(perform: moveEvents)
                    
                    Button {
                        testEvents.append(TestEvent(
                            placeName: "New Place",
                            placeIcon: "mappin.circle.fill",
                            activityType: .walking,
                            activityDuration: 10,
                            latitude: 37.77 + Double.random(in: -0.02...0.02),
                            longitude: -122.42 + Double.random(in: -0.02...0.02)
                        ))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ColorTheme.accent)
                            Text("Add Event")
                                .foregroundStyle(ColorTheme.accent)
                        }
                    }
                    .listRowBackground(ColorTheme.cardBackground)
                } header: {
                    Text("Timeline Events")
                        .foregroundStyle(ColorTheme.accent)
                } footer: {
                    Text("Events will be created in order, starting from the beginning of today. Each event includes travel to the destination and time spent there.")
                        .foregroundStyle(ColorTheme.secondaryText)
                }
                
                Section {
                    Button {
                        generateTestData()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Generate Test Data")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.black)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(ColorTheme.accent)
                    
                    Button {
                        clearAllData()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Clear All Data")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.red)
                } header: {
                    Text("Actions")
                        .foregroundStyle(ColorTheme.accent)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ColorTheme.background)
            .navigationTitle("Test Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .foregroundStyle(ColorTheme.accent)
                }
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
    
    private func deleteEvents(at offsets: IndexSet) {
        testEvents.remove(atOffsets: offsets)
    }
    
    private func moveEvents(from source: IndexSet, to destination: Int) {
        testEvents.move(fromOffsets: source, toOffset: destination)
    }
    
    private func generateTestData() {
        // Clear existing data first
        clearAllData()
        
        // Start time: 8:00 AM today
        let calendar = Calendar.current
        var currentTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        
        for (index, event) in testEvents.enumerated() {
            // First, create the place visit (you start AT a location)
            let stayDuration = TimeInterval.random(in: 1800...7200) // 30 min to 2 hours
            let departureTime = currentTime.addingTimeInterval(stayDuration)
            
            let isLastEvent = index == testEvents.count - 1
            
            let place = PlaceVisit(
                latitude: event.latitude,
                longitude: event.longitude,
                arrivalTime: currentTime,
                departureTime: isLastEvent ? nil : departureTime, // Last place is ongoing
                name: event.placeName,
                category: categoryFromIcon(event.placeIcon)
            )
            modelContext.insert(place)
            
            currentTime = departureTime
            
            // Then, create the travel segment to the NEXT place (if there is one)
            if !isLastEvent {
                let nextEvent = testEvents[index + 1]
                let travelDuration = TimeInterval(nextEvent.activityDuration * 60)
                let travelEndTime = currentTime.addingTimeInterval(travelDuration)
                
                // Calculate steps and distance based on the next event's activity type
                let (steps, distance) = calculateMetrics(for: nextEvent.activityType, duration: travelDuration)
                
                let segment = TimelineSegment(
                    activityType: nextEvent.activityType,
                    startTime: currentTime,
                    endTime: travelEndTime,
                    steps: steps,
                    distanceMeters: distance
                )
                
                // Add route coordinates from current place to next place
                addRouteCoordinates(to: segment, from: event, to: nextEvent, modelContext: modelContext)
                
                modelContext.insert(segment)
                
                currentTime = travelEndTime
            }
        }
        
        // Save
        try? modelContext.save()
        
        dismiss()
    }
    
    private func clearAllData() {
        // Delete all segments
        let segmentDescriptor = FetchDescriptor<TimelineSegment>()
        if let segments = try? modelContext.fetch(segmentDescriptor) {
            for segment in segments {
                modelContext.delete(segment)
            }
        }
        
        // Delete all places
        let placeDescriptor = FetchDescriptor<PlaceVisit>()
        if let places = try? modelContext.fetch(placeDescriptor) {
            for place in places {
                modelContext.delete(place)
            }
        }
        
        // Delete all coordinate points
        let coordDescriptor = FetchDescriptor<CoordinatePoint>()
        if let coords = try? modelContext.fetch(coordDescriptor) {
            for coord in coords {
                modelContext.delete(coord)
            }
        }
        
        try? modelContext.save()
    }
    
    private func calculateMetrics(for activityType: ActivityType, duration: TimeInterval) -> (steps: Int?, distance: Double) {
        let minutes = duration / 60
        
        switch activityType {
        case .walking:
            let steps = Int(minutes * 100) // ~100 steps per minute
            let distance = Double(steps) * 0.75 // ~0.75m per step
            return (steps, distance)
        case .running:
            let steps = Int(minutes * 160) // ~160 steps per minute
            let distance = Double(steps) * 1.2 // ~1.2m per step
            return (steps, distance)
        case .cycling:
            let distance = minutes * 250 // ~15 km/h
            return (nil, distance)
        case .vehicle:
            let distance = minutes * 500 // ~30 km/h average with traffic
            return (nil, distance)
        case .stationary:
            return (nil, 0)
        }
    }
    
    private func addRouteCoordinates(to segment: TimelineSegment, from: TestEvent, to: TestEvent, modelContext: ModelContext) {
        let numPoints = 5
        for i in 0...numPoints {
            let fraction = Double(i) / Double(numPoints)
            let lat = from.latitude + (to.latitude - from.latitude) * fraction
            let lon = from.longitude + (to.longitude - from.longitude) * fraction
            // Add some randomness
            let jitterLat = Double.random(in: -0.001...0.001)
            let jitterLon = Double.random(in: -0.001...0.001)
            
            let coord = CoordinatePoint(
                latitude: lat + jitterLat,
                longitude: lon + jitterLon,
                timestamp: segment.startTime.addingTimeInterval(segment.duration * fraction)
            )
            coord.segment = segment
            modelContext.insert(coord)
        }
    }
    
    private func categoryFromIcon(_ icon: String) -> PlaceCategory {
        switch icon {
        case "house.fill": return .home
        case "building.2.fill": return .work
        case "cup.and.saucer.fill", "mug.fill": return .food
        case "fork.knife": return .food
        case "cart.fill", "bag.fill": return .shop
        case "figure.run", "dumbbell.fill": return .gym
        case "cross.fill": return .other
        case "theatermasks.fill": return .entertainment
        case "tram.fill": return .transit
        default: return .other
        }
    }
}

// MARK: - Test Event Model

struct TestEvent: Identifiable {
    let id = UUID()
    var placeName: String
    var placeIcon: String
    var activityType: ActivityType
    var activityDuration: Int // minutes
    var latitude: Double
    var longitude: Double
}

// MARK: - Test Event Row

struct TestEventRow: View {
    @Binding var event: TestEvent
    @State private var showingIconPicker = false
    @State private var showingActivityPicker = false
    
    private let availableIcons = [
        "house.fill",
        "building.2.fill",
        "cup.and.saucer.fill",
        "fork.knife",
        "cart.fill",
        "figure.run",
        "cross.fill",
        "theatermasks.fill",
        "mappin.circle.fill",
        "building.columns.fill",
        "book.fill",
        "airplane",
        "tram.fill",
        "car.fill"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Place row
            HStack(spacing: 12) {
                // Icon picker
                Button {
                    showingIconPicker = true
                } label: {
                    Image(systemName: event.placeIcon)
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(ColorTheme.secondaryBackground)
                        .clipShape(Circle())
                }
                .sheet(isPresented: $showingIconPicker) {
                    IconPickerView(selectedIcon: $event.placeIcon, icons: availableIcons)
                }
                
                // Place name
                TextField("Place name", text: $event.placeName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ColorTheme.primaryText)
            }
            
            // Activity and duration row
            HStack(spacing: 16) {
                // Activity type picker
                Menu {
                    ForEach([ActivityType.walking, .running, .cycling, .vehicle], id: \.self) { type in
                        Button {
                            event.activityType = type
                        } label: {
                            Label(type.displayName, systemImage: type.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: event.activityType.icon)
                            .foregroundStyle(event.activityType.color)
                        Text(event.activityType.displayName)
                            .foregroundStyle(event.activityType.color)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTheme.secondaryText)
                    }
                    .font(.system(size: 14))
                }
                
                // Duration stepper
                HStack(spacing: 8) {
                    Text("Duration:")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTheme.secondaryText)
                    
                    Stepper("\(event.activityDuration) min", value: $event.activityDuration, in: 1...120, step: 5)
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTheme.primaryText)
                }
            }
            
            // Location row
            HStack(spacing: 16) {
                Text("Location:")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTheme.secondaryText)
                
                HStack(spacing: 4) {
                    TextField("Lat", value: $event.latitude, format: .number.precision(.fractionLength(4)))
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTheme.primaryText)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    
                    Text(",")
                        .foregroundStyle(ColorTheme.secondaryText)
                    
                    TextField("Lon", value: $event.longitude, format: .number.precision(.fractionLength(4)))
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTheme.primaryText)
                        .frame(width: 90)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Icon Picker View

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String
    let icons: [String]
    
    private let columns = [
        GridItem(.adaptive(minimum: 50))
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                            dismiss()
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundStyle(selectedIcon == icon ? ColorTheme.accent : ColorTheme.primaryText)
                                .frame(width: 50, height: 50)
                                .background(selectedIcon == icon ? ColorTheme.accent.opacity(0.2) : ColorTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding()
            }
            .background(ColorTheme.background)
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
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
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    TestDataView()
        .modelContainer(for: [TimelineSegment.self, PlaceVisit.self, CoordinatePoint.self], inMemory: true)
}
