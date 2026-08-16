//
//  SweatmatesColors.swift
//  StepMates
//
//  Warm-cream cards on a dark surface, flame-orange / electric-lime accents.
//  Mirrors the Sweatmates palette — swap these tokens if brand colors ever change.
//

import SwiftUI

extension Color {
    /// Hex initializer supporting "#RRGGBB" and "#RRGGBBAA".
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")))
        var rgba: UInt64 = 0
        scanner.scanHexInt64(&rgba)

        let hasAlpha = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).count > 6
        let r, g, b, a: Double
        if hasAlpha {
            r = Double((rgba & 0xFF00_0000) >> 24) / 255
            g = Double((rgba & 0x00FF_0000) >> 16) / 255
            b = Double((rgba & 0x0000_FF00) >> 8) / 255
            a = Double(rgba & 0x0000_00FF) / 255
        } else {
            r = Double((rgba & 0xFF0000) >> 16) / 255
            g = Double((rgba & 0x00FF00) >> 8) / 255
            b = Double(rgba & 0x0000FF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// A color that resolves differently in light vs. dark mode without needing an asset catalog entry.
    static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

/// The full Sweatmates-style token set: dark app surface, warm cream cards, flame/lime accents.
enum SweatmatesColors {

    // MARK: Surfaces

    /// The base app background — near-black with a warm undertone, not pure black.
    static let background = Color.adaptive(light: "#F5F1E8", dark: "#15130F")

    /// Secondary background, used behind grouped sections.
    static let backgroundSecondary = Color.adaptive(light: "#ECE6D8", dark: "#1D1B15")

    /// The signature warm off-white card surface that floats on top of `background`.
    static let cardSurface = Color.adaptive(light: "#FBF8F1", dark: "#F4EFE3")

    /// A slightly deeper cream, for nested cards or pressed states.
    static let cardSurfaceElevated = Color.adaptive(light: "#F2ECDC", dark: "#EAE2CD")

    /// Hairline separators and card borders.
    static let divider = Color.adaptive(light: "#E4DCC8", dark: "#2A2720")

    // MARK: Text

    /// Primary text — reads dark on the cream cards, light on the dark background.
    static let textPrimary = Color.adaptive(light: "#1C1A14", dark: "#F7F3E8")

    /// Text drawn directly on cream card surfaces (always dark, regardless of app theme).
    static let textOnCard = Color(hex: "#1C1A14")

    static let textSecondary = Color.adaptive(light: "#6B6555", dark: "#B8B09B")
    static let textOnCardSecondary = Color(hex: "#7A745F")

    static let textTertiary = Color.adaptive(light: "#9A927A", dark: "#7C7460")

    // MARK: Accents

    /// Flame orange — streaks, "at risk" states, primary CTA.
    static let accentFlame = Color(hex: "#FF6B2C")
    static let accentFlameDeep = Color(hex: "#E8501A")

    /// Electric lime — success, "safe", positive deltas.
    static let accentLime = Color(hex: "#C8FF3D")
    static let accentLimeDeep = Color(hex: "#9FDB1E")

    /// Streak flame token, used for the 🔥 counter glyph background.
    static let streakFlame = accentFlame

    // MARK: Semantic

    static let safe = accentLime
    static let atRisk = accentFlame
    static let danger = Color(hex: "#FF4545")
    static let pending = Color(hex: "#FFC24B")

    // MARK: Gradients

    static let flameGradient = LinearGradient(
        colors: [Color(hex: "#FF8A3D"), Color(hex: "#E8501A")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let limeGradient = LinearGradient(
        colors: [Color(hex: "#DBFF6E"), Color(hex: "#A8E020")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardShine = LinearGradient(
        colors: [Color.white.opacity(0.5), Color.white.opacity(0)],
        startPoint: .top,
        endPoint: .bottom
    )
}

#Preview("Swatches") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach([
                ("background", SweatmatesColors.background),
                ("cardSurface", SweatmatesColors.cardSurface),
                ("accentFlame", SweatmatesColors.accentFlame),
                ("accentLime", SweatmatesColors.accentLime),
                ("danger", SweatmatesColors.danger),
                ("pending", SweatmatesColors.pending),
            ], id: \.0) { name, color in
                HStack {
                    RoundedRectangle(cornerRadius: 12).fill(color).frame(width: 60, height: 40)
                    Text(name)
                }
            }
        }
        .padding()
    }
}
