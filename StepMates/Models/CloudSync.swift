//
//  CloudSync.swift
//  StepMates
//
//  Plain, CloudKit-agnostic mirrors of the shared-zone records. CloudKitSyncEngine owns
//  the CKRecord <-> snapshot translation; everything else in the app only ever sees these.
//

import Foundation

/// Which side of the pairing the current device is on. The owner created the room and its
/// zone lives in their private database; the partner joined via a share and reaches the
/// same zone through their shared database.
enum PairingRole: String, Codable, Sendable {
    case owner
    case partner
}

/// Where the current device stands in the pairing flow.
enum PairingState: Equatable, Sendable {
    /// No room created or joined yet.
    case unpaired
    /// A create-or-accept operation is in flight.
    case pairing
    /// Bound to a room's zone. The partner may or may not have joined yet — see
    /// `CloudKitSyncEngine.partnerSnapshot`.
    case paired
}

/// A mercy request attached to a `MemberStateRecord` — written by the requester, resolved
/// by their partner setting `resolution`.
struct PinkyPromiseRequest: Codable, Equatable, Sendable {
    enum Resolution: String, Codable, Sendable {
        case approved
        case denied
    }

    var reason: String
    var requestedAt: Date
    var requestedByRole: PairingRole
    var resolution: Resolution?
}

/// Mirrors a `RoomRecord`.
struct RoomSnapshot: Equatable, Sendable {
    var roomID: String
    var targetGoal: Int
    var mode: String
    var activeWager: Wager?
    var streakCount: Int
    var updatedAt: Date
}

/// Mirrors a `MemberStateRecord` — either the current user's own state or their partner's,
/// depending on which slot it was read from.
struct MemberSnapshot: Equatable, Sendable {
    var userRecordID: String
    var displayName: String
    var currentSteps: Int
    var todayDistance: Double
    var lastSyncedAt: Date
    var pendingPinkyPromise: PinkyPromiseRequest?
    var lastNudgeTimestamp: Date?
}
