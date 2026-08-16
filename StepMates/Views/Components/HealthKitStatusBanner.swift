//
//  HealthKitStatusBanner.swift
//  StepMates
//
//  A persistent, one-tap-to-fix banner shown wherever step sync has stalled because
//  Health access was denied or revoked — deep-links straight into iOS Settings.
//

import SwiftUI
import UIKit

struct HealthKitStatusBanner: View {
    var status: HealthKitAuthorizationStatus

    var body: some View {
        if status == .denied || status == .unavailable {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(SweatmatesColors.danger)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SweatmatesTypography.body(14, weight: .bold))
                        .foregroundStyle(SweatmatesColors.textOnCard)
                    Text(subtitle)
                        .font(SweatmatesTypography.caption(12))
                        .foregroundStyle(SweatmatesColors.textOnCardSecondary)
                }

                Spacer()

                if status == .denied {
                    Button("Open Settings", action: openSettings)
                        .font(SweatmatesTypography.caption(12, weight: .bold))
                        .foregroundStyle(SweatmatesColors.accentFlameDeep)
                        .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SweatmatesColors.cardSurface))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SweatmatesColors.danger.opacity(0.35), lineWidth: 1.5)
            )
        }
    }

    private var title: String {
        status == .unavailable ? "Health Isn't Available" : "Step Sync Paused"
    }

    private var subtitle: String {
        status == .unavailable
            ? "This device doesn't support Apple Health."
            : "Turn on Health access to keep your streak syncing automatically."
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview("HealthKit Status Banner") {
    VStack(spacing: 16) {
        HealthKitStatusBanner(status: .denied)
        HealthKitStatusBanner(status: .unavailable)
    }
    .padding(20)
    .background(SweatmatesColors.background)
}
