//
//  OnboardingProfileStore.swift
//  StepMates
//
//  Persists what onboarding collected (name, daily step goal, local avatar) so
//  HomeViewModel can apply it to the current user instead of falling back to mock data.
//  Deliberately lightweight — UserDefaults, not CloudKit, since the profile photo in
//  particular isn't synced to the partner yet.
//

import Foundation

struct OnboardingProfile: Codable, Sendable {
    var firstName: String
    var dailyStepGoal: Int
    var profileImageData: Data?
}

enum OnboardingProfileStore {
    private static let defaultsKey = "com.stepmates.onboarding.profile"

    static func save(_ profile: OnboardingProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func load() -> OnboardingProfile? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(OnboardingProfile.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
