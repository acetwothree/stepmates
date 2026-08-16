//
//  PendingWagerBanner.swift
//  StepMates
//
//  Shown when the partner has proposed a wager and it's this device's turn to agree —
//  wagers lock in only once both sides accept; declining clears the proposal outright.
//

import SwiftUI

struct PendingWagerBanner: View {
    var wager: Wager
    var pair: UserPair
    var onRespond: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("New Wager Proposed", systemImage: "hand.raised.fill")
                .microLabel(color: SweatmatesColors.accentFlame)

            Text(summary)
                .font(SweatmatesTypography.body(14, weight: .medium))
                .foregroundStyle(SweatmatesColors.textOnCard)

            HStack(spacing: 12) {
                Button {
                    onRespond(true)
                } label: {
                    Text("Agree")
                        .font(SweatmatesTypography.caption(13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(SweatmatesColors.limeGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    onRespond(false)
                } label: {
                    Text("Decline")
                        .font(SweatmatesTypography.caption(13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SweatmatesColors.cardSurfaceElevated))
                        .foregroundStyle(SweatmatesColors.textOnCard)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(SweatmatesColors.cardSurface))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(SweatmatesColors.accentFlame.opacity(0.35), lineWidth: 1.5)
        )
    }

    private var summary: String {
        switch wager.mode {
        case .versusSprint:
            let stakeText = wager.stakeForCurrentUser?.stakeDescription ?? "a forfeit"
            let target = wager.targetStepsForOwner ?? wager.targetStepsForPartner ?? 0
            return "\(pair.partner.displayName) proposed: \(stakeText) — \(target.formatted()) steps over \(wager.duration.displayName.lowercased())."
        case .coOpSharedTarget:
            return "\(pair.partner.displayName) proposed a combined \((wager.targetSteps ?? 0).formatted())-step target."
        case .treatYourself:
            return "\(pair.partner.displayName) proposed: \(wager.rewardDescription ?? "a reward") after a \(wager.streakRequirement ?? 0)-day streak."
        }
    }
}

#Preview("Pending Wager Banner") {
    PendingWagerBanner(wager: .mockAwaitingAgreement, pair: .mockConnected, onRespond: { _ in })
        .padding(20)
        .background(SweatmatesColors.background)
}
