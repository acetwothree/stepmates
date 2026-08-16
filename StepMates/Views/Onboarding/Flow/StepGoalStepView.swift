//
//  StepGoalStepView.swift
//  StepMates
//
//  Replaces Sweatmates' "how many days do you want to work out each week?" — a days-per-week
//  goal doesn't map cleanly onto a passive, every-day steps app, so this asks for a daily
//  step goal instead, which is what the rest of the app actually measures against.
//

import SwiftUI

struct StepGoalStepView: View {
    @Bindable var state: OnboardingState
    var onContinue: () -> Void
    var onBack: () -> Void

    private let options = [6_000, 8_000, 10_000, 12_000, 15_000]

    var body: some View {
        OnboardingScaffold(progress: OnboardingStep.stepGoal.progress, onBack: onBack) {
            VStack(spacing: 12) {
                Text("What's your daily\nstep goal?")
                    .font(SweatmatesTypography.title(26, weight: .heavy))
                    .foregroundStyle(SweatmatesColors.textPrimary)
                    .multilineTextAlignment(.center)

                Picker("Daily step goal", selection: $state.dailyStepGoal) {
                    ForEach(options, id: \.self) { steps in
                        Text("\(steps.formatted()) steps")
                            .font(SweatmatesTypography.title(24, weight: .bold))
                            .tag(steps)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 220)
            }
        } footer: {
            VStack(spacing: 10) {
                OnboardingCTAButton(title: "Continue", action: onContinue)
                Text("You can change this later")
                    .font(SweatmatesTypography.caption(12))
                    .foregroundStyle(SweatmatesColors.textTertiary)
            }
        }
    }
}

#Preview {
    StepGoalStepView(state: OnboardingState(), onContinue: {}, onBack: {})
}
