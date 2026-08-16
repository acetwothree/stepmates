//
//  HookStepView.swift
//  StepMates
//
//  The cold-open pain-point screen — no chrome, no progress bar, just the hook. Adapted
//  from Sweatmates' "Day 1 vs 1 week later" workout illustration into a steps framing.
//  Illustrated with two drawn scenes (OnboardingDay1 / OnboardingWeekLater in
//  Assets.xcassets) showing the same couple walking together vs. slumped on the couch.
//

import SwiftUI

struct HookStepView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            comparisonCard

            VStack(spacing: 12) {
                Text("You both start strong…")
                    .font(SweatmatesTypography.title(28, weight: .heavy))
                    .foregroundStyle(SweatmatesColors.textPrimary)
                Text("then fall off together.")
                    .font(SweatmatesTypography.title(28, weight: .heavy))
                    .foregroundStyle(SweatmatesColors.textSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 32)

            Text("Life gets busy. Motivation dips. But you still want to move more and feel closer together.")
                .font(SweatmatesTypography.body(15))
                .foregroundStyle(SweatmatesColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 14)

            Spacer()
            Spacer()

            OnboardingCTAButton(title: "This is me", action: onContinue)
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 24)
        .background(SweatmatesColors.background.ignoresSafeArea())
    }

    private var comparisonCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                comparisonColumn(label: "Day 1", imageName: "OnboardingDay1")
                Rectangle()
                    .fill(SweatmatesColors.divider)
                    .frame(width: 1)
                comparisonColumn(label: "1 Week Later", imageName: "OnboardingWeekLater")
            }
        }
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(SweatmatesColors.cardSurface))
        .padding(.horizontal, 24)
    }

    private func comparisonColumn(label: String, imageName: String) -> some View {
        VStack(spacing: 10) {
            Text(label)
                .font(SweatmatesTypography.headline(14, weight: .bold))
                .foregroundStyle(SweatmatesColors.textOnCard)
                .padding(.top, 16)

            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 130)
                .frame(maxWidth: .infinity)
                .clipped()
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

#Preview {
    HookStepView(onContinue: {})
}
