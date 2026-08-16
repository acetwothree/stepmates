//
//  PartnerActionBar.swift
//  StepMates
//
//  "Digital Nudge" pokes your partner; "Pinky Promise" asks them to waive today's stake.
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
                    title: "Digital Nudge",
                    icon: "hand.point.right.fill",
                    gradient: SweatmatesColors.flameGradient
                ) {
                    viewModel.sendNudge()
                }

                actionButton(
                    title: pinkyPromiseTitle,
                    icon: pinkyPromiseIcon,
                    gradient: SweatmatesColors.limeGradient,
                    isDisabled: viewModel.pinkyPromiseState == .requested
                ) {
                    viewModel.requestPinkyPromise()
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.nudgeConfirmation)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.pinkyPromiseState)
    }

    private var pinkyPromiseTitle: String {
        switch viewModel.pinkyPromiseState {
        case .idle, .denied: return "Pinky Promise"
        case .requested: return "Waiting…"
        case .approved: return "Waived!"
        }
    }

    private var pinkyPromiseIcon: String {
        viewModel.pinkyPromiseState == .approved ? "hands.sparkles.fill" : "hands.sparkles"
    }

    @ViewBuilder
    private func actionButton(
        title: String,
        icon: String,
        gradient: LinearGradient,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .bold))
                Text(title).font(SweatmatesTypography.caption(13, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .foregroundStyle(.white)
            .opacity(isDisabled ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

#Preview("Partner Action Bar") {
    PartnerActionBar(viewModel: HomeViewModel())
        .padding(20)
        .background(SweatmatesColors.background)
}
