//
//  SelectableChip.swift
//  StepMates
//
//  A single tappable preset pill — used for wager stakes, step targets, and reward presets.
//

import SwiftUI

struct SelectableChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SweatmatesTypography.body(14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(
                        isSelected
                            ? AnyShapeStyle(SweatmatesColors.flameGradient)
                            : AnyShapeStyle(SweatmatesColors.cardSurfaceElevated)
                    )
                )
                .foregroundStyle(isSelected ? .white : SweatmatesColors.textOnCard)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Selectable Chips") {
    WrapLayout(spacing: 8) {
        SelectableChip(title: "Buy Sunday Matcha", isSelected: true) {}
        SelectableChip(title: "Do the Dishes", isSelected: false) {}
        SelectableChip(title: "Cook Dinner", isSelected: false) {}
        SelectableChip(title: "Plan Date Night", isSelected: false) {}
        SelectableChip(title: "Custom", isSelected: false) {}
    }
    .padding(24)
    .background(SweatmatesColors.background)
}
