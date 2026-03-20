import Foundation

struct Item: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    var name: String
    var amount: Double
    var currency: String
    var billingCycle: BillingCycle
    var categoryId: String?
    var startDate: String?
    var nextBillingDate: String?
    var reminderDays: Int?
    var notes: String?
    var url: String?
    var logoUrl: String?
    var itemType: ItemType
    var status: ItemStatus
    var pausedAt: String?
    var pausedUntil: String?
    var cancelledAt: String?
    var cancellationDate: String?
    var archivedAt: String?
    var trialStartedAt: String?
    var trialEndDate: String?
    var isActive: Bool?
    let createdAt: String?
    let updatedAt: String?

    // Joined category (from Supabase query)
    var categories: Category?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case amount
        case currency
        case billingCycle = "billing_cycle"
        case categoryId = "category_id"
        case startDate = "start_date"
        case nextBillingDate = "next_billing_date"
        case reminderDays = "reminder_days"
        case notes
        case url
        case logoUrl = "logo_url"
        case itemType = "item_type"
        case status
        case pausedAt = "paused_at"
        case pausedUntil = "paused_until"
        case cancelledAt = "cancelled_at"
        case cancellationDate = "cancellation_date"
        case archivedAt = "archived_at"
        case trialStartedAt = "trial_started_at"
        case trialEndDate = "trial_end_date"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case categories
    }

    // MARK: - Computed Properties

    var monthlyAmount: Double {
        amount * billingCycle.monthlyMultiplier
    }

    var yearlyAmount: Double {
        amount * billingCycle.yearlyMultiplier
    }

    var nextBillingDateFormatted: Date? {
        guard let nextBillingDate else { return nil }
        return DateHelper.parseDate(nextBillingDate)
    }

    var startDateFormatted: Date? {
        guard let startDate else { return nil }
        return DateHelper.parseDate(startDate)
    }

    var daysUntilDue: Int? {
        guard let date = nextBillingDateFormatted else { return nil }
        return Calendar.current.dateComponents([.day], from: DateHelper.startOfToday(), to: DateHelper.startOfDay(date)).day
    }

    var billingAnchorDate: Date? {
        if let startDateFormatted {
            return startDateFormatted
        }

        if let nextBillingDateFormatted {
            return nextBillingDateFormatted
        }

        guard let createdAt, let createdAtFormatted = DateHelper.parseISO8601(createdAt) else { return nil }
        return DateHelper.startOfDay(createdAtFormatted)
    }

    var trialEndDateFormatted: Date? {
        guard let trialEndDate else { return nil }
        return DateHelper.parseDate(trialEndDate)
    }

    var daysUntilTrialEnds: Int? {
        guard let date = trialEndDateFormatted else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: date)).day
    }

    var isTrialExpired: Bool {
        guard status == .trial, let days = daysUntilTrialEnds else { return false }
        return days < 0
    }

    var pausedUntilFormatted: Date? {
        guard let pausedUntil else { return nil }
        return DateHelper.parseDate(pausedUntil)
    }

    var pausedAtFormatted: Date? {
        guard let pausedAt else { return nil }
        return DateHelper.parseISO8601(pausedAt)
    }

    var cancellationDateFormatted: Date? {
        guard let cancellationDate else { return nil }
        return DateHelper.parseDate(cancellationDate)
    }

    var cancelledAtFormatted: Date? {
        guard let cancelledAt else { return nil }
        return DateHelper.parseISO8601(cancelledAt)
    }

    var archivedAtFormatted: Date? {
        guard let archivedAt else { return nil }
        return DateHelper.parseISO8601(archivedAt)
    }

    var trialStartedAtFormatted: Date? {
        guard let trialStartedAt else { return nil }
        return DateHelper.parseISO8601(trialStartedAt)
    }

    var logoURL: URL? {
        guard let logoUrl, !logoUrl.isEmpty else { return nil }
        return URL(string: logoUrl)
    }

    var categoryColor: String {
        categories?.color ?? "#64748b"
    }

    var categoryName: String {
        categories?.name ?? "Uncategorized"
    }

    func minimumEffectiveDate(for action: String) -> Date? {
        switch action {
        case "cancel", "edit_cancellation":
            return startDateFormatted

        case "resume":
            return [startDateFormatted, pausedAtFormatted]
                .compactMap { $0 }
                .max()

        case "reactivate":
            // Prefer the effective cancellation date when present, but keep the
            // archive timestamp as the lower bound for archived items.
            return [startDateFormatted, cancellationDateFormatted ?? cancelledAtFormatted, archivedAtFormatted]
                .compactMap { $0 }
                .max()

        case "convert_trial":
            return [startDateFormatted, trialStartedAtFormatted]
                .compactMap { $0 }
                .max()

        default:
            return startDateFormatted
        }
    }

    func nextBillingDateForMaintenance(referenceDate: Date = .now) -> Date? {
        guard let nextBillingDateFormatted else { return nil }
        let referenceDay = DateHelper.startOfDay(referenceDate)
        guard DateHelper.isBeforeDay(nextBillingDateFormatted, than: referenceDay) else { return nil }

        let anchorDate = billingAnchorDate ?? nextBillingDateFormatted
        return DateHelper.nextRecurringDate(anchorDate: anchorDate, cycle: billingCycle, onOrAfter: referenceDay)
    }

    func nextBillingDateAfterLoggingPayment(on paymentDate: Date) -> Date? {
        guard status == .active else { return nil }
        guard let nextBillingDateFormatted else { return nil }
        let paymentDay = DateHelper.startOfDay(paymentDate)
        guard !DateHelper.isBeforeDay(paymentDay, than: nextBillingDateFormatted) else { return nil }

        let anchorDate = billingAnchorDate ?? nextBillingDateFormatted
        return DateHelper.nextRecurringDate(anchorDate: anchorDate, cycle: billingCycle, strictlyAfter: paymentDay)
    }

}

struct ItemInsert: Codable {
    let id: String
    let userId: String
    let name: String
    let amount: Double
    let currency: String
    let billingCycle: BillingCycle
    let categoryId: String?
    let startDate: String?
    let nextBillingDate: String?
    let reminderDays: Int?
    let notes: String?
    let url: String?
    let logoUrl: String?
    let itemType: ItemType
    let status: ItemStatus?
    let trialEndDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case amount
        case currency
        case billingCycle = "billing_cycle"
        case categoryId = "category_id"
        case startDate = "start_date"
        case nextBillingDate = "next_billing_date"
        case reminderDays = "reminder_days"
        case notes
        case url
        case logoUrl = "logo_url"
        case itemType = "item_type"
        case status
        case trialEndDate = "trial_end_date"
    }
}

struct ItemUpdate: Codable {
    var name: String?
    var amount: Double?
    var currency: String?
    var billingCycle: BillingCycle?
    var categoryId: String?
    var startDate: String?
    var nextBillingDate: String?
    var reminderDays: Int?
    var notes: String?
    var url: String?
    var logoUrl: String?
    var status: ItemStatus?
    var pausedAt: String?
    var pausedUntil: String?
    var cancelledAt: String?
    var cancellationDate: String?
    var archivedAt: String?
    var trialStartedAt: String?
    var trialEndDate: String?

    enum CodingKeys: String, CodingKey {
        case name
        case amount
        case currency
        case billingCycle = "billing_cycle"
        case categoryId = "category_id"
        case startDate = "start_date"
        case nextBillingDate = "next_billing_date"
        case reminderDays = "reminder_days"
        case notes
        case url
        case logoUrl = "logo_url"
        case status
        case pausedAt = "paused_at"
        case pausedUntil = "paused_until"
        case cancelledAt = "cancelled_at"
        case cancellationDate = "cancellation_date"
        case archivedAt = "archived_at"
        case trialStartedAt = "trial_started_at"
        case trialEndDate = "trial_end_date"
    }
}
