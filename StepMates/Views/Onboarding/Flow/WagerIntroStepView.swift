//
//  WagerIntroStepView.swift
//  StepMates
//
//  "Set a fun weekly wager" — introduces the stakes mechanic before asking the user to
//  actually pick one a few steps later.
//

import SwiftUI

struct WagerIntroStepView: View {
    var onContinue: () -> Void
    var onBack: () -> Void

    var body: some View {
        OnboardingScaffold(progress: OnboardingStep.wagerIntro.progress, onBack: onBack) {
            VStack(spacing: 24) {
                Text("🍽️")
                    .font(.system(size: 44))

                wagerCard

                VStack(spacing: 8) {
                    Text("Set a fun weekly wager")
                        .font(SweatmatesTypography.title(24, weight: .heavy))
                        .foregroundStyle(SweatmatesColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("A fun reward keeps you both motivated")
                        .font(SweatmatesTypography.body(15))
                        .foregroundStyle(SweatmatesColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        } footer: {
            OnboardingCTAButton(title: "Continue", action: onContinue)
        }
    }

    private var wagerCard: some View {
        VStack(spacing: 16) {
            Text("THIS WEEK'S WAGER").microLabel(color: .white.opacity(0.85))
            Text("1 Dinner")
                .font(SweatmatesTypography.title(32, weight: .heavy))
                .foregroundStyle(.white)

            HStack(spacing: 20) {
                Text("😎")
                Image(systemName: "arrow.right")
                    .foregroundStyle(.white.opacity(0.8))
                Text("🥺")
            }
            .font(.system(size: 30))
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(SweatmatesColors.flameGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

#Preview {
    WagerIntroStepView(onContinue: {}, onBack: {})
}
