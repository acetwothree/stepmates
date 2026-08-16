//
//  HomeViewModelTests.swift
//  StepMatesTests
//

import Testing
@testable import StepMates

@MainActor
struct HomeViewModelTests {
    @Test func sendNudgeShowsConfirmationWithPartnerName() {
        let viewModel = HomeViewModel()
        viewModel.sendNudge()
        #expect(viewModel.nudgeConfirmation == "Nudge sent to \(viewModel.pair.partner.displayName)!")
    }

    @Test func requestPinkyPromiseMovesStateToRequested() {
        let viewModel = HomeViewModel()
        viewModel.requestPinkyPromise()
        #expect(viewModel.pinkyPromiseState == .requested)
    }

    @Test func repeatedPinkyPromiseRequestWhilePendingIsIgnored() {
        let viewModel = HomeViewModel()
        viewModel.requestPinkyPromise()
        viewModel.requestPinkyPromise()
        #expect(viewModel.pinkyPromiseState == .requested)
    }

    @Test func addWagerReplacesActiveWager() {
        let viewModel = HomeViewModel(activeWager: nil)
        viewModel.addWager(.mockCoOp)
        #expect(viewModel.activeWager?.id == Wager.mockCoOp.id)
    }

    @Test func recapDoesNotAutoPresentOnANonSunday() {
        let viewModel = HomeViewModel()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))!
        viewModel.presentRecapIfNeeded(calendar: calendar, now: monday)
        #expect(viewModel.showWeeklyRecap == false)
    }

    @Test func recapAutoPresentsOnSundayWhenPartnerIsConnected() {
        // The gate lives on cloudKitSyncEngine.partnerSnapshot (the real signal that a
        // partner has synced at least once), not on any field derived from mock/empty pair
        // state — CloudKitSyncEngine is a singleton, so set and clear it explicitly to
        // avoid leaking state into other tests.
        CloudKitSyncEngine.shared.partnerSnapshot = MemberSnapshot(
            userRecordID: "test-partner",
            displayName: "Partner",
            currentSteps: 0,
            todayDistance: 0,
            lastSyncedAt: .now,
            pendingPinkyPromise: nil,
            lastNudgeTimestamp: nil
        )
        defer { CloudKitSyncEngine.shared.partnerSnapshot = nil }

        let viewModel = HomeViewModel()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 16))!
        viewModel.presentRecapIfNeeded(calendar: calendar, now: sunday)
        #expect(viewModel.showWeeklyRecap == true)
    }

    @Test func recapDoesNotAutoPresentForAFreshPairingEvenOnSunday() {
        // No partnerSnapshot at all — the default, unconnected state. Shouldn't get a
        // "weekly recap" popup for a week that never happened; this is the exact scenario
        // that used to flash the recap modal right after completing onboarding.
        let viewModel = HomeViewModel()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 16))!
        viewModel.presentRecapIfNeeded(calendar: calendar, now: sunday)
        #expect(viewModel.showWeeklyRecap == false)
    }
}
