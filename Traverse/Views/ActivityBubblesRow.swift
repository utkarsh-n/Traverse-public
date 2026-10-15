//
//  ActivityBubblesRow.swift
//  Traverse

import SwiftUI
import ShaderKit
import CoreMotion

// MARK: - Activity Bubbles Row

struct ActivityBubblesRow: View {
    let summary: DaySummary
    
    // Moves-style bubble sizes (20% larger)
    private let walkBubbleSize: CGFloat = 144
    private let secondaryBubbleSize: CGFloat = 84
    private let smallBubbleSize: CGFloat = 66
    
    // Use ShaderKit's built-in MotionManager
    @State private var motionManager = MotionManager()
    @State private var startTime = Date.now
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsedTime = startTime.distance(to: timeline.date)
            
            if summary.activitiesWithData.isEmpty {
                // Empty state - single gray bubble with "0 steps"
                VStack(spacing: 2) {
                    Text("Walk")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ColorTheme.secondaryText)
                    
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        ColorTheme.secondaryText.opacity(0.35),
                                        ColorTheme.secondaryText.opacity(0.3),
                                        ColorTheme.secondaryText.opacity(0.2)
                                    ],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay {
                                // Subtle inner highlight
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                .white.opacity(0.15),
                                                .clear
                                            ],
                                            center: UnitPoint(x: 0.3, y: 0.25),
                                            startRadius: 0,
                                            endRadius: 50
                                        )
                                    )
                            }
                            .shader(.glassSheen(intensity: 0.3, spread: 0.3), tilt: .zero, time: elapsedTime)
                            .clipShape(Circle())
                        
                        VStack(spacing: 0) {
                            Text("0")
                                .font(.system(size: 32, weight: .regular))
                                .foregroundStyle(ColorTheme.primaryText)
                            Text("steps")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(ColorTheme.primaryText.opacity(0.8))
                        }
                    }
                }
            } else {
                // Moves-style layout: large Walk bubble on left, smaller bubbles stacked on right
                HStack(alignment: .center, spacing: 12) {
                    // Walk bubble (always shown, large)
                    walkBubble(tilt: motionManager.tilt, time: elapsedTime)
                    
                    // Secondary bubbles (Cycle, Run) stacked vertically on the right
                    VStack(alignment: .leading, spacing: 8) {
                        if summary.activitiesWithData.contains(.cycling) {
                            cycleBubble(tilt: motionManager.tilt, time: elapsedTime)
                        }
                        if summary.activitiesWithData.contains(.running) {
                            runBubble(tilt: motionManager.tilt, time: elapsedTime)
                        }
                        if summary.activitiesWithData.contains(.vehicle) {
                            vehicleBubble(tilt: motionManager.tilt, time: elapsedTime)
                        }
                    }
                }
            }
        }
        .onAppear { motionManager.start() }
        .onDisappear { motionManager.stop() }
    }
    
    // MARK: - Walk Bubble (Large, primary) - Glass Sheen + Rainbow Glitter
    
    @ViewBuilder
    private func walkBubble(tilt: CGPoint, time: TimeInterval) -> some View {
        let steps = summary.stepsForActivity(.walking)
        let hasData = summary.activitiesWithData.contains(.walking)
        let baseColor = hasData ? ColorTheme.walking : ColorTheme.secondaryText.opacity(0.3)
        
        VStack(spacing: 2) {
            Text("Walk")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTheme.walking)
            
            ZStack {
                // Background circle with gradient for shiny bubble look
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                baseColor.opacity(0.9),
                                baseColor,
                                baseColor.opacity(0.7)
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: walkBubbleSize
                        )
                    )
                    .frame(width: walkBubbleSize, height: walkBubbleSize)
                    .overlay {
                        // Inner highlight for 3D bubble effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .white.opacity(0.4),
                                        .clear
                                    ],
                                    center: UnitPoint(x: 0.3, y: 0.25),
                                    startRadius: 0,
                                    endRadius: walkBubbleSize * 0.5
                                )
                            )
                    }
                    .overlay {
                        // Bottom shadow for depth
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .clear,
                                        .black.opacity(0.3)
                                    ],
                                    center: UnitPoint(x: 0.5, y: 0.7),
                                    startRadius: walkBubbleSize * 0.3,
                                    endRadius: walkBubbleSize * 0.55
                                )
                            )
                    }
                    .overlay {
                        // Rim highlight stroke
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.6),
                                        .white.opacity(0.1),
                                        .clear,
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                    .shader(.rainbowGlitter(intensity: 0.5), tilt: tilt, time: time)
                    .shader(.glassSheen(intensity: 0.6, spread: 0.4), tilt: tilt, time: time)
                    .clipShape(Circle())
                    // Outer glow
                    .shadow(color: baseColor.opacity(0.5), radius: 12, x: 0, y: 4)
                
                // Text overlay
                VStack(spacing: 0) {
                    Text(steps > 0 ? steps.formattedSteps : "0")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(.white)
                    Text("steps")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
            }
            .frame(width: walkBubbleSize, height: walkBubbleSize)
        }
    }
    
    // MARK: - Cycle Bubble - Rainbow Glitter + Glass Sheen
    
    @ViewBuilder
    private func cycleBubble(tilt: CGPoint, time: TimeInterval) -> some View {
        let duration = summary.durationForActivity(.cycling)
        let minutes = Int(duration / 60)
        let baseColor = ColorTheme.cycling
        
        VStack(spacing: 2) {
            Text("Cycle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTheme.cycling)
            
            ZStack {
                // Background circle with gradient for shiny bubble look
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                baseColor.opacity(0.9),
                                baseColor,
                                baseColor.opacity(0.7)
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: secondaryBubbleSize
                        )
                    )
                    .frame(width: secondaryBubbleSize, height: secondaryBubbleSize)
                    .overlay {
                        // Inner highlight for 3D bubble effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .white.opacity(0.35),
                                        .clear
                                    ],
                                    center: UnitPoint(x: 0.3, y: 0.25),
                                    startRadius: 0,
                                    endRadius: secondaryBubbleSize * 0.5
                                )
                            )
                    }
                    .overlay {
                        // Bottom shadow for depth
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .clear,
                                        .black.opacity(0.3)
                                    ],
                                    center: UnitPoint(x: 0.5, y: 0.7),
                                    startRadius: secondaryBubbleSize * 0.3,
                                    endRadius: secondaryBubbleSize * 0.55
                                )
                            )
                    }
                    .overlay {
                        // Rim highlight stroke
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.6),
                                        .white.opacity(0.1),
                                        .clear,
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    .shader(.rainbowGlitter(intensity: 0.5), tilt: tilt, time: time)
                    .shader(.glassSheen(intensity: 0.5, spread: 0.35), tilt: tilt, time: time)
                    .clipShape(Circle())
                    // Outer glow
                    .shadow(color: baseColor.opacity(0.5), radius: 10, x: 0, y: 3)
                
                // Text overlay
                VStack(spacing: 0) {
                    Text("\(minutes)")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.white)
                    Text("min")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
            }
            .frame(width: secondaryBubbleSize, height: secondaryBubbleSize)
        }
    }
    
    // MARK: - Run Bubble - Rainbow Glitter + Glass Sheen
    
    @ViewBuilder
    private func runBubble(tilt: CGPoint, time: TimeInterval) -> some View {
        let distance = summary.distanceForActivity(.running)
        let baseColor = ColorTheme.running
        
        VStack(spacing: 2) {
            Text("Run")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTheme.running)
            
            ZStack {
                // Background circle with gradient for shiny bubble look
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                baseColor.opacity(0.9),
                                baseColor,
                                baseColor.opacity(0.7)
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: smallBubbleSize
                        )
                    )
                    .frame(width: smallBubbleSize, height: smallBubbleSize)
                    .overlay {
                        // Inner highlight for 3D bubble effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .white.opacity(0.3),
                                        .clear
                                    ],
                                    center: UnitPoint(x: 0.3, y: 0.25),
                                    startRadius: 0,
                                    endRadius: smallBubbleSize * 0.5
                                )
                            )
                    }
                    .overlay {
                        // Bottom shadow for depth
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .clear,
                                        .black.opacity(0.3)
                                    ],
                                    center: UnitPoint(x: 0.5, y: 0.7),
                                    startRadius: smallBubbleSize * 0.3,
                                    endRadius: smallBubbleSize * 0.55
                                )
                            )
                    }
                    .overlay {
                        // Rim highlight stroke
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.6),
                                        .white.opacity(0.1),
                                        .clear,
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shader(.rainbowGlitter(intensity: 0.5), tilt: tilt, time: time)
                    .shader(.glassSheen(intensity: 0.5, spread: 0.3), tilt: tilt, time: time)
                    .clipShape(Circle())
                    // Outer glow
                    .shadow(color: baseColor.opacity(0.5), radius: 8, x: 0, y: 2)
                
                // Text overlay
                VStack(spacing: 0) {
                    Text(distance.formattedDistanceShort)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
            }
            .frame(width: smallBubbleSize, height: smallBubbleSize)
        }
    }
    
    // MARK: - Vehicle Bubble - Rainbow Glitter + Glass Sheen
    
    @ViewBuilder
    private func vehicleBubble(tilt: CGPoint, time: TimeInterval) -> some View {
        let duration = summary.durationForActivity(.vehicle)
        let minutes = Int(duration / 60)
        let baseColor = ColorTheme.vehicle
        
        VStack(spacing: 2) {
            Text("Transport")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTheme.vehicle)
            
            ZStack {
                // Background circle with gradient for shiny bubble look
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                baseColor.opacity(0.9),
                                baseColor,
                                baseColor.opacity(0.7)
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: smallBubbleSize
                        )
                    )
                    .frame(width: smallBubbleSize, height: smallBubbleSize)
                    .overlay {
                        // Inner highlight for 3D bubble effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .white.opacity(0.3),
                                        .clear
                                    ],
                                    center: UnitPoint(x: 0.3, y: 0.25),
                                    startRadius: 0,
                                    endRadius: smallBubbleSize * 0.5
                                )
                            )
                    }
                    .overlay {
                        // Bottom shadow for depth
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .clear,
                                        .black.opacity(0.3)
                                    ],
                                    center: UnitPoint(x: 0.5, y: 0.7),
                                    startRadius: smallBubbleSize * 0.3,
                                    endRadius: smallBubbleSize * 0.55
                                )
                            )
                    }
                    .overlay {
                        // Rim highlight stroke
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.6),
                                        .white.opacity(0.1),
                                        .clear,
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shader(.rainbowGlitter(intensity: 0.5), tilt: tilt, time: time)
                    .shader(.glassSheen(intensity: 0.5, spread: 0.3), tilt: tilt, time: time)
                    .clipShape(Circle())
                    // Outer glow
                    .shadow(color: baseColor.opacity(0.5), radius: 8, x: 0, y: 2)
                
                // Text overlay
                VStack(spacing: 0) {
                    Text("\(minutes)")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.white)
                    Text("min")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
            }
            .frame(width: smallBubbleSize, height: smallBubbleSize)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // With data
        ActivityBubblesRow(summary: DaySummary(
            date: Date(),
            segments: [
                TimelineSegment(activityType: .walking, startTime: Date().addingTimeInterval(-7200), endTime: Date().addingTimeInterval(-3600), steps: 9362, distanceMeters: 7200),
                TimelineSegment(activityType: .cycling, startTime: Date().addingTimeInterval(-3600), endTime: Date().addingTimeInterval(-1260), distanceMeters: 8000),
                TimelineSegment(activityType: .running, startTime: Date().addingTimeInterval(-1200), endTime: Date(), distanceMeters: 500)
            ],
            places: []
        ))
        
        // Empty state
        ActivityBubblesRow(summary: DaySummary(
            date: Date(),
            segments: [],
            places: []
        ))
    }
    .padding()
    .background(ColorTheme.background)
    .preferredColorScheme(.dark)
}
