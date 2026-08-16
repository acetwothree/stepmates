//
//  StepArenaView.swift
//  StepMates
//
//  The hero head-to-head: dual progress rings plus the dynamic "who's safe" delta pill.
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
                    day: comparison.currentUserDay,
                    gradient: SweatmatesColors.flameGradient
                )
                ringColumn(
                    name: pair.partner.displayName,
                    day: comparison.partnerDay,
                    gradient: SweatmatesColors.limeGradient
                )
            }
            deltaPill
        }
    }

    @ViewBuilder
    private func ringColumn(name: String, day: StepDay, gradient: LinearGradient) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(SweatmatesColors.divider, lineWidth: 14)

                Circle()
                    .trim(from: 0, to: day.progress)
                    .stroke(gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.85), value: day.progress)

                VStack(spacing: 2) {
                    Text(day.stepCount.formatted())
                        .font(SweatmatesTypography.statNumber(28))
                        .foregroundStyle(SweatmatesColors.textOnCard)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("\(Int(day.progress * 100))%")
                        .font(SweatmatesTypography.caption(12, weight: .bold))
                        .foregroundStyle(SweatmatesColors.textOnCardSecondary)
                }
                .padding(.horizontal, 8)
            }
            .frame(width: 140, height: 140)

            Text(name.uppercased()).microLabel()
        }
        .frame(maxWidth: .infinity)
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

    /// Priority: surface whichever partner still needs to move (actionable — prompts a nudge).
    /// Only once the partner is safe do we celebrate the current user's own margin.
    private var pillContent: (icon: String, text: String, tone: Color) {
        let me = comparison.currentUserDay
        let partner = comparison.partnerDay

        if !partner.hasHitGoal {
            return (
                "exclamationmark.triangle.fill",
                "\(pair.partner.displayName) is trailing — \(partner.stepsRemaining.formatted()) steps to safety",
                SweatmatesColors.accentFlame
            )
        } else if me.hasHitGoal {
            return (
                "checkmark.seal.fill",
                "You're safe (+\(me.surplusOverGoal.formatted()) steps)",
                SweatmatesColors.accentLimeDeep
            )
        } else {
            return (
                "flame.fill",
                "You're trailing — \(me.stepsRemaining.formatted()) steps to safety",
                SweatmatesColors.accentFlame
            )
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
