//
//  ProfilePhotoStepView.swift
//  StepMates
//
//  Picked photo is kept locally on-device for now (see OnboardingProfileStore) — it isn't
//  synced to the partner via CloudKit yet, so this is a local-only avatar until that lands.
//

import PhotosUI
import SwiftUI
import UIKit

struct ProfilePhotoStepView: View {
    @Bindable var state: OnboardingState
    var onContinue: () -> Void
    var onBack: () -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var showSkipConfirmation = false

    var body: some View {
        OnboardingScaffold(progress: OnboardingStep.profilePhoto.progress, onBack: onBack) {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Add a profile pic")
                        .font(SweatmatesTypography.title(24, weight: .heavy))
                        .foregroundStyle(SweatmatesColors.textPrimary)
                    Text("Only your partner will see it so make it silly")
                        .font(SweatmatesTypography.body(14))
                        .foregroundStyle(SweatmatesColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    photoPreview
                }
                .buttonStyle(.plain)
            }
        } footer: {
            OnboardingCTAButton(
                title: state.profileImageData == nil ? "Skip for now" : "Continue",
                action: handleContinueTapped
            )
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    state.profileImageData = data
                }
            }
        }
        .alert("Skip your photo? 🙈", isPresented: $showSkipConfirmation) {
            Button("Add a Photo", role: .cancel) {}
            Button("Skip Anyway", role: .destructive) { onContinue() }
        } message: {
            Text("Your partner won't get to see your face until you add one later.")
        }
    }

    private func handleContinueTapped() {
        if state.profileImageData == nil {
            showSkipConfirmation = true
        } else {
            onContinue()
        }
    }

    private var photoPreview: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(SweatmatesColors.cardSurfaceElevated)
            .frame(width: 220, height: 220)
            .overlay {
                if let data = state.profileImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(SweatmatesColors.textTertiary)
                }
            }
    }
}

#Preview {
    ProfilePhotoStepView(state: OnboardingState(), onContinue: {}, onBack: {})
}
