//
//  ContentView.swift
//  Traverse
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationService.self) private var locationService
    @Environment(MotionService.self) private var motionService
    
    @State private var isOnboardingComplete = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var timelineEngine: TimelineEngine?
    @State private var placeResolver: PlaceResolver?
    
    var body: some View {
        Group {
            if isOnboardingComplete {
                StorylineView()
                    .onAppear {
                        setupAndStartTracking()
                    }
            } else {
                WelcomeView(isOnboardingComplete: $isOnboardingComplete)
            }
        }
        .onChange(of: isOnboardingComplete) { _, newValue in
            if newValue {
                setupAndStartTracking()
            }
        }
    }
    
    private func setupAndStartTracking() {
        // Initialize services if not already done
        if placeResolver == nil {
            placeResolver = PlaceResolver(modelContext: modelContext)
        }
        
        if timelineEngine == nil, let resolver = placeResolver {
            timelineEngine = TimelineEngine(
                modelContext: modelContext,
                locationService: locationService,
                motionService: motionService,
                placeResolver: resolver
            )
        }
        
        // Start tracking
        timelineEngine?.start()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TimelineSegment.self, PlaceVisit.self, CoordinatePoint.self], inMemory: true)
        .environment(LocationService())
        .environment(MotionService())
}
