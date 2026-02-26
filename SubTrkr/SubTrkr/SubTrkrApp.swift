import SwiftUI
import Supabase

@main
struct SubTrkrApp: App {
    @State private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
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
    }
}
