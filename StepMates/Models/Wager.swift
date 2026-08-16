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

/// How long a wager runs. Each partner's target scales up from their own daily goal — never a
/// fixed number either of them picks by hand — so a wager can't be quietly re-negotiated by
/// choosing an easy target once it's locked in.
enum WagerDuration: String, Codable, Sendable, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day: return "1 Day"
        case .week: return "1 Week"
        case .month: return "1 Month"
        }
    }

    /// Scales a daily goal up to this duration's period target: as-is for a day, ×7 for a
    /// week, ×(actual days in that calendar month) for a month.
    func periodTarget(dailyGoal: Int, from startDate: Date = .now, calendar: Calendar = .current) -> Int {
        switch self {
        case .day: return dailyGoal
        case .week: return dailyGoal * 7
        case .month:
            let daysInMonth = calendar.range(of: .day, in: .month, for: startDate)?.count ?? 30
            return dailyGoal * daysInMonth
        }
    }

    func endDate(from startDate: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .day: return calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        case .week: return calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        case .month: return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        }
    }
}

/// Where a wager sits in its lifecycle.
enum WagerStatus: String, Codable, Sendable {
    /// Proposed by one side, waiting on the other to agree before it locks in.
    case proposed
    /// Both partners agreed — locked in, steps are actively counting toward it.
    case active
    /// Window closed and a winner/outcome has been recorded.
    case resolved
    /// Outcome is disputed or ambiguous (e.g. a HealthKit sync gap) — held for manual
    /// confirmation by both partners before it counts as resolved.
    case disputed

    var isOpen: Bool { self == .proposed || self == .active }
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
    var duration: WagerDuration
    var status: WagerStatus

    /// Asymmetric penalty stakes, keyed per person. Empty for `.treatYourself`.
    var stakeForCurrentUser: PenaltyStake?
    var stakeForPartner: PenaltyStake?

    /// Shared numeric target for `.coOpSharedTarget` (e.g. combined 20,000 steps over the
    /// wager's duration).
    var targetSteps: Int?

    /// Per-role `.versusSprint` targets, auto-calculated from each person's own daily goal at
    /// proposal time via `duration.periodTarget(dailyGoal:)` — role-keyed (not "current
    /// user"/"partner") since this value is written once and read identically by both devices.
    var targetStepsForOwner: Int?
    var targetStepsForPartner: Int?

    /// Consecutive shared-streak days required to unlock a `.treatYourself` reward.
    var streakRequirement: Int?
    var rewardDescription: String?

    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var outcome: WagerOutcome?

    /// Whichever role proposed this wager — their side auto-agrees; the other role has to
    /// explicitly accept before `status` can move to `.active`.
    var proposedByRole: PairingRole
    var agreedByOwner: Bool
    var agreedByPartner: Bool

    init(
        id: UUID = UUID(),
        pairID: UUID,
        mode: WagerMode,
        duration: WagerDuration,
        status: WagerStatus = .proposed,
        stakeForCurrentUser: PenaltyStake? = nil,
        stakeForPartner: PenaltyStake? = nil,
        targetSteps: Int? = nil,
        targetStepsForOwner: Int? = nil,
        targetStepsForPartner: Int? = nil,
        streakRequirement: Int? = nil,
        rewardDescription: String? = nil,
        startDate: Date = .now,
        endDate: Date,
        createdAt: Date = .now,
        outcome: WagerOutcome? = nil,
        proposedByRole: PairingRole = .owner,
        agreedByOwner: Bool = false,
        agreedByPartner: Bool = false
    ) {
        self.id = id
        self.pairID = pairID
        self.mode = mode
        self.duration = duration
        self.status = status
        self.stakeForCurrentUser = stakeForCurrentUser
        self.stakeForPartner = stakeForPartner
        self.targetSteps = targetSteps
        self.targetStepsForOwner = targetStepsForOwner
        self.targetStepsForPartner = targetStepsForPartner
        self.streakRequirement = streakRequirement
        self.rewardDescription = rewardDescription
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.outcome = outcome
        self.proposedByRole = proposedByRole
        self.agreedByOwner = agreedByOwner
        self.agreedByPartner = agreedByPartner
    }

    var isUnderReview: Bool { status == .disputed }
    var isFullyAgreed: Bool { agreedByOwner && agreedByPartner }
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
        duration: .week,
        status: .active,
        stakeForCurrentUser: PenaltyStake(owner: "Ben", stakeDescription: "I cook dinner"),
        stakeForPartner: PenaltyStake(owner: "Jess", stakeDescription: "You buy matcha"),
        targetStepsForOwner: 70_000,
        targetStepsForPartner: 56_000,
        endDate: Calendar.current.date(byAdding: .day, value: 4, to: .now) ?? .now,
        proposedByRole: .owner,
        agreedByOwner: true,
        agreedByPartner: true
    )

    static let mockCoOp = Wager(
        pairID: samplePairID,
        mode: .coOpSharedTarget,
        duration: .day,
        status: .active,
        targetSteps: 20_000,
        endDate: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
        proposedByRole: .owner,
        agreedByOwner: true,
        agreedByPartner: true
    )

    static let mockTreatYourself = Wager(
        pairID: samplePairID,
        mode: .treatYourself,
        duration: .month,
        status: .active,
        streakRequirement: 14,
        rewardDescription: "Dinner on us at Nonna's",
        endDate: Calendar.current.date(byAdding: .day, value: 9, to: .now) ?? .now,
        proposedByRole: .owner,
        agreedByOwner: true,
        agreedByPartner: true
    )

    static let mockPendingReview = Wager(
        pairID: samplePairID,
        mode: .versusSprint,
        duration: .week,
        status: .disputed,
        stakeForCurrentUser: PenaltyStake(owner: "Ben", stakeDescription: "I do the dishes all week"),
        stakeForPartner: PenaltyStake(owner: "Jess", stakeDescription: "You pick the next trip"),
        endDate: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
        outcome: WagerOutcome(
            loserUserID: nil,
            bothSucceeded: false,
            resolvedAt: .now,
            confirmedByCurrentUser: true,
            confirmedByPartner: false
        ),
        proposedByRole: .owner,
        agreedByOwner: true,
        agreedByPartner: true
    )

    /// Proposed by the owner, waiting on the partner to agree — exercises the pending-agreement
    /// banner's UI.
    static let mockAwaitingAgreement = Wager(
        pairID: samplePairID,
        mode: .versusSprint,
        duration: .week,
        status: .proposed,
        stakeForCurrentUser: PenaltyStake(owner: "Ben", stakeDescription: "Loser buys coffee"),
        stakeForPartner: PenaltyStake(owner: "Jess", stakeDescription: "Loser buys coffee"),
        targetStepsForOwner: 70_000,
        targetStepsForPartner: 56_000,
        endDate: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
        proposedByRole: .owner,
        agreedByOwner: true,
        agreedByPartner: false
    )

    static let mocks: [Wager] = [.mockVersusSprint, .mockCoOp, .mockTreatYourself, .mockPendingReview, .mockAwaitingAgreement]
}
