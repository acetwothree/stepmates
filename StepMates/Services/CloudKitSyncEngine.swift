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

/// One device's today-so-far totals, pushed as a unit so a single write always carries a
/// consistent snapshot instead of racing partial updates for each metric.
struct StepPushPayload: Sendable {
    var steps: Int
    var distance: Double
    var activeCalories: Double
    var flightsClimbed: Int
    var activeMinutes: Int
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
    private var offlineStepQueue: StepPushPayload?

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
            memberRecord[MemberField.todayActiveCalories] = 0.0 as CKRecordValue
            memberRecord[MemberField.todayFlightsClimbed] = 0 as CKRecordValue
            memberRecord[MemberField.todayActiveMinutes] = 0 as CKRecordValue
            memberRecord[MemberField.lastSyncedAt] = Date.now as CKRecordValue

            // CloudKit data lives in the user's iCloud account, not on-device — a previous
            // attempt (a prior test run, an app reinstall, a crash mid-flow) can leave a
            // share already attached to this zone. A zone can only ever have one zone-wide
            // share, and creating a second one fails, so reuse the existing one instead of
            // erroring out.
            if let existingShare = try await fetchExistingZoneShare(zoneID: zoneID) {
                _ = try await privateDatabase.modifyRecords(saving: [roomRecord, memberRecord], deleting: [], savePolicy: .allKeys)

                self.zoneID = zoneID
                role = .owner
                cachedMemberRecord = memberRecord
                roomSnapshot = RoomSnapshot(record: roomRecord)
                mySnapshot = MemberSnapshot(record: memberRecord)
                pairingState = .paired
                persistPairingState()
                setupDatabaseSubscriptions()

                return existingShare
            }

            let share = CKShare(recordZoneID: zoneID)
            share[CKShare.SystemFieldKey.title] = "StepMates" as CKRecordValue
            share.publicPermission = .none

            // .allKeys forces an unconditional overwrite instead of the default
            // .ifServerRecordUnchanged policy, which would reject these saves as conflicts
            // if stale Room/Member records from an earlier attempt already exist server-side
            // — freshly-constructed CKRecord objects carry no change tag to satisfy that
            // check against. We're the zone owner intentionally re-establishing our own
            // room, so overwriting prior state here is correct.
            let (saveResults, _) = try await privateDatabase.modifyRecords(
                saving: [roomRecord, memberRecord, share],
                deleting: [],
                savePolicy: .allKeys
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

    /// Zone-wide `CKShare`s are stored at a deterministic record name derived from the zone
    /// (`CKRecordNameZoneWideShare`), so this is a direct lookup rather than a query.
    private func fetchExistingZoneShare(zoneID: CKRecordZone.ID) async throws -> CKShare? {
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        do {
            let record = try await privateDatabase.record(for: shareID)
            return record as? CKShare
        } catch let error as CKError where error.code == .unknownItem {
            return nil
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
            record[MemberField.todayActiveCalories] = 0.0 as CKRecordValue
            record[MemberField.todayFlightsClimbed] = 0 as CKRecordValue
            record[MemberField.todayActiveMinutes] = 0 as CKRecordValue
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

    /// Immediately writes this device's latest today-so-far totals to its `MemberStateRecord`.
    /// Queues the payload locally on network failure instead of throwing it away.
    func pushLocalSteps(_ payload: StepPushPayload) async throws {
        guard pairingState == .paired else { return }

        do {
            let record = try await loadOrCreateMemberRecord()
            record[MemberField.currentSteps] = payload.steps as CKRecordValue
            record[MemberField.todayDistance] = payload.distance as CKRecordValue
            record[MemberField.todayActiveCalories] = payload.activeCalories as CKRecordValue
            record[MemberField.todayFlightsClimbed] = payload.flightsClimbed as CKRecordValue
            record[MemberField.todayActiveMinutes] = payload.activeMinutes as CKRecordValue
            record[MemberField.lastSyncedAt] = Date.now as CKRecordValue

            let saved = try await activeDatabase.save(record)
            cachedMemberRecord = saved
            mySnapshot = MemberSnapshot(record: saved)
            offlineStepQueue = nil
            isOffline = false
            lastSyncedAt = .now
        } catch let error as CKError where error.code == .networkUnavailable || error.code == .networkFailure {
            isOffline = true
            offlineStepQueue = payload
            lastError = error
        } catch {
            handle(error)
            throw error
        }
    }

    /// Debounced entry point for HealthKit-driven updates — coalesces rapid successive step
    /// deltas into a single CloudKit write instead of hammering the network on every tick.
    func schedulePushLocalSteps(_ payload: StepPushPayload) {
        pushDebounceTask?.cancel()
        pushDebounceTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            try? await pushLocalSteps(payload)
        }
    }

    /// Re-attempts the most recently queued offline delta, if any — call this opportunistically
    /// (e.g. on a remote-notification wake, when connectivity has likely returned).
    func retryQueuedStepsIfNeeded() async {
        guard let offlineStepQueue else { return }
        try? await pushLocalSteps(offlineStepQueue)
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

    // MARK: Nudge

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

    // MARK: Settings & debug

    /// Updates this device's own display name, both locally and on the shared record so the
    /// partner's next refresh picks it up.
    func updateMyDisplayName(_ name: String) async {
        do {
            let record = try await loadOrCreateMemberRecord()
            record[MemberField.displayName] = name as CKRecordValue
            let saved = try await activeDatabase.save(record)
            cachedMemberRecord = saved
            mySnapshot = MemberSnapshot(record: saved)
        } catch {
            handle(error)
        }
    }

    /// Updates the shared daily step goal on the Room record.
    func updateMyDailyGoal(_ goal: Int) async {
        guard let zoneID else { return }
        do {
            let roomID = CKRecord.ID(recordName: "Room", zoneID: zoneID)
            let record = try await activeDatabase.record(for: roomID)
            record[RoomField.targetGoal] = goal as CKRecordValue
            record[RoomField.updatedAt] = Date.now as CKRecordValue
            let saved = try await activeDatabase.save(record)
            roomSnapshot = RoomSnapshot(record: saved)
        } catch {
            handle(error)
        }
    }

    /// Forgets this device's pairing without touching the shared CloudKit zone — the regular,
    /// non-destructive "Unlink Partner" action. If this device is the zone owner, the partner's
    /// own device keeps its access until they separately leave or the owner revokes the share;
    /// this only ever affects the local device's view of the pairing.
    func unlinkPartnerLocally() {
        zoneID = nil
        role = nil
        cachedMemberRecord = nil
        roomSnapshot = nil
        partnerSnapshot = nil
        mySnapshot = nil
        pairingState = .unpaired
        clearPersistedPairing()
    }

    /// Debug-only: deletes the shared zone outright (only possible as the zone owner — a
    /// partner has no permission to delete a zone they don't own) before forgetting the local
    /// pairing. Unlike `unlinkPartnerLocally`, this actually destroys the shared room/member
    /// data for both sides.
    func debugClearCloudState() async {
        if role == .owner, let zoneID {
            do {
                _ = try await privateDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
            } catch {
                handle(error)
            }
        }
        unlinkPartnerLocally()
    }

    /// Debug-only: writes a plausible step count directly to the *other* role's member record
    /// so pairing/comparison UI can be exercised from a single device without a second phone.
    func debugSimulatePartnerSteps() async {
        guard let zoneID, let role else { return }
        let partnerRole: PairingRole = role == .owner ? .partner : .owner
        let partnerMemberID = CKRecord.ID(recordName: "Member-\(partnerRole.rawValue)", zoneID: zoneID)

        do {
            let record: CKRecord
            if let existing = try? await activeDatabase.record(for: partnerMemberID) {
                record = existing
            } else {
                record = CKRecord(recordType: RecordType.memberState, recordID: partnerMemberID)
                record[MemberField.userRecordID] = "debug-simulated-partner" as CKRecordValue
                record[MemberField.displayName] = "Test Partner" as CKRecordValue
            }

            let currentSteps = record[MemberField.currentSteps] as? Int ?? 0
            let newSteps = min(currentSteps + Int.random(in: 500...1_500), 25_000)
            record[MemberField.currentSteps] = newSteps as CKRecordValue
            record[MemberField.todayDistance] = (Double(newSteps) * 0.78) as CKRecordValue
            record[MemberField.todayActiveCalories] = (Double(newSteps) * 0.04) as CKRecordValue
            record[MemberField.todayFlightsClimbed] = Int.random(in: 0...12) as CKRecordValue
            record[MemberField.todayActiveMinutes] = Int(Double(newSteps) / 100) as CKRecordValue
            record[MemberField.lastSyncedAt] = Date.now as CKRecordValue

            let saved = try await activeDatabase.save(record)
            partnerSnapshot = MemberSnapshot(record: saved)
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
    static let todayActiveCalories = "todayActiveCalories"
    static let todayFlightsClimbed = "todayFlightsClimbed"
    static let todayActiveMinutes = "todayActiveMinutes"
    static let lastSyncedAt = "lastSyncedAt"
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
        todayActiveCalories = record[MemberField.todayActiveCalories] as? Double ?? 0
        todayFlightsClimbed = record[MemberField.todayFlightsClimbed] as? Int ?? 0
        todayActiveMinutes = record[MemberField.todayActiveMinutes] as? Int ?? 0
        lastSyncedAt = record[MemberField.lastSyncedAt] as? Date ?? .now
        lastNudgeTimestamp = record[MemberField.lastNudgeTimestamp] as? Date
    }
}
