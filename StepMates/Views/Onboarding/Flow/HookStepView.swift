//
//  HookStepView.swift
//  StepMates
//
//  The cold-open pain-point screen — no chrome, no progress bar, just the hook. Adapted
//  from Sweatmates' "Day 1 vs 1 week later" workout illustration into a steps framing.
//  Illustrated with SF Symbols (matching the rest of the app's icon language) rather than
//  custom character art.
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
        HStack(spacing: 0) {
            comparisonColumn(
                label: "Day 1",
                icon: "figure.walk",
                marks: [true, true, true],
                tint: SweatmatesColors.accentLimeDeep
            )
            Rectangle()
                .fill(SweatmatesColors.divider)
                .frame(width: 1)
                .padding(.vertical, 24)
            comparisonColumn(
                label: "1 Week Later",
                icon: "figure.seated.side",
                marks: [false, false, false],
                tint: SweatmatesColors.danger
            )
        }
        .padding(.vertical, 28)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(SweatmatesColors.cardSurface))
        .padding(.horizontal, 24)
    }

    private func comparisonColumn(label: String, icon: String, marks: [Bool], tint: Color) -> some View {
        VStack(spacing: 16) {
            Text(label)
                .font(SweatmatesTypography.headline(15, weight: .bold))
                .foregroundStyle(SweatmatesColors.textOnCard)

            HStack(spacing: 6) {
                ForEach(marks.indices, id: \.self) { index in
                    Image(systemName: marks[index] ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(tint)
                }
            }

            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(tint)
                .frame(height: 56)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HookStepView(onContinue: {})
}
