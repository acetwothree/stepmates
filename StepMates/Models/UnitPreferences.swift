//
//  UnitPreferences.swift
//  StepMates
//
//  A plain UserDefaults-backed preference (same pattern as OnboardingProfileStore) rather
//  than an @Observable singleton — HealthMetricKind.format reads it from a non-isolated
//  context, and UserDefaults access itself is already thread-safe.
//

import Foundation

enum DistanceUnit: String, CaseIterable, Identifiable, Sendable {
    case miles
    case kilometers

    var id: String { rawValue }
    var displayName: String { self == .miles ? "Miles" : "Kilometers" }
}

enum UnitPreferences {
    private static let distanceUnitKey = "com.stepmates.settings.distanceUnit"

    static var distanceUnit: DistanceUnit {
        get { DistanceUnit(rawValue: UserDefaults.standard.string(forKey: distanceUnitKey) ?? "") ?? .miles }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: distanceUnitKey) }
    }
}
