//
//  HealthKitManager.swift
//  StepMates
//
//  The single source of truth for the current user's passive step data. Everything here
//  is read-only: StepMates never writes to Health, it only listens.
//

// HealthKit's callback types (HKObserverQueryCompletionHandler, HKStatisticsCollectionQuery's
// initialResultsHandler, etc.) predate Swift concurrency and aren't marked @Sendable, even
// though we only ever hand them Sendable-safe captures. @preconcurrency is Apple's own
// documented mechanism for this exact situation — a not-fully-audited framework whose values
// need to cross into async/Task contexts — and downgrades those specific mismatches instead
// of hard-erroring under complete strict concurrency.
@preconcurrency import HealthKit
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
    private let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    private let flightsType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!
    private let exerciseTimeType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!

    var authorizationStatus: HealthKitAuthorizationStatus = .notDetermined
    var todaySteps = 0
    var todayDistanceMeters: Double = 0
    var todayActiveCalories: Double = 0
    var todayFlightsClimbed: Int = 0
    var todayActiveMinutes: Int = 0
    var todayHourlyTrend: [HourlyStepSnapshot] = []
    var lastSyncedAt: Date?
    var lastError: (any Error)?

    var isAuthorized: Bool { authorizationStatus == .authorized }

    private var observerQuery: HKObserverQuery?
    private var isBackgroundDeliveryEnabled = false

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
            try await healthStore.requestAuthorization(
                toShare: [],
                read: [stepType, distanceType, activeEnergyType, flightsType, exerciseTimeType]
            )
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

    /// Active calories burned from midnight through now, in kcal.
    func fetchTodayActiveCalories() async throws -> Double {
        try await fetchTodayCumulativeSum(for: activeEnergyType, unit: .kilocalorie())
    }

    /// Flights of stairs climbed from midnight through now.
    func fetchTodayFlightsClimbed() async throws -> Int {
        Int(try await fetchTodayCumulativeSum(for: flightsType, unit: .count()))
    }

    /// Apple's "exercise minutes" from midnight through now — the closest available proxy
    /// for sustained active walking/running time.
    func fetchTodayActiveMinutes() async throws -> Int {
        Int(try await fetchTodayCumulativeSum(for: exerciseTimeType, unit: .minute()))
    }

    private func fetchTodayCumulativeSum(for quantityType: HKQuantityType, unit: HKUnit) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: .now),
            end: .now,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            healthStore.execute(query)
        }
    }

    /// One day-by-day total per calendar day for the trailing `days` days (including today) —
    /// the shared engine behind the Stats screen's Week/Month charts for steps, distance,
    /// active calories, flights, and exercise minutes alike.
    func fetchDailyTotals(for metric: HealthMetricKind, days: Int) async throws -> [Date: Double] {
        let (quantityType, unit) = quantityTypeAndUnit(for: metric)
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: .now)) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now, options: .strictStartDate)
        var interval = DateComponents()
        interval.day = 1

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let results else {
                    continuation.resume(returning: [:])
                    return
                }

                var totals: [Date: Double] = [:]
                results.enumerateStatistics(from: startDate, to: .now) { statistics, _ in
                    let day = calendar.startOfDay(for: statistics.startDate)
                    totals[day] = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                }
                continuation.resume(returning: totals)
            }

            healthStore.execute(query)
        }
    }

    private func quantityTypeAndUnit(for metric: HealthMetricKind) -> (HKQuantityType, HKUnit) {
        switch metric {
        case .steps: return (stepType, .count())
        case .distance: return (distanceType, .meter())
        case .activeCalories: return (activeEnergyType, .kilocalorie())
        case .flightsClimbed: return (flightsType, .count())
        case .activeMinutes: return (exerciseTimeType, .minute())
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
            async let calories = fetchTodayActiveCalories()
            async let flights = fetchTodayFlightsClimbed()
            async let activeMinutes = fetchTodayActiveMinutes()

            let (resolvedSteps, resolvedDistance, resolvedHourly, resolvedCalories, resolvedFlights, resolvedActiveMinutes) =
                try await (steps, distance, hourly, calories, flights, activeMinutes)

            todaySteps = resolvedSteps
            todayDistanceMeters = resolvedDistance
            todayHourlyTrend = HourlyStepSnapshot.cumulativeSnapshots(from: resolvedHourly)
            todayActiveCalories = resolvedCalories
            todayFlightsClimbed = resolvedFlights
            todayActiveMinutes = resolvedActiveMinutes
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

        // No `self` capture here at all, by design: this closure's own isolation is
        // whatever HealthKit calls it with, and handing a captured `self` off into a new
        // Task from that ambiguous region is exactly what trips Swift 6's region-based
        // "task or actor isolated value cannot be sent" check. Referencing the `.shared`
        // singleton directly sidesteps it — nothing MainActor-isolated crosses the boundary,
        // the `await` on the other side does the hop.
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }
            Task { @MainActor in
                await HealthKitManager.shared.handleObserverUpdate()
                completionHandler()
            }
        }

        observerQuery = query
        healthStore.execute(query)
        enableBackgroundDeliveryIfNeeded()
    }

    /// Runs on every observer fire, including background launches. Wraps the fetch in a
    /// UIKit background task so iOS grants enough runtime to finish before suspending us.
    /// The caller is responsible for calling the HealthKit completion handler once this
    /// returns — skipping it repeatedly throttles future background delivery for this app.
    private func handleObserverUpdate() async {
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "StepMatesHealthSync") {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }

        await refreshTodayStats()

        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
    }

    private func enableBackgroundDeliveryIfNeeded() {
        guard !isBackgroundDeliveryEnabled else { return }
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            Task {
                await HealthKitManager.shared.updateBackgroundDeliveryStatus(success: success, error: error)
            }
        }
    }

    private func updateBackgroundDeliveryStatus(success: Bool, error: (any Error)?) {
        isBackgroundDeliveryEnabled = success
        if let error {
            lastError = error
        }
    }
}
