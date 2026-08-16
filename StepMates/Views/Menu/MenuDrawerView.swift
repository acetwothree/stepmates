//
//  MenuDrawerView.swift
//  StepMates
//
//  The hamburger popout menu content — profile row, page list, quick actions, and support,
//  styled after Sweatmates' drawer. Lives inside MenuOverlay, which handles the slide-in
//  animation and scrim; this view is just the panel's content.
//

import SwiftUI

struct MenuDrawerView: View {
    var viewModel: HomeViewModel
    var onSelectWeeklyRules: () -> Void
    var onSelectWagerBalance: () -> Void
    var onSelectPartner: () -> Void
    var onSelectHistory: () -> Void
    var onSelectSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            profileRow
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 20)

            Divider().overlay(SweatmatesColors.divider)

            VStack(spacing: 4) {
                menuRow(icon: "list.bullet.rectangle.fill", title: "Weekly Rules", badge: "NEW", action: onSelectWeeklyRules)
                menuRow(icon: "scalemass.fill", title: "Wager Balance", action: onSelectWagerBalance)
                menuRow(icon: "heart.fill", title: "Partner", action: onSelectPartner)
                menuRow(icon: "calendar", title: "History", action: onSelectHistory)
                menuRow(icon: "gearshape.fill", title: "Settings", action: onSelectSettings)
            }
            .padding(.top, 12)

            Text("ACTIONS")
                .font(SweatmatesTypography.microLabel(12))
                .foregroundStyle(SweatmatesColors.textTertiary)
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 12)

            actionCard(
                icon: "bell.fill",
                title: "Nudge Partner",
                subtitle: "Send a motivational push",
                tint: SweatmatesColors.accentFlame
            ) {
                viewModel.sendNudge()
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 20)

            Divider().overlay(SweatmatesColors.divider)
            Button {
                // Support isn't wired to anything yet — a placeholder tap target for now.
            } label: {
                Label("Support", systemImage: "questionmark.circle.fill")
                    .font(SweatmatesTypography.body(17, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // The background bleeds to the physical edges (including under the status bar /
        // Dynamic Island) so there's no gap showing the app behind the drawer, but the
        // content stack above it is NOT told to ignore safe areas — it lays out normally,
        // so the profile row starts below the status bar instead of colliding with it.
        .background(SweatmatesColors.background.ignoresSafeArea())
    }

    private var profileRow: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(SweatmatesColors.cardSurfaceElevated)
                    .frame(width: 58, height: 58)
                    .overlay(
                        Text(initial)
                            .font(SweatmatesTypography.headline(22, weight: .bold))
                            .foregroundStyle(SweatmatesColors.textOnCard)
                    )

                if viewModel.cloudKitSyncEngine.partnerSnapshot == nil {
                    ZStack {
                        Circle().fill(SweatmatesColors.accentFlame).frame(width: 24, height: 24)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay(Circle().stroke(SweatmatesColors.background, lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.pair.currentUser.displayName)
                    .font(SweatmatesTypography.headline(19, weight: .bold))
                    .foregroundStyle(SweatmatesColors.textPrimary)
                Text(subtitle)
                    .font(SweatmatesTypography.caption(14))
                    .foregroundStyle(SweatmatesColors.textSecondary)
            }

            Spacer()
        }
    }

    private var initial: String {
        String(viewModel.pair.currentUser.displayName.prefix(1)).uppercased()
    }

    private var subtitle: String {
        viewModel.cloudKitSyncEngine.partnerSnapshot == nil
            ? "Tap to invite your partner"
            : "Paired with \(viewModel.pair.partner.displayName)"
    }

    private func menuRow(icon: String, title: String, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.accentFlame)
                    .frame(width: 28)

                Text(title)
                    .font(SweatmatesTypography.body(18, weight: .semibold))
                    .foregroundStyle(SweatmatesColors.textPrimary)

                if let badge {
                    Text(badge)
                        .font(SweatmatesTypography.microLabel(10))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(SweatmatesColors.accentFlame))
                        .foregroundStyle(.white)
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func actionCard(icon: String, title: String, subtitle: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.15)).frame(width: 40, height: 40)
                    Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    // textOnCard/textOnCardSecondary, not textPrimary/textSecondary — this
                    // card's own background (cardSurface) stays light cream in both app
                    // themes, but textPrimary is adaptive and flips to near-white in dark
                    // mode, which was rendering as washed-out white-on-cream text.
                    Text(title)
                        .font(SweatmatesTypography.body(15, weight: .bold))
                        .foregroundStyle(SweatmatesColors.textOnCard)
                    Text(subtitle)
                        .font(SweatmatesTypography.caption(13))
                        .foregroundStyle(SweatmatesColors.textOnCardSecondary)
                }
                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SweatmatesColors.cardSurface))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MenuDrawerView(
        viewModel: HomeViewModel(),
        onSelectWeeklyRules: {},
        onSelectWagerBalance: {},
        onSelectPartner: {},
        onSelectHistory: {},
        onSelectSettings: {}
    )
}
