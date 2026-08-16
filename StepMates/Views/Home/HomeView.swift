//
//  HomeView.swift
//  StepMates
//
//  The live partner stage: streak header, head-to-head arena, active stake, and
//  nudge/pinky-promise actions — the screen a user lands on every time they open the app.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                HealthKitStatusBanner(status: viewModel.healthKitManager.authorizationStatus)

                if let request = viewModel.incomingPinkyPromiseRequest {
                    IncomingPinkyPromiseBanner(partnerName: viewModel.pair.partner.displayName, request: request) { approved in
                        viewModel.respondToPinkyPromise(approved: approved)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                StepArenaView(pair: viewModel.pair, comparison: viewModel.comparison)
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(SweatmatesColors.cardSurface))

                if let wager = viewModel.activeWager {
                    ActiveWagerBox(wager: wager, pair: viewModel.pair, comparison: viewModel.comparison)
                } else {
                    startWagerPrompt
                }

                PartnerActionBar(viewModel: viewModel)
            }
            .padding(20)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.healthKitManager.authorizationStatus)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.incomingPinkyPromiseRequest)
        }
        .background(SweatmatesColors.background.ignoresSafeArea())
        .sheet(isPresented: $viewModel.showCreateWagerSheet) {
            CreateWagerSheet(pair: viewModel.pair) { wager in
                viewModel.addWager(wager)
            }
        }
        .sheet(isPresented: $viewModel.showWeeklyRecap) {
            WeeklyRecapModal(pair: viewModel.pair, recap: viewModel.weeklyRecap)
        }
        .onAppear {
            viewModel.presentRecapIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                StreakBadge(
                    streakCount: viewModel.pair.sharedStreak,
                    isAtRisk: viewModel.pair.connectionStatus == .needsRepair
                )
                connectionStatusLabel
            }

            Spacer()

            HStack(spacing: 10) {
                circularIconButton(systemName: "chart.bar.fill") {
                    viewModel.showWeeklyRecap = true
                }
                circularIconButton(systemName: "gearshape.fill") {}
            }
        }
        .padding(.top, 8)
    }

    private var connectionStatusLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.pair.isActive ? SweatmatesColors.accentLimeDeep : SweatmatesColors.textTertiary)
                .frame(width: 7, height: 7)
            Text(connectionStatusText)
                .font(SweatmatesTypography.caption(13, weight: .semibold))
                .foregroundStyle(SweatmatesColors.textSecondary)
        }
        .padding(.leading, 4)
    }

    private var connectionStatusText: String {
        switch viewModel.pair.connectionStatus {
        case .connected: return "\(viewModel.pair.partner.displayName) is active"
        case .pending: return "Waiting for \(viewModel.pair.partner.displayName) to join…"
        case .disconnected: return "\(viewModel.pair.partner.displayName) disconnected"
        case .needsRepair: return "Sync paused — send a nudge"
        }
    }

    private func circularIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SweatmatesColors.textPrimary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(SweatmatesColors.cardSurfaceElevated))
        }
        .buttonStyle(.plain)
    }

    private var startWagerPrompt: some View {
        Button {
            viewModel.showCreateWagerSheet = true
        } label: {
            Label("Start a Wager", systemImage: "plus.circle.fill")
                .font(SweatmatesTypography.headline(16, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(SweatmatesColors.flameGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Home — Connected") {
    HomeView()
}
