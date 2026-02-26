import Foundation
import Supabase

final class ItemService {
    private let client: SupabaseClient
    private let notificationService: NotificationService

    init(client: SupabaseClient = SupabaseManager.shared.client,
         notificationService: NotificationService = NotificationService()) {
        self.client = client
        self.notificationService = notificationService
    }

    // MARK: - Read

    func getItems(type: ItemType? = nil) async throws -> [Item] {
        if let type {
            return try await client.from("items")
                .select("*, categories(*)")
                .eq("item_type", value: type.rawValue)
                .order("next_billing_date", ascending: true)
                .execute()
                .value
        }

        return try await client.from("items")
            .select("*, categories(*)")
            .order("next_billing_date", ascending: true)
            .execute()
            .value
    }

    func getActiveItems(type: ItemType? = nil) async throws -> [Item] {
        if let type {
            return try await client.from("items")
                .select("*, categories(*)")
                .eq("status", value: ItemStatus.active.rawValue)
                .eq("item_type", value: type.rawValue)
                .order("next_billing_date", ascending: true)
                .execute()
                .value
        }

        return try await client.from("items")
            .select("*, categories(*)")
            .eq("status", value: ItemStatus.active.rawValue)
            .order("next_billing_date", ascending: true)
            .execute()
            .value
    }

    func getItemById(_ id: String) async throws -> Item {
        return try await client.from("items")
            .select("*, categories(*)")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func getStatusHistory(itemId: String) async throws -> [StatusHistory] {
        return try await client.from("item_status_history")
            .select()
            .eq("item_id", value: itemId)
            .order("changed_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Create

    func createItem(_ data: ItemInsert) async throws -> Item {
        let item: Item = try await client.from("items")
            .insert(data)
            .select("*, categories(*)")
            .single()
            .execute()
            .value

        // Schedule notification for new item
        if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
            let days = UserDefaults.standard.integer(forKey: "defaultReminderDays")
            if item.status == .active {
                await notificationService.scheduleRenewalReminder(for: item, daysBefore: days > 0 ? days : 3)
            } else if item.status == .trial {
                await notificationService.scheduleTrialExpirationReminder(for: item)
            }
        }

        return item
    }

    // MARK: - Update

    func updateItem(id: String, data: ItemUpdate) async throws -> Item {
        let item: Item = try await client.from("items")
            .update(data)
            .eq("id", value: id)
            .select("*, categories(*)")
            .single()
            .execute()
            .value

        // Reschedule notifications for updated item
        if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
            notificationService.cancelNotifications(for: id)
            let days = UserDefaults.standard.integer(forKey: "defaultReminderDays")
            if item.status == .active {
                await notificationService.scheduleRenewalReminder(for: item, daysBefore: days > 0 ? days : 3)
            } else if item.status == .trial {
                await notificationService.scheduleTrialExpirationReminder(for: item)
            }
        }

        return item
    }

    // MARK: - Delete

    func deleteItem(id: String) async throws {
        try await client.from("items")
            .delete()
            .eq("id", value: id)
            .execute()

        notificationService.cancelNotifications(for: id)
    }

    // MARK: - Status Change

    func executeStatusChange(id: String, userId: String, statusData: StatusChangeData) async throws -> Item {
        var update = ItemUpdate()

        switch statusData.action {
        case "pause":
            update.status = .paused
            update.pausedAt = DateHelper.formatISO8601(Date.now)
            if let resumeDate = statusData.autoResumeDate {
                update.pausedUntil = DateHelper.formatDate(resumeDate)
            }

        case "cancel":
            update.status = .cancelled
            update.cancelledAt = DateHelper.formatISO8601(Date.now)
            if let effectiveDate = statusData.effectiveDate {
                update.cancellationDate = DateHelper.formatDate(effectiveDate)
            }

        case "resume", "reactivate":
            update.status = .active
            update.pausedAt = nil
            update.pausedUntil = nil
            update.cancelledAt = nil
            update.cancellationDate = nil

        case "archive":
            update.status = .archived
            update.archivedAt = DateHelper.formatISO8601(Date.now)

        case "start_trial":
            update.status = .trial
            update.trialStartedAt = DateHelper.formatISO8601(Date.now)
            if let endDate = statusData.effectiveDate {
                update.trialEndDate = DateHelper.formatDate(endDate)
            }

        case "convert_trial":
            update.status = .active
            update.trialStartedAt = nil
            update.trialEndDate = nil

        default:
            break
        }

        // Guard against unknown actions — don't write a no-op update or fabricated history
        guard let newStatus = update.status else {
            return try await getItemById(id)
        }

        // Update the item
        let item = try await updateItem(id: id, data: update)

        // Record status history
        let history = StatusHistoryInsert(
            itemId: id,
            userId: userId,
            status: newStatus,
            reason: statusData.reason,
            notes: statusData.notes
        )
        try await client.from("item_status_history")
            .insert(history)
            .execute()

        return item
    }

    // MARK: - Maintenance

    func advancePastDueItems() async throws {
        let items = try await getActiveItems()
        let now = Date.now

        for item in items {
            guard let nextDate = item.nextBillingDateFormatted, nextDate < now else { continue }

            var rolledDate = nextDate
            while rolledDate < now {
                rolledDate = DateHelper.advanceDate(rolledDate, by: item.billingCycle)
            }

            let update = ItemUpdate(nextBillingDate: DateHelper.formatDate(rolledDate))
            _ = try await updateItem(id: item.id, data: update)
        }
    }

    func archivePastCancellations() async throws {
        let items = try await getItems()
        let today = DateHelper.formatDate(Date.now)

        for item in items where item.status == .cancelled {
            guard let cancellationDate = item.cancellationDate, cancellationDate < today else { continue }

            let update = ItemUpdate(
                status: .archived,
                archivedAt: DateHelper.formatISO8601(Date.now)
            )
            _ = try await updateItem(id: item.id, data: update)
        }
    }

    func resumePausedItems() async throws {
        let items = try await getItems()
        let today = DateHelper.formatDate(Date.now)

        for item in items where item.status == .paused {
            guard let pausedUntil = item.pausedUntil, pausedUntil <= today else { continue }

            let update = ItemUpdate(
                status: .active,
                pausedAt: nil,
                pausedUntil: nil
            )
            _ = try await updateItem(id: item.id, data: update)
        }
    }

    func handleExpiredTrials(userId: String) async throws {
        let items = try await getItems()
        let today = DateHelper.formatDate(Date.now)

        for item in items where item.status == .trial {
            guard let trialEndDate = item.trialEndDate, trialEndDate < today else { continue }

            // Auto-cancel the expired trial
            let update = ItemUpdate(
                status: .cancelled,
                cancelledAt: DateHelper.formatISO8601(Date.now),
                cancellationDate: today
            )
            _ = try await updateItem(id: item.id, data: update)

            // Record the automatic transition
            let history = StatusHistoryInsert(
                itemId: item.id,
                userId: userId,
                status: .cancelled,
                reason: "Trial expired",
                notes: "Trial ended on \(trialEndDate)"
            )
            try await client.from("item_status_history")
                .insert(history)
                .execute()
        }
    }

    func getExpiringTrials(withinDays: Int = 7) async throws -> [Item] {
        let items = try await getItems()
        return items.filter { item in
            guard item.status == .trial,
                  let days = item.daysUntilTrialEnds,
                  days >= 0 && days <= withinDays else { return false }
            return true
        }
    }
}
