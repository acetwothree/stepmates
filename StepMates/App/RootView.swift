//
//  RootView.swift
//  StepMates
//
//  App shell: walks through HealthKit permission, then partner pairing, before landing on
//  Home — and re-arms both engines' background delivery on every launch regardless of which
//  screen ends up showing, since a background-launched process needs to re-register itself.
//

import SwiftUI

struct RootView: View {
    @State private var healthKitManager = HealthKitManager.shared
    @State private var cloudKitSyncEngine = CloudKitSyncEngine.shared
    @State private var didSkipHealthKitOnboarding = false
    @State private var didSkipPartnerInvite = false

    var body: some View {
        Group {
            if healthKitManager.authorizationStatus == .notDetermined, !didSkipHealthKitOnboarding {
                HealthKitPermissionView(healthKitManager: healthKitManager) {
                    didSkipHealthKitOnboarding = true
                }
            } else if cloudKitSyncEngine.pairingState == .unpaired, !didSkipPartnerInvite {
                PartnerInviteView(cloudKitSyncEngine: cloudKitSyncEngine) {
                    didSkipPartnerInvite = true
                }
            } else {
                HomeView()
            }
        }
        .task {
            await healthKitManager.bootstrapIfAuthorized()
        }
        .task {
            await cloudKitSyncEngine.bootstrap()
        }
    }
}

#Preview {
    RootView()
}
