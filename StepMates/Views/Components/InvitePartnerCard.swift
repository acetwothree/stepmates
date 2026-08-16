//
//  InvitePartnerCard.swift
//  StepMates
//
//  Prominent Home-screen card shown until a partner is actually paired: creates the CloudKit
//  room (or reuses one already created) and hands the invite straight to the native share
//  sheet — the same flow as onboarding's PartnerInviteView, just reachable again from Home.
//

import CloudKit
import SwiftUI

struct InvitePartnerCard: View {
    var displayName: String
    var dailyStepGoal: Int
    var pairingState: PairingState
    var cloudKitSyncEngine: CloudKitSyncEngine

    @State private var isCreatingRoom = false
    @State private var preparedShare: CKShare?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(SweatmatesColors.limeGradient).frame(width: 48, height: 48)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SweatmatesTypography.headline(16, weight: .bold))
                        .foregroundStyle(SweatmatesColors.textOnCard)
                    Text(subtitle)
                        .font(SweatmatesTypography.caption(12))
                        .foregroundStyle(SweatmatesColors.textOnCardSecondary)
                }
                Spacer(minLength: 0)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(SweatmatesTypography.caption(12, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.danger)
            }

            Button(action: createAndInvite) {
                HStack(spacing: 8) {
                    if isCreatingRoom {
                        ProgressView().tint(.white)
                    }
                    Text(buttonTitle)
                }
                .font(SweatmatesTypography.body(15, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(SweatmatesColors.flameGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isCreatingRoom)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(SweatmatesColors.cardSurface))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(SweatmatesColors.accentFlame.opacity(0.3), lineWidth: 1.5)
        )
        .sheet(isPresented: $showShareSheet) {
            if let preparedShare {
                CloudSharingView(share: preparedShare, container: .default()) {
                    showShareSheet = false
                }
                .ignoresSafeArea()
            }
        }
    }

    private var title: String {
        pairingState == .paired ? "Waiting for Your Partner" : "Invite Your Partner"
    }

    private var subtitle: String {
        pairingState == .paired
            ? "They haven't joined yet — resend the link if it got lost."
            : "Pair up to compare steps and start a wager."
    }

    private var buttonTitle: String {
        if isCreatingRoom { return "Creating Room…" }
        return pairingState == .paired ? "Resend Invite" : "Send Invite"
    }

    private func createAndInvite() {
        isCreatingRoom = true
        errorMessage = nil
        Task {
            do {
                let share = try await cloudKitSyncEngine.createRoomAndShare(displayName: displayName, dailyStepGoal: dailyStepGoal)
                preparedShare = share
                showShareSheet = true
            } catch {
                errorMessage = "Couldn't create your room: \(error.localizedDescription)"
            }
            isCreatingRoom = false
        }
    }
}

#Preview("Invite Partner — Unpaired") {
    InvitePartnerCard(displayName: "Ben", dailyStepGoal: 10_000, pairingState: .unpaired, cloudKitSyncEngine: .shared)
        .padding(20)
        .background(SweatmatesColors.background)
}

#Preview("Invite Partner — Waiting") {
    InvitePartnerCard(displayName: "Ben", dailyStepGoal: 10_000, pairingState: .paired, cloudKitSyncEngine: .shared)
        .padding(20)
        .background(SweatmatesColors.background)
}
