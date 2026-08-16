//
//  WeeklyRecapModal.swift
//  StepMates
//
//  Sunday night recap: the week's record, combined mileage, and outstanding IOUs.
//

import SwiftUI

struct WeeklyRecapModal: View {
    var pair: UserPair
    var recap: WeeklyRecap

    @Environment(\.dismiss) private var dismiss
    @State private var settledIOUIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    scoreCard
                    distanceCard
                    iouSection
                }
                .padding(20)
            }
            .background(SweatmatesColors.background.ignoresSafeArea())
            .navigationTitle("Week Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var scoreCard: some View {
        VStack(spacing: 12) {
            Text("This Week").microLabel()

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                scoreColumn(name: "You", wins: recap.currentUserWins)
                Text("–")
                    .font(SweatmatesTypography.statNumber(28))
                    .foregroundStyle(SweatmatesColors.textOnCardSecondary)
                scoreColumn(name: pair.partner.displayName, wins: recap.partnerWins)
            }

            if recap.ties > 0 {
                Text("\(recap.ties) tied day\(recap.ties == 1 ? "" : "s")")
                    .font(SweatmatesTypography.caption(12))
                    .foregroundStyle(SweatmatesColors.textOnCardSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(SweatmatesColors.cardSurface))
    }

    private func scoreColumn(name: String, wins: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(wins)")
                .font(SweatmatesTypography.statNumber(44))
                .foregroundStyle(SweatmatesColors.textOnCard)
            Text(name.uppercased()).microLabel(size: 10)
        }
        .frame(minWidth: 70)
    }

    private var distanceCard: some View {
        HStack {
            statColumn(title: "Combined Steps", value: recap.combinedSteps.formatted())
            Divider().frame(height: 40)
            statColumn(title: "Combined Distance", value: String(format: "%.1f mi", recap.combinedDistanceMiles))
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(SweatmatesColors.cardSurface))
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).microLabel(size: 10)
            Text(value)
                .font(SweatmatesTypography.headline(20, weight: .bold))
                .foregroundStyle(SweatmatesColors.textOnCard)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var iouSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Outstanding IOUs").microLabel(color: SweatmatesColors.textSecondary)

            if recap.outstandingIOUs.isEmpty {
                Text("All settled up 🎉")
                    .font(SweatmatesTypography.body(14))
                    .foregroundStyle(SweatmatesColors.textSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(recap.outstandingIOUs) { iou in
                        iouRow(iou)
                    }
                }
            }
        }
    }

    private func iouRow(_ iou: IOUDebt) -> some View {
        let isSettled = settledIOUIDs.contains(iou.id) || iou.isSettled
        return HStack {
            Image(systemName: iou.owedByCurrentUser ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(iou.owedByCurrentUser ? SweatmatesColors.accentFlame : SweatmatesColors.accentLimeDeep)

            Text(iou.description)
                .font(SweatmatesTypography.body(14))
                .foregroundStyle(SweatmatesColors.textOnCard)
                .strikethrough(isSettled)

            Spacer()

            Button {
                HapticService.shared.lightTap()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if isSettled {
                        settledIOUIDs.remove(iou.id)
                    } else {
                        settledIOUIDs.insert(iou.id)
                    }
                }
            } label: {
                Image(systemName: isSettled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSettled ? SweatmatesColors.accentLimeDeep : SweatmatesColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SweatmatesColors.cardSurfaceElevated))
        .opacity(isSettled ? 0.6 : 1)
    }
}

#Preview("Weekly Recap") {
    WeeklyRecapModal(pair: .mockConnected, recap: .mock)
}

#Preview("Weekly Recap — All Settled") {
    WeeklyRecapModal(pair: .mockConnected, recap: .mockAllSettled)
}
