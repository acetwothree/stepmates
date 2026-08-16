//
//  OnboardingScaffold.swift
//  StepMates
//
//  Shared chrome for every onboarding step after the hook screen: back chevron + a single
//  continuous progress bar up top, arbitrary content in the middle, a footer (usually one
//  CTA button) pinned to the bottom.
//

import SwiftUI

struct OnboardingScaffold<Content: View, Footer: View>: View {
    var progress: Double
    var onBack: (() -> Void)?
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                content()
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 20)
            }

            footer()
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(SweatmatesColors.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                onBack?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .opacity(onBack == nil ? 0 : 1)
            }
            .buttonStyle(.plain)
            .disabled(onBack == nil)

            ProgressView(value: progress)
                .tint(SweatmatesColors.accentFlame)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

/// Standard single-button footer most steps use — a full-width flame-gradient CTA that can
/// be disabled until the step's input is valid.
struct OnboardingCTAButton: View {
    var title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView().tint(.white)
                }
                Text(title)
            }
            .font(SweatmatesTypography.headline(17, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isEnabled ? SweatmatesColors.flameGradient : LinearGradient(colors: [SweatmatesColors.cardSurfaceElevated, SweatmatesColors.cardSurfaceElevated], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .foregroundStyle(isEnabled ? .white : SweatmatesColors.textTertiary)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}
