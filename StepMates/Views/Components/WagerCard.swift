//
//  WagerCard.swift
//  StepMates
//
//  Renders any Wager mode (Versus Sprint, Co-Op, Treat Yourself) as one consistent card.
//

import SwiftUI

struct WagerCard: View {
    var wager: Wager

    private var statusColor: Color {
        switch wager.status {
        case .pending: return SweatmatesColors.pending
        case .active: return SweatmatesColors.accentLime
        case .resolved: return SweatmatesColors.textTertiary
        case .pinkyPromiseReview: return SweatmatesColors.accentFlame
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(wager.mode.displayName).microLabel(color: SweatmatesColors.textOnCardSecondary)
                Spacer()
                statusPill
            }

            Text(wager.mode.tagline)
                .font(SweatmatesTypography.headline(17))
                .foregroundStyle(SweatmatesColors.textOnCard)

            stakesView

            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                Text(wager.daysRemaining == 0 ? "Ends today" : "\(wager.daysRemaining)d left")
                    .font(SweatmatesTypography.caption(12))
            }
            .foregroundStyle(SweatmatesColors.textOnCardSecondary)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(SweatmatesColors.cardSurface))
    }

    @ViewBuilder
    private var statusPill: some View {
        Text(wager.status == .pinkyPromiseReview ? "Pinky Promise" : wager.status.rawValue.capitalized)
            .font(SweatmatesTypography.microLabel(10))
            .tracking(1.2)
            .textCase(.uppercase)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(statusColor.opacity(0.18)))
            .foregroundStyle(statusColor)
    }

    @ViewBuilder
    private var stakesView: some View {
        switch wager.mode {
        case .versusSprint:
            VStack(alignment: .leading, spacing: 6) {
                if let mine = wager.stakeForCurrentUser {
                    stakeRow(icon: "person.fill", text: "If I lose: \(mine.stakeDescription)")
                }
                if let theirs = wager.stakeForPartner {
                    stakeRow(icon: "person.fill.badge.plus", text: "If they lose: \(theirs.stakeDescription)")
                }
            }
        case .coOpSharedTarget:
            if let target = wager.targetSteps {
                stakeRow(icon: "target", text: "Combined target: \(target) steps/day")
            }
        case .treatYourself:
            VStack(alignment: .leading, spacing: 6) {
                if let requirement = wager.streakRequirement {
                    stakeRow(icon: "flame.fill", text: "\(requirement)-day streak unlocks it")
                }
                if let reward = wager.rewardDescription {
                    stakeRow(icon: "gift.fill", text: reward)
                }
            }
        }
    }

    private func stakeRow(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(SweatmatesTypography.body(14))
            .foregroundStyle(SweatmatesColors.textOnCard.opacity(0.85))
    }
}

#Preview("Wager Cards") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(Wager.mocks) { wager in
                WagerCard(wager: wager)
            }
        }
        .padding(20)
    }
    .background(SweatmatesColors.background)
}
