//
//  UserPairTests.swift
//  StepMatesTests
//

import Testing
@testable import StepMates

struct UserPairTests {
    @Test func connectedPairIsActive() {
        #expect(UserPair.mockConnected.isActive)
    }

    @Test func pendingPairIsNotActive() {
        #expect(!UserPair.mockPending.isActive)
    }

    @Test func stepDayHasHitGoalWhenAtOrAboveGoal() {
        let day = StepDay(userID: PairedUser.mockMe.id, date: .now, stepCount: 10_000, goal: 10_000)
        #expect(day.hasHitGoal)
    }

    @Test func dailyStepComparisonPicksCorrectLeader() {
        let comparison = DailyStepComparison.mockToday
        let expectedLeader: StepLeader = comparison.currentUserDay.stepCount > comparison.partnerDay.stepCount ? .currentUser : .partner
        #expect(comparison.leader == expectedLeader)
    }
}
