//
//  CountdownBadge.swift
//  StepMates
//
//  "Resolves in 3h 42m" for a same-day deadline, "Resolves in 4d 6h" for a wager that spans
//  a week or month — wagers used to always be daily, so this only ever needed hours/minutes.
//

import SwiftUI

struct CountdownBadge: View {
    var deadline: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let remaining = max(0, deadline.timeIntervalSince(context.date))
            let days = Int(remaining) / 86_400
            let hours = (Int(remaining) % 86_400) / 3_600
            let minutes = (Int(remaining) % 3_600) / 60

            Label(labelText(remaining: remaining, days: days, hours: hours, minutes: minutes), systemImage: "clock.fill")
                .font(SweatmatesTypography.caption(12, weight: .semibold))
                .foregroundStyle(SweatmatesColors.textOnCardSecondary)
        }
    }

    private func labelText(remaining: TimeInterval, days: Int, hours: Int, minutes: Int) -> String {
        guard remaining > 0 else { return "Settling…" }
        if days > 0 { return "Resolves in \(days)d \(hours)h" }
        return "Resolves in \(hours)h \(minutes)m"
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
