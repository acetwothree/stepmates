# StepMates

A 1-to-1 native iOS clone of Sweatmates' UI/UX and social mechanics, adapted for
passive Apple HealthKit steps instead of manual workout/photo logging.

## Requirements

- Xcode 16+, iOS 17+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Setup

```bash
xcodegen generate
open StepMates.xcodeproj
```

## Project layout

- `StepMates/App` — app entry, root navigation, CKShare-acceptance delegate
- `StepMates/Models` — `UserPair`, `Wager`, `StepDay`, `WeeklyRecap`, `CloudSync` and mock data
- `StepMates/DesignSystem` — colors, typography (SF Pro Rounded)
- `StepMates/Services` — `HapticService`, `HealthKitManager`, `CloudKitSyncEngine`
- `StepMates/ViewModels` — `HomeViewModel`
- `StepMates/Views` — Home, Onboarding, Wagers, shared Components

Every model ships with static `.mock*` data so views render immediately in the SwiftUI
canvas. HealthKit (steps) and CloudKit (pairing, sync) are both live — see
[docs/TESTFLIGHT_SETUP.md](docs/TESTFLIGHT_SETUP.md) for the entitlements each requires.

## CI/CD

`.github/workflows/testflight.yml` builds, signs, and uploads to TestFlight on every push to
`main` (or manually via `workflow_dispatch`) — no local Mac required. One-time setup
(certificates, provisioning profile, App Store Connect API key, GitHub secrets) is documented
step-by-step in [docs/TESTFLIGHT_SETUP.md](docs/TESTFLIGHT_SETUP.md).
