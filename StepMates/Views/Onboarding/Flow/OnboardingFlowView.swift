//
//  OnboardingFlowView.swift
//  StepMates
//
//  Drives the whole onboarding sequence from one place. `step` only ever changes in
//  response to an explicit completion callback from the currently-showing screen — never
//  by reactively watching healthKitManager/cloudKitSyncEngine state. That's deliberate: it's
//  what fixes the bug where creating the CloudKit room (which flips pairingState to .paired
//  immediately, before the share sheet even appears) used to yank the invite screen out from
//  under its own sheet. See the comment on PartnerInviteView for the full explanation.
//

import SwiftUI

struct OnboardingFlowView: View {
    var healthKitManager: HealthKitManager
    var cloudKitSyncEngine: CloudKitSyncEngine
    var onFinished: () -> Void

    @State private var step: OnboardingStep = .hook
    @State private var onboardingState = OnboardingState()

    var body: some View {
        Group {
            switch step {
            case .hook:
                HookStepView(onContinue: advance)
            case .consistency:
                ConsistencyStepView(onContinue: advance, onBack: goBack)
            case .wagerIntro:
                WagerIntroStepView(onContinue: advance, onBack: goBack)
            case .socialProof:
                SocialProofStepView(onContinue: advance, onBack: goBack)
            case .stepGoal:
                StepGoalStepView(state: onboardingState, onContinue: advance, onBack: goBack)
            case .wagerExplainer:
                WagerExplainerStepView(onContinue: advance, onBack: goBack)
            case .wagerStake:
                WagerStakeStepView(state: onboardingState, onContinue: advance, onBack: goBack)
            case .name:
                NameStepView(state: onboardingState, onContinue: advance, onBack: goBack)
            case .profilePhoto:
                ProfilePhotoStepView(state: onboardingState, onContinue: advance, onBack: goBack)
            case .healthKitPermission:
                HealthKitPermissionView(healthKitManager: healthKitManager, onFinished: advance, onBack: goBack)
            case .partnerInvite:
                // A partner who joined via an already-accepted CKShare has nothing to invite
                // — the system-level accept sheet (shown before this app UI ever appeared)
                // already paired them. Without this check every partner would land on the
                // owner-facing "Invite Your Partner" screen regardless of role.
                if cloudKitSyncEngine.pairingState == .paired {
                    Color.clear.task { advance() }
                } else {
                    PartnerInviteView(cloudKitSyncEngine: cloudKitSyncEngine, state: onboardingState, onFinished: advance, onBack: goBack)
                }
            case .notifications:
                NotificationsStepView(onContinue: advance, onBack: goBack)
            case .unlock:
                UnlockStepView(state: onboardingState, onContinue: advance, onBack: goBack)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private func advance() {
        if let next = step.next {
            step = next
        } else {
            finish()
        }
    }

    private func goBack() {
        if let previous = step.previous {
            step = previous
        }
    }

    private func finish() {
        OnboardingProfileStore.save(
            OnboardingProfile(
                firstName: onboardingState.firstName,
                dailyStepGoal: onboardingState.dailyStepGoal,
                profileImageData: onboardingState.profileImageData
            )
        )
        onFinished()
    }
}

#Preview {
    OnboardingFlowView(healthKitManager: .shared, cloudKitSyncEngine: .shared, onFinished: {})
}
