//
//  WeeklyRecapTests.swift
//  StepMatesTests
//

import Testing
@testable import StepMates

struct WeeklyRecapTests {
    @Test func combinedStepsSumsBothPartners() {
        let recap = WeeklyRecap(currentUserWins: 4, partnerWins: 3, currentUserTotalSteps: 1_000, partnerTotalSteps: 2_000)
        #expect(recap.combinedSteps == 3_000)
    }

    @Test func combinedDistanceUsesTwoThousandStepsPerMile() {
        let recap = WeeklyRecap(currentUserWins: 4, partnerWins: 3, currentUserTotalSteps: 2_000, partnerTotalSteps: 2_000)
        #expect(recap.combinedDistanceMiles == 2.0)
    }
}
