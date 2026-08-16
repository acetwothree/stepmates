//
//  HealthKitPermissionView.swift
//  StepMates
//
//  Sets expectations for the passive, no-manual-logging model before asking for Health
//  access. Advances the flow once the system prompt resolves (any outcome) rather than
//  reactively watching authorizationStatus — same "explicit completion, not reactive state"
//  principle as PartnerInviteView, for the same reason: keeps the onboarding coordinator's
//  navigation predictable regardless of how a request happens to resolve.
//

import SwiftUI
import UIKit

struct HealthKitPermissionView: View {
    var healthKitManager: HealthKitManager
    var onFinished: () -> Void
    var onBack: (() -> Void)?

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            if onBack != nil {
                header
            }

            Spacer()

            iconBadge

            VStack(spacing: 12) {
                Text("Sync Steps\nAutomatically")
                    .multilineTextAlignment(.center)
                    .font(SweatmatesTypography.title(30))
                    .foregroundStyle(SweatmatesColors.textPrimary)

                Text("StepMates reads your daily steps from Apple Health in the background. No manual logging, no camera, no sync button — ever.")
                    .multilineTextAlignment(.center)
                    .font(SweatmatesTypography.body(15))
                    .foregroundStyle(SweatmatesColors.textSecondary)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 28)

            VStack(alignment: .leading, spacing: 16) {
                valueProp(icon: "bolt.fill", text: "Fully passive — StepMates never asks you to log anything")
                valueProp(icon: "lock.fill", text: "Private — your step data never leaves your phone")
                valueProp(icon: "flame.fill", text: "Powers your streak and every wager, automatically")
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(SweatmatesColors.cardSurface))
            .padding(.horizontal, 24)
            .padding(.top, 32)

            if healthKitManager.authorizationStatus == .denied || healthKitManager.authorizationStatus == .unavailable {
                HealthKitStatusBanner(status: healthKitManager.authorizationStatus)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()

            VStack(spacing: 14) {
                OnboardingCTAButton(
                    title: isRequesting ? "Requesting…" : "Allow Step Sync",
                    isLoading: isRequesting,
                    action: requestAccess
                )

                Button("Maybe Later", action: onFinished)
                    .font(SweatmatesTypography.body(14, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(SweatmatesColors.background.ignoresSafeArea())
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: healthKitManager.authorizationStatus)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                onBack?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            ProgressView(value: OnboardingStep.healthKitPermission.progress)
                .tint(SweatmatesColors.accentFlame)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(SweatmatesColors.flameGradient)
                .frame(width: 96, height: 96)
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func valueProp(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(SweatmatesColors.accentFlame)
                .frame(width: 24)
            Text(text)
                .font(SweatmatesTypography.body(14))
                .foregroundStyle(SweatmatesColors.textOnCard)
        }
    }

    private func requestAccess() {
        isRequesting = true
        Task {
            await healthKitManager.requestAuthorization()
            isRequesting = false
            onFinished()
        }
    }
}

#Preview("Not Determined") {
    HealthKitPermissionView(healthKitManager: .shared, onFinished: {}, onBack: {})
}

#Preview("Denied") {
    let manager = HealthKitManager.shared
    manager.authorizationStatus = .denied
    return HealthKitPermissionView(healthKitManager: manager, onFinished: {}, onBack: {})
}
