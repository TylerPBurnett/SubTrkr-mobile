# Face ID Quick Unlock — Design

**Date:** 2026-03-06

## Purpose

Allow users to unlock the app with Face ID on subsequent launches instead of re-entering credentials. Enabled by default after first successful login, togglable in Settings.

## How It Works

- After a successful Supabase sign-in, `@AppStorage("biometricUnlockEnabled")` defaults to `true`.
- On app launch, `ContentView` checks: valid Supabase session + biometric unlock enabled + device supports biometrics → show `BiometricLockScreen` and auto-prompt Face ID.
- If biometrics unavailable or disabled, skip straight to `MainTabView`.

## State Flow

```
App launches
  → isAuthenticated? No → AuthScreen
  → isAuthenticated? Yes
    → biometricUnlockEnabled && canUseBiometrics? No → MainTabView
    → Yes → BiometricLockScreen (auto-prompts Face ID)
      → Success → MainTabView
      → Fail/Cancel → stay on BiometricLockScreen
        → "Try Again" button → re-prompt with fresh LAContext
        → "Sign in with another account" → sign out → AuthScreen
```

## New Components

| Component | Type | Purpose |
|-----------|------|---------|
| `BiometricService` | Service (struct) | Thin wrapper around `LocalAuthentication` — `canUseBiometrics()` and `authenticate() async throws -> Bool` |
| `BiometricLockScreen` | View | Minimal screen: app logo, "Unlock with Face ID" button, "Sign in with another account" link |

## BiometricService

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
        context.localizedFallbackTitle = ""  // hide system "Enter Password" fallback
        context.localizedCancelTitle = "Cancel"
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock SubTrkr"
        )
    }
}
```

### Key API Decisions (from Apple docs)

- **`.deviceOwnerAuthenticationWithBiometrics`** (not `.deviceOwnerAuthentication`) — avoids automatic fallback to device passcode. We control the fallback (Supabase sign-in).
- **`localizedFallbackTitle = ""`** — hides the system "Enter Password" button since our fallback is the sign-in screen, not the device passcode.
- **Fresh `LAContext` per attempt** — `LAContext` is single-use after evaluation.
- **`async/await` API** — matches structured concurrency patterns used throughout the app.

## ContentView Changes

Add a `biometricLocked` state to the existing auth gate:

```swift
@AppStorage("biometricUnlockEnabled") private var biometricUnlockEnabled = true
@State private var biometricLocked = true

// In body:
if authService.isLoading {
    LaunchScreen()
} else if !authService.isAuthenticated {
    AuthScreen()
} else if biometricLocked && biometricUnlockEnabled && BiometricService().canUseBiometrics() {
    BiometricLockScreen(onUnlocked: { biometricLocked = false },
                        onSignOut: { Task { try? await authService.signOut() } })
} else {
    MainTabView()
}
```

## BiometricLockScreen

- Shows app logo + "Unlock with Face ID" button + "Sign in with another account" text button
- Auto-prompts Face ID in `.task` on appear
- On success → calls `onUnlocked`
- On failure → stays on screen, user can tap to retry or sign out
- Does NOT sign out on failure (preserves Supabase session for retry)

## Settings Integration

Add toggle in existing Settings screen, only visible when device supports biometrics:

```swift
if BiometricService().canUseBiometrics() {
    Toggle("Unlock with Face ID", isOn: $biometricUnlockEnabled)
        .onChange(of: biometricUnlockEnabled) { _, newValue in
            if newValue {
                Task {
                    let success = try? await BiometricService().authenticate()
                    if success != true { biometricUnlockEnabled = false }
                }
            }
        }
}
```

Toggling on requires a biometric check to confirm identity before enabling.

## Info.plist

Add required key:

```
NSFaceIDUsageDescription: "SubTrkr uses Face ID to quickly unlock your account."
```

Without this, the app crashes on first Face ID prompt.

## What We're NOT Building

- No PIN/passcode fallback — full sign-in screen is the fallback
- No background lock timer — only locks on fresh app launch, not every background return
- No Keychain credential storage — Supabase SDK manages its own session persistence
- No Liquid Glass styling — standard dark theme matching existing auth screens
