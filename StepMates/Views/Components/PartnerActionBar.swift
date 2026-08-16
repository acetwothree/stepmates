//
//  PartnerActionBar.swift
//  StepMates
//
//  The Home screen's bottom action row: nudge your partner, or open the wager sheet to
//  edit today's stakes.
//

import SwiftUI

struct PartnerActionBar: View {
    var viewModel: HomeViewModel

    var body: some View {
        VStack(spacing: 10) {
            if let confirmation = viewModel.nudgeConfirmation {
                Text(confirmation)
                    .font(SweatmatesTypography.caption(13, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.accentFlame)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 12) {
                actionButton(
                    title: "Nudge Partner",
                    emoji: "👟",
                    gradient: SweatmatesColors.flameGradient
                ) {
                    viewModel.sendNudge()
                }

                actionButton(
                    title: "Edit Today's Wager",
                    emoji: "⚡️",
                    gradient: SweatmatesColors.limeGradient
                ) {
                    viewModel.showCreateWagerSheet = true
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.nudgeConfirmation)
    }

    @ViewBuilder
    private func actionButton(
        title: String,
        emoji: String,
        gradient: LinearGradient,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(emoji).font(.system(size: 18))
                Text(title).font(SweatmatesTypography.caption(13, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Partner Action Bar") {
    PartnerActionBar(viewModel: HomeViewModel())
        .padding(20)
        .background(SweatmatesColors.background)
}
