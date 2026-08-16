//
//  WeeklyRecap.swift
//  StepMates
//
//  Sunday night summary: who won the week, the combined mileage, and what's still owed.
//

import Foundation

/// A single unsettled stake left over from a resolved wager — shown in the weekly recap
/// until either partner marks it paid.
struct IOUDebt: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var owedByCurrentUser: Bool
    var description: String
    var isSettled: Bool

    init(
        id: UUID = UUID(),
        owedByCurrentUser: Bool,
        description: String,
        isSettled: Bool = false
    ) {
        self.id = id
        self.owedByCurrentUser = owedByCurrentUser
        self.description = description
        self.isSettled = isSettled
    }
}

/// The Sunday-night recap: the week's win/loss record between partners, combined activity,
/// and any stakes still outstanding.
struct WeeklyRecap: Identifiable, Codable, Sendable {
    let id: UUID
    var weekOf: Date
    var currentUserWins: Int
    var partnerWins: Int
    var ties: Int
    var currentUserTotalSteps: Int
    var partnerTotalSteps: Int
    var outstandingIOUs: [IOUDebt]

    init(
        id: UUID = UUID(),
        weekOf: Date = .now,
        currentUserWins: Int,
        partnerWins: Int,
        ties: Int = 0,
        currentUserTotalSteps: Int,
        partnerTotalSteps: Int,
        outstandingIOUs: [IOUDebt] = []
    ) {
        self.id = id
        self.weekOf = weekOf
        self.currentUserWins = currentUserWins
        self.partnerWins = partnerWins
        self.ties = ties
        self.currentUserTotalSteps = currentUserTotalSteps
        self.partnerTotalSteps = partnerTotalSteps
        self.outstandingIOUs = outstandingIOUs
    }

    var combinedSteps: Int { currentUserTotalSteps + partnerTotalSteps }

    /// Rough steps-to-miles conversion using the common ~2,000-steps-per-mile average stride.
    var combinedDistanceMiles: Double { Double(combinedSteps) / 2_000 }
}

// MARK: - Mock Data

extension WeeklyRecap {
    static let mock = WeeklyRecap(
        currentUserWins: 4,
        partnerWins: 3,
        ties: 0,
        currentUserTotalSteps: 68_240,
        partnerTotalSteps: 64_910,
        outstandingIOUs: [
            IOUDebt(owedByCurrentUser: false, description: "Jess buys Sunday matcha"),
            IOUDebt(owedByCurrentUser: true, description: "You cook dinner Friday"),
        ]
    )

    static let mockAllSettled = WeeklyRecap(
        currentUserWins: 5,
        partnerWins: 2,
        ties: 0,
        currentUserTotalSteps: 71_400,
        partnerTotalSteps: 59_120
    )
}
