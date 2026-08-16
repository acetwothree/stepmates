//
//  NameStepView.swift
//  StepMates
//

import SwiftUI

struct NameStepView: View {
    @Bindable var state: OnboardingState
    var onContinue: () -> Void
    var onBack: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        OnboardingScaffold(progress: OnboardingStep.name.progress, onBack: onBack) {
            VStack(spacing: 12) {
                Text("What's your first name?")
                    .font(SweatmatesTypography.title(24, weight: .heavy))
                    .foregroundStyle(SweatmatesColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("(pet name preferred)")
                    .font(SweatmatesTypography.body(14))
                    .foregroundStyle(SweatmatesColors.textSecondary)

                TextField("", text: $state.firstName, prompt: Text("Your name").foregroundStyle(SweatmatesColors.textTertiary))
                    .font(SweatmatesTypography.title(22, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SweatmatesColors.textPrimary)
                    .textInputAutocapitalization(.words)
                    .focused($isFocused)
                    .padding(.top, 28)
                    .padding(.bottom, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(SweatmatesColors.divider).frame(height: 1)
                    }
                    .padding(.top, 40)
            }
            .onAppear { isFocused = true }
        } footer: {
            OnboardingCTAButton(
                title: "Continue",
                isEnabled: !state.firstName.trimmingCharacters(in: .whitespaces).isEmpty,
                action: onContinue
            )
        }
    }
}

#Preview {
    NameStepView(state: OnboardingState(), onContinue: {}, onBack: {})
}
