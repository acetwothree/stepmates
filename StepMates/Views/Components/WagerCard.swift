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
        case .proposed: return SweatmatesColors.pending
        case .active: return SweatmatesColors.accentLime
        case .resolved: return SweatmatesColors.textTertiary
        case .disputed: return SweatmatesColors.accentFlame
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(wager.mode.displayName) · \(wager.duration.displayName)").microLabel(color: SweatmatesColors.textOnCardSecondary)
                Spacer()
                statusPill
            }

            Text(wager.mode.tagline)
                .font(SweatmatesTypography.headline(17))
                .foregroundStyle(SweatmatesColors.textOnCard)

            stakesView

            if wager.isFullyAgreed {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                    Text(wager.daysRemaining == 0 ? "Ends today" : "\(wager.daysRemaining)d left")
                        .font(SweatmatesTypography.caption(12))
                }
                .foregroundStyle(SweatmatesColors.textOnCardSecondary)
            } else {
                Text("Locks in once both of you agree")
                    .font(SweatmatesTypography.caption(12, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.pending)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(SweatmatesColors.cardSurface))
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
    }

    @ViewBuilder
    private var statusPill: some View {
        Text(wager.status == .disputed ? "Under Review" : wager.status.rawValue.capitalized)
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
                    stakeRow(icon: "person.fill", text: "If I lose: \(mine.stakeDescription)", iconTint: SweatmatesColors.accentFlame)
                }
                if let theirs = wager.stakeForPartner {
                    stakeRow(icon: "person.fill.badge.plus", text: "If they lose: \(theirs.stakeDescription)", iconTint: SweatmatesColors.accentLimeDeep)
                }
                if let target = wager.targetStepsForOwner ?? wager.targetStepsForPartner {
                    stakeRow(icon: "target", text: "Target: \(target.formatted()) steps over \(wager.duration.displayName.lowercased())")
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

    /// Icon and text are colored independently (not a single-tint Label) so a stake's icon can
    /// carry the flame/lime "whose side" color the rest of the app already uses (see the ring
    /// avatars in StepArenaView) without recoloring the stake description text itself — lime is
    /// too light against the cream card to stay readable as body text.
    private func stakeRow(icon: String, text: String, iconTint: Color = SweatmatesColors.textOnCard.opacity(0.7)) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 18)
            Text(text)
                .font(SweatmatesTypography.body(14))
                .foregroundStyle(SweatmatesColors.textOnCard.opacity(0.85))
        }
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
