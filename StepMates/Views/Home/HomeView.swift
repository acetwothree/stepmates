//
//  HomeView.swift
//  StepMates
//
//  The live partner stage: streak header, head-to-head arena, today's wager, and
//  nudge/edit-wager actions — the screen a user lands on every time they open the app.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                HealthKitStatusBanner(status: viewModel.healthKitManager.authorizationStatus)

                if viewModel.cloudKitSyncEngine.partnerSnapshot == nil {
                    InvitePartnerCard(
                        displayName: viewModel.pair.currentUser.displayName,
                        dailyStepGoal: viewModel.pair.currentUser.dailyStepGoal,
                        pairingState: viewModel.cloudKitSyncEngine.pairingState,
                        cloudKitSyncEngine: viewModel.cloudKitSyncEngine
                    )
                }

                StepArenaView(pair: viewModel.pair, comparison: viewModel.comparison)
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(SweatmatesColors.cardSurface))

                if let awaiting = viewModel.wagerAwaitingMyAgreement {
                    PendingWagerBanner(wager: awaiting, pair: viewModel.pair) { accepted in
                        viewModel.respondToWagerProposal(accept: accepted)
                    }
                } else if let wager = viewModel.activeWager {
                    TodaysWagerCard(wager: wager, pair: viewModel.pair)
                } else {
                    startWagerPrompt
                }

                PartnerActionBar(viewModel: viewModel)
            }
            .padding(20)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.healthKitManager.authorizationStatus)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.cloudKitSyncEngine.partnerSnapshot)
        }
        .background(SweatmatesColors.background.ignoresSafeArea())
        .sheet(isPresented: $viewModel.showCreateWagerSheet) {
            CreateWagerSheet(pair: viewModel.pair, myRole: viewModel.cloudKitSyncEngine.role ?? .owner) { wager in
                viewModel.addWager(wager)
            }
        }
        .alert("Wager Locked In", isPresented: $viewModel.showWagerLockedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You and \(viewModel.pair.partner.displayName) both agreed to this wager — it can't be changed until it resolves.")
        }
        .sheet(isPresented: $viewModel.showWeeklyRecap) {
            WeeklyRecapModal(pair: viewModel.pair, recap: viewModel.weeklyRecap)
        }
        .sheet(isPresented: $viewModel.showStats) {
            StatsView(
                pair: viewModel.pair,
                healthKitManager: viewModel.healthKitManager,
                partnerSnapshot: viewModel.cloudKitSyncEngine.partnerSnapshot
            )
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.presentRecapIfNeeded()
            Task { await viewModel.refreshAll() }
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
                    viewModel.showStats = true
                }
                circularIconButton(systemName: "gearshape.fill") {
                    viewModel.showSettings = true
                }
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

    /// `cardSurface` + `textOnCard` rather than `cardSurfaceElevated` + `textPrimary` — the
    /// latter pairing is an always-light background with an adaptive foreground, which goes
    /// low-contrast (near-white icon on a light cream fill) in dark mode.
    private func circularIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SweatmatesColors.textOnCard)
                .frame(width: 44, height: 44)
                .background(Circle().fill(SweatmatesColors.cardSurface))
                .overlay(Circle().stroke(SweatmatesColors.divider, lineWidth: 1))
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
