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
                    title: isCreatingRoom ? "Creating Room…" : "Invite Your Partner",
                    isLoading: isCreatingRoom,
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
                    let wager = Wager(
                        pairID: UUID(),
                        mode: .versusSprint,
                        status: .active,
                        stakeForCurrentUser: stake,
                        stakeForPartner: stake,
                        targetSteps: goal,
                        endDate: Date.todaySettlement
                    )
                    try? await cloudKitSyncEngine.updateActiveWager(wager)
                }
            } catch {
                errorMessage = "Couldn't create your room. Check your connection and try again."
            }
            isCreatingRoom = false
        }
    }
}

#Preview("Partner Invite") {
    PartnerInviteView(cloudKitSyncEngine: .shared, state: OnboardingState(), onFinished: {}, onBack: {})
}
