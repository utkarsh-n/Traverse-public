//
//  WelcomeView.swift
//  Traverse
//

import SwiftUI

struct WelcomeView: View {
    @Environment(LocationService.self) private var locationService
    @Environment(MotionService.self) private var motionService
    
    @State private var currentStep: OnboardingStep = .welcome
    @Binding var isOnboardingComplete: Bool
    
    enum OnboardingStep {
        case welcome
        case motion
        case location
        case complete
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon
            Image(systemName: iconForStep)
                .font(.system(size: 64))
                .foregroundStyle(ColorTheme.accent)
                .padding(.bottom, 32)
            
            // Title
            Text(titleForStep)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(ColorTheme.primaryText)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)
            
            // Description
            Text(descriptionForStep)
                .font(.system(size: 16))
                .foregroundStyle(ColorTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Action button
            Button {
                handleAction()
            } label: {
                Text(buttonTitleForStep)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ColorTheme.accent)
                    }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(ColorTheme.background)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Step Content
    
    private var iconForStep: String {
        switch currentStep {
        case .welcome: return "figure.walk"
        case .motion: return "figure.walk.motion"
        case .location: return "location.fill"
        case .complete: return "checkmark.circle.fill"
        }
    }
    
    private var titleForStep: String {
        switch currentStep {
        case .welcome: return "Welcome to Traverse"
        case .motion: return "Track Your Movement"
        case .location: return "Know Where You Go"
        case .complete: return "You're All Set"
        }
    }
    
    private var descriptionForStep: String {
        switch currentStep {
        case .welcome:
            return "Traverse quietly tracks your daily movement — walks, runs, bike rides, and drives — and shows your day as a storyline."
        case .motion:
            return "Traverse uses motion data to detect whether you're walking, running, cycling, or driving. This runs in the background with minimal battery impact."
        case .location:
            return "Traverse tracks your location throughout the day to build your personal movement timeline. Your data stays on your device."
        case .complete:
            return "Traverse will now quietly track your day in the background. Just live your life and open the app to see your story unfold."
        }
    }
    
    private var buttonTitleForStep: String {
        switch currentStep {
        case .welcome: return "Get Started"
        case .motion: return "Enable Motion Tracking"
        case .location: return "Enable Location Tracking"
        case .complete: return "Start Exploring"
        }
    }
    
    // MARK: - Actions
    
    private func handleAction() {
        switch currentStep {
        case .welcome:
            withAnimation {
                currentStep = .motion
            }
            
        case .motion:
            // Request motion authorization first, then proceed
            Task {
                await motionService.requestAuthorization()
                
                await MainActor.run {
                    withAnimation {
                        currentStep = .location
                    }
                }
            }
            
        case .location:
            // Request location permission
            locationService.requestWhenInUseAuthorization()
            
            // Wait a bit for the dialog, then request Always
            Task {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    locationService.requestAlwaysAuthorization()
                }
                
                try? await Task.sleep(for: .seconds(0.5))
                await MainActor.run {
                    withAnimation {
                        currentStep = .complete
                    }
                }
            }
            
        case .complete:
            // Mark onboarding as complete
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            
            withAnimation {
                isOnboardingComplete = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView(isOnboardingComplete: .constant(false))
        .environment(LocationService())
        .environment(MotionService())
}
