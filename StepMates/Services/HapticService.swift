//
//  HapticService.swift
//  StepMates
//
//  Centralizes every tactile response so feel stays consistent: nudges are sharp
//  and rigid, wager locks are heavy and deliberate, victories feel celebratory.
//

import UIKit

/// Tactile feedback for every touchpoint in the app. All generators live on the main
/// actor since `UIFeedbackGenerator` is UIKit and must be driven from the main thread.
@MainActor
final class HapticService {
    static let shared = HapticService()

    private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        prepareAll()
    }

    /// Warms up every generator so the first real trigger has no latency.
    func prepareAll() {
        rigidGenerator.prepare()
        heavyGenerator.prepare()
        lightGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    /// Poking your partner ("Digital Nudge") — a short, sharp rigid tap.
    func nudge() {
        rigidGenerator.impactOccurred()
        rigidGenerator.prepare()
    }

    /// Confirming a wager's stakes ("Pinky Promise" / locking in a bet) — a heavy, deliberate thud.
    func wagerLock() {
        heavyGenerator.impactOccurred()
        heavyGenerator.prepare()
    }

    /// Hitting the daily goal — a celebratory success notification.
    func dailyVictory() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    /// Falling short / losing a wager — a warning notification, distinct from a hard failure.
    func setback() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    /// Light tap for low-stakes UI: toggles, segmented controls, card taps.
    func lightTap() {
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }

    /// Selection change feedback, e.g. scrubbing between wager modes.
    func selectionChanged() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
}
