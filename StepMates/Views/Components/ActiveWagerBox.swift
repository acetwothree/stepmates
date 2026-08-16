//
//  ActiveWagerBox.swift
//  StepMates
//
//  The prominent "what's on the line today" card: forfeit, settlement countdown, and status.
//

import SwiftUI

struct ActiveWagerBox: View {
    var wager: Wager
    var pair: UserPair
    var comparison: DailyStepComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(wager.mode == .treatYourself ? "Treat Yourself" : "Active Stake")
                    .microLabel()
                Spacer()
                CountdownBadge(deadline: .todaySettlement)
            }

            Text(headline)
                .font(SweatmatesTypography.headline(18))
                .foregroundStyle(SweatmatesColors.textOnCard)

            statusPill
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(SweatmatesColors.cardSurface))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(statusColor.opacity(0.3), lineWidth: 1.5)
        )
    }

    private var headline: String {
        switch wager.mode {
        case .versusSprint:
            if let mine = wager.stakeForCurrentUser?.stakeDescription,
               let theirs = wager.stakeForPartner?.stakeDescription {
                return mine == theirs ? mine : "You: \(mine)  ·  \(pair.partner.displayName): \(theirs)"
            }
            return wager.stakeForCurrentUser?.stakeDescription
                ?? wager.stakeForPartner?.stakeDescription
                ?? "Loser picks the forfeit"
        case .coOpSharedTarget:
            return "Combined target: \((wager.targetSteps ?? 0).formatted()) steps/day"
        case .treatYourself:
            return wager.rewardDescription ?? "Reward TBD"
        }
    }

    private var statusText: String {
        switch wager.mode {
        case .treatYourself:
            return "Treat Yourself Goal: \(pair.sharedStreak)/\(wager.streakRequirement ?? 0) days"
        case .versusSprint, .coOpSharedTarget:
            return comparison.bothHitGoal ? "Both Safe" : "At Risk"
        }
    }

    private var statusColor: Color {
        switch wager.mode {
        case .treatYourself:
            return SweatmatesColors.accentFlame
        case .versusSprint, .coOpSharedTarget:
            return comparison.bothHitGoal ? SweatmatesColors.accentLimeDeep : SweatmatesColors.danger
        }
    }

    private var statusPill: some View {
        Text(statusText)
            .font(SweatmatesTypography.microLabel(11))
            .tracking(1.2)
            .textCase(.uppercase)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(statusColor.opacity(0.16)))
            .foregroundStyle(statusColor)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: statusText)
    }
}

#Preview("Active Wager Box") {
    VStack(spacing: 16) {
        ActiveWagerBox(wager: .mockVersusSprint, pair: .mockConnected, comparison: .mockToday)
        ActiveWagerBox(wager: .mockCoOp, pair: .mockConnected, comparison: .mockBothSafe)
        ActiveWagerBox(wager: .mockTreatYourself, pair: .mockConnected, comparison: .mockToday)
    }
    .padding(20)
    .background(SweatmatesColors.background)
}
