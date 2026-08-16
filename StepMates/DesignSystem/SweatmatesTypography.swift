//
//  SweatmatesTypography.swift
//  StepMates
//
//  SF Pro Rounded across the board, with tight-tracked uppercase micro-labels
//  for the "STREAK", "TODAY", "PINKY PROMISE" style eyebrow text.
//

import SwiftUI

enum SweatmatesTypography {

    // MARK: Rounded font scale

    static func display(_ size: CGFloat = 40, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func title(_ size: CGFloat = 28, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func headline(_ size: CGFloat = 18, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func body(_ size: CGFloat = 16, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func caption(_ size: CGFloat = 13, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// The small uppercase eyebrow label style ("STREAK", "TODAY'S STEPS", "PINKY PROMISE").
    static func microLabel(_ size: CGFloat = 11, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// The oversized numeric style used for the streak count and step totals.
    static func statNumber(_ size: CGFloat = 48, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Applies the uppercase, wide-tracked micro-label treatment used throughout Sweatmates
/// for card eyebrows ("STREAK", "TODAY", "WAGER LOCKED").
struct MicroLabelStyle: ViewModifier {
    var size: CGFloat = 11
    var weight: Font.Weight = .bold
    var color: Color = SweatmatesColors.textOnCardSecondary

    func body(content: Content) -> some View {
        content
            .font(SweatmatesTypography.microLabel(size, weight: weight))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension View {
    /// Uppercase micro-label eyebrow text, e.g. `Text("Streak").microLabel()`.
    func microLabel(
        size: CGFloat = 11,
        weight: Font.Weight = .bold,
        color: Color = SweatmatesColors.textOnCardSecondary
    ) -> some View {
        modifier(MicroLabelStyle(size: size, weight: weight, color: color))
    }
}

#Preview("Type Scale") {
    VStack(alignment: .leading, spacing: 14) {
        Text("Streak").microLabel()
        Text("12").font(SweatmatesTypography.statNumber())
        Text("Hit your goal and you're safe").font(SweatmatesTypography.title())
        Text("Add light stakes").font(SweatmatesTypography.headline())
        Text("Pinky Promise resolves once you both confirm.").font(SweatmatesTypography.body())
        Text("Synced 6 min ago").font(SweatmatesTypography.caption())
    }
    .padding(24)
    .foregroundStyle(SweatmatesColors.textOnCard)
    .background(SweatmatesColors.cardSurface)
}
