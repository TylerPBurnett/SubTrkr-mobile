import Foundation

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        }
    }

    var monthlyMultiplier: Double {
        switch self {
        case .weekly: return 52.0 / 12.0
        case .monthly: return 1.0
        case .quarterly: return 1.0 / 3.0
        case .yearly: return 1.0 / 12.0
        }
    }

    var yearlyMultiplier: Double {
        switch self {
        case .weekly: return 52.0
        case .monthly: return 12.0
        case .quarterly: return 4.0
        case .yearly: return 1.0
        }
    }
}

enum ItemType: String, Codable, CaseIterable, Identifiable {
    case subscription
    case bill

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .subscription: return "Subscription"
        case .bill: return "Bill"
        }
    }

    var pluralName: String {
        switch self {
        case .subscription: return "Subscriptions"
        case .bill: return "Bills"
        }
    }
}

enum ItemStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case paused
    case cancelled
    case archived
    case trial

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .cancelled: return "Cancelled"
        case .archived: return "Archived"
        case .trial: return "Trial"
        }
    }

    var iconName: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .archived: return "archivebox.fill"
        case .trial: return "clock.fill"
        }
    }
}

enum NotificationChannelType: String, Codable, CaseIterable {
    case telegram
    case discord
    case slack
}

enum NotificationEventType: String, Codable, CaseIterable {
    case renewal_reminder
    case trial_expiration
}

enum NotificationLogStatus: String, Codable {
    case sent
    case failed
    case skipped
}

enum SortOption: String, CaseIterable, Identifiable {
    case nextBillingDate = "next_billing_date"
    case name = "name"
    case price = "price"
    case category = "category"
    case status = "status"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nextBillingDate: return "Next Billing"
        case .name: return "Name"
        case .price: return "Price"
        case .category: return "Category"
        case .status: return "Status"
        }
    }

    var iconName: String {
        switch self {
        case .nextBillingDate: return "calendar"
        case .name: return "textformat"
        case .price: return "dollarsign"
        case .category: return "folder"
        case .status: return "circle.dotted"
        }
    }
}
