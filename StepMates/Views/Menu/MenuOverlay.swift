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

                    // No .ignoresSafeArea() on content() itself — that was pulling its whole
                    // layout (including the profile row) up under the status bar / Dynamic
                    // Island, not just its background. MenuDrawerView bleeds its own
                    // background to the edges internally while keeping its content laid out
                    // normally; ignoring safe area up here on the GeometryReader instead just
                    // gives it the full physical size to work with.
                    content()
                        .frame(width: proxy.size.width * 0.82, height: proxy.size.height)
                        .shadow(color: .black.opacity(0.25), radius: 24, x: 8, y: 0)
                        .transition(.move(edge: .leading))
                }
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPresented)
    }
}
