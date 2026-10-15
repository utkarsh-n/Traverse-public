//
//  ShaderPrototypingView.swift
//  Traverse
//
//  A prototyping panel for experimenting with ShaderKit effects
//

import SwiftUI
import ShaderKit

// MARK: - Shader Prototyping View

struct ShaderPrototypingView: View {
    @State private var startTime = Date.now
    @State private var manualTiltX: Double = 0
    @State private var manualTiltY: Double = 0
    @State private var bubbleSize: CGFloat = 150
    @State private var useGradient = false
    @State private var baseColor = Color.green
    @State private var gradientColor1 = Color.blue
    @State private var gradientColor2 = Color.purple
    @State private var intensity: Double = 0.7
    @State private var density: Double = 50
    @State private var selectedPreset: Int = 0
    
    // Presets: name + description
    private let presets: [(name: String, desc: String)] = [
        ("None", "Base color only"),
        ("Foil", "Rainbow foil overlay"),
        ("Inverted Foil", "Foil with shine"),
        ("Rainbow Glitter", "Glittery rainbow"),
        ("Shimmer", "Metallic shimmer"),
        ("Diagonal Holo", "Diagonal lines with depth"),
        ("Crisscross Holo", "Diamond pattern holo"),
        ("Galaxy Holo", "Cosmos rainbow overlay"),
        ("Blended Holo", "Luminance-blended rainbow"),
        ("Glitter", "Sparkle particles"),
        ("Multi Glitter", "Multi-scale sparkles"),
        ("Sparkles", "Tilt-activated grid"),
        ("Intense Bling", "Maximum diamond holo"),
        ("Light Sweep", "Sweeping light band"),
        ("Radial Sweep", "Rotating radial light"),
        ("Angled Sweep", "Angled light sweep"),
        ("Edge Shine", "Edge highlight"),
        ("Glare", "Following light hotspot"),
        ("Simple Glare", "Radial glare"),
        ("Starburst", "Rainbow rays from center"),
        ("Radial Star", "Star with radial fade"),
        ("Vertical Beams", "Rainbow beam pattern"),
        ("Diamond Grid", "Diamond holo pattern"),
        ("Subtle Gradient", "Large-scale gradient"),
        ("Metallic Crosshatch", "Sun-pillar crosshatch"),
        ("Polished Aluminum", "Brushed metal"),
        ("Glass Enclosure", "Beveled glass layer"),
        ("Glass Sheen", "Glass sheen overlay"),
        ("Glass Bevel", "Edge bevel thickness"),
        ("Chromatic Glass", "Prismatic RGB edges"),
        // Composite presets
        ("Foil + Glitter", "Classic holo card"),
        ("Holo + Sweep", "Diagonal with light"),
        ("Galaxy + Sparkle", "Cosmic sparkle"),
        ("Glass + Foil", "Glass over foil"),
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                previewSection
                Divider().background(Color.gray)
                tiltControlsSection
                Divider().background(Color.gray)
                baseAppearanceSection
                Divider().background(Color.gray)
                presetSelectionSection
                Divider().background(Color.gray)
                parametersSection
            }
            .padding()
        }
        .navigationTitle("Shader Lab")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black)
        // Stabilize view identity to prevent ColorPicker from causing navigation issues
        .id("shader-lab-view")
    }
    
    private var previewSection: some View {
        VStack(spacing: 16) {
            Text("Preview")
                .font(.headline)
                .foregroundStyle(.white)
            
            Text(presets[selectedPreset].name)
                .font(.subheadline)
                .foregroundStyle(.gray)
            
            TimelineView(.animation) { timeline in
                let time = startTime.distance(to: timeline.date)
                let tilt = CGPoint(x: manualTiltX, y: manualTiltY)
                
                PresetBubbleView(
                    presetIndex: selectedPreset,
                    useGradient: useGradient,
                    baseColor: baseColor,
                    gradientColor1: gradientColor1,
                    gradientColor2: gradientColor2,
                    size: bubbleSize,
                    tilt: tilt,
                    time: time,
                    intensity: intensity,
                    density: density
                )
            }
            
            HStack {
                Text("Size: \(Int(bubbleSize))")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Slider(value: $bubbleSize, in: 50...300)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var tiltControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tilt Simulation")
                .font(.headline)
                .foregroundStyle(.white)
            
            HStack {
                Text("X: \(manualTiltX, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .frame(width: 80, alignment: .leading)
                Slider(value: $manualTiltX, in: -1...1)
            }
            
            HStack {
                Text("Y: \(manualTiltY, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .frame(width: 80, alignment: .leading)
                Slider(value: $manualTiltY, in: -1...1)
            }
            
            Button("Reset") {
                manualTiltX = 0
                manualTiltY = 0
            }
            .font(.caption)
            .foregroundStyle(.blue)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var baseAppearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Base Appearance")
                .font(.headline)
                .foregroundStyle(.white)
            
            Toggle("Use Gradient", isOn: $useGradient)
                .foregroundStyle(.white)
            
            if useGradient {
                HStack {
                    Text("Color 1").foregroundStyle(.gray)
                    Spacer()
                    ColorPicker("", selection: $gradientColor1, supportsOpacity: false)
                        .labelsHidden()
                }
                HStack {
                    Text("Color 2").foregroundStyle(.gray)
                    Spacer()
                    ColorPicker("", selection: $gradientColor2, supportsOpacity: false)
                        .labelsHidden()
                }
            } else {
                HStack {
                    Text("Base Color").foregroundStyle(.gray)
                    Spacer()
                    ColorPicker("", selection: $baseColor, supportsOpacity: false)
                        .labelsHidden()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var presetSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Effect Preset")
                .font(.headline)
                .foregroundStyle(.white)
            
            Text(presets[selectedPreset].desc)
                .font(.caption)
                .foregroundStyle(.gray)
            
            Picker("Preset", selection: $selectedPreset) {
                ForEach(0..<presets.count, id: \.self) { i in
                    Text(presets[i].name).tag(i)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameters")
                .font(.headline)
                .foregroundStyle(.white)
            
            HStack {
                Text("Intensity: \(intensity, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .frame(width: 130, alignment: .leading)
                Slider(value: $intensity, in: 0...2)
            }
            
            HStack {
                Text("Density: \(density, specifier: "%.0f")")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .frame(width: 130, alignment: .leading)
                Slider(value: $density, in: 10...200)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preset Bubble View (separate struct to help compiler)

struct PresetBubbleView: View {
    let presetIndex: Int
    let useGradient: Bool
    let baseColor: Color
    let gradientColor1: Color
    let gradientColor2: Color
    let size: CGFloat
    let tilt: CGPoint
    let time: TimeInterval
    let intensity: Double
    let density: Double
    
    var body: some View {
        baseCircle
            .modifier(PresetModifier(
                index: presetIndex,
                tilt: tilt,
                time: time,
                intensity: intensity,
                density: density
            ))
            .clipShape(Circle())
    }
    
    @ViewBuilder
    private var baseCircle: some View {
        if useGradient {
            Circle()
                .fill(LinearGradient(
                    colors: [gradientColor1, gradientColor2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: size, height: size)
        } else {
            Circle()
                .fill(baseColor)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Preset Modifier (ViewModifier with explicit tilt/time)

struct PresetModifier: ViewModifier {
    let index: Int
    let tilt: CGPoint
    let time: TimeInterval
    let intensity: Double
    let density: Double
    
    func body(content: Content) -> some View {
        switch index {
        case 0: content
        case 1: content.shader(.foil(intensity: intensity), tilt: tilt, time: time)
        case 2: content.shader(.invertedFoil(intensity: intensity), tilt: tilt, time: time)
        case 3: content.shader(.rainbowGlitter(intensity: intensity), tilt: tilt, time: time)
        case 4: content.shader(.shimmer(intensity: intensity), tilt: tilt, time: time)
        case 5: content.shader(.diagonalHolo(intensity: intensity), tilt: tilt, time: time)
        case 6: content.shader(.crisscrossHolo(intensity: intensity), tilt: tilt, time: time)
        case 7: content.shader(.galaxyHolo(intensity: intensity), tilt: tilt, time: time)
        case 8: content.shader(.blendedHolo(intensity: Float(intensity), saturation: 0.75), tilt: tilt, time: time)
        case 9: content.shader(.glitter(density: density), tilt: tilt, time: time)
        case 10: content.shader(.multiGlitter(density: density), tilt: tilt, time: time)
        case 11: content.shader(.sparkles, tilt: tilt, time: time)
        case 12: content.shader(.intenseBling, tilt: tilt, time: time)
        case 13: content.shader(.lightSweep, tilt: tilt, time: time)
        case 14: content.shader(.radialSweep, tilt: tilt, time: time)
        case 15: content.shader(.angledSweep, tilt: tilt, time: time)
        case 16: content.shader(.edgeShine, tilt: tilt, time: time)
        case 17: content.shader(.glare(intensity: intensity), tilt: tilt, time: time)
        case 18: content.shader(.simpleGlare(intensity: intensity), tilt: tilt, time: time)
        case 19: content.shader(.starburst(intensity: intensity), tilt: tilt, time: time)
        case 20: content.shader(.radialStar(intensity: intensity), tilt: tilt, time: time)
        case 21: content.shader(.verticalBeams(intensity: intensity), tilt: tilt, time: time)
        case 22: content.shader(.diamondGrid(intensity: intensity), tilt: tilt, time: time)
        case 23: content.shader(.subtleGradient(intensity: intensity), tilt: tilt, time: time)
        case 24: content.shader(.metallicCrosshatch(intensity: intensity), tilt: tilt, time: time)
        case 25: content.shader(.polishedAluminum(intensity: intensity), tilt: tilt, time: time)
        case 26: content.shader(.glassEnclosure(intensity: intensity), tilt: tilt, time: time)
        case 27: content.shader(.glassSheen(intensity: intensity), tilt: tilt, time: time)
        case 28: content.shader(.glassBevel(intensity: intensity), tilt: tilt, time: time)
        case 29: content.shader(.chromaticGlass(intensity: intensity), tilt: tilt, time: time)
        // Composite presets - chain shaders with same tilt/time
        case 30: content.shader(.foil(intensity: intensity), tilt: tilt, time: time).shader(.glitter(density: density), tilt: tilt, time: time)
        case 31: content.shader(.diagonalHolo(intensity: intensity), tilt: tilt, time: time).shader(.lightSweep, tilt: tilt, time: time)
        case 32: content.shader(.galaxyHolo(intensity: intensity), tilt: tilt, time: time).shader(.sparkles, tilt: tilt, time: time)
        case 33: content.shader(.glassEnclosure(intensity: intensity), tilt: tilt, time: time).shader(.foil(intensity: intensity * 0.5), tilt: tilt, time: time)
        default: content
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ShaderPrototypingView()
    }
}
