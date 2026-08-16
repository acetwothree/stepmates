//
//  StepMatesApp.swift
//  StepMates
//

import SwiftUI

@main
struct StepMatesApp: App {
    @UIApplicationDelegateAdaptor(ShareAcceptanceHandler.self) private var shareAcceptanceHandler

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
