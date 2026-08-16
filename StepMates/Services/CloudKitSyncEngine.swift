//
//  CloudKitSyncEngine.swift
//  StepMates
//
//  Zero-server pairing and sync: one custom zone per room, shared via CKShare. The owner's
//  zone lives in their private database; the invited partner reaches the same records
//  through their shared database once they accept. No accounts, no backend — just iCloud.
//

import CloudKit
import Observation
import UIKit

enum CloudKitSyncError: Error, Sendable {
    case shareSaveFailed
    case notPaired
}

/// Owns every CloudKit interaction: room creation, sharing, the passive step push, and the
/// remote-notification-driven refresh that keeps both partners' devices in sync.
@MainActor
@Observable
final class CloudKitSyncEngine {
    static let shared = CloudKitSyncEngine()

    private static let zoneName = "StepMatesZone"
    private static let pairingDefaultsKey = "com.stepmates.cloudkit.pairing"

    private let container = CKContainer.default()
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }
    private var sharedDatabase: CKDatabase { container.sharedCloudDatabase }
    /// Whichever database actually holds the shared zone's records for this device: the
    /// owner's zone lives in their own private database; a partner reaches it only through
    /// their shared database.
    private var activeDatabase: CKDatabase { role == .owner ? privateDatabase : sharedDatabase }

    var pairingState: PairingState = .unpaired
    var role: PairingRole?
    var roomSnapshot: RoomSnapshot?
    var partnerSnapshot: MemberSnapshot?
    var mySnapshot: MemberSnapshot?
    var isOffline = false
    var lastError: (any Error)?
    var lastSyncedAt: Date?

    private var zoneID: CKRecordZone.ID?
    private var cachedMemberRecord: CKRecord?
    private var pushDebounceTask: Task<Void, Never>?
    private var offlineStepQueue: (steps: Int, distance: Double)?

    private init() {
        restorePersistedPairing()
    }

    // MARK: Lifecycle

    /// Re-arms subscriptions and pulls fresh state on every launch, mirroring
    /// `HealthKitManager.bootstrapIfAuthorized()` — a no-op until a room actually exists.
    func bootstrap() async {
        guard pairingState == .paired else { return }
        setupDatabaseSubscriptions()
        await refreshFromCloud()
    }

    // MARK: Room creation & sharing

    /// Creates the custom zone, writes the room + this device's member record, and attaches
    /// a zone-wide `CKShare` — everything in the zone becomes visible to whoever accepts it.
    /// `displayName` and `dailyStepGoal` default to sensible fallbacks so existing callers
    /// (and previews) don't need to change, but onboarding threads the collected values in.
    func createRoomAndShare(displayName: String? = nil, dailyStepGoal: Int = 10_000) async throws -> CKShare {
        pairingState = .pairing
        let zoneID = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)

        do {
            _ = try await privateDatabase.save(CKRecordZone(zoneID: zoneID))

            let roomRecord = CKRecord(recordType: RecordType.room, recordID: CKRecord.ID(recordName: "Room", zoneID: zoneID))
            roomRecord[RoomField.roomID] = generateRoomID() as CKRecordValue
            roomRecord[RoomField.targetGoal] = dailyStepGoal as CKRecordValue
            roomRecord[RoomField.mode] = WagerMode.versusSprint.rawValue as CKRecordValue
            roomRecord[RoomField.streakCount] = 0 as CKRecordValue
            roomRecord[RoomField.updatedAt] = Date.now as CKRecordValue

            let memberRecordID = CKRecord.ID(recordName: "Member-\(PairingRole.owner.rawValue)", zoneID: zoneID)
            let memberRecord = CKRecord(recordType: RecordType.memberState, recordID: memberRecordID)
            let userRecordID = try await container.userRecordID()
            memberRecord[MemberField.userRecordID] = userRecordID.recordName as CKRecordValue
            memberRecord[MemberField.displayName] = (displayName?.isEmpty == false ? displayName! : UIDevice.current.name) as CKRecordValue
            memberRecord[MemberField.currentSteps] = 0 as CKRecordValue
            memberRecord[MemberField.todayDistance] = 0.0 as CKRecordValue
            memberRecord[MemberField.lastSyncedAt] = Date.now as CKRecordValue

            let share = CKShare(recordZoneID: zoneID)
            share[CKShare.SystemFieldKey.title] = "StepMates" as CKRecordValue
            share.publicPermission = .none

            let (saveResults, _) = try await privateDatabase.modifyRecords(
                saving: [roomRecord, memberRecord, share],
                deleting: []
            )

            guard case .success(let savedShareRecord) = saveResults[share.recordID],
                  let savedShare = savedShareRecord as? CKShare else {
                throw CloudKitSyncError.shareSaveFailed
            }

            self.zoneID = zoneID
            role = .owner
            cachedMemberRecord = memberRecord
            roomSnapshot = RoomSnapshot(record: roomRecord)
            mySnapshot = MemberSnapshot(record: memberRecord)
            pairingState = .paired
            persistPairingState()
            setupDatabaseSubscriptions()

            return savedShare
        } catch {
            pairingState = .unpaired
            handle(error)
            throw error
        }
    }

    /// Accepts an invite link, binds this device to the owner's zone via the shared database,
    /// and writes this partner's own member record so the owner sees them join.
    func acceptShare(from metadata: CKShare.Metadata, displayName: String = "Your Step Partner") async throws {
        pairingState = .pairing

        do {
            try await performAcceptShareOperation(metadata: metadata)
        } catch {
            pairingState = .unpaired
            handle(error)
            throw error
        }

        zoneID = metadata.share.recordID.zoneID
        role = .partner
        cachedMemberRecord = nil

        do {
            let record = try await loadOrCreateMemberRecord()
            let userRecordID = try await container.userRecordID()
            record[MemberField.userRecordID] = userRecordID.recordName as CKRecordValue
            record[MemberField.displayName] = displayName as CKRecordValue
            record[MemberField.currentSteps] = 0 as CKRecordValue
            record[MemberField.todayDistance] = 0.0 as CKRecordValue
            record[MemberField.lastSyncedAt] = Date.now as CKRecordValue

            let saved = try await activeDatabase.save(record)
            cachedMemberRecord = saved
            mySnapshot = MemberSnapshot(record: saved)
        } catch {
            zoneID = nil
            role = nil
            pairingState = .unpaired
            handle(error)
            throw error
        }

        pairingState = .paired
        persistPairingState()
        setupDatabaseSubscriptions()
        await refreshFromCloud()
    }

    /// Wraps `CKAcceptSharesOperation` — there's no native async overload for it, so this is
    /// the one hand-rolled continuation in the engine. Only the operation-level result block
    /// resumes the continuation; the per-share block just captures an error to prioritize.
    private func performAcceptShareOperation(metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            var perShareError: Error?

            operation.perShareResultBlock = { _, result in
                if case .failure(let error) = result {
                    perShareError = error
                }
            }

            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    if let perShareError {
                        continuation.resume(throwing: perShareError)
                    } else {
                        continuation.resume()
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            container.add(operation)
        }
    }

    // MARK: Passive step sync

    /// Immediately writes this device's latest steps to its `MemberStateRecord`. Queues the
    /// delta locally on network failure instead of throwing it away.
    func pushLocalSteps(_ steps: Int, distance: Double) async throws {
        guard pairingState == .paired else { return }

        do {
            let record = try await loadOrCreateMemberRecord()
            record[MemberField.currentSteps] = steps as CKRecordValue
            record[MemberField.todayDistance] = distance as CKRecordValue
            record[MemberField.lastSyncedAt] = Date.now as CKRecordValue

            let saved = try await activeDatabase.save(record)
            cachedMemberRecord = saved
            mySnapshot = MemberSnapshot(record: saved)
            offlineStepQueue = nil
            isOffline = false
            lastSyncedAt = .now
        } catch let error as CKError where error.code == .networkUnavailable || error.code == .networkFailure {
            isOffline = true
            offlineStepQueue = (steps, distance)
            lastError = error
        } catch {
            handle(error)
            throw error
        }
    }

    /// Debounced entry point for HealthKit-driven updates — coalesces rapid successive step
    /// deltas into a single CloudKit write instead of hammering the network on every tick.
    func schedulePushLocalSteps(_ steps: Int, distance: Double) {
        pushDebounceTask?.cancel()
        pushDebounceTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            try? await pushLocalSteps(steps, distance: distance)
        }
    }

    /// Re-attempts the most recently queued offline delta, if any — call this opportunistically
    /// (e.g. on a remote-notification wake, when connectivity has likely returned).
    func retryQueuedStepsIfNeeded() async {
        guard let offlineStepQueue else { return }
        try? await pushLocalSteps(offlineStepQueue.steps, distance: offlineStepQueue.distance)
    }

    // MARK: Subscriptions & remote notifications

    /// Registers a whole-database subscription on both databases so iOS delivers a silent
    /// push whenever either side's records change — this is best-effort: a failure here
    /// (e.g. a subscription that already exists) shouldn't block pairing.
    func setupDatabaseSubscriptions() {
        Task {
            await createSubscriptionIfNeeded(on: privateDatabase, subscriptionID: "private-changes")
            await createSubscriptionIfNeeded(on: sharedDatabase, subscriptionID: "shared-changes")
        }
    }

    private func createSubscriptionIfNeeded(on database: CKDatabase, subscriptionID: String) async {
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await database.save(subscription)
        } catch {
            lastError = error
        }
    }

    /// Handles a silent push delivered via `application(_:didReceiveRemoteNotification:)`.
    /// Returns whether this notification was actually ours to handle.
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async -> Bool {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) is CKDatabaseNotification else {
            return false
        }
        await refreshFromCloud()
        await retryQueuedStepsIfNeeded()
        return true
    }

    // MARK: Nudge & Pinky Promise

    /// Touches this device's own `lastNudgeTimestamp` — the partner's subscription fires on
    /// the change, and their next refresh surfaces the nudge.
    func sendNudge() async {
        do {
            let record = try await loadOrCreateMemberRecord()
            record[MemberField.lastNudgeTimestamp] = Date.now as CKRecordValue
            let saved = try await activeDatabase.save(record)
            cachedMemberRecord = saved
            mySnapshot = MemberSnapshot(record: saved)
        } catch {
            handle(error)
        }
    }

    /// The trailing partner's ask for mercy — written to their own record for the other
    /// side to see and resolve.
    func submitPinkyPromiseRequest(reason: String) async {
        guard let role else { return }
        do {
            let record = try await loadOrCreateMemberRecord()
            let request = PinkyPromiseRequest(reason: reason, requestedAt: .now, requestedByRole: role, resolution: nil)
            record[MemberField.pendingPinkyPromise] = try JSONEncoder().encode(request) as CKRecordValue
            let saved = try await activeDatabase.save(record)
            cachedMemberRecord = saved
            mySnapshot = MemberSnapshot(record: saved)
        } catch {
            handle(error)
        }
    }

    /// The other partner's answer. Resolves the requester's pending flag in place (rather
    /// than clearing it) so their device can distinguish "approved" from "denied", and waives
    /// the active wager outright on approval.
    func respondToPinkyPromise(approved: Bool) async {
        guard let zoneID, let role else { return }
        let partnerRole: PairingRole = role == .owner ? .partner : .owner
        let partnerMemberID = CKRecord.ID(recordName: "Member-\(partnerRole.rawValue)", zoneID: zoneID)

        do {
            let record = try await activeDatabase.record(for: partnerMemberID)
            if var request = decodePendingPinkyPromise(from: record) {
                request.resolution = approved ? .approved : .denied
                record[MemberField.pendingPinkyPromise] = try JSONEncoder().encode(request) as CKRecordValue
            }
            let saved = try await activeDatabase.save(record)
            partnerSnapshot = MemberSnapshot(record: saved)

            if approved, var wager = roomSnapshot?.activeWager {
                wager.status = .resolved
                wager.outcome = WagerOutcome(
                    loserUserID: nil,
                    bothSucceeded: true,
                    resolvedAt: .now,
                    confirmedByCurrentUser: true,
                    confirmedByPartner: true
                )
                try await updateActiveWager(wager)
            }
        } catch {
            handle(error)
        }
    }

    // MARK: Room / wager state

    func updateActiveWager(_ wager: Wager) async throws {
        guard let zoneID else { return }
        do {
            let roomID = CKRecord.ID(recordName: "Room", zoneID: zoneID)
            let record = try await activeDatabase.record(for: roomID)
            record[RoomField.activeWagerData] = try JSONEncoder().encode(wager) as CKRecordValue
            record[RoomField.updatedAt] = Date.now as CKRecordValue
            let saved = try await activeDatabase.save(record)
            roomSnapshot = RoomSnapshot(record: saved)
        } catch {
            handle(error)
            throw error
        }
    }

    /// Re-fetches the room and both member records. Missing records (e.g. the partner
    /// hasn't joined yet) are simply left as `nil` rather than failing the whole refresh.
    func refreshFromCloud() async {
        guard let zoneID, let role else { return }

        let roomID = CKRecord.ID(recordName: "Room", zoneID: zoneID)
        let myMemberID = CKRecord.ID(recordName: "Member-\(role.rawValue)", zoneID: zoneID)
        let partnerRole: PairingRole = role == .owner ? .partner : .owner
        let partnerMemberID = CKRecord.ID(recordName: "Member-\(partnerRole.rawValue)", zoneID: zoneID)

        do {
            let results = try await activeDatabase.records(for: [roomID, myMemberID, partnerMemberID])

            if case .success(let record) = results[roomID] {
                roomSnapshot = RoomSnapshot(record: record)
            }
            if case .success(let record) = results[myMemberID] {
                cachedMemberRecord = record
                mySnapshot = MemberSnapshot(record: record)
            }
            if case .success(let record) = results[partnerMemberID] {
                partnerSnapshot = MemberSnapshot(record: record)
            }

            lastSyncedAt = .now
            isOffline = false
        } catch {
            handle(error)
        }
    }

    // MARK: Helpers

    private func loadOrCreateMemberRecord() async throws -> CKRecord {
        if let cachedMemberRecord { return cachedMemberRecord }
        guard let zoneID, let role else { throw CloudKitSyncError.notPaired }

        let memberID = CKRecord.ID(recordName: "Member-\(role.rawValue)", zoneID: zoneID)
        do {
            let record = try await activeDatabase.record(for: memberID)
            cachedMemberRecord = record
            return record
        } catch let error as CKError where error.code == .unknownItem {
            let record = CKRecord(recordType: RecordType.memberState, recordID: memberID)
            cachedMemberRecord = record
            return record
        }
    }

    private func decodePendingPinkyPromise(from record: CKRecord) -> PinkyPromiseRequest? {
        guard let data = record[MemberField.pendingPinkyPromise] as? Data else { return nil }
        return try? JSONDecoder().decode(PinkyPromiseRequest.self, from: data)
    }

    private func generateRoomID() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code = String((0..<4).map { _ in characters.randomElement()! })
        return "SWEAT-\(code)"
    }

    /// Central error triage for the cases CloudKit code is expected to handle explicitly:
    /// offline writes get queued rather than lost, and a zone that's gone (deleted, share
    /// revoked) drops us cleanly back to unpaired instead of leaving stale local state.
    private func handle(_ error: Error) {
        lastError = error
        guard let ckError = error as? CKError else { return }
        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            isOffline = true
        case .zoneNotFound, .userDeletedZone:
            pairingState = .unpaired
            role = nil
            zoneID = nil
            cachedMemberRecord = nil
            clearPersistedPairing()
        default:
            break
        }
    }

    // MARK: Local persistence

    private struct PersistedPairing: Codable {
        var zoneName: String
        var zoneOwnerName: String
        var role: PairingRole
    }

    private func persistPairingState() {
        guard let zoneID, let role else { return }
        let persisted = PersistedPairing(zoneName: zoneID.zoneName, zoneOwnerName: zoneID.ownerName, role: role)
        guard let data = try? JSONEncoder().encode(persisted) else { return }
        UserDefaults.standard.set(data, forKey: Self.pairingDefaultsKey)
    }

    private func restorePersistedPairing() {
        guard let data = UserDefaults.standard.data(forKey: Self.pairingDefaultsKey),
              let persisted = try? JSONDecoder().decode(PersistedPairing.self, from: data) else {
            return
        }
        zoneID = CKRecordZone.ID(zoneName: persisted.zoneName, ownerName: persisted.zoneOwnerName)
        role = persisted.role
        pairingState = .paired
    }

    private func clearPersistedPairing() {
        UserDefaults.standard.removeObject(forKey: Self.pairingDefaultsKey)
    }
}

// MARK: - CKRecord schema

private enum RecordType {
    static let room = "RoomRecord"
    static let memberState = "MemberStateRecord"
}

private enum RoomField {
    static let roomID = "roomID"
    static let targetGoal = "targetGoal"
    static let mode = "mode"
    static let activeWagerData = "activeWagerData"
    static let streakCount = "streakCount"
    static let updatedAt = "updatedAt"
}

private enum MemberField {
    static let userRecordID = "userRecordID"
    static let displayName = "displayName"
    static let currentSteps = "currentSteps"
    static let todayDistance = "todayDistance"
    static let lastSyncedAt = "lastSyncedAt"
    static let pendingPinkyPromise = "pendingPinkyPromise"
    static let lastNudgeTimestamp = "lastNudgeTimestamp"
}

private extension RoomSnapshot {
    init?(record: CKRecord) {
        guard let roomID = record[RoomField.roomID] as? String else { return nil }
        self.roomID = roomID
        targetGoal = record[RoomField.targetGoal] as? Int ?? 10_000
        mode = record[RoomField.mode] as? String ?? WagerMode.versusSprint.rawValue
        streakCount = record[RoomField.streakCount] as? Int ?? 0
        updatedAt = record[RoomField.updatedAt] as? Date ?? .now
        if let data = record[RoomField.activeWagerData] as? Data {
            activeWager = try? JSONDecoder().decode(Wager.self, from: data)
        } else {
            activeWager = nil
        }
    }
}

private extension MemberSnapshot {
    init?(record: CKRecord) {
        guard let userRecordID = record[MemberField.userRecordID] as? String,
              let displayName = record[MemberField.displayName] as? String else { return nil }
        self.userRecordID = userRecordID
        self.displayName = displayName
        currentSteps = record[MemberField.currentSteps] as? Int ?? 0
        todayDistance = record[MemberField.todayDistance] as? Double ?? 0
        lastSyncedAt = record[MemberField.lastSyncedAt] as? Date ?? .now
        lastNudgeTimestamp = record[MemberField.lastNudgeTimestamp] as? Date
        if let data = record[MemberField.pendingPinkyPromise] as? Data {
            pendingPinkyPromise = try? JSONDecoder().decode(PinkyPromiseRequest.self, from: data)
        } else {
            pendingPinkyPromise = nil
        }
    }
}
