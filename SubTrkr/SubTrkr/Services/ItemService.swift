import Foundation
import Supabase

final class ItemService {
    enum ItemServiceError: LocalizedError {
        case futureCancellationDateUnsupported
        case futureEffectiveDateUnsupported
        case effectiveDateBeforeItemStart
        case invalidArchiveTransition

        var errorDescription: String? {
            switch self {
            case .futureCancellationDateUnsupported:
                return "Cancellation dates must be today or earlier."
            case .futureEffectiveDateUnsupported:
                return "Effective dates must be today or earlier."
            case .effectiveDateBeforeItemStart:
                return "Effective dates must be on or after the item's start date."
            case .invalidArchiveTransition:
                return "Only cancelled items can be archived."
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

    func getStatusHistory(itemId: String, userId: String) async throws -> [StatusHistory] {
        return try await client.from("item_status_history")
            .select()
            .eq("item_id", value: itemId)
            .eq("user_id", value: userId)
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
                await notificationService.scheduleRenewalReminder(
                    for: item,
                    daysBefore: item.notificationReminderDays(fallback: days)
                )
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

        await syncNotifications(for: item)

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

    func executeStatusChange(id: String, userId _: String, statusData: StatusChangeData) async throws -> Item {
        let currentItem = try await getItemById(id)
        let today = DateHelper.startOfToday()
        let todayString = DateHelper.formatDate(today)
        let minimumEffectiveDate = currentItem.minimumEffectiveDate(for: statusData.action)
        var effectiveDate: Date?
        var pauseUntil: String?
        var trialEndDate: String?
        var nextBillingDate: String?
        var clearFields: [String] = []

        switch statusData.action {
        case "pause":
            if let resumeDate = statusData.autoResumeDate {
                pauseUntil = DateHelper.formatDate(resumeDate)
            }

        case "cancel":
            effectiveDate = try resolvedHistoricalEffectiveDate(
                statusData.effectiveDate,
                futureDateError: .futureCancellationDateUnsupported,
                minimumDate: minimumEffectiveDate
            )

        case "edit_cancellation":
            effectiveDate = try resolvedHistoricalEffectiveDate(
                statusData.effectiveDate,
                futureDateError: .futureCancellationDateUnsupported,
                minimumDate: minimumEffectiveDate
            )

        case "resume":
            let resolvedDate = try resolvedHistoricalEffectiveDate(
                statusData.effectiveDate,
                minimumDate: minimumEffectiveDate
            )

            effectiveDate = resolvedDate
            clearFields = Self.activeStatusClearFields
            nextBillingDate = DateHelper.formatDate(currentItem.nextBillingDateAfterResuming(on: resolvedDate))

        case "reactivate":
            let resolvedDate = try resolvedHistoricalEffectiveDate(
                statusData.effectiveDate,
                minimumDate: minimumEffectiveDate
            )

            effectiveDate = resolvedDate
            clearFields = Self.activeStatusClearFields
            nextBillingDate = nextBillingDateAfterActivation(for: currentItem, effectiveDate: resolvedDate)

        case "archive":
            guard currentItem.status == .cancelled else {
                throw ItemServiceError.invalidArchiveTransition
            }

        case "start_trial":
            if let endDate = statusData.effectiveDate {
                trialEndDate = DateHelper.formatDate(endDate)
            }

        case "convert_trial":
            let resolvedDate = try resolvedHistoricalEffectiveDate(
                statusData.effectiveDate,
                minimumDate: minimumEffectiveDate
            )

            effectiveDate = resolvedDate
            clearFields = Self.activeStatusClearFields
            nextBillingDate = nextBillingDateAfterActivation(for: currentItem, effectiveDate: resolvedDate)

        default:
            break
        }

        let item = try await executeStatusChangeRPC(
            id: id,
            action: statusData.action,
            effectiveDate: effectiveDate.map(DateHelper.formatDate),
            pauseUntil: pauseUntil,
            trialEndDate: trialEndDate,
            nextBillingDate: nextBillingDate,
            clearFields: clearFields,
            reason: statusData.reason,
            notes: statusData.notes,
            today: todayString,
            minimumEffectiveDate: minimumEffectiveDate.map(DateHelper.formatDate)
        )

        await syncNotifications(for: item)

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

            let updatedItem = try await executeStatusChangeRPC(
                id: item.id,
                action: "resume",
                effectiveDate: pausedUntil,
                pauseUntil: nil,
                trialEndDate: nil,
                nextBillingDate: DateHelper.formatDate(item.nextBillingDateAfterResuming(on: resumeDate)),
                clearFields: Self.activeStatusClearFields,
                reason: "Auto-resumed",
                notes: nil,
                today: today,
                minimumEffectiveDate: item.minimumEffectiveDate(for: "resume").map(DateHelper.formatDate)
            )

            await syncNotifications(for: updatedItem)
        }
    }

    func handleExpiredTrials(userId _: String) async throws {
        let items = try await getItems()
        let today = DateHelper.formatDate(Date.now)

        for item in items where item.status == .trial {
            guard let trialEndDate = item.trialEndDate, trialEndDate < today else { continue }

            let updatedItem = try await executeStatusChangeRPC(
                id: item.id,
                action: "trial_expired",
                effectiveDate: trialEndDate,
                pauseUntil: nil,
                trialEndDate: nil,
                nextBillingDate: nil,
                clearFields: [],
                reason: "Trial expired",
                notes: "Trial ended on \(trialEndDate)",
                today: today,
                minimumEffectiveDate: item.minimumEffectiveDate(for: "cancel").map(DateHelper.formatDate)
            )

            await syncNotifications(for: updatedItem)
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

    static func normalizeHistoricalEffectiveDate(_ effectiveDate: Date?,
                                                 today: Date = DateHelper.startOfToday(),
                                                 futureDateError: ItemServiceError = .futureEffectiveDateUnsupported,
                                                 minimumDate: Date? = nil) throws -> Date {
        let normalizedToday = DateHelper.startOfDay(today)
        let resolvedDate = DateHelper.startOfDay(effectiveDate ?? normalizedToday)

        guard !DateHelper.isBeforeDay(normalizedToday, than: resolvedDate) else {
            throw futureDateError
        }

        if let minimumDate {
            let normalizedMinimumDate = DateHelper.startOfDay(minimumDate)
            if DateHelper.isBeforeDay(resolvedDate, than: normalizedMinimumDate) {
                throw ItemServiceError.effectiveDateBeforeItemStart
            }
        }

        return resolvedDate
    }

    private func resolvedHistoricalEffectiveDate(_ effectiveDate: Date?,
                                                 futureDateError: ItemServiceError = .futureEffectiveDateUnsupported,
                                                 minimumDate: Date? = nil) throws -> Date {
        try Self.normalizeHistoricalEffectiveDate(
            effectiveDate,
            futureDateError: futureDateError,
            minimumDate: minimumDate
        )
    }

    private func nextBillingDateAfterActivation(for item: Item, effectiveDate: Date) -> String {
        let nextBillingDate = DateHelper.nextFutureBillingDate(from: effectiveDate, by: item.billingCycle)
        return DateHelper.formatDate(nextBillingDate)
    }

    private func executeStatusChangeRPC(id: String,
                                        action: String,
                                        effectiveDate: String?,
                                        pauseUntil: String?,
                                        trialEndDate: String?,
                                        nextBillingDate: String?,
                                        clearFields: [String],
                                        reason: String?,
                                        notes: String?,
                                        today: String,
                                        minimumEffectiveDate: String?) async throws -> Item {
        let params = ExecuteItemStatusChangeParams(
            itemId: id,
            action: action,
            effectiveDate: effectiveDate,
            pauseUntil: pauseUntil,
            trialEndDate: trialEndDate,
            nextBillingDate: nextBillingDate,
            clearFields: clearFields,
            reason: reason?.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            today: today,
            minimumEffectiveDate: minimumEffectiveDate
        )

        return try await client.rpc("execute_item_status_change", params: params)
            .single()
            .execute()
            .value
    }

    private func syncNotifications(for item: Item) async {
        notificationService.cancelNotifications(for: item.id)
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }

        let days = UserDefaults.standard.integer(forKey: "defaultReminderDays")

        if item.status == .active {
            await notificationService.scheduleRenewalReminder(
                for: item,
                daysBefore: item.notificationReminderDays(fallback: days)
            )
        } else if item.status == .trial {
            await notificationService.scheduleTrialExpirationReminder(for: item)
        }
    }

    private static let activeStatusClearFields = [
        "paused_at",
        "paused_until",
        "cancelled_at",
        "cancellation_date",
        "archived_at",
        "trial_started_at",
        "trial_end_date",
    ]
}

private struct ExecuteItemStatusChangeParams: Encodable {
    let itemId: String
    let action: String
    let effectiveDate: String?
    let pauseUntil: String?
    let trialEndDate: String?
    let nextBillingDate: String?
    let clearFields: [String]
    let reason: String?
    let notes: String?
    let today: String
    let minimumEffectiveDate: String?

    enum CodingKeys: String, CodingKey {
        case itemId = "p_item_id"
        case action = "p_action"
        case effectiveDate = "p_effective_date"
        case pauseUntil = "p_pause_until"
        case trialEndDate = "p_trial_end_date"
        case nextBillingDate = "p_next_billing_date"
        case clearFields = "p_clear_fields"
        case reason = "p_reason"
        case notes = "p_notes"
        case today = "p_today"
        case minimumEffectiveDate = "p_minimum_effective_date"
    }
}
