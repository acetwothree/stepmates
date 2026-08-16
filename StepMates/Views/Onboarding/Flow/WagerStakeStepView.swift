//
//  WagerStakeStepView.swift
//  StepMates
//
//  "Wager if you don't meet your weekly goal?" — presets mirror CreateWagerSheet's so the
//  vocabulary is consistent once the user reaches the full wager-creation flow later.
//

import SwiftUI

struct WagerStakeStepView: View {
    @Bindable var state: OnboardingState
    var onContinue: () -> Void
    var onBack: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        OnboardingScaffold(progress: OnboardingStep.wagerStake.progress, onBack: onBack) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wager if you don't\nmeet your weekly goal?")
                        .font(SweatmatesTypography.title(24, weight: .heavy))
                        .foregroundStyle(SweatmatesColors.textPrimary)
                    Text("If you miss your weekly goal you'll owe this.")
                        .font(SweatmatesTypography.body(14))
                        .foregroundStyle(SweatmatesColors.textSecondary)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(OnboardingWagerStake.presets) { stake in
                        stakeCard(stake)
                    }
                }

                customStakeCard

                if state.selectedWagerStake?.id == OnboardingWagerStake.custom.id {
                    TextField("e.g. massage, dessert, movie pick", text: $state.customWagerStake)
                        .font(SweatmatesTypography.body(15))
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SweatmatesColors.cardSurfaceElevated))
                        .foregroundStyle(SweatmatesColors.textPrimary)
                }
            }
        } footer: {
            VStack(spacing: 10) {
                OnboardingCTAButton(title: "Continue", isEnabled: state.resolvedWagerStakeDescription != nil, action: onContinue)
                Text("You can change this later")
                    .font(SweatmatesTypography.caption(12))
                    .foregroundStyle(SweatmatesColors.textTertiary)
            }
        }
    }

    private func stakeCard(_ stake: OnboardingWagerStake) -> some View {
        let isSelected = state.selectedWagerStake?.id == stake.id
        return Button {
            HapticService.shared.lightTap()
            state.selectedWagerStake = stake
        } label: {
            VStack(spacing: 10) {
                Text(stake.emoji).font(.system(size: 32))
                Text(stake.title)
                    .font(SweatmatesTypography.body(14, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textOnCard)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SweatmatesColors.cardSurface))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? SweatmatesColors.accentFlame : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var customStakeCard: some View {
        let isSelected = state.selectedWagerStake?.id == OnboardingWagerStake.custom.id
        return Button {
            HapticService.shared.lightTap()
            state.selectedWagerStake = OnboardingWagerStake.custom
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(SweatmatesColors.cardSurfaceElevated)
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus").foregroundStyle(SweatmatesColors.textOnCard)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create Your Own")
                        .font(SweatmatesTypography.body(15, weight: .semibold))
                        .foregroundStyle(SweatmatesColors.textOnCard)
                    Text("e.g. massage, dessert, movie pick")
                        .font(SweatmatesTypography.caption(12))
                        .foregroundStyle(SweatmatesColors.textOnCardSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textOnCardSecondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SweatmatesColors.cardSurface))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? SweatmatesColors.accentFlame : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WagerStakeStepView(state: OnboardingState(), onContinue: {}, onBack: {})
}
