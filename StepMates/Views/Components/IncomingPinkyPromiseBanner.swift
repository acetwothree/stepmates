//
//  IncomingPinkyPromiseBanner.swift
//  StepMates
//
//  Shown when the partner has asked for mercy on today's stake — the other half of the
//  Pinky Promise flow: someone has to be on the receiving end of that request.
//

import SwiftUI

struct IncomingPinkyPromiseBanner: View {
    var partnerName: String
    var request: PinkyPromiseRequest
    var onRespond: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pinky Promise Request", systemImage: "hands.sparkles.fill")
                .microLabel(color: SweatmatesColors.accentFlame)

            Text("\(partnerName): \(request.reason)")
                .font(SweatmatesTypography.body(14, weight: .medium))
                .foregroundStyle(SweatmatesColors.textOnCard)

            HStack(spacing: 12) {
                Button {
                    onRespond(true)
                } label: {
                    Text("Approve")
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
                    Text("Deny")
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
}

#Preview("Incoming Pinky Promise") {
    IncomingPinkyPromiseBanner(
        partnerName: "Jess",
        request: PinkyPromiseRequest(
            reason: "Trailing by 1,800 steps — cut me some slack?",
            requestedAt: .now,
            requestedByRole: .partner,
            resolution: nil
        ),
        onRespond: { _ in }
    )
    .padding(20)
    .background(SweatmatesColors.background)
}
