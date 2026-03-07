import SwiftUI

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
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if !isAuth {
                biometricLocked = true
            }
        }
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // system
        }
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
