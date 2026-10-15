//
//  DaySelectorView.swift
//  Traverse
//

import SwiftUI

struct DaySelectorView: View {
    @Binding var selectedDate: Date
    let earliestDate: Date
    
    @GestureState private var dragOffset: CGFloat = 0
    @State private var showingLeftChevron = false
    @State private var showingRightChevron = false
    
    var body: some View {
        HStack {
            // Left chevron (appears during swipe)
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTheme.accent)
                .opacity(showingLeftChevron ? 1 : 0)
            
            Spacer()
            
            // Date display - large title like Moves
            Text(selectedDate.isToday ? "Today" : selectedDate.dayDisplayString)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(ColorTheme.primaryText)
                .offset(x: dragOffset * 0.3)
            
            Spacer()
            
            // Right chevron (appears during swipe)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTheme.accent)
                .opacity(showingRightChevron ? 1 : 0)
        }
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.width
                }
                .onChanged { value in
                    // Show chevrons based on drag direction
                    withAnimation(.easeOut(duration: 0.1)) {
                        showingLeftChevron = value.translation.width > 30 && canGoToPreviousDay
                        showingRightChevron = value.translation.width < -30 && canGoToNextDay
                    }
                }
                .onEnded { value in
                    // Hide chevrons
                    withAnimation(.easeOut(duration: 0.2)) {
                        showingLeftChevron = false
                        showingRightChevron = false
                    }
                    
                    // Swipe threshold
                    let threshold: CGFloat = 50
                    
                    if value.translation.width > threshold && canGoToPreviousDay {
                        // Swipe right - go to previous day
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                        }
                    } else if value.translation.width < -threshold && canGoToNextDay {
                        // Swipe left - go to next day
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                        }
                    }
                }
        )
    }
    
    private var canGoToPreviousDay: Bool {
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        return previousDay >= earliestDate.startOfDay
    }
    
    private var canGoToNextDay: Bool {
        !selectedDate.isToday
    }
}

// MARK: - Preview

#Preview {
    VStack {
        DaySelectorView(
            selectedDate: .constant(Date()),
            earliestDate: Date().addingTimeInterval(-86400 * 7)
        )
        
        DaySelectorView(
            selectedDate: .constant(Date().addingTimeInterval(-86400)),
            earliestDate: Date().addingTimeInterval(-86400 * 7)
        )
    }
    .padding()
    .background(ColorTheme.background)
    .preferredColorScheme(.dark)
}
