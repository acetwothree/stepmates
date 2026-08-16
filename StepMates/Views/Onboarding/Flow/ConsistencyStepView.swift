//
//  ConsistencyStepView.swift
//  StepMates
//
//  "StepMates creates long-term consistency" — the with/without comparison chart, adapted
//  from Sweatmates' workout-streak framing to a step-streak one. Both lines start flat and
//  animate apart on appear (orange rising, grey falling), with an explicit legend since
//  Swift Charts' auto-legend was hidden for layout reasons.
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

    @State private var hasAnimated = false

    private var data: [ConsistencyPoint] {
        let withStepMates = hasAnimated ? [68.0, 78.0, 92.0] : [68.0, 68.0, 68.0]
        let willpowerAlone = hasAnimated ? [68.0, 38.0, 16.0] : [68.0, 68.0, 68.0]
        return (0...2).flatMap { month in
            [
                ConsistencyPoint(series: "With StepMates", month: month, value: withStepMates[month]),
                ConsistencyPoint(series: "Willpower alone", month: month, value: willpowerAlone[month]),
            ]
        }
    }

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
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).delay(0.3)) {
                hasAnimated = true
            }
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your consistency")
                .font(SweatmatesTypography.headline(16, weight: .bold))
                .foregroundStyle(SweatmatesColors.textOnCard)

            legend

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
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...100)
            .frame(height: 180)

            // Manual labels instead of AxisMarks at the plot's exact left/right edges — Swift
            // Charts clips or drops axis value labels positioned right at the boundary, which
            // was silently swallowing "Month 3" on the right. Plain text below the chart has
            // no such edge case.
            HStack {
                Text("Month 1")
                Spacer()
                Text("Month 3")
            }
            .font(SweatmatesTypography.caption(11))
            .foregroundStyle(SweatmatesColors.textOnCardSecondary)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(SweatmatesColors.cardSurface))
    }

    private var legend: some View {
        HStack(spacing: 18) {
            legendItem(color: SweatmatesColors.accentFlame, label: "With StepMates")
            legendItem(color: SweatmatesColors.textTertiary, label: "Willpower alone")
            Spacer()
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(SweatmatesTypography.caption(12, weight: .semibold))
                .foregroundStyle(SweatmatesColors.textOnCardSecondary)
        }
    }
}

#Preview {
    ConsistencyStepView(onContinue: {}, onBack: {})
}
