# Face ID Quick Unlock — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow users to unlock the app with Face ID on subsequent launches instead of re-entering credentials.

**Architecture:** `BiometricService` (struct) wraps `LocalAuthentication`. `BiometricLockScreen` gates access between auth check and `MainTabView` in `ContentView`. Setting stored in `@AppStorage`, defaults to enabled.

**Tech Stack:** LocalAuthentication framework, SwiftUI, `@AppStorage`

---

### Task 1: Add NSFaceIDUsageDescription to Info.plist

**Files:**
- Modify: `SubTrkr/SubTrkr/Info.plist:57` (before closing `</dict>`)

**Step 1: Add the privacy key**

Add before the final `</dict></plist>`:

```xml
	<key>NSFaceIDUsageDescription</key>
	<string>SubTrkr uses Face ID to quickly unlock your account.</string>
```

**Step 2: Verify**

Open Info.plist and confirm the key appears. Build the project to ensure no plist parse errors:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Info.plist
git commit -m "feat(auth): add NSFaceIDUsageDescription to Info.plist"
```

---

### Task 2: Create BiometricService

**Files:**
- Create: `SubTrkr/SubTrkr/Services/BiometricService.swift`
- Modify: `SubTrkr/SubTrkr.xcodeproj/project.pbxproj` (add file to target)

**Step 1: Create the service file**

```swift
import LocalAuthentication

struct BiometricService {
    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error
        )
    }

    func authenticate() async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        context.localizedCancelTitle = "Cancel"
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock SubTrkr"
        )
    }
}
```

Key decisions:
- `.deviceOwnerAuthenticationWithBiometrics` — no automatic device passcode fallback
- `localizedFallbackTitle = ""` — hides system "Enter Password" button
- Fresh `LAContext` per call — required by Apple (single-use after evaluation)
- `async/await` — matches project's structured concurrency patterns

**Step 2: Add to Xcode project**

Add `BiometricService.swift` to the SubTrkr target in `project.pbxproj`:
- PBXFileReference entry
- PBXBuildFile entry in PBXSourcesBuildPhase
- Add to Services PBXGroup

**Step 3: Build to verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add SubTrkr/SubTrkr/Services/BiometricService.swift SubTrkr/SubTrkr.xcodeproj/project.pbxproj
git commit -m "feat(auth): add BiometricService wrapping LocalAuthentication"
```

---

### Task 3: Create BiometricLockScreen

**Files:**
- Create: `SubTrkr/SubTrkr/Views/Auth/BiometricLockScreen.swift`
- Modify: `SubTrkr/SubTrkr.xcodeproj/project.pbxproj` (add file to target)

**Step 1: Create the lock screen view**

```swift
import SwiftUI

struct BiometricLockScreen: View {
    let onUnlocked: () -> Void
    let onSignOut: () -> Void

    @State private var authFailed = false
    private let biometricService = BiometricService()

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App logo
                VStack(spacing: 12) {
                    Image("AppLogoMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)

                    Text("SubTrkr")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.textPrimary)
                }

                Spacer()

                // Unlock button
                VStack(spacing: 16) {
                    Button {
                        Task { await authenticate() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "faceid")
                                .font(.title2)
                            Text("Unlock with Face ID")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.brand)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    if authFailed {
                        Text("Authentication failed. Try again or sign in.")
                            .font(.caption)
                            .foregroundStyle(.accentRed)
                    }

                    Button("Sign in with another account") {
                        onSignOut()
                    }
                    .font(.caption)
                    .foregroundStyle(.brand)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.bottom, 60)
            }
        }
        .task {
            await authenticate()
        }
    }

    private func authenticate() async {
        do {
            let success = try await biometricService.authenticate()
            if success {
                authFailed = false
                onUnlocked()
            } else {
                authFailed = true
            }
        } catch {
            authFailed = true
        }
    }
}
```

Key patterns:
- Auto-prompts Face ID in `.task` on first appear
- Manual retry via "Unlock with Face ID" button
- Does NOT sign out on failure — preserves Supabase session
- Uses project color tokens (`.bgBase`, `.textPrimary`, `.brand`, `.accentRed`)
- `.buttonStyle(.plain)` consistent with AuthScreen pattern

**Step 2: Add to Xcode project**

Add `BiometricLockScreen.swift` to SubTrkr target in `project.pbxproj`:
- PBXFileReference entry
- PBXBuildFile entry in PBXSourcesBuildPhase
- Add to Views/Auth PBXGroup

**Step 3: Build to verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Auth/BiometricLockScreen.swift SubTrkr/SubTrkr.xcodeproj/project.pbxproj
git commit -m "feat(auth): add BiometricLockScreen view"
```

---

### Task 4: Wire BiometricLockScreen into ContentView

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/ContentView.swift:1-29`

**Step 1: Add biometric state and gate logic**

Update `ContentView` to add the biometric lock between auth check and `MainTabView`:

```swift
struct ContentView: View {
    @Environment(AuthService.self) private var authService
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    @AppStorage("biometricUnlockEnabled") private var biometricUnlockEnabled = true
    @State private var biometricLocked = true

    private let biometricService = BiometricService()

    var body: some View {
        Group {
            if authService.isLoading {
                LaunchScreen()
            } else if !authService.isAuthenticated {
                AuthScreen()
            } else if biometricLocked && biometricUnlockEnabled && biometricService.canUseBiometrics() {
                BiometricLockScreen(
                    onUnlocked: { biometricLocked = false },
                    onSignOut: { Task { try? await authService.signOut() } }
                )
            } else {
                MainTabView()
            }
        }
        .animation(.smooth(duration: 0.3), value: authService.isAuthenticated)
        .animation(.smooth(duration: 0.3), value: authService.isLoading)
        .animation(.smooth(duration: 0.3), value: biometricLocked)
        .preferredColorScheme(colorScheme)
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if !isAuth {
                biometricLocked = true
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
```

Key details:
- `biometricLocked` resets to `true` when user signs out (via `.onChange`), so next sign-in will re-prompt
- Order matters: check `!isAuthenticated` before biometric gate, so sign-out always shows `AuthScreen`
- `biometricService.canUseBiometrics()` checked in body — returns `false` on simulator or devices without Face ID, skipping the lock screen entirely

**Step 2: Build to verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Views/ContentView.swift
git commit -m "feat(auth): wire BiometricLockScreen into ContentView auth gate"
```

---

### Task 5: Add Face ID toggle to Settings

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Settings/SettingsView.swift:13` (add AppStorage)
- Modify: `SubTrkr/SubTrkr/Views/Settings/SettingsView.swift:96` (add section after Notifications)

**Step 1: Add the biometric toggle section**

Add `@AppStorage("biometricUnlockEnabled")` property to `SettingsView` and a new section after the Notifications section:

Add property at line 13 (after `appearanceMode`):
```swift
@AppStorage("biometricUnlockEnabled") private var biometricUnlockEnabled = true
```

Add new section after the Notifications `Section` (after line 96):
```swift
                // Security
                if BiometricService().canUseBiometrics() {
                    Section {
                        Toggle(isOn: $biometricUnlockEnabled) {
                            Label("Unlock with Face ID", systemImage: "faceid")
                                .foregroundStyle(.textPrimary)
                        }
                        .tint(.brand)
                        .onChange(of: biometricUnlockEnabled) { _, newValue in
                            if newValue {
                                Task {
                                    let success = try? await BiometricService().authenticate()
                                    if success != true {
                                        biometricUnlockEnabled = false
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Security")
                    } footer: {
                        Text("Require Face ID to unlock SubTrkr when you open the app.")
                    }
                }
```

Key details:
- Section only renders when device supports biometrics
- Toggling ON triggers a biometric check — prevents enabling on a borrowed device
- Toggling OFF requires no confirmation (user is already authenticated)
- `.tint(.brand)` matches existing toggle style
- Uses `faceid` SF Symbol for the label

**Step 2: Build to verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Settings/SettingsView.swift
git commit -m "feat(auth): add Face ID toggle to Settings"
```

---

### Task 6: Manual testing on device

**Testing checklist** (requires physical device with Face ID — simulator doesn't support biometrics):

1. **Fresh install, first login** — sign in with email/password → app goes straight to `MainTabView` (no Face ID prompt on simulator; on device, Face ID prompts)
2. **Subsequent launch (device)** — kill and reopen app → Face ID prompt appears → authenticate → `MainTabView` shown
3. **Face ID cancel** — tap Cancel on Face ID prompt → stays on lock screen → "Sign in with another account" visible
4. **Retry** — tap "Unlock with Face ID" → re-prompts Face ID
5. **Sign in with another account** — tap link → signs out → `AuthScreen` shown
6. **Settings toggle OFF** — go to Settings → Security → toggle off → kill and reopen → goes straight to `MainTabView`
7. **Settings toggle ON** — toggle on → Face ID prompt appears to confirm → if successful, toggle stays on
8. **No biometrics (simulator)** — biometric section hidden in Settings, lock screen skipped entirely

**Step 1: Install and test on simulator**

```bash
xcrun simctl install 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C \
  /tmp/SubTrkr-build/Build/Products/Debug-iphonesimulator/SubTrkr.app
xcrun simctl launch 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C com.subtrkr.app
```

On simulator: verify app loads normally (biometric gate is skipped since `canUseBiometrics()` returns `false`).

**Step 2: Test on physical device**

Connect device via Xcode, build and run. Walk through the checklist above.
