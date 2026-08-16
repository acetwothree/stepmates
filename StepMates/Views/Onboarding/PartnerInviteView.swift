//
//  PartnerInviteView.swift
//  StepMates
//
//  One button, one share sheet: creates the CloudKit room and hands the invite link
//  straight to iMessage — no account creation, no password, on either side.
//

import CloudKit
import SwiftUI

struct PartnerInviteView: View {
    var cloudKitSyncEngine: CloudKitSyncEngine
    var onSkip: () -> Void

    @State private var isCreatingRoom = false
    @State private var preparedShare: CKShare?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
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
                Button(action: createAndInvite) {
                    HStack {
                        if isCreatingRoom {
                            ProgressView().tint(.white)
                        }
                        Text(isCreatingRoom ? "Creating Room…" : "Invite Your Partner")
                    }
                    .font(SweatmatesTypography.headline(17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(SweatmatesColors.flameGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(isCreatingRoom)

                Button("Maybe Later", action: onSkip)
                    .font(SweatmatesTypography.body(14, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(SweatmatesColors.background.ignoresSafeArea())
        .sheet(isPresented: $showShareSheet) {
            if let preparedShare {
                CloudSharingView(share: preparedShare, container: .default()) {
                    showShareSheet = false
                }
                .ignoresSafeArea()
            }
        }
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
        Task {
            do {
                preparedShare = try await cloudKitSyncEngine.createRoomAndShare()
                showShareSheet = true
            } catch {
                errorMessage = "Couldn't create your room. Check your connection and try again."
            }
            isCreatingRoom = false
        }
    }
}

#Preview("Partner Invite") {
    PartnerInviteView(cloudKitSyncEngine: .shared, onSkip: {})
}
