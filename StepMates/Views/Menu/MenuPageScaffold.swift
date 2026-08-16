//
//  MenuPageScaffold.swift
//  StepMates
//
//  Shared chrome for every page opened from the hamburger menu: a back chevron, a title, and
//  an optional trailing accessory (e.g. Weekly Rules' Edit button). These pages are always
//  presented as a full-screen cover directly over Home (never nested inside the menu's own
//  presentation), so dismiss() here — whether from the back button or a swipe-down — lands
//  back on Home every time, never on an intermediate menu screen.
//

import SwiftUI

struct MenuPageScaffold<Content: View, TrailingAccessory: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    @ViewBuilder var trailingAccessory: () -> TrailingAccessory

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content()
                    .padding(20)
            }
        }
        .background(SweatmatesColors.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(SweatmatesTypography.headline(17, weight: .bold))
                .foregroundStyle(SweatmatesColors.textPrimary)

            Spacer()

            trailingAccessory()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

extension MenuPageScaffold where TrailingAccessory == EmptyView {
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, content: content, trailingAccessory: { EmptyView() })
    }
}
