//
//  CountdownBadge.swift
//  StepMates
//
//  "Resolves in 3h 42m" — a live countdown to the daily wager settlement moment.
//

import SwiftUI

struct CountdownBadge: View {
    var deadline: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let remaining = max(0, deadline.timeIntervalSince(context.date))
            let hours = Int(remaining) / 3_600
            let minutes = (Int(remaining) % 3_600) / 60

            Label(
                remaining <= 0 ? "Settling…" : "Resolves in \(hours)h \(minutes)m",
                systemImage: "clock.fill"
            )
            .font(SweatmatesTypography.caption(12, weight: .semibold))
            .foregroundStyle(SweatmatesColors.textOnCardSecondary)
        }
    }
}

extension Date {
    /// The next occurrence of 11:59:59 PM in the current calendar — the daily wager
    /// settlement moment every active wager counts down to.
    static var todaySettlement: Date {
        let components = DateComponents(hour: 23, minute: 59, second: 59)
        return Calendar.current.nextDate(
            after: .now,
            matching: components,
            matchingPolicy: .nextTime,
            direction: .forward
        ) ?? .now
    }
}

#Preview("Countdown Badge") {
    CountdownBadge(deadline: .todaySettlement)
        .padding()
        .background(SweatmatesColors.cardSurface)
}
