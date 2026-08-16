//
//  Wager.swift
//  StepMates
//
//  Sweatmates-style stakes, rebuilt around passive step counts instead of logged workouts.
//

import Foundation

/// How a wager scores the two partners against each other.
enum WagerMode: String, Codable, Sendable, CaseIterable {
    /// Head-to-head: whoever falls short of the goal (or falls furthest behind) pays the stake.
    case versusSprint
    /// Both partners share one target; either both hit it and stay safe, or both pay.
    case coOpSharedTarget
    /// No losing side — hitting a shared multi-day streak unlocks a joint reward for both.
    case treatYourself

    var displayName: String {
        switch self {
        case .versusSprint: return "Versus Sprint"
        case .coOpSharedTarget: return "Co-Op Shared Target"
        case .treatYourself: return "Treat Yourself"
        }
    }

    var tagline: String {
        switch self {
        case .versusSprint: return "Loser pays."
        case .coOpSharedTarget: return "Both safe or both pay."
        case .treatYourself: return "Hit the streak, treat yourselves."
        }
    }
}

/// Where a wager sits in its lifecycle.
enum WagerStatus: String, Codable, Sendable {
    /// Created, both sides haven't confirmed the stakes yet.
    case pending
    /// Confirmed by both partners, steps are actively counting toward it.
    case active
    /// Window closed and a winner/outcome has been recorded.
    case resolved
    /// Outcome is disputed or ambiguous (e.g. a HealthKit sync gap) — held for manual confirmation
    /// by both partners, mirroring Sweatmates' honor-system "Pinky Promise" review.
    case pinkyPromiseReview

    var isOpen: Bool { self == .pending || self == .active }
}

/// One side of an asymmetric penalty — the stake only pays out if *that* person loses.
struct PenaltyStake: Codable, Hashable, Sendable {
    var owner: String
    var stakeDescription: String

    static let example = PenaltyStake(owner: "Ben", stakeDescription: "I cook dinner")
    static let exampleReciprocal = PenaltyStake(owner: "Jess", stakeDescription: "You buy matcha")
}

/// Who ended up owing what once a wager resolves.
struct WagerOutcome: Codable, Hashable, Sendable {
    var loserUserID: UUID?
    var bothSucceeded: Bool
    var resolvedAt: Date
    var confirmedByCurrentUser: Bool
    var confirmedByPartner: Bool

    var isFullyConfirmed: Bool { confirmedByCurrentUser && confirmedByPartner }
}

/// A single stake between two partners — the core "game loop" object every home screen card,
/// nudge, and streak calculation is built around.
struct Wager: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var pairID: UUID
    var mode: WagerMode
    var status: WagerStatus

    /// Asymmetric penalty stakes, keyed per person. Empty for `.treatYourself`.
    var stakeForCurrentUser: PenaltyStake?
    var stakeForPartner: PenaltyStake?

    /// Shared numeric target for `.coOpSharedTarget` (e.g. combined 20,000 steps/day).
    var targetSteps: Int?

    /// Consecutive shared-streak days required to unlock a `.treatYourself` reward.
    var streakRequirement: Int?
    var rewardDescription: String?

    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var outcome: WagerOutcome?

    init(
        id: UUID = UUID(),
        pairID: UUID,
        mode: WagerMode,
        status: WagerStatus = .pending,
        stakeForCurrentUser: PenaltyStake? = nil,
        stakeForPartner: PenaltyStake? = nil,
        targetSteps: Int? = nil,
        streakRequirement: Int? = nil,
        rewardDescription: String? = nil,
        startDate: Date = .now,
        endDate: Date,
        createdAt: Date = .now,
        outcome: WagerOutcome? = nil
    ) {
        self.id = id
        self.pairID = pairID
        self.mode = mode
        self.status = status
        self.stakeForCurrentUser = stakeForCurrentUser
        self.stakeForPartner = stakeForPartner
        self.targetSteps = targetSteps
        self.streakRequirement = streakRequirement
        self.rewardDescription = rewardDescription
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.outcome = outcome
    }

    var isUnderReview: Bool { status == .pinkyPromiseReview }
    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: .now, to: endDate).day ?? 0)
    }
}

// MARK: - Mock Data

extension Wager {
    private static let samplePairID = UserPair.mockConnected.id

    static let mockVersusSprint = Wager(
        pairID: samplePairID,
        mode: .versusSprint,
        status: .active,
        stakeForCurrentUser: PenaltyStake(owner: "Ben", stakeDescription: "I cook dinner"),
        stakeForPartner: PenaltyStake(owner: "Jess", stakeDescription: "You buy matcha"),
        endDate: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    )

    static let mockCoOp = Wager(
        pairID: samplePairID,
        mode: .coOpSharedTarget,
        status: .active,
        targetSteps: 20_000,
        endDate: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    )

    static let mockTreatYourself = Wager(
        pairID: samplePairID,
        mode: .treatYourself,
        status: .active,
        streakRequirement: 14,
        rewardDescription: "Dinner on us at Nonna's",
        endDate: Calendar.current.date(byAdding: .day, value: 9, to: .now) ?? .now
    )

    static let mockPendingReview = Wager(
        pairID: samplePairID,
        mode: .versusSprint,
        status: .pinkyPromiseReview,
        stakeForCurrentUser: PenaltyStake(owner: "Ben", stakeDescription: "I do the dishes all week"),
        stakeForPartner: PenaltyStake(owner: "Jess", stakeDescription: "You pick the next trip"),
        endDate: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
        outcome: WagerOutcome(
            loserUserID: nil,
            bothSucceeded: false,
            resolvedAt: .now,
            confirmedByCurrentUser: true,
            confirmedByPartner: false
        )
    )

    static let mocks: [Wager] = [.mockVersusSprint, .mockCoOp, .mockTreatYourself, .mockPendingReview]
}
