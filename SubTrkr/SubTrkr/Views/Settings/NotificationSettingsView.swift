import SwiftUI

struct NotificationSettingsView: View {
    @State private var notificationsEnabled = false
    @State private var defaultReminderDays = 3
    @State private var hasPermission = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Enable Notifications", systemImage: "bell.fill")
                }
                .tint(.brand)
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        Task {
                            let granted = await NotificationService().requestPermission()
                            hasPermission = granted
                            if !granted {
                                notificationsEnabled = false
                            }
                        }
                    }
                }
            } header: {
                Text("Local Notifications")
            } footer: {
                Text("Get notified before your subscriptions and bills renew.")
            }

            if notificationsEnabled {
                Section("Default Reminder") {
                    Picker("Remind me", selection: $defaultReminderDays) {
                        Text("1 day before").tag(1)
                        Text("3 days before").tag(3)
                        Text("7 days before").tag(7)
                        Text("14 days before").tag(14)
                        Text("30 days before").tag(30)
                    }
                }
            }

            Section {
                HStack {
                    Label("Telegram", systemImage: "paperplane.fill")
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    Text("Desktop only")
                        .font(.caption)
                        .foregroundStyle(.textTertiary)
                }
                HStack {
                    Label("Discord", systemImage: "bubble.left.fill")
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    Text("Desktop only")
                        .font(.caption)
                        .foregroundStyle(.textTertiary)
                }
                HStack {
                    Label("Slack", systemImage: "number")
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    Text("Desktop only")
                        .font(.caption)
                        .foregroundStyle(.textTertiary)
                }
            } header: {
                Text("Notification Channels")
            } footer: {
                Text("Manage Telegram, Discord, and Slack notifications from the desktop app.")
            }
        }
        .navigationTitle("Notifications")
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            hasPermission = settings.authorizationStatus == .authorized
            notificationsEnabled = hasPermission
        }
    }
}
