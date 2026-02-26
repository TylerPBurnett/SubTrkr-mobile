import Foundation

enum DateHelper {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601FallbackFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static func parseDate(_ string: String) -> Date? {
        dateFormatter.date(from: string)
    }

    static func parseISO8601(_ string: String) -> Date? {
        iso8601Formatter.date(from: string) ?? iso8601FallbackFormatter.date(from: string)
    }

    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func formatISO8601(_ date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    static func formatMediumDate(_ date: Date) -> String {
        mediumDateFormatter.string(from: date)
    }

    static func relativeDateString(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfToday, to: startOfDate).day ?? 0

        switch days {
        case ..<0:
            return "\(abs(days)) day\(abs(days) == 1 ? "" : "s") overdue"
        case 0:
            return "Today"
        case 1:
            return "Tomorrow"
        case 2...7:
            return "In \(days) days"
        case 8...30:
            let weeks = days / 7
            return "In \(weeks) week\(weeks == 1 ? "" : "s")"
        default:
            return formatMediumDate(date)
        }
    }

    static func advanceDate(_ date: Date, by cycle: BillingCycle) -> Date {
        let calendar = Calendar.current
        switch cycle {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}
