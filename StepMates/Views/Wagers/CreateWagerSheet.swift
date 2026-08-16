//
//  CreateWagerSheet.swift
//  StepMates
//
//  Sweatmates-style wager creation: penalty stake or joint reward, playful presets, a
//  duration (1 day/week/month), and a target that's always auto-calculated from each
//  person's own daily goal — never hand-picked, so the wager can't be quietly stacked in
//  one side's favor. Proposing locks nothing in by itself: the other partner has to agree
//  (see PendingWagerBanner) before status moves from .proposed to .active.
//

import SwiftUI

struct CreateWagerSheet: View {
    enum Kind: String, CaseIterable, Hashable {
        case penalty = "Penalty Wager"
        case treatYourself = "Treat Yourself Reward"
    }

    var pair: UserPair
    var myRole: PairingRole
    var onCreate: (Wager) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var kind: Kind = .penalty
    @State private var duration: WagerDuration = .week
    @State private var selectedPenaltyChip: String = Self.penaltyPresets[0]
    @State private var customPenaltyText = ""
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
    private static let streakOptions = [3, 5, 7, 14]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    kindToggle
                    durationSection

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

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("How long")
            HStack(spacing: 8) {
                ForEach(WagerDuration.allCases) { option in
                    SelectableChip(title: option.displayName, isSelected: duration == option) {
                        HapticService.shared.lightTap()
                        duration = option
                    }
                }
            }

            if kind == .penalty {
                targetSummary
            }
        }
    }

    /// Always derived, never hand-picked: each side's target is their own daily goal scaled
    /// by the chosen duration, so switching duration recalculates this live.
    private var targetSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Target (auto-calculated)")
            HStack(spacing: 16) {
                targetColumn(label: "You", steps: duration.periodTarget(dailyGoal: pair.currentUser.dailyStepGoal))
                targetColumn(label: pair.partner.displayName, steps: duration.periodTarget(dailyGoal: pair.partner.dailyStepGoal))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SweatmatesColors.cardSurfaceElevated))
    }

    private func targetColumn(label: String, steps: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(SweatmatesTypography.microLabel(10))
                .foregroundStyle(SweatmatesColors.textOnCardSecondary)
            Text("\(steps.formatted()) steps")
                .font(SweatmatesTypography.body(15, weight: .bold))
                .foregroundStyle(SweatmatesColors.textOnCard)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Text("Propose Wager")
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
        let start = Date.now
        let end = duration.endDate(from: start)
        let newWager: Wager

        switch kind {
        case .penalty:
            let description = selectedPenaltyChip == "Custom"
                ? customPenaltyText
                : (Self.penaltyDescriptions[selectedPenaltyChip] ?? "Loser picks the forfeit")
            let resolvedDescription = description.isEmpty ? "Loser picks the forfeit" : description
            let mine = PenaltyStake(owner: pair.currentUser.displayName, stakeDescription: resolvedDescription)
            let theirs = PenaltyStake(owner: pair.partner.displayName, stakeDescription: resolvedDescription)

            let myTarget = duration.periodTarget(dailyGoal: pair.currentUser.dailyStepGoal, from: start)
            let partnerTarget = duration.periodTarget(dailyGoal: pair.partner.dailyStepGoal, from: start)
            let ownerTarget = myRole == .owner ? myTarget : partnerTarget
            let partnerRoleTarget = myRole == .owner ? partnerTarget : myTarget

            newWager = Wager(
                pairID: pair.id,
                mode: .versusSprint,
                duration: duration,
                status: .proposed,
                stakeForCurrentUser: mine,
                stakeForPartner: theirs,
                targetStepsForOwner: ownerTarget,
                targetStepsForPartner: partnerRoleTarget,
                startDate: start,
                endDate: end,
                proposedByRole: myRole,
                agreedByOwner: myRole == .owner,
                agreedByPartner: myRole == .partner
            )
        case .treatYourself:
            let reward = selectedRewardChip == "Custom" ? customRewardText : selectedRewardChip
            newWager = Wager(
                pairID: pair.id,
                mode: .treatYourself,
                duration: duration,
                status: .proposed,
                streakRequirement: streakRequirement,
                rewardDescription: reward.isEmpty ? "A treat, TBD" : reward,
                startDate: start,
                endDate: end,
                proposedByRole: myRole,
                agreedByOwner: myRole == .owner,
                agreedByPartner: myRole == .partner
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
    CreateWagerSheet(pair: .mockConnected, myRole: .owner) { _ in }
}
