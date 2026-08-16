//
//  TodaysWagerCard.swift
//  StepMates
//
//  A single-line "what's on the line" card — simplified from the old multi-mode Active Stake
//  box down to one plain-English stakes line, e.g. "Stakes: Loser buys coffee ☕️". Despite the
//  name (kept from when every wager was daily), it now covers whatever duration is active and
//  reflects the real countdown to `wager.endDate` instead of always-today.
//

import SwiftUI

struct TodaysWagerCard: View {
    var wager: Wager
    var pair: UserPair

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Wager · \(wager.duration.displayName)").microLabel()
                Spacer()
                if wager.isFullyAgreed {
                    CountdownBadge(deadline: wager.endDate)
                }
            }

            Text(stakesLine)
                .font(SweatmatesTypography.headline(18, weight: .semibold))
                .foregroundStyle(SweatmatesColors.textOnCard)

            if !wager.isFullyAgreed {
                Label("Waiting for \(pair.partner.displayName) to agree", systemImage: "hourglass")
                    .font(SweatmatesTypography.caption(12, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.pending)
            }
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
