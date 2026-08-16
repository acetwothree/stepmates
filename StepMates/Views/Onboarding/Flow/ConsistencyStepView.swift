//
//  ConsistencyStepView.swift
//  StepMates
//
//  "StepMates creates long-term consistency" — the with/without comparison chart, adapted
//  from Sweatmates' workout-streak framing to a step-streak one.
//

import Charts
import SwiftUI

private struct ConsistencyPoint: Identifiable {
    var id: String { "\(series)-\(month)" }
    var series: String
    var month: Int
    var value: Double
}

struct ConsistencyStepView: View {
    var onContinue: () -> Void
    var onBack: () -> Void

    private let data: [ConsistencyPoint] = [
        ConsistencyPoint(series: "With StepMates", month: 0, value: 68),
        ConsistencyPoint(series: "With StepMates", month: 1, value: 78),
        ConsistencyPoint(series: "With StepMates", month: 2, value: 92),
        ConsistencyPoint(series: "Willpower alone", month: 0, value: 68),
        ConsistencyPoint(series: "Willpower alone", month: 1, value: 38),
        ConsistencyPoint(series: "Willpower alone", month: 2, value: 16),
    ]

    var body: some View {
        OnboardingScaffold(progress: OnboardingStep.consistency.progress, onBack: onBack) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("StepMates creates")
                        .font(SweatmatesTypography.title(26, weight: .heavy))
                        .foregroundStyle(SweatmatesColors.textPrimary)
                    Text("long-term consistency")
                        .font(SweatmatesTypography.title(26, weight: .heavy))
                        .foregroundStyle(SweatmatesColors.accentFlame)
                }

                chartCard

                VStack(spacing: 4) {
                    Text("90% of couples")
                        .font(SweatmatesTypography.headline(20, weight: .bold))
                        .foregroundStyle(SweatmatesColors.accentFlame)
                    Text("using StepMates maintain their step streak after 3 months.")
                        .font(SweatmatesTypography.body(14))
                        .foregroundStyle(SweatmatesColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        } footer: {
            OnboardingCTAButton(title: "See how it works", action: onContinue)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your consistency")
                .font(SweatmatesTypography.headline(16, weight: .bold))
                .foregroundStyle(SweatmatesColors.textOnCard)

            Chart(data) { point in
                LineMark(
                    x: .value("Month", point.month),
                    y: .value("Consistency", point.value)
                )
                .foregroundStyle(by: .value("Series", point.series))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            .chartForegroundStyleScale([
                "With StepMates": SweatmatesColors.accentFlame,
                "Willpower alone": SweatmatesColors.textTertiary,
            ])
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: [0, 2]) { value in
                    AxisValueLabel {
                        if let month = value.as(Int.self) {
                            Text(month == 0 ? "Month 1" : "Month 3")
                                .font(SweatmatesTypography.caption(11))
                                .foregroundStyle(SweatmatesColors.textOnCardSecondary)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 200)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(SweatmatesColors.cardSurface))
    }
}

#Preview {
    ConsistencyStepView(onContinue: {}, onBack: {})
}
