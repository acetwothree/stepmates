//
//  WagerExplainerStepView.swift
//  StepMates
//
//  "How your weekly wager works" — the three-outcome breakdown. The mechanic itself
//  transfers directly from Sweatmates since it's about hitting-or-missing a goal, not
//  specifically about workouts.
//

import SwiftUI

private struct WagerOutcomeRow {
    var title: String
    var subtitle: String
    var subtitleColor: Color
    var youSafe: Bool
    var partnerSafe: Bool
}

struct WagerExplainerStepView: View {
    var onContinue: () -> Void
    var onBack: () -> Void

    private let rows: [WagerOutcomeRow] = [
        WagerOutcomeRow(title: "Both hit your goal", subtitle: "No one pays.", subtitleColor: SweatmatesColors.accentLimeDeep, youSafe: true, partnerSafe: true),
        WagerOutcomeRow(title: "Only one falls short", subtitle: "Whoever falls short owes 1 reward.", subtitleColor: SweatmatesColors.accentFlame, youSafe: false, partnerSafe: true),
        WagerOutcomeRow(title: "Both fall short", subtitle: "No one pays.", subtitleColor: SweatmatesColors.textSecondary, youSafe: false, partnerSafe: false),
    ]

    var body: some View {
        OnboardingScaffold(progress: OnboardingStep.wagerExplainer.progress, onBack: onBack) {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("How your weekly\nwager works")
                        .font(SweatmatesTypography.title(26, weight: .heavy))
                        .foregroundStyle(SweatmatesColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("It's simple — whoever falls short pays the weekly reward.")
                        .font(SweatmatesTypography.body(14))
                        .foregroundStyle(SweatmatesColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    ForEach(rows, id: \.title) { row in
                        outcomeCard(row)
                    }
                }
            }
        } footer: {
            OnboardingCTAButton(title: "Set your wager", action: onContinue)
        }
    }

    private func outcomeCard(_ row: WagerOutcomeRow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(SweatmatesTypography.headline(16, weight: .bold))
                    .foregroundStyle(SweatmatesColors.textOnCard)
                Text(row.subtitle)
                    .font(SweatmatesTypography.caption(13, weight: .semibold))
                    .foregroundStyle(row.subtitleColor)
            }
            Spacer()
            HStack(spacing: 10) {
                outcomeBadge(safe: row.youSafe, label: "YOU")
                outcomeBadge(safe: row.partnerSafe, label: "PARTNER")
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(SweatmatesColors.cardSurface))
    }

    private func outcomeBadge(safe: Bool, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: safe ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(safe ? SweatmatesColors.accentLimeDeep : SweatmatesColors.danger)
            Text(label)
                .font(SweatmatesTypography.microLabel(8))
                .foregroundStyle(SweatmatesColors.textOnCardSecondary)
        }
    }
}

#Preview {
    WagerExplainerStepView(onContinue: {}, onBack: {})
}
