//
//  MenuOverlay.swift
//  StepMates
//
//  The scrim + slide-in mechanics for the hamburger drawer — a dimmed background that taps
//  to dismiss, with the drawer content sliding in from the leading edge. Pure presentation;
//  MenuDrawerView owns what's actually inside it.
//

import SwiftUI

struct MenuOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                if isPresented {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            isPresented = false
                        }

                    // content() deliberately stays inside the safe area here — MenuDrawerView
                    // bleeds its own background to the physical edges internally, but its
                    // layout (profile row, menu rows, etc.) needs proxy.size to reflect the
                    // safe-area-respecting height. Applying .ignoresSafeArea() up at this
                    // GeometryReader level (as this used to do) hands content() the full
                    // physical screen size instead, which is what was pushing the profile row
                    // up under the status bar / Dynamic Island despite its own top padding.
                    content()
                        .frame(width: proxy.size.width * 0.82, height: proxy.size.height)
                        .shadow(color: .black.opacity(0.25), radius: 24, x: 8, y: 0)
                        .transition(.move(edge: .leading))
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPresented)
    }
}
