import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    @AppStorage("biometricUnlockEnabled") private var biometricUnlockEnabled = true
    @State private var biometricLocked = true
    @State private var canUseBiometrics = false
    @State private var privacyShieldVisible = false
    private let biometricService = BiometricService()

    var body: some View {
        ZStack {
            rootContent

            if privacyShieldVisible {
                AppPrivacyShieldView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.smooth(duration: 0.3), value: authService.isAuthenticated)
        .animation(.smooth(duration: 0.3), value: authService.isLoading)
        .animation(.smooth(duration: 0.3), value: biometricLocked)
        .animation(.easeOut(duration: 0.18), value: privacyShieldVisible)
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if !isAuth {
                biometricLocked = true
            }
        }
        .onChange(of: scenePhase, handleScenePhaseChange)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            showPrivacyShield()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            hidePrivacyShield()
        }
        .task {
            canUseBiometrics = biometricService.canUseBiometrics()
            privacyShieldVisible = scenePhase != .active
        }
        .preferredColorScheme(colorScheme)
    }

    @ViewBuilder
    private var rootContent: some View {
        if authService.isLoading {
            LaunchScreen()
        } else if !authService.isAuthenticated {
            AuthScreen()
        } else if biometricLocked && biometricUnlockEnabled && canUseBiometrics {
            BiometricLockScreen(
                onUnlocked: { biometricLocked = false },
                onSignOut: { Task { try? await authService.signOut() } }
            )
        } else {
            MainTabView()
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // system
        }
    }

    private func handleScenePhaseChange(_ oldPhase: ScenePhase, _ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            canUseBiometrics = biometricService.canUseBiometrics()
            hidePrivacyShield()
        case .inactive:
            showPrivacyShield()
        case .background:
            biometricLocked = true
            showPrivacyShield()
        @unknown default:
            break
        }
    }

    private func showPrivacyShield() {
        privacyShieldVisible = true
    }

    private func hidePrivacyShield() {
        privacyShieldVisible = false
    }
}

// MARK: - Launch Screen

struct LaunchScreen: View {
    @State private var scale = 0.8
    @State private var opacity = 0.0

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            VStack(spacing: 16) {
                Image("AppLogoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .accessibilityHidden(true)
                    .scaleEffect(scale)

                Text("SubTrkr")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.textPrimary)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

private struct AppPrivacyShieldView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image("AppLogoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)

                (
                    Text("Sub")
                        .foregroundStyle(.white)
                    +
                    Text("Trkr")
                        .foregroundStyle(.brand)
                )
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
            }
            .padding(32)
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(AuthService.self) private var authService
    @State private var selectedTab = 0
    @State private var showAddSheet = false
    @State private var addItemType: ItemType = .subscription

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "square.grid.2x2.fill", value: 0) {
                DashboardView()
            }

            Tab("Subscriptions", systemImage: "arrow.triangle.2.circlepath", value: 1) {
                ItemListView(itemType: .subscription)
            }

            Tab("Bills", systemImage: "doc.text.fill", value: 2) {
                ItemListView(itemType: .bill)
            }

            Tab("Analytics", systemImage: "chart.bar.fill", value: 3) {
                AnalyticsView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: 4) {
                SettingsView()
            }
        }
        .tint(.brand)
    }
}
