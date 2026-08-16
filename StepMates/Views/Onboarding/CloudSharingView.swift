//
//  CloudSharingView.swift
//  StepMates
//
//  Thin SwiftUI wrapper around UICloudSharingController — the native share sheet that lets
//  a user text a CKShare invite link via iMessage (or AirDrop, Mail, etc.) in one tap.
//

import CloudKit
import SwiftUI
import UIKit

struct CloudSharingView: UIViewControllerRepresentable {
    var share: CKShare
    var container: CKContainer
    var onDismiss: () -> Void = {}

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        coordinator.onDismiss = onDismiss
        return coordinator
    }

    @MainActor
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        var onDismiss: () -> Void = {}

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "StepMates"
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            // The controller shows its own failure alert; nothing further to surface here.
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onDismiss()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onDismiss()
        }
    }
}
