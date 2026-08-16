//
//  NotificationsStepView.swift
//  StepMates
//
//  Requests notification permission — new capability, not used anywhere else in the app
//  yet. A one-time onboarding ask doesn't need a dedicated observable manager the way
//  HealthKit/CloudKit do, so this just calls UNUserNotificationCenter directly.
//

import SwiftUI
import UserNotifications

struct NotificationsStepView: View {
    var onContinue: () -> Void
    var onBack: () -> Void

    @State private var isRequesting = false

    var body: some View {
        OnboardingScaffold(progress: OnboardingStep.notifications.progress, onBack: onBack) {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Don't miss when your\npartner hits their goal")
                        .font(SweatmatesTypography.title(24, weight: .heavy))
                        .foregroundStyle(SweatmatesColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Stay in sync and keep each other motivated")
                        .font(SweatmatesTypography.body(14))
                        .foregroundStyle(SweatmatesColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                ZStack {
                    Circle()
                        .fill(SweatmatesColors.cardSurface)
                        .frame(width: 140, height: 140)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(SweatmatesColors.textTertiary)
                }
                .padding(.top, 20)
            }
        } footer: {
            OnboardingCTAButton(
                title: isRequesting ? "Requesting…" : "Enable Notifications",
                isLoading: isRequesting,
                action: requestNotifications
            )
        }
    }

    private func requestNotifications() {
        isRequesting = true
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            isRequesting = false
            onContinue()
        }
    }
}

#Preview {
    NotificationsStepView(onContinue: {}, onBack: {})
}
