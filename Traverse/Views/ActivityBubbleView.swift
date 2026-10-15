//
//  ActivityBubbleView.swift
//  Traverse
//

import SwiftUI

struct ActivityBubbleView: View {
    let activityType: ActivityType
    let primaryValue: String
    let size: CGFloat
    
    @State private var displayMode: DisplayMode = .steps
    @State private var isAnimated = false
    
    enum DisplayMode: CaseIterable {
        case steps
        case distance
        case duration
        
        var next: DisplayMode {
            let allCases = DisplayMode.allCases
            let currentIndex = allCases.firstIndex(of: self) ?? 0
            let nextIndex = (currentIndex + 1) % allCases.count
            return allCases[nextIndex]
        }
    }
    
    // Additional data for cycling through metrics
    var steps: Int?
    var distanceMeters: Double?
    var duration: TimeInterval?
    
    private var currentDisplayValue: String {
        switch displayMode {
        case .steps:
            if let steps {
                return steps.formattedSteps
            }
            return primaryValue
        case .distance:
            if let distance = distanceMeters {
                return distance.formattedDistanceShort
            }
            return primaryValue
        case .duration:
            if let dur = duration {
                return dur.shortDuration
            }
            return primaryValue
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Bubble circle
            Circle()
                .fill(activityType.color)
                .frame(width: size, height: size)
                .overlay {
                    Text(currentDisplayValue)
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                }
                .scaleEffect(isAnimated ? 1.0 : 0.3)
                .opacity(isAnimated ? 1.0 : 0)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayMode = displayMode.next
                    }
                }
            
            // Activity label
            Text(activityType.displayName.lowercased())
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(activityType.color)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                isAnimated = true
            }
        }
    }
    
    private var fontSize: CGFloat {
        if size >= 70 {
            return 18
        } else if size >= 50 {
            return 14
        } else {
            return 12
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        ActivityBubbleView(
            activityType: .walking,
            primaryValue: "4,231",
            size: 80,
            steps: 4231,
            distanceMeters: 3200,
            duration: 2400
        )
        
        ActivityBubbleView(
            activityType: .running,
            primaryValue: "2.1km",
            size: 60,
            distanceMeters: 2100,
            duration: 1200
        )
        
        ActivityBubbleView(
            activityType: .cycling,
            primaryValue: "5.4km",
            size: 50,
            distanceMeters: 5400,
            duration: 1800
        )
        
        ActivityBubbleView(
            activityType: .vehicle,
            primaryValue: "12km",
            size: 40,
            distanceMeters: 12000,
            duration: 900
        )
    }
    .padding()
    .background(ColorTheme.background)
    .preferredColorScheme(.dark)
}
