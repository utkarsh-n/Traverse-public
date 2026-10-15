//
//  SettingsView.swift
//  Traverse
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("useMetricUnits") private var useMetricUnits = true
    @State private var showingTestData = false
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Units section
                Section {
                    Picker("Distance Unit", selection: $useMetricUnits) {
                        Text("Kilometers").tag(true)
                        Text("Miles").tag(false)
                    }
                    .listRowBackground(ColorTheme.cardBackground)
                } header: {
                    Text("Units")
                        .foregroundStyle(ColorTheme.accent)
                } footer: {
                    Text("Choose how distances are displayed throughout the app.")
                        .foregroundStyle(ColorTheme.secondaryText)
                }
                
                // Privacy section
                Section {
                    Button {
                        openSettings()
                    } label: {
                        HStack {
                            Label("Location Settings", systemImage: "location")
                                .foregroundStyle(ColorTheme.primaryText)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTheme.secondaryText)
                        }
                    }
                    .listRowBackground(ColorTheme.cardBackground)
                    
                    Button {
                        openSettings()
                    } label: {
                        HStack {
                            Label("Motion Settings", systemImage: "figure.walk.motion")
                                .foregroundStyle(ColorTheme.primaryText)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTheme.secondaryText)
                        }
                    }
                    .listRowBackground(ColorTheme.cardBackground)
                } header: {
                    Text("Privacy")
                        .foregroundStyle(ColorTheme.accent)
                }
                
                // Developer section
                Section {
                    Button {
                        showingTestData = true
                    } label: {
                        HStack {
                            Label("Test Data", systemImage: "hammer.fill")
                                .foregroundStyle(ColorTheme.primaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTheme.secondaryText)
                        }
                    }
                    .listRowBackground(ColorTheme.cardBackground)
                    
                    NavigationLink {
                        ShaderPrototypingView()
                    } label: {
                        Label("Shader Lab", systemImage: "sparkles")
                            .foregroundStyle(ColorTheme.primaryText)
                    }
                    .listRowBackground(ColorTheme.cardBackground)
                } header: {
                    Text("Developer")
                        .foregroundStyle(ColorTheme.accent)
                } footer: {
                    Text("Tools for testing and prototyping.")
                        .foregroundStyle(ColorTheme.secondaryText)
                }
                
                // About section
                Section {
                    HStack {
                        Text("Version")
                            .foregroundStyle(ColorTheme.primaryText)
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(ColorTheme.secondaryText)
                    }
                    .listRowBackground(ColorTheme.cardBackground)
                    
                    HStack {
                        Text("Traverse")
                            .foregroundStyle(ColorTheme.primaryText)
                        Spacer()
                        Text("Your daily movement timeline")
                            .foregroundStyle(ColorTheme.secondaryText)
                            .font(.system(size: 14))
                    }
                    .listRowBackground(ColorTheme.cardBackground)
                } header: {
                    Text("About")
                        .foregroundStyle(ColorTheme.accent)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ColorTheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(ColorTheme.accent)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showingTestData) {
                TestDataView()
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
