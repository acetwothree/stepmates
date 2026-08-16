//
//  UserPair.swift
//  StepMates
//
//  Core pairing model: two people, one shared streak, one room.
//

import Foundation

/// A single person inside a pairing — either the current device owner or their partner.
struct PairedUser: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var avatarSystemName: String
    var dailyStepGoal: Int
    var timeZoneIdentifier: String

    init(
        id: UUID = UUID(),
        displayName: String,
        avatarSystemName: String = "figure.walk.circle.fill",
        dailyStepGoal: Int = 10_000,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarSystemName = avatarSystemName
        self.dailyStepGoal = dailyStepGoal
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

/// Lifecycle of the link between two people.
enum ConnectionStatus: String, Codable, Sendable {
    /// Invite sent, room created, partner hasn't joined yet.
    case pending
    /// Both people are linked and HealthKit is syncing on both ends.
    case connected
    /// Partner unlinked, deleted the app, or revoked Health access.
    case disconnected
    /// Connected, but one side hasn't synced steps in over 24h — needs a nudge.
    case needsRepair

    var isActionable: Bool {
        switch self {
        case .pending, .disconnected, .needsRepair: return true
        case .connected: return false
        }
    }
}

/// A pairing between the current user and their partner: the shared "room" that every
/// wager, streak, and step comparison hangs off of. Mirrors Sweatmates' partner-room concept,
/// but the connection itself is driven by passive HealthKit sync rather than manual check-ins.
struct UserPair: Identifiable, Codable, Sendable {
    let id: UUID
    var roomID: String
    var currentUser: PairedUser
    var partner: PairedUser
    var sharedStreak: Int
    var longestStreak: Int
    var streakFreezesAvailable: Int
    var connectionStatus: ConnectionStatus
    var pairedSince: Date
    var lastSyncedAt: Date

    init(
        id: UUID = UUID(),
        roomID: String,
        currentUser: PairedUser,
        partner: PairedUser,
        sharedStreak: Int = 0,
        longestStreak: Int = 0,
        streakFreezesAvailable: Int = 1,
        connectionStatus: ConnectionStatus = .pending,
        pairedSince: Date = .now,
        lastSyncedAt: Date = .now
    ) {
        self.id = id
        self.roomID = roomID
        self.currentUser = currentUser
        self.partner = partner
        self.sharedStreak = sharedStreak
        self.longestStreak = longestStreak
        self.streakFreezesAvailable = streakFreezesAvailable
        self.connectionStatus = connectionStatus
        self.pairedSince = pairedSince
        self.lastSyncedAt = lastSyncedAt
    }

    /// True once partner sync is live and steps can be compared.
    var isActive: Bool { connectionStatus == .connected }

    /// How long ago the partner's Health data last synced, for "last seen" copy.
    var syncStaleness: TimeInterval { Date.now.timeIntervalSince(lastSyncedAt) }
}

// MARK: - Mock Data

extension PairedUser {
    static let mockMe = PairedUser(
        displayName: "Ben",
        avatarSystemName: "figure.walk.circle.fill",
        dailyStepGoal: 10_000
    )

    static let mockPartner = PairedUser(
        displayName: "Jess",
        avatarSystemName: "figure.run.circle.fill",
        dailyStepGoal: 8_000
    )
}

extension UserPair {
    static let mockConnected = UserPair(
        roomID: "SWEAT-7X2K",
        currentUser: .mockMe,
        partner: .mockPartner,
        sharedStreak: 12,
        longestStreak: 21,
        streakFreezesAvailable: 1,
        connectionStatus: .connected,
        pairedSince: Calendar.current.date(byAdding: .day, value: -34, to: .now) ?? .now,
        lastSyncedAt: Calendar.current.date(byAdding: .minute, value: -6, to: .now) ?? .now
    )

    static let mockPending = UserPair(
        roomID: "SWEAT-9QF1",
        currentUser: .mockMe,
        partner: PairedUser(displayName: "Invite Sent", avatarSystemName: "person.crop.circle.dashed"),
        sharedStreak: 0,
        connectionStatus: .pending
    )

    static let mockNeedsRepair = UserPair(
        roomID: "SWEAT-3LMZ",
        currentUser: .mockMe,
        partner: .mockPartner,
        sharedStreak: 5,
        longestStreak: 9,
        connectionStatus: .needsRepair,
        pairedSince: Calendar.current.date(byAdding: .day, value: -10, to: .now) ?? .now,
        lastSyncedAt: Calendar.current.date(byAdding: .hour, value: -30, to: .now) ?? .now
    )

    static let mocks: [UserPair] = [.mockConnected, .mockPending, .mockNeedsRepair]
}
