//
//  StreakBadge.swift
//  StepMates
//
//  The 🔥 shared-streak counter — the single most-glanced-at number in the app.
//  The flame carries a subtle, continuous pulse to keep it feeling alive.
//

import SwiftUI

struct StreakBadge: View {
    var streakCount: Int
    var isAtRisk: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isAtRisk ? SweatmatesColors.danger : SweatmatesColors.accentFlame)
                .phaseAnimator([false, true]) { icon, phase in
                    icon
                        .scaleEffect(phase ? 1.18 : 1.0)
                        .opacity(phase ? 1.0 : 0.8)
                } animation: { _ in
                    .easeInOut(duration: 1.1)
                }

            Text("\(streakCount) Day Streak")
                .font(SweatmatesTypography.headline(17, weight: .bold))
                .foregroundStyle(SweatmatesColors.textOnCard)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(SweatmatesColors.cardSurfaceElevated)
        )
    }
}

#Preview("Streak Badge") {
    VStack(spacing: 16) {
        StreakBadge(streakCount: UserPair.mockConnected.sharedStreak)
        StreakBadge(streakCount: UserPair.mockNeedsRepair.sharedStreak, isAtRisk: true)
    }
    .padding(32)
    .background(SweatmatesColors.background)
}
