//
//  StatsViewModel.swift
//  StepMates
//
//  Drives the Detailed Stats screen's Day/Week/Month trend chart. The "Today" comparison
//  section reads healthKitManager/cloudKitSyncEngine directly and needs no fetching of its
//  own — this view model only owns the historical query, which HealthKit can answer for the
//  current user but CloudKit currently cannot for the partner (it only ever stores "today").
//

import Foundation
import Observation

enum StatsRange: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        }
    }
}

struct DailyMetricPoint: Identifiable {
    var id: Date { date }
    var date: Date
    var value: Double
}

@MainActor
@Observable
final class StatsViewModel {
    var range: StatsRange = .day
    var selectedMetric: HealthMetricKind = .steps
    var isLoading = false

    private var dailyTotals: [HealthMetricKind: [Date: Double]] = [:]
    private let healthKitManager: HealthKitManager

    init(healthKitManager: HealthKitManager = .shared) {
        self.healthKitManager = healthKitManager
    }

    func refresh() async {
        guard healthKitManager.isAuthorized else { return }
        isLoading = true
        defer { isLoading = false }

        let days = max(range.days, 7) // always fetch at least a week so switching ranges is instant
        async let steps = healthKitManager.fetchDailyTotals(for: .steps, days: days)
        async let distance = healthKitManager.fetchDailyTotals(for: .distance, days: days)
        async let calories = healthKitManager.fetchDailyTotals(for: .activeCalories, days: days)
        async let flights = healthKitManager.fetchDailyTotals(for: .flightsClimbed, days: days)
        async let activeMinutes = healthKitManager.fetchDailyTotals(for: .activeMinutes, days: days)

        if let (resolvedSteps, resolvedDistance, resolvedCalories, resolvedFlights, resolvedActiveMinutes) =
            try? await (steps, distance, calories, flights, activeMinutes) {
            dailyTotals = [
                .steps: resolvedSteps,
                .distance: resolvedDistance,
                .activeCalories: resolvedCalories,
                .flightsClimbed: resolvedFlights,
                .activeMinutes: resolvedActiveMinutes,
            ]
        }
    }

    /// Day-by-day points for the currently selected metric and range, oldest first.
    func series(for metric: HealthMetricKind) -> [DailyMetricPoint] {
        let totals = dailyTotals[metric] ?? [:]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<range.days).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return DailyMetricPoint(date: day, value: totals[day] ?? 0)
        }
    }
}
