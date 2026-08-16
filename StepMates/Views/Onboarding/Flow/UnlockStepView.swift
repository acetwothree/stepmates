//
//  UnlockStepView.swift
//  StepMates
//
//  Replaces Sweatmates' three-screen paywall (trial intro → trial reminder → plan picker)
//  with one honest screen: there's no billing backend behind this app yet, so rather than
//  recreate a fake pricing/trial-countdown UI that couldn't actually charge anyone, this
//  just recaps what onboarding collected and unlocks the app for free. Swap this out once
//  real StoreKit products exist.
//

import SwiftUI

struct UnlockStepView: View {
    var state: OnboardingState
    var onContinue: () -> Void
    var onBack: () -> Void

    var body: some View {
        OnboardingScaffold(progress: OnboardingStep.unlock.progress, onBack: onBack) {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(state.firstName.isEmpty ? "You're all set" : "You're all set, \(state.firstName)")
                        .font(SweatmatesTypography.title(26, weight: .heavy))
                        .foregroundStyle(SweatmatesColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Here's what you set up")
                        .font(SweatmatesTypography.body(15))
                        .foregroundStyle(SweatmatesColors.textSecondary)
                }

                summaryCard

                Label("No payment due now", systemImage: "checkmark.circle.fill")
                    .font(SweatmatesTypography.body(14, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.accentLimeDeep)
            }
        } footer: {
            OnboardingCTAButton(title: "Unlock Full Access", action: onContinue)
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            summaryRow(icon: "figure.walk", label: "Daily step goal", value: "\(state.dailyStepGoal.formatted()) steps")
            Divider().background(SweatmatesColors.divider)
            summaryRow(
                icon: "hands.sparkles.fill",
                label: "Weekly wager",
                value: state.resolvedWagerStakeDescription ?? "Not set yet"
            )
        }
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(SweatmatesColors.cardSurface))
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(SweatmatesColors.accentFlame)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(SweatmatesTypography.caption(12))
                    .foregroundStyle(SweatmatesColors.textOnCardSecondary)
                Text(value)
                    .font(SweatmatesTypography.body(15, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textOnCard)
            }
            Spacer()
        }
        .padding(16)
    }
}

#Preview {
    UnlockStepView(state: OnboardingState(), onContinue: {}, onBack: {})
}
