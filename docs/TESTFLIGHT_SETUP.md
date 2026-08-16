# TestFlight CI/CD Setup

One-time setup to get `.github/workflows/testflight.yml` deploying to TestFlight on every
push to `main`. Everything here happens on developer.apple.com, appstoreconnect.apple.com,
and github.com — no Mac required at any point.

---

## 1. App ID & Capabilities (developer.apple.com)

1. Go to **Certificates, Identifiers & Profiles → Identifiers → +**.
2. Register a new **App ID**:
   - Type: **App**
   - Bundle ID: **Explicit** — `com.acetwothree.stepmates` (must match `PRODUCT_BUNDLE_IDENTIFIER` in [project.yml](../project.yml) exactly)
3. Under **Capabilities**, enable:
   - ☑ **HealthKit**
   - ☑ **iCloud** → check **CloudKit**
   - ☑ **Push Notifications**
   - ☑ **Background Modes** is *not* a portal capability — it's set purely in [Info.plist](../StepMates/Resources/Info.plist) (`processing`, `remote-notification`), already done.
4. Save.

## 2. CloudKit Container

1. Still in **Identifiers**, open the App ID you just created → **iCloud** row → **Configure**.
2. Choose **Create Container**, name it `iCloud.com.acetwothree.stepmates` (must exactly match
   `com.apple.developer.icloud-container-identifiers` in
   [StepMates.entitlements](../StepMates/Resources/StepMates.entitlements)).
3. Save. The container is created automatically the first time the app runs with a valid
   entitlement — no manual schema setup needed for this app (CloudKitSyncEngine creates the
   `StepMatesZone` record zone and record types at runtime).

## 3. Distribution Certificate (.p12)

You need a certificate + its private key, exported together as one `.p12` file. Since you
have no Mac, the cleanest path is generating the CSR and cert entirely via the portal:

1. **Certificates → +** → **Apple Distribution** → Continue.
2. You need a Certificate Signing Request (CSR). Options without a Mac:
   - Easiest: ask a friend/colleague with a Mac to open **Keychain Access → Certificate
     Assistant → Request a Certificate from a Certificate Authority**, save the `.certSigningRequest`
     file, and send it to you (they don't need your Apple ID — the CSR itself carries no secrets).
   - Alternative: generate a CSR + private key with OpenSSL on Windows:
     ```bash
     openssl req -new -newkey rsa:2048 -nodes -keyout distribution.key -out distribution.csr -subj "/CN=StepMates Distribution"
     ```
3. Upload the `.csr` to the portal, download the resulting `distribution.cer`.
4. Convert to `.p12` (needs the matching private key from step 2):
   ```bash
   openssl x509 -in distribution.cer -inform DER -out distribution.pem -outform PEM
   openssl pkcs12 -export -inkey distribution.key -in distribution.pem -out distribution.p12 -passout pass:YOUR_P12_PASSWORD
   ```
   (`openssl` ships with Git Bash on Windows, so this runs fine in the same terminal you use for git.)
5. Keep `distribution.p12` and the password you chose — you'll base64-encode the file for a
   GitHub secret below.

## 4. Provisioning Profile

1. **Profiles → +** → **App Store** (under Distribution) → Continue.
2. Select the `com.acetwothree.stepmates` App ID → Continue.
3. Select the distribution certificate from step 3 → Continue.
4. Name it (e.g. `StepMates AppStore`) → Generate → Download the `.mobileprovision` file.

## 5. App Store Connect record

1. In **App Store Connect → Apps → +**, create the app:
   - Bundle ID: `com.acetwothree.stepmates` (select the App ID from step 1)
   - SKU: anything unique, e.g. `stepmates-ios`
2. This is required before the first CI upload will succeed — `xcodebuild -exportArchive`
   with `destination: upload` uploads *to* an existing app record, it doesn't create one.

## 6. App Store Connect API Key (.p8)

1. **App Store Connect → Users and Access → Integrations → App Store Connect API**.
2. **+** to generate a new key. Role: **App Manager** (or **Admin**).
3. Download the `.p8` file **immediately** — Apple only lets you download it once.
4. Note the **Key ID** and **Issuer ID** shown on that page — you'll need both.

---

## 7. GitHub Secrets

Repo → **Settings → Secrets and variables → Actions → New repository secret**. Add all eight:

| Secret name | Value | Encoding |
|---|---|---|
| `DISTRIBUTION_CERTIFICATE_P12_BASE64` | the `.p12` from step 3 | base64 (see below) |
| `DISTRIBUTION_CERTIFICATE_PASSWORD` | the password you set exporting the `.p12` | plain text |
| `PROVISIONING_PROFILE_BASE64` | the `.mobileprovision` from step 4 | base64 (see below) |
| `APPLE_TEAM_ID` | your 10-character Team ID (top-right of the developer portal, or **Membership** page) | plain text |
| `KEYCHAIN_PASSWORD` | any password you make up — only protects the throwaway CI keychain for the duration of one job run | plain text |
| `APP_STORE_CONNECT_API_KEY_P8` | the full contents of the `.p8` file from step 6, pasted as-is | raw text, **not** base64 |
| `APPLE_KEY_ID` | Key ID from step 6 | plain text |
| `APPLE_ISSUER_ID` | Issuer ID from step 6 | plain text |

Note the two secrets beyond the ones you listed — `APPLE_TEAM_ID` and `KEYCHAIN_PASSWORD` —
are both required: `xcodebuild archive` needs a team ID for manual signing, and the CI
keychain needs *some* password to unlock (its value has no meaningful secrecy since the
keychain is destroyed at the end of every job run).

### Base64-encoding the two binary files

Git Bash:
```bash
base64 -w 0 distribution.p12 > distribution.p12.base64
base64 -w 0 StepMates_AppStore.mobileprovision > profile.base64
```

PowerShell:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("distribution.p12")) | Set-Content -NoNewline distribution.p12.base64
[Convert]::ToBase64String([IO.File]::ReadAllBytes("StepMates_AppStore.mobileprovision")) | Set-Content -NoNewline profile.base64
```

Open each `.base64` file and paste its single line of text as the secret value. Either way,
make sure the result is **one unbroken line** — some `base64` implementations wrap long
output across lines by default (Git Bash's `-w 0` and PowerShell's `-NoNewline` above both
avoid that), and a wrapped value can trip up the decode step in CI.

The `.p8` key, by contrast, is already plain text (starts with `-----BEGIN PRIVATE KEY-----`)
— paste its contents directly, unencoded.

---

## 8. First run

Push to `main`, or trigger manually from the **Actions** tab (**TestFlight Deploy → Run
workflow** — this repo's workflow supports `workflow_dispatch`). Watch the run in the
**Actions** tab; each step is logged in full since there's no local machine to reproduce
failures on.

### If the upload step fails

The **Build & archive** step runs before upload and its output — the `.xcarchive` — is
uploaded as a workflow artifact regardless of whether the later upload step succeeds (see
the `if: always()` upload-artifact step). If TestFlight upload fails for a reason you can't
resolve from the logs alone (an Apple-side hiccup, an ambiguous signing error), download that
artifact and hand it to *any* Mac — even one you don't own — Xcode's **Organizer** can open a
`.xcarchive` directly and re-run export/upload from the GUI without needing this project
checked out at all.

### Common failure causes

- **"No profiles for 'com.acetwothree.stepmates' were found"** — the bundle ID in the provisioning
  profile doesn't match `PRODUCT_BUNDLE_IDENTIFIER` in [project.yml](../project.yml), or the
  profile was generated before you enabled a capability (HealthKit/iCloud/Push) on the App ID
  — regenerate the profile after confirming all three capabilities are checked.
- **"The bundle version must be higher than the previously uploaded version"** — shouldn't
  happen; the workflow sets `CURRENT_PROJECT_VERSION` to the GitHub Actions run number on
  every build, which only ever increases. If you see this, check nothing overrode that value.
- **Entitlements mismatch on upload** — if you added a new capability to the app (edited
  `StepMates.entitlements`) without regenerating the provisioning profile on the portal, the
  profile won't grant it. Regenerate the profile any time entitlements change, and update the
  `PROVISIONING_PROFILE_BASE64` secret.
- **`aps-environment` says "development" in the committed entitlements file** — this is
  expected and fine. Xcode automatically rewrites it to `production` at archive time to match
  an App Store distribution profile; you don't need to change the source file.
