import Foundation
import UserNotifications
import Supabase

final class NotificationService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: - Local Notifications

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleRenewalReminder(for item: Item, daysBefore: Int = 3) async {
        guard let nextDate = item.nextBillingDateFormatted else { return }

        let calendar = Calendar.current
        guard let reminderDate = calendar.date(byAdding: .day, value: -daysBefore, to: nextDate),
              reminderDate > Date.now else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(item.name) renewal coming up"
        content.body = "\(item.amount.formatted(currency: item.currency)) due \(DateHelper.relativeDateString(nextDate))"
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "renewal-\(item.id)",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleTrialExpirationReminder(for item: Item) async {
        guard let endDate = item.trialEndDateFormatted else { return }

        let calendar = Calendar.current
        guard let reminderDate = calendar.date(byAdding: .day, value: -1, to: endDate),
              reminderDate > Date.now else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(item.name) trial ending"
        content.body = "Your free trial ends \(DateHelper.relativeDateString(endDate))"
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "trial-\(item.id)",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancelNotifications(for itemId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["renewal-\(itemId)", "trial-\(itemId)"]
        )
    }

    func rescheduleAllNotifications(items: [Item], daysBefore: Int = 3) async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        for item in items where item.status == .active {
            await scheduleRenewalReminder(for: item, daysBefore: daysBefore)
        }

        for item in items where item.status == .trial {
            await scheduleTrialExpirationReminder(for: item)
        }
    }

    // MARK: - Notification Channels (Supabase)

    func getNotificationChannels() async throws -> [NotificationChannel] {
        return try await client.from("notification_channels")
            .select()
            .execute()
            .value
    }

    func getNotificationPreferences() async throws -> NotificationPreferences? {
        let results: [NotificationPreferences] = try await client.from("notification_preferences")
            .select()
            .execute()
            .value
        return results.first
    }

    func getNotificationLog(limit: Int = 20) async throws -> [NotificationLogEntry] {
        return try await client.from("notification_log")
            .select()
            .order("sent_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }
}
