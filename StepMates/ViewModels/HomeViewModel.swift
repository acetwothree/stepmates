//
//  HomeViewModel.swift
//  StepMates
//
//  Drives the Home screen's game state. The current user's steps mirror HealthKitManager
//  live; the partner's steps, the shared streak, and the active wager mirror
//  CloudKitSyncEngine live. Nudges and new wagers round-trip through CloudKit for real —
//  nothing here is simulated anymore.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class HomeViewModel {
    var pair: UserPair
    var comparison: DailyStepComparison
    var activeWager: Wager?
    var weeklyRecap: WeeklyRecap
    var healthKitManager: HealthKitManager
    var cloudKitSyncEngine: CloudKitSyncEngine

    var nudgeConfirmation: String?
    var showWeeklyRecap = false
    var showStats = false
    var showSettings = false

    // Hamburger menu + the full-screen pages it opens. Every one of these is presented
    // directly from HomeView (not nested inside the menu's own presentation), so dismissing
    // any of them — back arrow or swipe/tap-out — always lands back on Home, never on an
    // intermediate menu screen.
    var showMenu = false
    var showWeeklyRules = false
    var showWagerBalance = false
    var showPartnerPage = false
    var showHistory = false

    private var nudgeClearTask: Task<Void, Never>?
    private var hasOfferedRecapThisSession = false

    init(
        pair: UserPair = .empty,
        comparison: DailyStepComparison = .empty,
        activeWager: Wager? = nil,
        weeklyRecap: WeeklyRecap = .empty,
        healthKitManager: HealthKitManager = .shared,
        cloudKitSyncEngine: CloudKitSyncEngine = .shared
    ) {
        self.pair = pair
        self.comparison = comparison
        self.activeWager = activeWager
        self.weeklyRecap = weeklyRecap
        self.healthKitManager = healthKitManager
        self.cloudKitSyncEngine = cloudKitSyncEngine

        // Apply whatever onboarding collected (name, daily step goal) over the empty
        // defaults, so answering those questions during onboarding actually shows up.
        if let profile = OnboardingProfileStore.load() {
            if !profile.firstName.isEmpty {
                self.pair.currentUser.displayName = profile.firstName
            }
            self.pair.currentUser.dailyStepGoal = profile.dailyStepGoal
            self.comparison.currentUserDay.goal = profile.dailyStepGoal
        }

        // Pick up whatever each engine already has before arming tracking for whatever
        // comes next — withObservationTracking's onChange only fires on the *next*
        // mutation, not the value already current at registration time.
        syncStepsFromHealthKit()
        observeHealthKitChanges()

        syncFromCloudKit()
        observeCloudKitChanges()
    }

    // MARK: HealthKit -> local state -> CloudKit

    private func observeHealthKitChanges() {
        withObservationTracking {
            _ = healthKitManager.todaySteps
            _ = healthKitManager.todayHourlyTrend
        } onChange: { [weak self] in
            // Resolve self once here, then hand off to a single @MainActor helper — the
            // Task body does nothing but that one call, with no `await` inside it (no
            // suspension point for region analysis to lose track of self across).
            guard let self else { return }
            Task { @MainActor in
                self.handleHealthKitChange()
            }
        }
    }

    private func handleHealthKitChange() {
        syncStepsFromHealthKit()
        observeHealthKitChanges()
    }

    /// Applies HealthKit's latest numbers to the current user's `StepDay`, recalculates the
    /// live delta, fires the daily-victory haptic exactly once on crossing into "safe," and
    /// forwards the new total to CloudKit so the partner's device picks it up.
    private func syncStepsFromHealthKit() {
        guard healthKitManager.isAuthorized else { return }

        let wasSafe = comparison.currentUserDay.hasHitGoal
        var updatedDay = comparison.currentUserDay
        updatedDay.stepCount = healthKitManager.todaySteps
        if !healthKitManager.todayHourlyTrend.isEmpty {
            updatedDay.hourlyTrend = healthKitManager.todayHourlyTrend
        }
        updatedDay.lastSyncedAt = healthKitManager.lastSyncedAt ?? .now

        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            comparison = DailyStepComparison(
                date: comparison.date,
                currentUserDay: updatedDay,
                partnerDay: comparison.partnerDay
            )
        }

        if !wasSafe, updatedDay.hasHitGoal {
            HapticService.shared.dailyVictory()
        }

        cloudKitSyncEngine.schedulePushLocalSteps(
            StepPushPayload(
                steps: updatedDay.stepCount,
                distance: healthKitManager.todayDistanceMeters,
                activeCalories: healthKitManager.todayActiveCalories,
                flightsClimbed: healthKitManager.todayFlightsClimbed,
                activeMinutes: healthKitManager.todayActiveMinutes,
                goal: updatedDay.goal
            )
        )
    }

    // MARK: CloudKit -> local state

    private func observeCloudKitChanges() {
        withObservationTracking {
            _ = cloudKitSyncEngine.partnerSnapshot
            _ = cloudKitSyncEngine.roomSnapshot
            _ = cloudKitSyncEngine.mySnapshot
            _ = cloudKitSyncEngine.pairingState
        } onChange: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.handleCloudKitChange()
            }
        }
    }

    private func handleCloudKitChange() {
        syncFromCloudKit()
        observeCloudKitChanges()
    }

    /// Mirrors the room and both member snapshots into `pair`, `comparison`, and
    /// `activeWager` — the same fields the UI already reads, now backed by live data
    /// instead of mock state.
    private func syncFromCloudKit() {
        if let partner = cloudKitSyncEngine.partnerSnapshot {
            pair.partner.displayName = partner.displayName
            pair.connectionStatus = partner.lastSyncedAt.timeIntervalSinceNow < -86_400 ? .needsRepair : .connected

            var partnerDay = comparison.partnerDay
            partnerDay.stepCount = partner.currentSteps
            partnerDay.lastSyncedAt = partner.lastSyncedAt
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                comparison = DailyStepComparison(
                    date: comparison.date,
                    currentUserDay: comparison.currentUserDay,
                    partnerDay: partnerDay
                )
            }
        } else if cloudKitSyncEngine.pairingState == .paired {
            // Room exists but the partner hasn't written their first state yet.
            pair.connectionStatus = .pending
        }

        if let room = cloudKitSyncEngine.roomSnapshot {
            pair.sharedStreak = room.streakCount
            pair.currentUser.dailyStepGoal = room.targetGoal
            comparison.currentUserDay.goal = room.targetGoal
            if let wager = room.activeWager {
                activeWager = wager
            }
        }

        if let mine = cloudKitSyncEngine.mySnapshot {
            pair.currentUser.displayName = mine.displayName
        }
    }

    // MARK: Actions

    /// Sends the "Digital Nudge" haptic poke, shows a transient confirmation banner, and
    /// touches the real CloudKit record so the partner's device is actually notified.
    func sendNudge() {
        HapticService.shared.nudge()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            nudgeConfirmation = "Nudge sent to \(pair.partner.displayName)!"
        }

        nudgeClearTask?.cancel()
        nudgeClearTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                nudgeConfirmation = nil
            }
        }

        Task {
            await cloudKitSyncEngine.sendNudge()
        }
    }

    /// Forces a fresh pull from both HealthKit and CloudKit — called every time Home appears,
    /// not just relying on the one-shot fetch from onboarding's authorization request. That
    /// one-shot fetch has no retry path if it silently fails (network hiccup, HealthKit not
    /// fully warmed up on a genuinely first launch), and the HealthKit observer only fires on
    /// *new* samples — so if the user already had steps logged before ever opening the app and
    /// takes no further steps while it's foregrounded, a failed initial fetch would otherwise
    /// never self-correct.
    func refreshAll() async {
        await healthKitManager.refreshTodayStats()
        await cloudKitSyncEngine.refreshFromCloud()
    }

    /// The current wager, but only when it's a proposal genuinely waiting on *this* device to
    /// respond — nil once both sides have agreed, and nil for the proposer's own device (they
    /// already auto-agreed by proposing, so they see the "waiting on partner" state on the
    /// wager card instead of a banner asking them to respond to themselves).
    var wagerAwaitingMyAgreement: Wager? {
        guard let wager = activeWager, !wager.isFullyAgreed, let myRole = cloudKitSyncEngine.role else { return nil }
        let haveIAgreed = myRole == .owner ? wager.agreedByOwner : wager.agreedByPartner
        return haveIAgreed ? nil : wager
    }

    /// Answers a wager the partner proposed. Accepting marks this device's role as agreed and,
    /// once both sides have agreed, flips status to `.active` — locked in until it resolves.
    /// Declining clears the proposal outright rather than leaving a rejected wager lingering.
    func respondToWagerProposal(accept: Bool) {
        guard var wager = activeWager, let myRole = cloudKitSyncEngine.role else { return }
        HapticService.shared.wagerLock()

        guard accept else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                activeWager = nil
            }
            Task { try? await cloudKitSyncEngine.clearActiveWager() }
            return
        }

        switch myRole {
        case .owner: wager.agreedByOwner = true
        case .partner: wager.agreedByPartner = true
        }
        if wager.isFullyAgreed {
            wager.status = .active
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            activeWager = wager
        }
        Task {
            try? await cloudKitSyncEngine.updateActiveWager(wager)
        }
    }

    func addWager(_ wager: Wager) {
        HapticService.shared.wagerLock()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            activeWager = wager
        }
        Task {
            try? await cloudKitSyncEngine.updateActiveWager(wager)
        }
    }

    /// Surfaces the weekly recap automatically on Sundays, once per session — but only once
    /// the pairing is actually established (partner has synced at least once). Gates
    /// directly on cloudKitSyncEngine.partnerSnapshot rather than pair.connectionStatus:
    /// the latter defaults to UserPair.empty's .pending, true, but a *skipped* or
    /// failed pairing attempt could otherwise leave stale/mock-derived state that
    /// satisfies a looser check. partnerSnapshot is nil until the partner has genuinely
    /// synced at least once, which is the real precondition for a recap to mean anything.
    func presentRecapIfNeeded(calendar: Calendar = .current, now: Date = .now) {
        guard !hasOfferedRecapThisSession else { return }
        guard cloudKitSyncEngine.partnerSnapshot != nil else { return }
        hasOfferedRecapThisSession = true
        if calendar.component(.weekday, from: now) == 1 {
            showWeeklyRecap = true
            Task { await refreshWeeklyRecap() }
        }
    }

    /// Pulls the trailing 7 days of real `DailyResultRecord`s and turns them into a genuine
    /// win/loss record and combined steps. Outstanding IOUs apply the *current* active wager's
    /// stakes across however many days each side lost this week — there's no per-day wager
    /// history, so a wager that changed mid-week would misattribute a couple of days' stakes.
    /// Days missing a record for either side (not paired yet that day, or a sync gap) are
    /// simply skipped rather than backfilled with a fabricated value.
    func refreshWeeklyRecap() async {
        guard let myRole = cloudKitSyncEngine.role else { return }
        let results = await cloudKitSyncEngine.fetchWeeklyResults()
        guard !results.isEmpty else { return }

        let calendar = Calendar.current
        let byDay = Dictionary(grouping: results) { calendar.startOfDay(for: $0.date) }

        var currentUserWins = 0
        var partnerWins = 0
        var ties = 0
        var currentUserTotal = 0
        var partnerTotal = 0
        var currentUserLossDays = 0
        var partnerLossDays = 0

        for dayResults in byDay.values {
            guard let mine = dayResults.first(where: { $0.role == myRole }),
                  let theirs = dayResults.first(where: { $0.role != myRole }) else { continue }

            currentUserTotal += mine.stepCount
            partnerTotal += theirs.stepCount

            if mine.stepCount == theirs.stepCount {
                ties += 1
            } else if mine.stepCount > theirs.stepCount {
                currentUserWins += 1
                partnerLossDays += 1
            } else {
                partnerWins += 1
                currentUserLossDays += 1
            }
        }

        var outstandingIOUs: [IOUDebt] = []
        if let wager = activeWager, wager.mode == .versusSprint {
            if currentUserLossDays > 0, let stake = wager.stakeForCurrentUser?.stakeDescription {
                let suffix = currentUserLossDays > 1 ? " ×\(currentUserLossDays)" : ""
                outstandingIOUs.append(IOUDebt(owedByCurrentUser: true, description: "\(stake)\(suffix)"))
            }
            if partnerLossDays > 0, let stake = wager.stakeForPartner?.stakeDescription {
                let suffix = partnerLossDays > 1 ? " ×\(partnerLossDays)" : ""
                outstandingIOUs.append(IOUDebt(owedByCurrentUser: false, description: "\(stake)\(suffix)"))
            }
        }

        weeklyRecap = WeeklyRecap(
            currentUserWins: currentUserWins,
            partnerWins: partnerWins,
            ties: ties,
            currentUserTotalSteps: currentUserTotal,
            partnerTotalSteps: partnerTotal,
            outstandingIOUs: outstandingIOUs
        )
    }
}
