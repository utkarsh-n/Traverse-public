//
//  TimelineSegmentRow.swift
//  Traverse

import SwiftUI

// MARK: - Moves-Style Timeline Segment Row

struct TimelineSegmentRow: View {
    let segment: TimelineSegment
    let isLast: Bool
    var onTap: (() -> Void)?
    
    private let lineWidth: CGFloat = 4
    private let timeWidth: CGFloat = 50
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Time label on left
            Text(segment.startTime.timeString)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(ColorTheme.secondaryText)
                .frame(width: timeWidth, alignment: .trailing)
                .padding(.trailing, 12)
            
            // Colored vertical line
            Rectangle()
                .fill(segment.activityType.color)
                .frame(width: lineWidth)
                .frame(height: 50)
            
            // Activity text
            HStack(spacing: 4) {
                Text(segment.activityType.displayName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(segment.activityType.color)
                
                Text(segment.durationFormatted)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(ColorTheme.primaryText)
                
                // Pulsing indicator if ongoing
                if segment.isOngoing {
                    PulsingDot(color: segment.activityType.color)
                }
            }
            .padding(.leading, 16)
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Moves-Style Place Card Row

struct PlaceCardRow: View {
    let place: PlaceVisit
    var onTap: (() -> Void)?
    
    private let lineWidth: CGFloat = 4
    private let timeWidth: CGFloat = 50
    private let pillWidth: CGFloat = 40
    private let basePillHeight: CGFloat = 60 // For <= 1 hour
    
    // Calculate pill height based on duration
    // Base height for <= 1 hour, then 1.5x growth rate for additional time
    private var pillHeight: CGFloat {
        let durationHours = place.duration / 3600
        if durationHours <= 1 {
            return basePillHeight
        } else {
            // 1.5x proportion for time beyond 1 hour
            let additionalHours = durationHours - 1
            let additionalHeight = additionalHours * basePillHeight * 0.5 // 1.5x means 0.5x extra per hour
            return min(basePillHeight + additionalHeight, basePillHeight * 3) // Cap at 3x max
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Empty time area for alignment with activity rows
            Color.clear
                .frame(width: timeWidth)
                .padding(.trailing, 12)
            
            // White vertical pill with icon - centered over the timeline position
            ZStack {
                Capsule()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
                
                Image(systemName: place.category?.icon ?? "mappin.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.black.opacity(0.8))
            }
            .frame(width: pillWidth, height: pillHeight)
            .offset(x: -(pillWidth - lineWidth) / 2) // Shift left so pill centers on the line position
            
            // Place name to the right
            HStack(spacing: 8) {
                Text(place.displayName)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(ColorTheme.primaryText)
                
                if place.isOngoing {
                    PulsingDot(color: ColorTheme.accent)
                }
            }
            .padding(.leading, 12 - (pillWidth - lineWidth) / 2) // Adjust padding to account for offset
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Pulsing Dot

struct PulsingDot: View {
    let color: Color
    
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Timeline Item

enum TimelineItem: Identifiable {
    case segment(TimelineSegment)
    case place(PlaceVisit)
    
    var id: UUID {
        switch self {
        case .segment(let seg): return seg.id
        case .place(let place): return place.id
        }
    }
    
    var startTime: Date {
        switch self {
        case .segment(let seg): return seg.startTime
        case .place(let place): return place.arrivalTime
        }
    }
}

// MARK: - Previews

#Preview("Activity Segment") {
    VStack(spacing: 0) {
        TimelineSegmentRow(
            segment: TimelineSegment(
                activityType: .walking,
                startTime: Date().addingTimeInterval(-3600),
                endTime: Date().addingTimeInterval(-1800),
                steps: 1204,
                distanceMeters: 980
            ),
            isLast: false
        )
        
        TimelineSegmentRow(
            segment: TimelineSegment(
                activityType: .vehicle,
                startTime: Date().addingTimeInterval(-1800),
                endTime: Date().addingTimeInterval(-900),
                distanceMeters: 5400
            ),
            isLast: false
        )
        
        TimelineSegmentRow(
            segment: TimelineSegment(
                activityType: .running,
                startTime: Date().addingTimeInterval(-900),
                endTime: nil,
                distanceMeters: 1200
            ),
            isLast: true
        )
    }
    .padding()
    .background(ColorTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Place Card") {
    VStack(spacing: 20) {
        PlaceCardRow(
            place: PlaceVisit(
                latitude: 37.7749,
                longitude: -122.4194,
                arrivalTime: Date().addingTimeInterval(-7200),
                departureTime: Date().addingTimeInterval(-3600),
                name: "Home",
                category: .home
            )
        )
        
        PlaceCardRow(
            place: PlaceVisit(
                latitude: 37.7849,
                longitude: -122.4094,
                arrivalTime: Date().addingTimeInterval(-3600),
                departureTime: Date().addingTimeInterval(-1800),
                name: "Work",
                category: .work
            )
        )
        
        PlaceCardRow(
            place: PlaceVisit(
                latitude: 37.7649,
                longitude: -122.4294,
                arrivalTime: Date().addingTimeInterval(-1800),
                name: "Fourbarrel Coffee",
                category: .food
            )
        )
    }
    .padding()
    .background(ColorTheme.background)
    .preferredColorScheme(.dark)
}
