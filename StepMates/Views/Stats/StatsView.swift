//
//  StatsView.swift
//  StepMates
//
//  Detailed Stats: a Day/Week/Month trend chart for the current user (the only side CloudKit
//  can actually give history for — it only ever stores "today"), plus a real side-by-side
//  "Today" comparison across all five metrics for both partners.
//

import Charts
import SwiftUI

struct StatsView: View {
    var pair: UserPair
    var healthKitManager: HealthKitManager
    var partnerSnapshot: MemberSnapshot?

    @State private var viewModel = StatsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    rangePicker
                    metricPicker
                    trendCard
                    todayComparisonCard
                }
                .padding(20)
            }
            .background(SweatmatesColors.background.ignoresSafeArea())
            .navigationTitle("Detailed Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.refresh() }
            .onChange(of: viewModel.range) {
                Task { await viewModel.refresh() }
            }
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $viewModel.range) {
            ForEach(StatsRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HealthMetricKind.allCases) { metric in
                    metricChip(metric)
                }
            }
        }
    }

    private func metricChip(_ metric: HealthMetricKind) -> some View {
        let isSelected = viewModel.selectedMetric == metric
        return Button {
            HapticService.shared.lightTap()
            viewModel.selectedMetric = metric
        } label: {
            Label(metric.displayName, systemImage: metric.systemImage)
                .font(SweatmatesTypography.caption(13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(isSelected ? SweatmatesColors.accentFlame : SweatmatesColors.cardSurfaceElevated))
                .foregroundStyle(isSelected ? .white : SweatmatesColors.textOnCard)
        }
        .buttonStyle(.plain)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Trend").microLabel()

            if viewModel.range == .day {
                if viewModel.selectedMetric == .steps {
                    hourlyStepsChart
                } else {
                    // HealthKit gives us an hour-by-hour breakdown for steps only — the other
                    // metrics' "today" totals are already covered in the comparison card below.
                    Text("Switch to Week or Month to see a trend for \(viewModel.selectedMetric.displayName.lowercased()).")
                        .font(SweatmatesTypography.caption(13))
                        .foregroundStyle(SweatmatesColors.textOnCardSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }
            } else {
                dailyBarChart
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(SweatmatesColors.cardSurface))
    }

    private var hourlyStepsChart: some View {
        Chart(healthKitManager.todayHourlyTrend) { point in
            LineMark(
                x: .value("Hour", point.hour),
                y: .value("Steps", point.cumulativeSteps)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(SweatmatesColors.accentFlame)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text("\(hour)h")
                    }
                }
            }
        }
        .frame(height: 180)
    }

    private var dailyBarChart: some View {
        let points = viewModel.series(for: viewModel.selectedMetric)
        return Chart(points) { point in
            BarMark(
                x: .value("Day", point.date, unit: .day),
                y: .value(viewModel.selectedMetric.displayName, point.value)
            )
            .foregroundStyle(SweatmatesColors.accentFlame.gradient)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: viewModel.range == .month ? 7 : 1)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 180)
    }

    private var todayComparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today · You vs \(pair.partner.displayName)").microLabel()

            VStack(spacing: 14) {
                ForEach(HealthMetricKind.allCases) { metric in
                    comparisonRow(metric)
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(SweatmatesColors.cardSurface))
    }

    private func comparisonRow(_ metric: HealthMetricKind) -> some View {
        HStack {
            Label(metric.displayName, systemImage: metric.systemImage)
                .font(SweatmatesTypography.body(13, weight: .semibold))
                .foregroundStyle(SweatmatesColors.textOnCard)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(metric.format(myValue(for: metric)))
                    .font(SweatmatesTypography.body(13, weight: .bold))
                    .foregroundStyle(SweatmatesColors.textOnCard)
                Text("You")
                    .font(SweatmatesTypography.caption(10))
                    .foregroundStyle(SweatmatesColors.textOnCardSecondary)
            }
            .frame(width: 76, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 2) {
                Text(partnerValueText(for: metric))
                    .font(SweatmatesTypography.body(13, weight: .bold))
                    .foregroundStyle(SweatmatesColors.textOnCard)
                Text(pair.partner.displayName)
                    .font(SweatmatesTypography.caption(10))
                    .foregroundStyle(SweatmatesColors.textOnCardSecondary)
                    .lineLimit(1)
            }
            .frame(width: 76, alignment: .trailing)
        }
    }

    private func myValue(for metric: HealthMetricKind) -> Double {
        switch metric {
        case .steps: return Double(healthKitManager.todaySteps)
        case .distance: return healthKitManager.todayDistanceMeters
        case .activeCalories: return healthKitManager.todayActiveCalories
        case .flightsClimbed: return Double(healthKitManager.todayFlightsClimbed)
        case .activeMinutes: return Double(healthKitManager.todayActiveMinutes)
        }
    }

    /// "—" rather than a fabricated 0 when the partner hasn't synced anything yet — a real
    /// absence of data reads differently from a real zero.
    private func partnerValueText(for metric: HealthMetricKind) -> String {
        guard let partnerSnapshot else { return "—" }
        let value: Double
        switch metric {
        case .steps: value = Double(partnerSnapshot.currentSteps)
        case .distance: value = partnerSnapshot.todayDistance
        case .activeCalories: value = partnerSnapshot.todayActiveCalories
        case .flightsClimbed: value = Double(partnerSnapshot.todayFlightsClimbed)
        case .activeMinutes: value = Double(partnerSnapshot.todayActiveMinutes)
        }
        return metric.format(value)
    }
}

#Preview("Detailed Stats") {
    StatsView(pair: .mockConnected, healthKitManager: .shared, partnerSnapshot: nil)
}
