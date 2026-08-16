//
//  TodaysWagerCard.swift
//  StepMates
//
//  A single-line "what's on the line today" card — simplified from the old multi-mode
//  Active Stake box down to one plain-English stakes line, e.g. "Stakes: Loser buys coffee ☕️".
//

import SwiftUI

struct TodaysWagerCard: View {
    var wager: Wager
    var pair: UserPair

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Wager").microLabel()
                Spacer()
                CountdownBadge(deadline: .todaySettlement)
            }

            Text(stakesLine)
                .font(SweatmatesTypography.headline(18, weight: .semibold))
                .foregroundStyle(SweatmatesColors.textOnCard)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(SweatmatesColors.cardSurface))
    }

    private var stakesLine: String {
        switch wager.mode {
        case .versusSprint:
            if let description = wager.stakeForCurrentUser?.stakeDescription ?? wager.stakeForPartner?.stakeDescription {
                return "Stakes: \(description) \(emoji(for: description))"
            }
            return "Stakes: Loser picks the forfeit"
        case .coOpSharedTarget:
            return "Combined target: \((wager.targetSteps ?? 0).formatted()) steps/day"
        case .treatYourself:
            return wager.rewardDescription.map { "Reward: \($0)" } ?? "Reward TBD"
        }
    }

    /// Presets picked during onboarding/wager creation carry an emoji; a freehand custom
    /// stake doesn't, so this just falls back to a neutral one rather than guessing.
    private func emoji(for description: String) -> String {
        OnboardingWagerStake.presets.first { $0.description == description }?.emoji ?? "🤝"
    }
}

#Preview("Today's Wager Card") {
    VStack(spacing: 16) {
        TodaysWagerCard(wager: .mockVersusSprint, pair: .mockConnected)
        TodaysWagerCard(wager: .mockCoOp, pair: .mockConnected)
        TodaysWagerCard(wager: .mockTreatYourself, pair: .mockConnected)
    }
    .padding(20)
    .background(SweatmatesColors.background)
}
