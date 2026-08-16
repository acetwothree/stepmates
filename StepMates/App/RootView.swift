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

    /// Decided once, synchronously, from whatever state each singleton already has at
    /// launch (CloudKitSyncEngine restores persisted pairing synchronously in its own
    /// init, so this is usually accurate immediately). Deliberately NOT a computed property
    /// re-evaluated on every render — see OnboardingFlowView's header comment for why:
    /// reactively watching pairingState/authorizationStatus here would reproduce the exact
    /// same "navigated away mid-flow" bug at the root level instead of inside the flow.
    @State private var isOnboarding: Bool

    init() {
        let hk = HealthKitManager.shared
        let ck = CloudKitSyncEngine.shared
        _isOnboarding = State(initialValue: hk.authorizationStatus == .notDetermined || ck.pairingState == .unpaired)
    }

    var body: some View {
        Group {
            if isOnboarding {
                OnboardingFlowView(healthKitManager: healthKitManager, cloudKitSyncEngine: cloudKitSyncEngine) {
                    isOnboarding = false
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
            if isOnboarding,
               healthKitManager.authorizationStatus != .notDetermined,
               cloudKitSyncEngine.pairingState != .unpaired {
                isOnboarding = false
            }
        }
    }
}

#Preview {
    RootView()
}
