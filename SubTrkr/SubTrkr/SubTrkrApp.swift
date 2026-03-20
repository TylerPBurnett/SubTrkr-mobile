import SwiftUI
import Supabase

@main
struct SubTrkrApp: App {
    @State private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(authService)
        }
    }

    @ViewBuilder
    private var rootView: some View {
#if DEBUG
        if UITestHarness.isBillingFormEnabled {
            UITestBillingAnchorHarnessView()
        } else {
            ContentView()
                .onOpenURL { url in
                    Task {
                        try? await authService.handleOAuthCallback(url: url)
                    }
                }
                .task {
                    await authService.initialize()
                    await authService.observeAuthChanges()
                }
        }
#else
        ContentView()
            .onOpenURL { url in
                Task {
                    try? await authService.handleOAuthCallback(url: url)
                }
            }
            .task {
                await authService.initialize()
                await authService.observeAuthChanges()
            }
#endif
    }
}
