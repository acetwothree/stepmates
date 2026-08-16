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
    var showCreateWagerSheet = false
    var showWeeklyRecap = false
    var showStats = false

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
                activeMinutes: healthKitManager.todayActiveMinutes
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
        }
    }
}
