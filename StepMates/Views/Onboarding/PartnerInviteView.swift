//
//  PartnerInviteView.swift
//  StepMates
//
//  One button, one share sheet: creates the CloudKit room and hands the invite link
//  straight to iMessage — no account creation, no password, on either side.
//
//  `onFinished` fires exactly once, only after the share sheet is actually dismissed (or
//  the user taps "Maybe Later") — never just because `cloudKitSyncEngine.pairingState`
//  changed. createRoomAndShare() flips pairingState to .paired the moment the room is
//  created, well before the share sheet even appears; a caller that reactively navigates
//  away on that change alone would yank this view out from under its own sheet before the
//  user ever saw it. Driving the transition from this explicit callback instead is what
//  fixes that race — see OnboardingFlowView, which treats onFinished as the only signal
//  to advance.
//

import CloudKit
import SwiftUI

struct PartnerInviteView: View {
    var cloudKitSyncEngine: CloudKitSyncEngine
    var state: OnboardingState
    var onFinished: () -> Void
    var onBack: (() -> Void)?

    @State private var isCreatingRoom = false
    @State private var preparedShare: CKShare?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if onBack != nil {
                header
            }

            Spacer()

            iconBadge

            VStack(spacing: 12) {
                Text("Invite Your\nStep Partner")
                    .multilineTextAlignment(.center)
                    .font(SweatmatesTypography.title(30))
                    .foregroundStyle(SweatmatesColors.textPrimary)

                Text("Send a link. They tap it and you're paired — no account, no password, just steps.")
                    .multilineTextAlignment(.center)
                    .font(SweatmatesTypography.body(15))
                    .foregroundStyle(SweatmatesColors.textSecondary)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 28)

            if let errorMessage {
                Text(errorMessage)
                    .font(SweatmatesTypography.caption(12, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.danger)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 14) {
                OnboardingCTAButton(
                    title: buttonTitle,
                    isLoading: isCreatingRoom || cloudKitSyncEngine.pairingState == .pairing,
                    action: createAndInvite
                )

                Button("Maybe Later", action: onFinished)
                    .font(SweatmatesTypography.body(14, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(SweatmatesColors.background.ignoresSafeArea())
        .sheet(isPresented: $showShareSheet, onDismiss: onFinished) {
            if let preparedShare {
                CloudSharingView(share: preparedShare, container: .default()) {
                    showShareSheet = false
                }
                .ignoresSafeArea()
            }
        }
        // A share accepted via the system sheet just before this app UI appeared can still be
        // resolving in the background while this screen is showing. Advance automatically once
        // it lands — but only for a genuine incoming accept (role flips to .partner), never for
        // this device's own room creation (role .owner), which already advances explicitly via
        // the share-sheet's onDismiss above and must not be double-triggered here.
        .onChange(of: cloudKitSyncEngine.pairingState) { _, newState in
            if newState == .paired, cloudKitSyncEngine.role == .partner {
                onFinished()
            }
        }
    }

    /// While a just-accepted share is still resolving in the background, the button is
    /// disabled with this label instead of "Invite Your Partner" — tapping it now would create
    /// a second, unrelated room for someone who's actually about to join an existing one.
    private var buttonTitle: String {
        if cloudKitSyncEngine.pairingState == .pairing {
            return "Checking your invite…"
        }
        return isCreatingRoom ? "Creating Room…" : "Invite Your Partner"
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                onBack?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            ProgressView(value: OnboardingStep.partnerInvite.progress)
                .tint(SweatmatesColors.accentFlame)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(SweatmatesColors.limeGradient)
                .frame(width: 96, height: 96)
            Image(systemName: "person.2.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func createAndInvite() {
        isCreatingRoom = true
        errorMessage = nil
        let name = state.firstName
        let goal = state.dailyStepGoal
        Task {
            do {
                let share = try await cloudKitSyncEngine.createRoomAndShare(displayName: name, dailyStepGoal: goal)
                preparedShare = share
                showShareSheet = true

                if let stakeDescription = state.resolvedWagerStakeDescription {
                    let stake = PenaltyStake(owner: "shared", stakeDescription: stakeDescription)
                    // Proposed, not active: the partner hasn't joined yet, so there's no one
                    // to agree to it. It shows up as a pending proposal for them to accept
                    // once they do — same as any other wager, per the "both parties have to
                    // agree" rule.
                    let wager = Wager(
                        pairID: UUID(),
                        mode: .versusSprint,
                        duration: .day,
                        status: .proposed,
                        stakeForCurrentUser: stake,
                        stakeForPartner: stake,
                        targetStepsForOwner: goal,
                        targetStepsForPartner: goal,
                        endDate: Date.todaySettlement,
                        proposedByRole: .owner,
                        agreedByOwner: true,
                        agreedByPartner: false
                    )
                    try? await cloudKitSyncEngine.updateActiveWager(wager)
                }
            } catch {
                errorMessage = "Couldn't create your room: \(error.localizedDescription)"
            }
            isCreatingRoom = false
        }
    }
}

#Preview("Partner Invite") {
    PartnerInviteView(cloudKitSyncEngine: .shared, state: OnboardingState(), onFinished: {}, onBack: {})
}
