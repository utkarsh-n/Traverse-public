//
//  ColorTheme.swift
//  Traverse
//

import SwiftUI

enum ColorTheme {
    // Primary accent color (green - inspired by Moves)
    static let accent = Color(hex: "4CD964")  // Vibrant green
    
    // Activity colors
    static let walking = Color(hex: "4CD964")  // Green
    static let running = Color(hex: "FF3B30")  // Red
    static let cycling = Color(hex: "007AFF")  // Blue
    static let vehicle = Color(hex: "FF9500")  // Orange
    static let stationary = Color(hex: "8E8E93")  // Gray
    
    // Dark theme colors
    static let background = Color(hex: "000000")  // Pure black
    static let cardBackground = Color(hex: "1C1C1E")  // Dark gray card
    static let secondaryBackground = Color(hex: "2C2C2E")  // Slightly lighter
    
    // Text colors
    static let primaryText = Color.white
    static let secondaryText = Color(hex: "8E8E93")  // Gray text
    
    // Place category colors
    static let home = Color(hex: "4CD964")  // Green
    static let work = Color(hex: "007AFF")  // Blue
    static let food = Color(hex: "FF9500")  // Orange
    static let shop = Color(hex: "FF3B30")  // Red
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
