//
//  StepArenaView.swift
//  StepMates
//
//  The hero head-to-head: dual progress rings with the step count as the largest thing on
//  screen, each person's goal + percentage underneath, and a head-to-head "leading/trailing"
//  pill comparing the two partners directly (not each against their own goal).
//

import SwiftUI

struct StepArenaView: View {
    var pair: UserPair
    var comparison: DailyStepComparison

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 24) {
                ringColumn(
                    name: "You",
                    initialsSource: pair.currentUser.displayName,
                    day: comparison.currentUserDay,
                    gradient: SweatmatesColors.flameGradient
                )
                ringColumn(
                    name: pair.partner.displayName,
                    initialsSource: pair.partner.displayName,
                    day: comparison.partnerDay,
                    gradient: SweatmatesColors.limeGradient
                )
            }
            deltaPill
        }
    }

    @ViewBuilder
    private func ringColumn(name: String, initialsSource: String, day: StepDay, gradient: LinearGradient) -> some View {
        VStack(spacing: 8) {
            avatarBubble(initialsSource: initialsSource, gradient: gradient)

            Text(name.uppercased()).microLabel()

            ZStack {
                Circle()
                    .stroke(SweatmatesColors.divider, lineWidth: 14)

                Circle()
                    .trim(from: 0, to: day.progress)
                    .stroke(gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.85), value: day.progress)

                Text(day.stepCount.formatted())
                    .font(SweatmatesTypography.statNumber(34))
                    .foregroundStyle(SweatmatesColors.textOnCard)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
            }
            .frame(width: 148, height: 148)

            Text("Goal \(day.goal.formatted()) · \(Int(day.progress * 100))%")
                .font(SweatmatesTypography.caption(12, weight: .semibold))
                .foregroundStyle(SweatmatesColors.textOnCardSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// A small initial-bubble avatar in the same gradient as that person's ring — gives each
    /// side of the head-to-head an actual face instead of just a text label, and ties the
    /// avatar visually to "their" color the same way the ring and delta pill already do.
    private func avatarBubble(initialsSource: String, gradient: LinearGradient) -> some View {
        ZStack {
            Circle().fill(gradient).frame(width: 32, height: 32)
            Text(String(initialsSource.prefix(1)).uppercased())
                .font(SweatmatesTypography.caption(13, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var deltaPill: some View {
        let content = pillContent
        return Label(content.text, systemImage: content.icon)
            .font(SweatmatesTypography.body(14, weight: .semibold))
            .foregroundStyle(content.tone)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(content.tone.opacity(0.14)))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: content.text)
    }

    /// Head-to-head framing: who's ahead of *whom*, right now — not who's ahead of their own
    /// goal. Green when the current user leads, orange when they trail, neutral on a tie.
    private var pillContent: (icon: String, text: String, tone: Color) {
        switch comparison.leader {
        case .currentUser:
            return ("arrow.up.circle.fill", "Leading by \(comparison.delta.formatted()) steps", SweatmatesColors.accentLimeDeep)
        case .partner:
            return ("arrow.down.circle.fill", "Trailing by \(comparison.delta.formatted()) steps", SweatmatesColors.accentFlame)
        case .tied:
            return ("equal.circle.fill", "Tied right now", SweatmatesColors.textSecondary)
        }
    }
}

#Preview("Step Arena — You Trailing") {
    StepArenaView(pair: .mockConnected, comparison: .mockToday)
        .padding(20)
        .background(SweatmatesColors.cardSurface)
}

#Preview("Step Arena — Partner Trailing") {
    StepArenaView(pair: .mockConnected, comparison: .mockPartnerTrailing)
        .padding(20)
        .background(SweatmatesColors.cardSurface)
}

#Preview("Step Arena — Both Safe") {
    StepArenaView(pair: .mockConnected, comparison: .mockBothSafe)
        .padding(20)
        .background(SweatmatesColors.cardSurface)
}
