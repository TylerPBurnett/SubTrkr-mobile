import Foundation
import Supabase

final class ItemService {
    enum ItemServiceError: LocalizedError {
        case futureCancellationDateUnsupported
        case futureEffectiveDateUnsupported
        case effectiveDateBeforeItemStart

        var errorDescription: String? {
            switch self {
            case .futureCancellationDateUnsupported:
                return "Cancellation dates must be today or earlier."
            case .futureEffectiveDateUnsupported:
                return "Effective dates must be today or earlier."
            case .effectiveDateBeforeItemStart:
                return "Effective dates must be on or after the item's start date."
            }
        }
    }

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

    func getAllStatusHistory() async throws -> [StatusHistory] {
        return try await client.from("item_status_history")
            .select()
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
        let currentItem = try await getItemById(id)
        var update = ItemUpdate()
        var historyEffectiveDate: Date?

        switch statusData.action {
        case "pause":
            update.status = .paused
            update.pausedAt = DateHelper.formatISO8601(Date.now)
            historyEffectiveDate = Date.now
            if let resumeDate = statusData.autoResumeDate {
                update.pausedUntil = DateHelper.formatDate(resumeDate)
            }

        case "cancel":
            let effectiveDate = try resolvedHistoricalEffectiveDate(
                statusData.effectiveDate,
                futureDateError: .futureCancellationDateUnsupported,
                minimumDate: currentItem.minimumEffectiveDate(for: statusData.action)
            )

            update.status = .cancelled
            update.cancelledAt = DateHelper.formatISO8601(Date.now)
            update.cancellationDate = DateHelper.formatDate(effectiveDate)
            historyEffectiveDate = effectiveDate

        case "edit_cancellation":
            let effectiveDate = try resolvedHistoricalEffectiveDate(
                statusData.effectiveDate,
                futureDateError: .futureCancellationDateUnsupported,
                minimumDate: currentItem.minimumEffectiveDate(for: statusData.action)
            )

            update.status = .cancelled
            update.cancellationDate = DateHelper.formatDate(effectiveDate)
            historyEffectiveDate = effectiveDate

        case "resume", "reactivate":
            let effectiveDate = try resolvedHistoricalEffectiveDate(
                statusData.effectiveDate,
                minimumDate: currentItem.minimumEffectiveDate(for: statusData.action)
            )

            update.status = .active
            update.pausedAt = nil
            update.pausedUntil = nil
            update.cancelledAt = nil
            update.cancellationDate = nil
            update.archivedAt = nil
            update.trialStartedAt = nil
            update.trialEndDate = nil
            update.nextBillingDate = nextBillingDateAfterActivation(for: currentItem, effectiveDate: effectiveDate)
            historyEffectiveDate = effectiveDate

        case "archive":
            update.status = .archived
            update.archivedAt = DateHelper.formatISO8601(Date.now)
            historyEffectiveDate = Date.now

        case "start_trial":
            update.status = .trial
            update.trialStartedAt = DateHelper.formatISO8601(Date.now)
            historyEffectiveDate = Date.now
            if let endDate = statusData.effectiveDate {
                update.trialEndDate = DateHelper.formatDate(endDate)
            }

        case "convert_trial":
            let effectiveDate = try resolvedHistoricalEffectiveDate(
                statusData.effectiveDate,
                minimumDate: currentItem.minimumEffectiveDate(for: statusData.action)
            )

            update.status = .active
            update.pausedAt = nil
            update.pausedUntil = nil
            update.cancelledAt = nil
            update.cancellationDate = nil
            update.archivedAt = nil
            update.trialStartedAt = nil
            update.trialEndDate = nil
            update.nextBillingDate = nextBillingDateAfterActivation(for: currentItem, effectiveDate: effectiveDate)
            historyEffectiveDate = effectiveDate

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
        let history = makeStatusHistoryInsert(
            itemId: id,
            userId: userId,
            status: newStatus,
            action: statusData.action,
            reason: statusData.reason,
            userNotes: statusData.notes,
            effectiveDate: historyEffectiveDate
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
            guard let rolledDate = item.nextBillingDateForMaintenance(referenceDate: now) else { continue }
            let update = ItemUpdate(nextBillingDate: DateHelper.formatDate(rolledDate))
            _ = try await updateItem(id: item.id, data: update)
        }
    }

    func archivePastCancellations() async throws {
        // Phase 1 keeps cancelled items editable so users can correct the effective date later.
    }

    func resumePausedItems() async throws {
        let items = try await getItems()
        let today = DateHelper.formatDate(Date.now)

        for item in items where item.status == .paused {
            guard let pausedUntil = item.pausedUntil,
                  pausedUntil <= today,
                  let resumeDate = DateHelper.parseDate(pausedUntil) else { continue }

            let update = ItemUpdate(
                nextBillingDate: nextBillingDateAfterActivation(for: item, effectiveDate: resumeDate),
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
                notes: StatusHistoryMetadataCodec.encode(
                    metadata: StatusHistoryMetadata(
                        action: "trial_expired",
                        effectiveDate: today
                    ),
                    userNotes: "Trial ended on \(trialEndDate)"
                )
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

    private func resolvedHistoricalEffectiveDate(_ effectiveDate: Date?,
                                                 futureDateError: ItemServiceError = .futureEffectiveDateUnsupported,
                                                 minimumDate: Date? = nil) throws -> Date {
        let resolvedDate = effectiveDate ?? Date.now

        guard !DateHelper.isBeforeDay(Date.now, than: resolvedDate) else {
            throw futureDateError
        }

        if let minimumDate, DateHelper.isBeforeDay(resolvedDate, than: minimumDate) {
            throw ItemServiceError.effectiveDateBeforeItemStart
        }

        return resolvedDate
    }

    private func nextBillingDateAfterActivation(for item: Item, effectiveDate: Date) -> String {
        let nextBillingDate = DateHelper.nextFutureBillingDate(from: effectiveDate, by: item.billingCycle)
        return DateHelper.formatDate(nextBillingDate)
    }

    private func makeStatusHistoryInsert(itemId: String,
                                         userId: String,
                                         status: ItemStatus,
                                         action: String,
                                         reason: String?,
                                         userNotes: String?,
                                         effectiveDate: Date?) -> StatusHistoryInsert {
        let metadata = StatusHistoryMetadata(
            action: action,
            effectiveDate: effectiveDate.map(DateHelper.formatDate)
        )

        return StatusHistoryInsert(
            itemId: itemId,
            userId: userId,
            status: status,
            reason: reason,
            notes: StatusHistoryMetadataCodec.encode(metadata: metadata, userNotes: userNotes)
        )
    }
}
