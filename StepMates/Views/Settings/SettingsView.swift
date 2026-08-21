//
//  SettingsView.swift
//  StepMates
//
//  Full Settings screen wired from Home's gear icon: profile, units, notifications, partner
//  link status, HealthKit status, about, and a Developer/Admin debug section. The debug
//  section stays visible in every build (not gated behind #if DEBUG) since TestFlight is the
//  only way this app ever gets tested — see project README/CI.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    var viewModel: HomeViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var dailyStepGoal: Int = 10_000
    @State private var distanceUnit: DistanceUnit = UnitPreferences.distanceUnit

    @AppStorage("com.stepmates.settings.notifyNudges") private var notifyNudges = true
    @AppStorage("com.stepmates.settings.notifyGoalHit") private var notifyGoalHit = true
    @AppStorage("com.stepmates.settings.notifyWeeklyRecap") private var notifyWeeklyRecap = true

    @State private var isSimulatingPartner = false
    @State private var isClearingCloudState = false
    @State private var showUnlinkConfirmation = false
    @State private var showClearCloudConfirmation = false

    private let goalOptions = Array(stride(from: 5_000, through: 25_000, by: 500))

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                unitsSection
                notificationsSection
                partnerSection
                healthKitSection
                aboutSection
                debugSection
            }
            .scrollContentBackground(.hidden)
            .background(SweatmatesColors.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                displayName = viewModel.pair.currentUser.displayName
                dailyStepGoal = viewModel.pair.currentUser.dailyStepGoal
            }
            .onDisappear {
                saveDisplayNameIfChanged()
            }
        }
    }

    // MARK: Profile

    private var profileSection: some View {
        Section("Profile") {
            TextField("Display Name", text: $displayName)
                .onSubmit(saveDisplayNameIfChanged)

            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Step Goal")
                    .font(SweatmatesTypography.caption(12))
                    .foregroundStyle(SweatmatesColors.textSecondary)
                // A custom binding rather than `.onChange(of: dailyStepGoal)` — onChange
                // would also fire from onAppear's initial sync (not just real picker
                // interaction), triggering a spurious CloudKit write every time Settings
                // opens. This binding's setter only runs when the user actually spins the
                // wheel.
                Picker("Daily Step Goal", selection: Binding(
                    get: { dailyStepGoal },
                    set: { newValue in
                        dailyStepGoal = newValue
                        saveDailyGoal(newValue)
                    }
                )) {
                    ForEach(goalOptions, id: \.self) { steps in
                        Text("\(steps.formatted()) steps").tag(steps)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 140)
            }
        }
    }

    private func saveDailyGoal(_ newValue: Int) {
        Task { await viewModel.cloudKitSyncEngine.updateMyDailyGoal(newValue) }
        var profile = OnboardingProfileStore.load() ?? OnboardingProfile(firstName: displayName, dailyStepGoal: newValue)
        profile.dailyStepGoal = newValue
        OnboardingProfileStore.save(profile)
    }

    private func saveDisplayNameIfChanged() {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != viewModel.pair.currentUser.displayName else { return }
        viewModel.pair.currentUser.displayName = trimmed
        var profile = OnboardingProfileStore.load() ?? OnboardingProfile(firstName: trimmed, dailyStepGoal: dailyStepGoal)
        profile.firstName = trimmed
        OnboardingProfileStore.save(profile)
        Task { await viewModel.cloudKitSyncEngine.updateMyDisplayName(trimmed) }
    }

    // MARK: Units

    private var unitsSection: some View {
        Section("Units") {
            Picker("Distance", selection: $distanceUnit) {
                ForEach(DistanceUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .onChange(of: distanceUnit) { _, newValue in
                UnitPreferences.distanceUnit = newValue
            }
        }
    }

    // MARK: Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Partner Nudges", isOn: $notifyNudges)
            Toggle("Daily Goal Reached", isOn: $notifyGoalHit)
            Toggle("Weekly Recap", isOn: $notifyWeeklyRecap)
        }
    }

    // MARK: Partner

    private var partnerSection: some View {
        Section("Partner") {
            LabeledContent("Status", value: partnerStatusText)

            if viewModel.cloudKitSyncEngine.pairingState == .paired {
                Button("Unlink Partner", role: .destructive) {
                    showUnlinkConfirmation = true
                }
                .confirmationDialog(
                    "Unlink from \(viewModel.pair.partner.displayName)?",
                    isPresented: $showUnlinkConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Unlink Partner", role: .destructive) {
                        viewModel.cloudKitSyncEngine.unlinkPartnerLocally()
                    }
                } message: {
                    Text("This device will forget the pairing. Your partner keeps their own copy until they unlink too.")
                }
            }
        }
    }

    private var partnerStatusText: String {
        switch viewModel.cloudKitSyncEngine.pairingState {
        case .unpaired: return "Not paired"
        case .pairing: return "Pairing…"
        case .paired: return viewModel.cloudKitSyncEngine.partnerSnapshot != nil ? "Connected" : "Waiting for partner"
        }
    }

    // MARK: HealthKit

    private var healthKitSection: some View {
        Section("Apple Health") {
            LabeledContent("Sync Status", value: healthKitStatusText)
            if viewModel.healthKitManager.authorizationStatus == .denied {
                Button("Open Settings", action: openSystemSettings)
            }
        }
    }

    private var healthKitStatusText: String {
        switch viewModel.healthKitManager.authorizationStatus {
        case .notDetermined: return "Not Requested"
        case .authorized: return "Connected"
        case .denied: return "Access Denied"
        case .unavailable: return "Unavailable"
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Privacy Policy", value: "Coming soon")
            LabeledContent("Terms of Service", value: "Coming soon")
            LabeledContent("Version", value: appVersionText)
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: Developer / Admin debug

    private var debugSection: some View {
        Section {
            Button("Reset Onboarding") {
                OnboardingProfileStore.clear()
                dismiss()
                AppFlowCoordinator.shared.isOnboarding = true
            }

            Button("Request HealthKit Permissions Again") {
                Task { await viewModel.healthKitManager.requestAuthorization() }
            }

            Button {
                simulatePartnerSteps()
            } label: {
                HStack {
                    Text("Simulate Partner Steps")
                    if isSimulatingPartner {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isSimulatingPartner || viewModel.cloudKitSyncEngine.pairingState != .paired)

            Button("Unlink Partner & Clear Cloud State", role: .destructive) {
                showClearCloudConfirmation = true
            }
            .disabled(isClearingCloudState || viewModel.cloudKitSyncEngine.pairingState == .unpaired)
            .confirmationDialog(
                "Permanently delete the shared room?",
                isPresented: $showClearCloudConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    clearCloudState()
                }
            } message: {
                Text("This deletes the shared CloudKit room for both you and your partner. This can't be undone.")
            }
            if let lastError = viewModel.cloudKitSyncEngine.lastError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last CloudKit Error")
                        .font(SweatmatesTypography.caption(12, weight: .semibold))
                        .foregroundStyle(SweatmatesColors.textSecondary)
                    Text(lastError.localizedDescription)
                        .font(SweatmatesTypography.caption(12))
                        .foregroundStyle(SweatmatesColors.danger)
                }
            }
        } header: {
            Text("Developer / Admin")
        } footer: {
            Text("Debug tools for testing without a second device.")
        }
    }

    private func simulatePartnerSteps() {
        isSimulatingPartner = true
        Task {
            await viewModel.cloudKitSyncEngine.debugSimulatePartnerSteps()
            isSimulatingPartner = false
        }
    }

    private func clearCloudState() {
        isClearingCloudState = true
        Task {
            await viewModel.cloudKitSyncEngine.debugClearCloudState()
            isClearingCloudState = false
        }
    }
}

#Preview {
    SettingsView(viewModel: HomeViewModel())
}
