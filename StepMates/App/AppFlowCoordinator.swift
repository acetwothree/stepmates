//
//  AppFlowCoordinator.swift
//  StepMates
//
//  Owns the one bit RootView needs to decide onboarding vs. Home. Pulled out of RootView's
//  local @State into a shared singleton so the Settings debug section's "Reset Onboarding"
//  action can flip it from deep in the view hierarchy without RootView reactively re-deriving
//  it from HealthKit/CloudKit state on every render (see RootView's own header comment for
//  why that reactive approach caused a real bug during onboarding).
//

import Observation

@MainActor
@Observable
final class AppFlowCoordinator {
    static let shared = AppFlowCoordinator()

    var isOnboarding: Bool

    private init() {
        let hk = HealthKitManager.shared
        let ck = CloudKitSyncEngine.shared
        isOnboarding = hk.authorizationStatus == .notDetermined || ck.pairingState == .unpaired
    }
}
