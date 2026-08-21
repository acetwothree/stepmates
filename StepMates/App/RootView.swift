//
//  RootView.swift
//  StepMates
//
//  App shell: shows the onboarding flow or goes straight to Home, and re-arms both
//  engines' background delivery on every launch regardless of which screen ends up
//  showing, since a background-launched process needs to re-register itself.
//

import SwiftUI

struct RootView: View {
    @State private var healthKitManager = HealthKitManager.shared
    @State private var cloudKitSyncEngine = CloudKitSyncEngine.shared
    @Environment(\.scenePhase) private var scenePhase

    /// Decided once, synchronously, from whatever state each singleton already has at
    /// launch (CloudKitSyncEngine restores persisted pairing synchronously in its own
    /// init, so this is usually accurate immediately) — see AppFlowCoordinator. Deliberately
    /// NOT a computed property re-evaluated on every render — see OnboardingFlowView's header
    /// comment for why: reactively watching pairingState/authorizationStatus here would
    /// reproduce the exact same "navigated away mid-flow" bug at the root level instead of
    /// inside the flow.
    @State private var flow = AppFlowCoordinator.shared

    var body: some View {
        Group {
            if flow.isOnboarding {
                OnboardingFlowView(healthKitManager: healthKitManager, cloudKitSyncEngine: cloudKitSyncEngine) {
                    flow.isOnboarding = false
                }
            } else {
                HomeView()
            }
        }
        .task {
            await healthKitManager.bootstrapIfAuthorized()
            await cloudKitSyncEngine.bootstrap()
            // One-time correction, and only in the "turns out onboarding wasn't needed"
            // direction — e.g. a returning user whose HealthKit status was still the
            // .notDetermined default at the synchronous init() check above, corrected once
            // bootstrap resolves it. Never flips the other way: once false (or once the
            // user is inside the flow), later state changes don't reopen onboarding.
            if flow.isOnboarding,
               healthKitManager.authorizationStatus != .notDetermined,
               cloudKitSyncEngine.pairingState != .unpaired {
                flow.isOnboarding = false
            }
        }
        // The one-shot .task above only ever runs once per app process — a partner's display
        // name change (or any other CloudKit update) picked up by push notification is
        // best-effort and not guaranteed prompt, so without this, returning to an
        // already-running app (not a true cold relaunch) can show stale partner data
        // indefinitely. Silent pushes stay as the fast path; this is the reliable fallback.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await cloudKitSyncEngine.refreshFromCloud()
            }
        }
    }
}

#Preview {
    RootView()
}
