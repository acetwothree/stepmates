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

    /// `userDidAcceptCloudKitShareWith` above only fires when the app is already running in
    /// the background at the moment the share link is tapped. On a cold launch — which is
    /// every first-time invite, by definition — iOS instead hands the share metadata to
    /// *this* method as part of scene configuration, never calling the other one at all.
    /// Without this override every partner accepting their very first invite would silently
    /// get nothing: no callback, no error, just a fresh unpaired app.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shareMetadata = options.cloudKitShareMetadata {
            Task {
                try? await CloudKitSyncEngine.shared.acceptShare(from: shareMetadata)
            }
        }
        return UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        let handled = await CloudKitSyncEngine.shared.handleRemoteNotification(userInfo: userInfo)
        return handled ? .newData : .noData
    }
}
