//
//  ShareAcceptanceHandler.swift
//  StepMates
//
//  SwiftUI has no native hook for CKShare acceptance — the system resolves a tapped invite
//  link into a CKShare.Metadata and delivers it directly to UIApplicationDelegate, not
//  through onOpenURL/onContinueUserActivity. This is the app's only AppDelegate, so it also
//  registers for and routes the silent remote-notification pushes CloudKit subscriptions rely on.
//

import CloudKit
import UIKit

@MainActor
final class ShareAcceptanceHandler: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task {
            try? await CloudKitSyncEngine.shared.acceptShare(from: cloudKitShareMetadata)
        }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        let handled = await CloudKitSyncEngine.shared.handleRemoteNotification(userInfo: userInfo)
        return handled ? .newData : .noData
    }
}
