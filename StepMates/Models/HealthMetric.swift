//
//  HealthMetric.swift
//  StepMates
//
//  The five metrics the Detailed Stats screen compares — a typed handle so views and
//  HealthKitManager's historical query share one vocabulary instead of passing raw
//  HKQuantityType/HKUnit values around outside the HealthKit layer.
//

import Foundation

enum HealthMetricKind: String, CaseIterable, Identifiable, Sendable {
    case steps
    case distance
    case activeCalories
    case flightsClimbed
    case activeMinutes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .steps: return "Steps"
        case .distance: return "Distance"
        case .activeCalories: return "Active Calories"
        case .flightsClimbed: return "Flights Climbed"
        case .activeMinutes: return "Active Time"
        }
    }

    var systemImage: String {
        switch self {
        case .steps: return "figure.walk"
        case .distance: return "location.fill"
        case .activeCalories: return "flame.fill"
        case .flightsClimbed: return "stairs"
        case .activeMinutes: return "timer"
        }
    }

    /// Formats a raw metric value (steps as a count, distance in meters, calories in kcal,
    /// flights as a count, active time in minutes) into display-ready text.
    func format(_ value: Double) -> String {
        switch self {
        case .steps, .flightsClimbed:
            return Int(value.rounded()).formatted()
        case .distance:
            switch UnitPreferences.distanceUnit {
            case .miles:
                return String(format: "%.1f mi", value / 1_609.34)
            case .kilometers:
                return String(format: "%.1f km", value / 1_000)
            }
        case .activeCalories:
            return "\(Int(value.rounded())) kcal"
        case .activeMinutes:
            return "\(Int(value.rounded())) min"
        }
    }
}
