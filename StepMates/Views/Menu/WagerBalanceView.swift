//
//  WagerBalanceView.swift
//  StepMates
//
//  OWED (what you owe your partner) and EARNED (what your partner owes you) — split from
//  the same real IOUDebt list the weekly recap already computes from actual step history.
//

import SwiftUI

struct WagerBalanceView: View {
    var viewModel: HomeViewModel

    var body: some View {
        MenuPageScaffold(title: "Wager Balance") {
            VStack(alignment: .leading, spacing: 28) {
                balanceSection(header: "OWED", ious: owed, emptyText: "you're all caught up")
                balanceSection(header: "EARNED", ious: earned, emptyText: "no treats earned yet")
            }
        }
    }

    private var owed: [IOUDebt] {
        viewModel.weeklyRecap.outstandingIOUs.filter { $0.owedByCurrentUser && !$0.isSettled }
    }

    private var earned: [IOUDebt] {
        viewModel.weeklyRecap.outstandingIOUs.filter { !$0.owedByCurrentUser && !$0.isSettled }
    }

    private func balanceSection(header: String, ious: [IOUDebt], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(header)
                .font(SweatmatesTypography.microLabel(11))
                .foregroundStyle(SweatmatesColors.textSecondary)

            if ious.isEmpty {
                Text(emptyText)
                    .font(SweatmatesTypography.body(14))
                    .foregroundStyle(SweatmatesColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SweatmatesColors.cardSurfaceElevated))
            } else {
                VStack(spacing: 10) {
                    ForEach(ious) { iou in
                        HStack {
                            Image(systemName: iou.owedByCurrentUser ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundStyle(iou.owedByCurrentUser ? SweatmatesColors.accentFlame : SweatmatesColors.accentLimeDeep)
                            Text(iou.description)
                                .font(SweatmatesTypography.body(14))
                                .foregroundStyle(SweatmatesColors.textOnCard)
                            Spacer()
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SweatmatesColors.cardSurface))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("With balances") {
    let viewModel = HomeViewModel()
    viewModel.weeklyRecap = .mock
    return WagerBalanceView(viewModel: viewModel)
}

#Preview("Empty") {
    WagerBalanceView(viewModel: HomeViewModel())
}
