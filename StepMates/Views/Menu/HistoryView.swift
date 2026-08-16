//
//  HistoryView.swift
//  StepMates
//
//  Streak + this-week's record, both real. "Past Weeks" is an honest empty state for now —
//  the app only computes the trailing 7-day window on demand, it doesn't archive past weeks
//  yet, so there's nothing genuine to show there until that's built.
//

import SwiftUI

struct HistoryView: View {
    var viewModel: HomeViewModel

    var body: some View {
        MenuPageScaffold(title: "History") {
            VStack(spacing: 24) {
                statsRow
                pastWeeksSection
            }
        }
        .task {
            await viewModel.refreshWeeklyRecap()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 14) {
            statCard(emoji: "🔥", label: "STREAK", value: "\(viewModel.pair.sharedStreak)", unit: "days", tint: SweatmatesColors.accentFlame)
            statCard(emoji: "🏆", label: "TOTAL", value: "\(viewModel.weeklyRecap.currentUserWins)", unit: "days won this week", tint: SweatmatesColors.accentLimeDeep)
        }
    }

    private func statCard(emoji: String, label: String, value: String, unit: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(emoji)
                Text(label)
                    .font(SweatmatesTypography.microLabel(11))
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(SweatmatesTypography.statNumber(32))
                .foregroundStyle(SweatmatesColors.textOnCard)
            Text(unit)
                .font(SweatmatesTypography.caption(12))
                .foregroundStyle(SweatmatesColors.textOnCardSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(SweatmatesColors.cardSurface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(tint.opacity(0.25), lineWidth: 1))
    }

    private var pastWeeksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Weeks")
                .font(SweatmatesTypography.headline(16, weight: .bold))
                .foregroundStyle(SweatmatesColors.textPrimary)

            VStack(spacing: 12) {
                Image(systemName: "arrow.counterclockwise.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(SweatmatesColors.textTertiary)
                Text("No past weeks yet")
                    .font(SweatmatesTypography.body(15, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textPrimary)
                Text("Complete your first week to see your history here")
                    .font(SweatmatesTypography.caption(13))
                    .foregroundStyle(SweatmatesColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(SweatmatesColors.cardSurfaceElevated))
        }
    }
}

#Preview {
    HistoryView(viewModel: HomeViewModel())
}
