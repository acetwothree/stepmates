//
//  PartnerPageView.swift
//  StepMates
//
//  Partner link status and management — reuses the same CKShare-based InvitePartnerCard flow
//  as Home rather than a manual pairing-code UI, since that's how this app actually pairs
//  devices (a share link, not a typed code).
//

import SwiftUI

struct PartnerPageView: View {
    var viewModel: HomeViewModel

    @State private var showUnlinkConfirmation = false

    var body: some View {
        MenuPageScaffold(title: "Partner") {
            VStack(spacing: 20) {
                if viewModel.cloudKitSyncEngine.partnerSnapshot != nil {
                    connectedCard
                } else {
                    InvitePartnerCard(
                        displayName: viewModel.pair.currentUser.displayName,
                        dailyStepGoal: viewModel.pair.currentUser.dailyStepGoal,
                        pairingState: viewModel.cloudKitSyncEngine.pairingState,
                        cloudKitSyncEngine: viewModel.cloudKitSyncEngine
                    )
                }
            }
        }
    }

    private var connectedCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(SweatmatesColors.limeGradient).frame(width: 72, height: 72)
                Text(String(viewModel.pair.partner.displayName.prefix(1)).uppercased())
                    .font(SweatmatesTypography.title(28, weight: .heavy))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(viewModel.pair.partner.displayName)
                    .font(SweatmatesTypography.headline(18, weight: .bold))
                    .foregroundStyle(SweatmatesColors.textPrimary)
                Text("Connected")
                    .font(SweatmatesTypography.caption(13, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.accentLimeDeep)
            }

            Button("Unlink Partner", role: .destructive) {
                showUnlinkConfirmation = true
            }
            .font(SweatmatesTypography.body(14, weight: .semibold))
            .padding(.top, 8)
            .confirmationDialog(
                "Unlink from \(viewModel.pair.partner.displayName)?",
                isPresented: $showUnlinkConfirmation,
                titleVisibility: .visible
            ) {
                Button("Unlink Partner", role: .destructive) {
                    viewModel.cloudKitSyncEngine.unlinkPartnerLocally()
                }
            } message: {
                Text("This device will forget the pairing. Your partner keeps their own copy until they unlink too.")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(SweatmatesColors.cardSurface))
    }
}

#Preview {
    PartnerPageView(viewModel: HomeViewModel())
}
