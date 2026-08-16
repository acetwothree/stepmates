//
//  OnboardingState.swift
//  StepMates
//
//  Data collected across the onboarding flow, shared by reference across every step so
//  earlier answers (step goal, name, wager stake) are available by the time we actually
//  create the CloudKit room. Persisted once, at the end of the flow — see
//  OnboardingProfileStore.
//

import SwiftUI

/// The ordered sequence of onboarding screens, adapted from Sweatmates' workout-focused
/// flow for StepMates' passive, steps-only concept. `hook` has no shared chrome (no back
/// button, no progress bar) — it's the cold-open pain-point screen. Every step after it
/// shares one continuous progress bar, matching the reference flow.
enum OnboardingStep: Int, CaseIterable {
    case hook
    case consistency
    case wagerIntro
    case socialProof
    case stepGoal
    case wagerExplainer
    case wagerStake
    case name
    case profilePhoto
    case healthKitPermission
    case partnerInvite
    case notifications
    case unlock

    /// 0 for the first chrome-bearing step, 1 for the last — `hook` isn't included since it
    /// has no progress bar to begin with.
    var progress: Double {
        guard self != .hook else { return 0 }
        let chromeSteps = OnboardingStep.allCases.filter { $0 != .hook }
        guard let index = chromeSteps.firstIndex(of: self) else { return 0 }
        return Double(index) / Double(max(chromeSteps.count - 1, 1))
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}

/// A wager stake preset offered during onboarding — mirrors CreateWagerSheet's presets so
/// the vocabulary stays consistent once the user reaches the full wager-creation flow later.
/// `id` is explicit (not derived from `title`) specifically so `.custom` has a stable
/// identity to compare against regardless of what its display title says.
struct OnboardingWagerStake: Identifiable, Equatable {
    var id: String
    var emoji: String
    var title: String
    var description: String
}

extension OnboardingWagerStake {
    static let presets: [OnboardingWagerStake] = [
        OnboardingWagerStake(id: "dinner", emoji: "🍽️", title: "1 Dinner", description: "Loser cooks dinner"),
        OnboardingWagerStake(id: "coffee", emoji: "☕", title: "1 Coffee", description: "Loser buys coffee"),
        OnboardingWagerStake(id: "cash", emoji: "💵", title: "$10", description: "Loser pays $10"),
        OnboardingWagerStake(id: "massage", emoji: "💆", title: "1 Massage", description: "Loser gives a massage"),
    ]

    static let custom = OnboardingWagerStake(id: "custom", emoji: "✏️", title: "Create Your Own", description: "")
}

@MainActor
@Observable
final class OnboardingState {
    var dailyStepGoal = 10_000
    var selectedWagerStake: OnboardingWagerStake?
    var customWagerStake = ""
    var firstName = ""
    var profileImageData: Data?

    /// The stake description to actually store on the wager — custom text if the user chose
    /// "Create Your Own", otherwise the selected preset's description.
    var resolvedWagerStakeDescription: String? {
        if let selectedWagerStake, selectedWagerStake.id != OnboardingWagerStake.custom.id {
            return selectedWagerStake.description
        }
        let trimmed = customWagerStake.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : "Loser \(trimmed)"
    }
}
