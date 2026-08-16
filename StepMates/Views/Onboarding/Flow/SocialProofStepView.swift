//
//  SocialProofStepView.swift
//  StepMates
//
//  "See each other show up" — social proof before asking for HealthKit/partner commitments.
//  Uses a stylized illustrated "selfie" (OnboardingPartnerSelfie) rather than a fabricated
//  "real" partner photo. Both step bars count up from 0 on appear.
//

import SwiftUI

struct SocialProofStepView: View {
    var onContinue: () -> Void
    var onBack: () -> Void

    @State private var animatedSteps: Double = 0
    private let targetSteps: Double = 70_000

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
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).delay(0.2)) {
                animatedSteps = targetSteps
            }
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

            Image("OnboardingPartnerSelfie")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 220, height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Text("Partner")
                        .font(SweatmatesTypography.caption(11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.black.opacity(0.35)))
                        .padding(12)
                }
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

            progressRow(label: "You", initials: "ME", tint: .blue)
            progressRow(label: "Partner", initials: "PA", tint: SweatmatesColors.accentFlame)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(SweatmatesColors.cardSurface))
    }

    private func progressRow(label: String, initials: String, tint: Color) -> some View {
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
                            .frame(width: geometry.size.width * (animatedSteps / targetSteps))
                    }
            }
            .frame(height: 8)

            AnimatableStepCountText(value: animatedSteps)
                .font(SweatmatesTypography.caption(11, weight: .bold))
                .foregroundStyle(SweatmatesColors.accentLimeDeep)
                .frame(width: 58, alignment: .trailing)
        }
    }
}

/// Text content doesn't interpolate under `withAnimation` the way geometry does — this is
/// the standard `Animatable` trick to get a genuine frame-by-frame counting effect instead
/// of a snap or a digit-roll transition.
private struct AnimatableStepCountText: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Int(value).formatted())
    }
}

#Preview {
    SocialProofStepView(onContinue: {}, onBack: {})
}
