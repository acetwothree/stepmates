//
//  StepDay.swift
//  StepMates
//
//  Daily HealthKit step aggregates, per user, plus the head-to-head comparison the
//  Home screen and Wager cards are built around.
//

import Foundation

/// A cumulative step-count sample at a given hour of the day, used to draw the intraday
/// trend line and to compute "who pulled ahead when" for live deltas.
struct HourlyStepSnapshot: Identifiable, Codable, Hashable, Sendable {
    var id: Int { hour }
    /// Hour of day, 0–23, in the user's local time zone.
    var hour: Int
    /// Running total of steps from midnight through the end of this hour.
    var cumulativeSteps: Int
}

/// A single hour's worth of steps as HealthKit reports it via `HKStatisticsCollectionQuery` —
/// a per-hour delta, not a running total. Kept distinct from `HourlyStepSnapshot` (which is
/// cumulative) so the HealthKit layer stays a thin, honest mirror of what the API returns.
struct HourlyStepBucket: Identifiable, Hashable, Sendable {
    var id: Int { hour }
    var hour: Int
    var steps: Int
}

extension HourlyStepSnapshot {
    /// Rolls raw per-hour HealthKit buckets into the running-total snapshots the UI expects.
    static func cumulativeSnapshots(from buckets: [HourlyStepBucket]) -> [HourlyStepSnapshot] {
        var running = 0
        return buckets.sorted { $0.hour < $1.hour }.map { bucket in
            running += bucket.steps
            return HourlyStepSnapshot(hour: bucket.hour, cumulativeSteps: running)
        }
    }
}

/// One user's step metrics for a single calendar day, as read from HealthKit.
struct StepDay: Identifiable, Codable, Sendable {
    let id: UUID
    var userID: UUID
    var date: Date
    var stepCount: Int
    var goal: Int
    var hourlyTrend: [HourlyStepSnapshot]
    var lastSyncedAt: Date

    init(
        id: UUID = UUID(),
        userID: UUID,
        date: Date,
        stepCount: Int,
        goal: Int,
        hourlyTrend: [HourlyStepSnapshot] = [],
        lastSyncedAt: Date = .now
    ) {
        self.id = id
        self.userID = userID
        self.date = date
        self.stepCount = stepCount
        self.goal = goal
        self.hourlyTrend = hourlyTrend
        self.lastSyncedAt = lastSyncedAt
    }

    var progress: Double { goal > 0 ? min(Double(stepCount) / Double(goal), 1) : 0 }
    var hasHitGoal: Bool { stepCount >= goal }
    var stepsRemaining: Int { max(0, goal - stepCount) }
    var surplusOverGoal: Int { max(0, stepCount - goal) }
}

/// Who's ahead, right now, between the current user and their partner — the number that
/// drives the "live delta" badge on the Home screen.
enum StepLeader: String, Codable, Sendable {
    case currentUser
    case partner
    case tied
}

/// Pairs up both partners' `StepDay` for the same calendar date so the UI can render a
/// single head-to-head comparison instead of two separate step counts.
struct DailyStepComparison: Identifiable, Sendable {
    var id: Date { date }
    var date: Date
    var currentUserDay: StepDay
    var partnerDay: StepDay

    var delta: Int { abs(currentUserDay.stepCount - partnerDay.stepCount) }

    var leader: StepLeader {
        if currentUserDay.stepCount == partnerDay.stepCount { return .tied }
        return currentUserDay.stepCount > partnerDay.stepCount ? .currentUser : .partner
    }

    var bothHitGoal: Bool { currentUserDay.hasHitGoal && partnerDay.hasHitGoal }
    var eitherHitGoal: Bool { currentUserDay.hasHitGoal || partnerDay.hasHitGoal }
}

// MARK: - Mock Data

extension HourlyStepSnapshot {
    /// A smooth, realistic-looking cumulative curve for canvas previews.
    static func mockTrend(finalTotal: Int, throughHour: Int = 21) -> [HourlyStepSnapshot] {
        let wakeHour = 7
        return (0...23).map { hour in
            guard hour >= wakeHour, hour <= throughHour else {
                return HourlyStepSnapshot(hour: hour, cumulativeSteps: hour < wakeHour ? 0 : finalTotal)
            }
            let progress = Double(hour - wakeHour) / Double(max(throughHour - wakeHour, 1))
            let eased = progress * progress * (3 - 2 * progress) // smoothstep
            return HourlyStepSnapshot(hour: hour, cumulativeSteps: Int(Double(finalTotal) * eased))
        }
    }
}

extension StepDay {
    static let mockCurrentUserToday = StepDay(
        userID: PairedUser.mockMe.id,
        date: .now,
        stepCount: 8_432,
        goal: 10_000,
        hourlyTrend: .mockTrend(finalTotal: 8_432, throughHour: Calendar.current.component(.hour, from: .now))
    )

    static let mockPartnerToday = StepDay(
        userID: PairedUser.mockPartner.id,
        date: .now,
        stepCount: 9_180,
        goal: 8_000,
        hourlyTrend: .mockTrend(finalTotal: 9_180, throughHour: Calendar.current.component(.hour, from: .now))
    )

    static let mockWeek: [StepDay] = (0..<7).map { offset in
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now) ?? .now
        let total = Int.random(in: 6_000...12_500)
        return StepDay(
            userID: PairedUser.mockMe.id,
            date: date,
            stepCount: total,
            goal: 10_000,
            hourlyTrend: .mockTrend(finalTotal: total)
        )
    }
}

extension DailyStepComparison {
    /// You're behind, partner has already hit their goal — exercises the "you're trailing" pill state.
    static let mockToday = DailyStepComparison(
        date: .now,
        currentUserDay: .mockCurrentUserToday,
        partnerDay: .mockPartnerToday
    )

    /// You're safe, partner hasn't hit their goal yet — exercises the "partner is trailing" pill state.
    static let mockPartnerTrailing = DailyStepComparison(
        date: .now,
        currentUserDay: StepDay(
            userID: PairedUser.mockMe.id,
            date: .now,
            stepCount: 10_820,
            goal: 10_000,
            hourlyTrend: .mockTrend(finalTotal: 10_820)
        ),
        partnerDay: StepDay(
            userID: PairedUser.mockPartner.id,
            date: .now,
            stepCount: 6_200,
            goal: 8_000,
            hourlyTrend: .mockTrend(finalTotal: 6_200)
        )
    )

    /// Both partners have hit their goal — exercises the "both safe" pill state.
    static let mockBothSafe = DailyStepComparison(
        date: .now,
        currentUserDay: StepDay(
            userID: PairedUser.mockMe.id,
            date: .now,
            stepCount: 10_500,
            goal: 10_000,
            hourlyTrend: .mockTrend(finalTotal: 10_500)
        ),
        partnerDay: StepDay(
            userID: PairedUser.mockPartner.id,
            date: .now,
            stepCount: 8_300,
            goal: 8_000,
            hourlyTrend: .mockTrend(finalTotal: 8_300)
        )
    )
}
