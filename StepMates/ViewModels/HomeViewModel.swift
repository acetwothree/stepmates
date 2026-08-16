//
//  HomeViewModel.swift
//  StepMates
//
//  Drives the Home screen's game state. The current user's steps mirror HealthKitManager
//  live; the partner's steps, the shared streak, and the active wager mirror
//  CloudKitSyncEngine live. Nudges, Pinky Promise, and new wagers all round-trip through
//  CloudKit for real — nothing here is simulated anymore.
//

import SwiftUI
import Observation

/// Lifecycle of a trailing partner's request to waive today's stake.
enum PinkyPromiseState: Equatable, Sendable {
    /// No request outstanding.
    case idle
    /// Sent, waiting on the partner to approve or deny.
    case requested
    /// Partner approved — today's stake is waived.
    case approved
    /// Partner denied — the stake stands.
    case denied
}

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
    /// Status of a mercy request *I* submitted.
    var pinkyPromiseState: PinkyPromiseState = .idle
    /// A mercy request *my partner* submitted, waiting on my response.
    var incomingPinkyPromiseRequest: PinkyPromiseRequest?
    var showCreateWagerSheet = false
    var showWeeklyRecap = false

    private var nudgeClearTask: Task<Void, Never>?
    private var hasOfferedRecapThisSession = false

    init(
        pair: UserPair = .mockConnected,
        comparison: DailyStepComparison = .mockToday,
        activeWager: Wager? = .mockVersusSprint,
        weeklyRecap: WeeklyRecap = .mock,
        healthKitManager: HealthKitManager = .shared,
        cloudKitSyncEngine: CloudKitSyncEngine = .shared
    ) {
        self.pair = pair
        self.comparison = comparison
        self.activeWager = activeWager
        self.weeklyRecap = weeklyRecap
        self.healthKitManager = healthKitManager
        self.cloudKitSyncEngine = cloudKitSyncEngine

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
            Task { @MainActor [weak self] in
                self?.syncStepsFromHealthKit()
                self?.observeHealthKitChanges()
            }
        }
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

        cloudKitSyncEngine.schedulePushLocalSteps(updatedDay.stepCount, distance: healthKitManager.todayDistanceMeters)
    }

    // MARK: CloudKit -> local state

    private func observeCloudKitChanges() {
        withObservationTracking {
            _ = cloudKitSyncEngine.partnerSnapshot
            _ = cloudKitSyncEngine.roomSnapshot
            _ = cloudKitSyncEngine.mySnapshot
            _ = cloudKitSyncEngine.pairingState
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.syncFromCloudKit()
                self?.observeCloudKitChanges()
            }
        }
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

            if let pending = partner.pendingPinkyPromise, pending.resolution == nil {
                incomingPinkyPromiseRequest = pending
            } else {
                incomingPinkyPromiseRequest = nil
            }
        } else if cloudKitSyncEngine.pairingState == .paired {
            // Room exists but the partner hasn't written their first state yet.
            pair.connectionStatus = .pending
            incomingPinkyPromiseRequest = nil
        }

        if let room = cloudKitSyncEngine.roomSnapshot {
            pair.sharedStreak = room.streakCount
            if let wager = room.activeWager {
                activeWager = wager
            }
        }

        if let mine = cloudKitSyncEngine.mySnapshot?.pendingPinkyPromise {
            switch mine.resolution {
            case .approved: pinkyPromiseState = .approved
            case .denied: pinkyPromiseState = .denied
            case nil: pinkyPromiseState = .requested
            }
        } else {
            pinkyPromiseState = .idle
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

    /// Submits a real mercy request for today's stake. The result (approved/denied) arrives
    /// via `syncFromCloudKit()` once the partner responds.
    func requestPinkyPromise() {
        guard pinkyPromiseState != .requested else { return }
        HapticService.shared.wagerLock()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            pinkyPromiseState = .requested
        }

        let reason = "Trailing by \(comparison.currentUserDay.stepsRemaining) steps — cut me some slack?"
        Task {
            await cloudKitSyncEngine.submitPinkyPromiseRequest(reason: reason)
        }
    }

    /// Answers the partner's own incoming mercy request.
    func respondToPinkyPromise(approved: Bool) {
        HapticService.shared.wagerLock()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            incomingPinkyPromiseRequest = nil
        }
        Task {
            await cloudKitSyncEngine.respondToPinkyPromise(approved: approved)
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

    /// Surfaces the weekly recap automatically on Sundays, once per session.
    func presentRecapIfNeeded(calendar: Calendar = .current, now: Date = .now) {
        guard !hasOfferedRecapThisSession else { return }
        hasOfferedRecapThisSession = true
        if calendar.component(.weekday, from: now) == 1 {
            showWeeklyRecap = true
        }
    }
}
