//
//  TraverseApp.swift
//  Traverse
//

import SwiftUI
import SwiftData

@main
struct TraverseApp: App {
    // Services
    @State private var locationService = LocationService()
    @State private var motionService = MotionService()
    
    // SwiftData container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TimelineSegment.self,
            PlaceVisit.self,
            CoordinatePoint.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationService)
                .environment(motionService)
        }
        .modelContainer(sharedModelContainer)
    }
}
