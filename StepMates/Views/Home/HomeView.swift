//
//  HomeView.swift
//  StepMates
//
//  The live partner stage: hamburger menu, streak header, head-to-head arena, and a quick
//  link into detailed stats — the screen a user lands on every time they open the app.
//  Wager management, partner management, and history now live on their own pages reachable
//  from the hamburger menu (see Views/Menu), each presented directly over this screen so
//  dismissing any of them — back arrow or swipe-down — always lands back here, never on an
//  intermediate menu screen.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        ZStack(alignment: .leading) {
            mainContent

            MenuOverlay(isPresented: $viewModel.showMenu) {
                MenuDrawerView(
                    viewModel: viewModel,
                    onSelectWeeklyRules: { openPage { viewModel.showWeeklyRules = true } },
                    onSelectWagerBalance: { openPage { viewModel.showWagerBalance = true } },
                    onSelectPartner: { openPage { viewModel.showPartnerPage = true } },
                    onSelectHistory: { openPage { viewModel.showHistory = true } },
                    onSelectSettings: { openPage { viewModel.showSettings = true } }
                )
            }
        }
        .fullScreenCover(isPresented: $viewModel.showWeeklyRules) {
            WeeklyRulesView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $viewModel.showWagerBalance) {
            WagerBalanceView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $viewModel.showPartnerPage) {
            PartnerPageView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $viewModel.showHistory) {
            HistoryView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showWeeklyRecap) {
            WeeklyRecapModal(pair: viewModel.pair, recap: viewModel.weeklyRecap)
        }
    }

    /// Closes the drawer and opens the requested page on the next runloop tick — doing both
    /// in the same instant makes SwiftUI's dismiss and present animations fight each other.
    /// The page itself appears instantly rather than sliding up: wrapping the state change in
    /// a transaction with animations disabled suppresses fullScreenCover's default
    /// present-from-bottom transition.
    private func openPage(_ present: @escaping () -> Void) {
        viewModel.showMenu = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                present()
            }
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                hamburgerRow
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

                if let awaiting = viewModel.wagerAwaitingMyAgreement {
                    PendingWagerBanner(wager: awaiting, pair: viewModel.pair) { accepted in
                        viewModel.respondToWagerProposal(accept: accepted)
                    }
                } else if let wager = viewModel.activeWager {
                    // Once this device is no longer the one being asked to respond (either
                    // it's fully agreed and active, or this device proposed it and is waiting
                    // on the partner), the pending banner above disappears — without this,
                    // nothing on Home ever showed the wager existed at all, agreed or not.
                    WagerCard(wager: wager)
                }

                StepArenaView(pair: viewModel.pair, comparison: viewModel.comparison)
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(SweatmatesColors.cardSurface))

                detailedStatsLink
            }
            .padding(20)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.healthKitManager.authorizationStatus)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.cloudKitSyncEngine.partnerSnapshot)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.activeWager)
        }
        .background(SweatmatesColors.background.ignoresSafeArea())
        .sheet(isPresented: $viewModel.showStats) {
            StatsView(
                pair: viewModel.pair,
                healthKitManager: viewModel.healthKitManager,
                partnerSnapshot: viewModel.cloudKitSyncEngine.partnerSnapshot
            )
        }
        .onAppear {
            viewModel.presentRecapIfNeeded()
            Task { await viewModel.refreshAll() }
        }
    }

    private var hamburgerRow: some View {
        HStack {
            Button {
                viewModel.showMenu = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textOnCard)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(SweatmatesColors.cardSurface))
                    .overlay(Circle().stroke(SweatmatesColors.divider, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()
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
        }
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

    private var detailedStatsLink: some View {
        Button {
            viewModel.showStats = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(SweatmatesColors.accentFlame.opacity(0.14)).frame(width: 44, height: 44)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SweatmatesColors.accentFlame)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Detailed Stats")
                        .font(SweatmatesTypography.body(15, weight: .bold))
                        .foregroundStyle(SweatmatesColors.textOnCard)
                    Text("Day, week, and month comparisons")
                        .font(SweatmatesTypography.caption(12))
                        .foregroundStyle(SweatmatesColors.textOnCardSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textOnCardSecondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(SweatmatesColors.cardSurface))
        }
        .buttonStyle(.plain)
    }
}

#Preview("Home — Connected") {
    HomeView()
}
