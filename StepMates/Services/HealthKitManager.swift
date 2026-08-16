//
//  HealthKitManager.swift
//  StepMates
//
//  The single source of truth for the current user's passive step data. Everything here
//  is read-only: StepMates never writes to Health, it only listens.
//

import HealthKit
import Observation
import UIKit

/// Where the user stands on granting Health read access.
///
/// HealthKit deliberately never reveals whether *read* access was granted or denied —
/// `HKHealthStore.authorizationStatus(for:)` only reflects *share* (write) permission,
/// and since StepMates never requests write access, that API alone can't tell us anything
/// useful after the first prompt. See `HealthKitManager.refreshAuthorizationStatus()`.
enum HealthKitAuthorizationStatus: Equatable, Sendable {
    /// The user hasn't been asked yet.
    case notDetermined
    /// We can read step data.
    case authorized
    /// The user denied access (or it's restricted) — we can't read step data.
    case denied
    /// This device doesn't support HealthKit at all (e.g. certain iPad configurations).
    case unavailable
}

/// Owns every HealthKit interaction: authorization, one-shot fetches, and the background
/// observer that lets iOS wake the app when new steps land — no manual sync button, ever.
@MainActor
@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!

    var authorizationStatus: HealthKitAuthorizationStatus = .notDetermined
    var todaySteps = 0
    var todayDistanceMeters: Double = 0
    var todayHourlyTrend: [HourlyStepSnapshot] = []
    var lastSyncedAt: Date?
    var lastError: (any Error)?

    var isAuthorized: Bool { authorizationStatus == .authorized }

    private var observerQuery: HKObserverQuery?
    private var isBackgroundDeliveryEnabled = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    // MARK: Authorization

    /// Shows the system permission sheet (a no-op if the user already decided) and, once
    /// resolved, starts live observation. Call this from the onboarding CTA, not on launch.
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType, distanceType])
        } catch {
            lastError = error
        }

        await refreshAuthorizationStatus()
        await activateSyncIfAuthorized()
    }

    /// Re-establishes background delivery on every app launch — HealthKit relaunches the app
    /// in the background to deliver updates, and that fresh process needs to re-register its
    /// observer query before it can act on them. Safe to call even before authorization exists.
    func bootstrapIfAuthorized() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            return
        }
        await refreshAuthorizationStatus()
        await activateSyncIfAuthorized()
    }

    /// Determines authorization by probing for readable data rather than trusting
    /// `authorizationStatus(for:)`, which is meaningless for read-only types.
    func refreshAuthorizationStatus() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            return
        }

        let shareStatus = healthStore.authorizationStatus(for: stepType)
        if shareStatus == .notDetermined {
            authorizationStatus = .notDetermined
            return
        }

        authorizationStatus = await hasReadableStepHistory() ? .authorized : .denied
    }

    /// A lightweight probe: if we can read even one step sample from the last year, read
    /// access is granted. Real iPhones accumulate step data passively, so a total absence
    /// of any sample after authorization has been requested is a reliable "denied" signal.
    private func hasReadableStepHistory() async -> Bool {
        await withCheckedContinuation { continuation in
            let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
            let predicate = HKQuery.predicateForSamples(withStart: yearAgo, end: .now, options: [])
            let query = HKSampleQuery(
                sampleType: stepType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: !(samples?.isEmpty ?? true))
            }
            healthStore.execute(query)
        }
    }

    private func activateSyncIfAuthorized() async {
        guard isAuthorized else { return }
        startObservingStepChanges()
        await refreshTodayStats()
    }

    // MARK: One-shot fetches

    /// Total steps from midnight through now.
    func fetchTodaySteps() async throws -> Int {
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: .now),
            end: .now,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }

    /// Total walking/running distance from midnight through now, in meters — supplementary
    /// to steps, shown alongside the weekly recap's combined-distance stat.
    func fetchTodayDistanceMeters() async throws -> Double {
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: .now),
            end: .now,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let meters = statistics?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: meters)
            }
            healthStore.execute(query)
        }
    }

    /// Steps bucketed by hour, from midnight through now, for the intraday trend line.
    func fetchTodayHourlySteps() async throws -> [HourlyStepBucket] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: .now, options: .strictStartDate)
        var interval = DateComponents()
        interval.hour = 1

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startOfDay,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let results else {
                    continuation.resume(returning: [])
                    return
                }

                var buckets: [HourlyStepBucket] = []
                results.enumerateStatistics(from: startOfDay, to: .now) { statistics, _ in
                    let hour = calendar.component(.hour, from: statistics.startDate)
                    let steps = Int(statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    buckets.append(HourlyStepBucket(hour: hour, steps: steps))
                }
                continuation.resume(returning: buckets)
            }

            healthStore.execute(query)
        }
    }

    /// Refreshes every published stat in parallel and stamps `lastSyncedAt`. This is what
    /// both the initial load and every subsequent observer wake-up funnel through.
    func refreshTodayStats() async {
        do {
            async let steps = fetchTodaySteps()
            async let distance = fetchTodayDistanceMeters()
            async let hourly = fetchTodayHourlySteps()

            let (resolvedSteps, resolvedDistance, resolvedHourly) = try await (steps, distance, hourly)

            todaySteps = resolvedSteps
            todayDistanceMeters = resolvedDistance
            todayHourlyTrend = HourlyStepSnapshot.cumulativeSnapshots(from: resolvedHourly)
            lastSyncedAt = .now
            lastError = nil
        } catch {
            lastError = error
        }
    }

    // MARK: Background observation

    /// Watches for new step samples and enables background delivery so iOS can relaunch
    /// the app to process them even when it isn't running — the core of the "zero friction,
    /// no sync button" requirement.
    private func startObservingStepChanges() {
        guard observerQuery == nil else { return }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }
            // Resolve self once here rather than re-declaring [weak self] on the nested
            // Task — see the comment in handleObserverUpdate for why that trips Swift 6's
            // region-based "task or actor isolated value cannot be sent" check.
            guard let self else {
                completionHandler()
                return
            }
            Task { @MainActor in
                await self.handleObserverUpdate(completionHandler: completionHandler)
            }
        }

        observerQuery = query
        healthStore.execute(query)
        enableBackgroundDeliveryIfNeeded()
    }

    /// Runs on every observer fire, including background launches. Wraps the fetch in a
    /// UIKit background task so iOS grants enough runtime to finish before suspending us,
    /// and always calls the HealthKit completion handler — skipping it repeatedly throttles
    /// future background delivery for this app.
    private func handleObserverUpdate(completionHandler: @escaping HKObserverQueryCompletionHandler) async {
        // The expiration handler isn't MainActor-isolated — it's a plain escaping closure
        // handed to UIKit, not a Task, so it doesn't inherit this method's actor context.
        // Resolve `self` once here and let the Task capture that single strong reference
        // directly; re-declaring [weak self] a second time on the nested Task is what
        // trips Swift 6's region-based "task or actor isolated value cannot be sent" check.
        let taskID = UIApplication.shared.beginBackgroundTask(withName: "StepMates.HealthKitSync") { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.endBackgroundTaskIfNeeded()
            }
        }
        backgroundTaskID = taskID

        await refreshTodayStats()
        completionHandler()

        if taskID != .invalid {
            UIApplication.shared.endBackgroundTask(taskID)
            backgroundTaskID = .invalid
        }
    }

    /// Ends the currently tracked background task, if any. Pulled out so the expiration
    /// handler's Task body has nothing to do but call one MainActor-isolated method.
    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func enableBackgroundDeliveryIfNeeded() {
        guard !isBackgroundDeliveryEnabled else { return }
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { [weak self] success, error in
            guard let self else { return }
            Task { @MainActor in
                self.isBackgroundDeliveryEnabled = success
                if let error {
                    self.lastError = error
                }
            }
        }
    }
}
