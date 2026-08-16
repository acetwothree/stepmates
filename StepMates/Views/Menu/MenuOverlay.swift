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

                    content()
                        .frame(width: proxy.size.width * 0.82)
                        .frame(maxHeight: .infinity)
                        .ignoresSafeArea()
                        .shadow(color: .black.opacity(0.25), radius: 24, x: 8, y: 0)
                        .transition(.move(edge: .leading))
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPresented)
    }
}
