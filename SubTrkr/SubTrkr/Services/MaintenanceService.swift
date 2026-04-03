import Foundation

@MainActor
final class MaintenanceService {
    typealias Operation = @MainActor (String) async throws -> Void

    static let shared = MaintenanceService()

    private let operation: Operation
    private var completedUserIds: Set<String> = []
    private var inFlightTasks: [String: Task<Void, Error>] = [:]

    init(operation: @escaping Operation = MaintenanceService.defaultOperation) {
        self.operation = operation
    }

    func runIfNeeded(userId: String) async throws -> Bool {
        if completedUserIds.contains(userId) {
            return false
        }

        if let task = inFlightTasks[userId] {
            try await task.value
            return true
        }

        let task = Task { @MainActor [operation] in
            try await operation(userId)
        }
        inFlightTasks[userId] = task

        defer {
            inFlightTasks[userId] = nil
        }

        try await task.value
        completedUserIds.insert(userId)
        return true
    }

    func reset(userId: String? = nil) {
        if let userId {
            completedUserIds.remove(userId)
            inFlightTasks[userId]?.cancel()
            inFlightTasks[userId] = nil
            return
        }

        for task in inFlightTasks.values {
            task.cancel()
        }

        inFlightTasks.removeAll()
        completedUserIds.removeAll()
    }

    private static func defaultOperation(userId: String) async throws {
        let itemService = ItemService()
        let notificationService = NotificationService()

        try await itemService.advancePastDueItems()
        try await itemService.archivePastCancellations()
        try await itemService.resumePausedItems()
        try await itemService.handleExpiredTrials(userId: userId)

        if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
            let allItems = try await itemService.getItems()
            let days = UserDefaults.standard.integer(forKey: "defaultReminderDays")
            await notificationService.rescheduleAllNotifications(
                items: allItems,
                daysBefore: days > 0 ? days : 3
            )
        }
    }
}
