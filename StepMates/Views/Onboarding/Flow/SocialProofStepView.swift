//
//  SocialProofStepView.swift
//  StepMates
//
//  "See each other show up" — social proof before asking for HealthKit/partner commitments.
//  Uses a generic placeholder avatar rather than a fabricated "real" partner photo.
//

import SwiftUI

struct SocialProofStepView: View {
    var onContinue: () -> Void
    var onBack: () -> Void

    var body: some View {
        OnboardingScaffold(progress: OnboardingStep.socialProof.progress, onBack: onBack) {
            VStack(spacing: 28) {
                partnerCardStack

                weekCard

                VStack(spacing: 8) {
                    Text("See each other show up")
                        .font(SweatmatesTypography.title(24, weight: .heavy))
                        .foregroundStyle(SweatmatesColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Consistency gets easier when you're not alone.")
                        .font(SweatmatesTypography.body(15))
                        .foregroundStyle(SweatmatesColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        } footer: {
            OnboardingCTAButton(title: "Continue", action: onContinue)
        }
    }

    private var partnerCardStack: some View {
        ZStack {
            ForEach([8.0, 4.0], id: \.self) { offset in
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(SweatmatesColors.cardSurfaceElevated)
                    .frame(width: 220, height: 260)
                    .rotationEffect(.degrees(offset))
            }

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(SweatmatesColors.limeGradient)
                .frame(width: 220, height: 260)
                .overlay(
                    VStack {
                        Spacer()
                        Image(systemName: "figure.walk.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        HStack {
                            Text("Partner")
                                .font(SweatmatesTypography.caption(11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(.black.opacity(0.35)))
                            Spacer()
                        }
                        .padding(12)
                    }
                )
        }
        .padding(.vertical, 12)
    }

    private var weekCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("This Week")
                    .font(SweatmatesTypography.headline(16, weight: .bold))
                    .foregroundStyle(SweatmatesColors.textOnCard)
                Spacer()
                Label("3-week streak", systemImage: "flame.fill")
                    .font(SweatmatesTypography.caption(11, weight: .bold))
                    .foregroundStyle(SweatmatesColors.accentFlame)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(SweatmatesColors.accentFlame.opacity(0.14)))
            }

            progressRow(label: "You", initials: "ME", tint: .blue, fraction: 1.0)
            progressRow(label: "Partner", initials: "PA", tint: SweatmatesColors.accentFlame, fraction: 1.0)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(SweatmatesColors.cardSurface))
    }

    private func progressRow(label: String, initials: String, tint: Color, fraction: Double) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tint)
                .frame(width: 34, height: 34)
                .overlay(Text(initials).font(SweatmatesTypography.caption(11, weight: .bold)).foregroundStyle(.white))

            Text(label)
                .font(SweatmatesTypography.body(14, weight: .semibold))
                .foregroundStyle(SweatmatesColors.textOnCard)

            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(SweatmatesColors.divider)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(SweatmatesColors.accentLimeDeep)
                            .frame(width: geometry.size.width * fraction)
                    }
            }
            .frame(height: 8)

            Text("3/3")
                .font(SweatmatesTypography.caption(12, weight: .bold))
                .foregroundStyle(SweatmatesColors.accentLimeDeep)
        }
    }
}

#Preview {
    SocialProofStepView(onContinue: {}, onBack: {})
}
