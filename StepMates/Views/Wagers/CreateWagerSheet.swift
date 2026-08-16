//
//  CreateWagerSheet.swift
//  StepMates
//
//  Sweatmates-style wager creation: penalty stake or joint reward, playful presets,
//  daily step target. Symmetric "loser pays" stakes by design — asymmetric per-partner
//  stakes remain supported by the Wager model for wagers created elsewhere.
//

import SwiftUI

struct CreateWagerSheet: View {
    enum Kind: String, CaseIterable, Hashable {
        case penalty = "Penalty Wager"
        case treatYourself = "Treat Yourself Reward"
    }

    var pair: UserPair
    var onCreate: (Wager) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var kind: Kind = .penalty
    @State private var selectedPenaltyChip: String = Self.penaltyPresets[0]
    @State private var customPenaltyText = ""
    @State private var selectedTargetSteps = 10_000
    @State private var selectedRewardChip: String = Self.rewardPresets[0]
    @State private var customRewardText = ""
    @State private var streakRequirement = 7

    private static let penaltyPresets = ["Buy Sunday Matcha", "Do the Dishes", "Cook Dinner", "Plan Date Night", "Custom"]
    private static let penaltyDescriptions: [String: String] = [
        "Buy Sunday Matcha": "Loser buys Sunday matcha",
        "Do the Dishes": "Loser does the dishes",
        "Cook Dinner": "Loser cooks dinner",
        "Plan Date Night": "Loser plans date night",
    ]
    private static let rewardPresets = ["Dinner Out", "Movie Night", "Spa Day", "Custom"]
    private static let stepTargets = [8_000, 10_000, 12_000]
    private static let streakOptions = [3, 5, 7, 14]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    kindToggle

                    if kind == .penalty {
                        penaltySection
                    } else {
                        treatYourselfSection
                    }
                }
                .padding(20)
                .padding(.bottom, 80)
            }
            .background(SweatmatesColors.background.ignoresSafeArea())
            .navigationTitle("New Wager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                lockItInButton
            }
        }
    }

    // MARK: Sections

    private var kindToggle: some View {
        HStack(spacing: 8) {
            ForEach(Kind.allCases, id: \.self) { option in
                Button {
                    HapticService.shared.selectionChanged()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { kind = option }
                } label: {
                    Text(option.rawValue)
                        .font(SweatmatesTypography.body(14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(
                                kind == option
                                    ? AnyShapeStyle(SweatmatesColors.flameGradient)
                                    : AnyShapeStyle(SweatmatesColors.cardSurfaceElevated)
                            )
                        )
                        .foregroundStyle(kind == option ? .white : SweatmatesColors.textOnCard)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var penaltySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("If you lose…")
            WrapLayout(spacing: 8) {
                ForEach(Self.penaltyPresets, id: \.self) { preset in
                    SelectableChip(title: preset, isSelected: selectedPenaltyChip == preset) {
                        HapticService.shared.lightTap()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            selectedPenaltyChip = preset
                        }
                    }
                }
            }

            if selectedPenaltyChip == "Custom" {
                TextField("Describe the forfeit", text: $customPenaltyText)
                    .stepMatesFieldStyle()
            }

            sectionLabel("Daily step target")
            HStack(spacing: 8) {
                ForEach(Self.stepTargets, id: \.self) { target in
                    SelectableChip(title: "\(target.formatted())", isSelected: selectedTargetSteps == target) {
                        HapticService.shared.lightTap()
                        selectedTargetSteps = target
                    }
                }
            }
        }
    }

    private var treatYourselfSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("The reward")
            WrapLayout(spacing: 8) {
                ForEach(Self.rewardPresets, id: \.self) { preset in
                    SelectableChip(title: preset, isSelected: selectedRewardChip == preset) {
                        HapticService.shared.lightTap()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            selectedRewardChip = preset
                        }
                    }
                }
            }

            if selectedRewardChip == "Custom" {
                TextField("Describe the reward", text: $customRewardText)
                    .stepMatesFieldStyle()
            }

            sectionLabel("Streak required")
            HStack(spacing: 8) {
                ForEach(Self.streakOptions, id: \.self) { days in
                    SelectableChip(title: "\(days) days", isSelected: streakRequirement == days) {
                        HapticService.shared.lightTap()
                        streakRequirement = days
                    }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).microLabel(color: SweatmatesColors.textSecondary)
    }

    private var lockItInButton: some View {
        Button {
            createWager()
        } label: {
            Text("Lock It In")
                .font(SweatmatesTypography.headline(17, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(SweatmatesColors.flameGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: Actions

    private func createWager() {
        let endDate = Date.todaySettlement
        let newWager: Wager

        switch kind {
        case .penalty:
            let description = selectedPenaltyChip == "Custom"
                ? customPenaltyText
                : (Self.penaltyDescriptions[selectedPenaltyChip] ?? "Loser picks the forfeit")
            let resolvedDescription = description.isEmpty ? "Loser picks the forfeit" : description
            let mine = PenaltyStake(owner: pair.currentUser.displayName, stakeDescription: resolvedDescription)
            let theirs = PenaltyStake(owner: pair.partner.displayName, stakeDescription: resolvedDescription)
            newWager = Wager(
                pairID: pair.id,
                mode: .versusSprint,
                status: .active,
                stakeForCurrentUser: mine,
                stakeForPartner: theirs,
                targetSteps: selectedTargetSteps,
                endDate: endDate
            )
        case .treatYourself:
            let reward = selectedRewardChip == "Custom" ? customRewardText : selectedRewardChip
            newWager = Wager(
                pairID: pair.id,
                mode: .treatYourself,
                status: .active,
                streakRequirement: streakRequirement,
                rewardDescription: reward.isEmpty ? "A treat, TBD" : reward,
                endDate: endDate
            )
        }

        onCreate(newWager)
        dismiss()
    }
}

private extension View {
    func stepMatesFieldStyle() -> some View {
        padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SweatmatesColors.cardSurfaceElevated))
            .foregroundStyle(SweatmatesColors.textOnCard)
    }
}

#Preview("Create Wager Sheet") {
    CreateWagerSheet(pair: .mockConnected) { _ in }
}
