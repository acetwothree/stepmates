//
//  WeeklyRulesView.swift
//  StepMates
//
//  The active wager's terms, laid out like Sweatmates' Weekly Rules page: each side's target,
//  what's owed if you miss it, and the streak reward if there is one. Owns its own Edit sheet
//  and locked-wager alert rather than routing through Home's — this page is itself presented
//  as a full-screen cover, and stacking a second sheet from the presenter that opened it is
//  less reliable than each presented screen owning its own next-level presentation.
//

import SwiftUI

struct WeeklyRulesView: View {
    var viewModel: HomeViewModel

    @State private var showEditSheet = false
    @State private var showLockedAlert = false

    var body: some View {
        MenuPageScaffold(title: "Weekly Rules") {
            content
        } trailingAccessory: {
            Button("Edit", action: editTapped)
                .font(SweatmatesTypography.body(14, weight: .bold))
                .foregroundStyle(SweatmatesColors.accentFlame)
        }
        .sheet(isPresented: $showEditSheet) {
            CreateWagerSheet(pair: viewModel.pair, myRole: viewModel.cloudKitSyncEngine.role ?? .owner) { wager in
                viewModel.addWager(wager)
            }
        }
        .alert("Wager Locked In", isPresented: $showLockedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You and \(viewModel.pair.partner.displayName) both agreed to this wager — it can't be changed until it resolves.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let wager = viewModel.activeWager {
            VStack(spacing: 24) {
                titleBlock

                targetsCard(wager)

                if let stakeText = missStakeText(wager) {
                    ruleSection(header: "IF YOU MISS") {
                        stakeRow(emoji: emoji(for: stakeText), text: stakeText)
                    }
                }

                if wager.mode == .treatYourself || wager.streakRequirement != nil {
                    ruleSection(header: "IF YOU HIT YOUR STREAK", trailing: "NEW") {
                        rewardRow(wager)
                    }
                }

                Text("Stay accountable together")
                    .font(SweatmatesTypography.caption(12, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textTertiary)
                    .padding(.top, 8)
            }
        } else {
            emptyState
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("✦ WEEKLY RULES ✦")
                .font(SweatmatesTypography.microLabel(13))
                .tracking(1.5)
                .foregroundStyle(SweatmatesColors.textSecondary)
            Text("Hit your step target")
                .font(SweatmatesTypography.headline(18))
                .foregroundStyle(SweatmatesColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private func targetsCard(_ wager: Wager) -> some View {
        let myTarget = viewModel.cloudKitSyncEngine.role == .partner ? wager.targetStepsForPartner : wager.targetStepsForOwner
        let partnerTarget = viewModel.cloudKitSyncEngine.role == .partner ? wager.targetStepsForOwner : wager.targetStepsForPartner

        return HStack(spacing: 0) {
            targetColumn(label: viewModel.pair.partner.displayName, steps: partnerTarget)
            Divider().frame(height: 40)
            targetColumn(label: viewModel.pair.currentUser.displayName, steps: myTarget)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(SweatmatesColors.cardSurface))
    }

    private func targetColumn(label: String, steps: Int?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(SweatmatesTypography.caption(12))
                .foregroundStyle(SweatmatesColors.textOnCardSecondary)
            Text(steps.map { "\($0.formatted())" } ?? "—")
                .font(SweatmatesTypography.headline(20, weight: .bold))
                .foregroundStyle(SweatmatesColors.textOnCard)
            Text(steps == nil ? "" : "steps · \(wagerDurationLabel)")
                .font(SweatmatesTypography.caption(10))
                .foregroundStyle(SweatmatesColors.textOnCardSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var wagerDurationLabel: String {
        viewModel.activeWager?.duration.displayName.lowercased() ?? ""
    }

    private func ruleSection<Content: View>(header: String, trailing: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(header)
                    .font(SweatmatesTypography.microLabel(11))
                    .foregroundStyle(SweatmatesColors.textSecondary)
                if let trailing {
                    Text(trailing)
                        .font(SweatmatesTypography.microLabel(9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(SweatmatesColors.accentFlame))
                        .foregroundStyle(.white)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stakeRow(emoji: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 22))
            Text(text)
                .font(SweatmatesTypography.body(15, weight: .semibold))
                .foregroundStyle(SweatmatesColors.textOnCard)
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SweatmatesColors.cardSurface))
    }

    @ViewBuilder
    private func rewardRow(_ wager: Wager) -> some View {
        if let reward = wager.rewardDescription {
            stakeRow(emoji: "🍦", text: reward)
        } else {
            Button {
                showEditSheet = true
            } label: {
                Label("Add Treat", systemImage: "plus")
                    .font(SweatmatesTypography.body(14, weight: .bold))
                    .foregroundStyle(SweatmatesColors.accentFlame)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(SweatmatesColors.accentFlame, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 36))
                .foregroundStyle(SweatmatesColors.textTertiary)
            Text("No wager yet")
                .font(SweatmatesTypography.headline(17, weight: .bold))
                .foregroundStyle(SweatmatesColors.textPrimary)
            Text("Propose a wager to set the rules you're both playing for.")
                .font(SweatmatesTypography.body(14))
                .foregroundStyle(SweatmatesColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showEditSheet = true
            } label: {
                Text("Propose a Wager")
                    .font(SweatmatesTypography.headline(15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(SweatmatesColors.flameGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.top, 60)
        .padding(.horizontal, 20)
    }

    private func missStakeText(_ wager: Wager) -> String? {
        switch wager.mode {
        case .versusSprint:
            return wager.stakeForCurrentUser?.stakeDescription ?? wager.stakeForPartner?.stakeDescription
        case .coOpSharedTarget:
            if let target = wager.targetSteps {
                return "Combined target: \(target.formatted()) steps/day"
            }
            return nil
        case .treatYourself:
            return nil
        }
    }

    private func emoji(for description: String) -> String {
        OnboardingWagerStake.presets.first { $0.description == description }?.emoji ?? "🤝"
    }

    private func editTapped() {
        if let wager = viewModel.activeWager, wager.isFullyAgreed {
            showLockedAlert = true
        } else {
            showEditSheet = true
        }
    }
}

#Preview {
    WeeklyRulesView(viewModel: HomeViewModel(activeWager: .mockVersusSprint))
}
