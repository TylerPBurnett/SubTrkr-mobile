import Foundation

@Observable
@MainActor
final class ItemFormViewModel {
    private struct Snapshot: Equatable {
        let name: String
        let amount: Double
        let currency: String
        let billingCycle: BillingCycle
        let categoryId: String?
        let startDate: String
        let nextBillingDate: String
        let reminderDays: Int?
        let notes: String
        let url: String
        let logoUrl: String
        let status: ItemStatus
        let trialEndDate: String?
        let serviceSearchText: String
    }

    private let itemService = ItemService()
    private let categoryService = CategoryService()
    private var initialSnapshot: Snapshot?

    // Form fields
    var name = ""
    var amount: Double = 0
    var currency = "USD"
    var billingCycle: BillingCycle = .monthly
    var categoryId: String?
    var startDate = Date.now
    var nextBillingDate = Date.now
    var reminderDays: Int?
    var notes = ""
    var url = ""
    var logoUrl = ""
    var itemType: ItemType
    var status: ItemStatus = .active
    var trialEndDate: Date?

    // State
    var categories: [Category] = []
    var isLoading = false
    var error: String?
    var isSaved = false
    var editingItem: Item?
    var userEditedNextBillingDate = false

    // Service autocomplete
    var serviceSearchText = ""
    var showServiceSuggestions = false
    var serviceSuggestions: [KnownService] {
        KnownServices.search(serviceSearchText)
    }

    init(itemType: ItemType, editingItem: Item? = nil) {
        self.itemType = itemType
        self.editingItem = editingItem

        if let item = editingItem {
            name = item.name
            amount = item.amount
            currency = "USD"
            billingCycle = item.billingCycle
            categoryId = item.categoryId
            startDate = item.startDate.flatMap { DateHelper.parseDate($0) } ?? Date.now
            nextBillingDate = item.nextBillingDateFormatted ?? Date.now
            reminderDays = item.reminderDays
            notes = item.notes ?? ""
            url = item.url ?? ""
            logoUrl = item.logoUrl ?? ""
            status = item.status
            trialEndDate = item.trialEndDateFormatted
        }

        initialSnapshot = Snapshot(
            name: name,
            amount: amount,
            currency: currency,
            billingCycle: billingCycle,
            categoryId: categoryId,
            startDate: DateHelper.formatDate(startDate),
            nextBillingDate: DateHelper.formatDate(nextBillingDate),
            reminderDays: reminderDays,
            notes: notes,
            url: url,
            logoUrl: logoUrl,
            status: status,
            trialEndDate: trialEndDate.map(DateHelper.formatDate),
            serviceSearchText: serviceSearchText
        )
    }

    var isEditing: Bool { editingItem != nil }

    private var currentSnapshot: Snapshot {
        Snapshot(
            name: name,
            amount: amount,
            currency: currency,
            billingCycle: billingCycle,
            categoryId: categoryId,
            startDate: DateHelper.formatDate(startDate),
            nextBillingDate: DateHelper.formatDate(nextBillingDate),
            reminderDays: reminderDays,
            notes: notes,
            url: url,
            logoUrl: logoUrl,
            status: status,
            trialEndDate: trialEndDate.map(DateHelper.formatDate),
            serviceSearchText: serviceSearchText
        )
    }

    var isDirty: Bool {
        guard let initialSnapshot else { return false }
        return currentSnapshot != initialSnapshot
    }

    var isValid: Bool {
        !name.isEmpty && (amount > 0 || status == .trial)
    }

    func autoCalcNextBillingDate() {
        guard !isEditing, !userEditedNextBillingDate else { return }
        var date = startDate
        let now = Date.now
        // Keep "due today" on today instead of skipping ahead because the current time is past midnight.
        while DateHelper.isBeforeDay(date, than: now) {
            date = DateHelper.advanceDate(date, by: billingCycle, anchorDate: startDate)
        }
        nextBillingDate = date
    }

    var relevantCategories: [Category] {
        categories.filter { $0.type == itemType.rawValue || $0.type == nil }
    }

    // MARK: - Actions

    func loadCategories() async {
        do {
            categories = try await categoryService.getCategories()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func selectService(_ service: KnownService) {
        name = service.name
        amount = service.defaultPrice
        currency = "USD"
        billingCycle = service.billingCycle
        logoUrl = service.logoUrl
        url = service.url
        serviceSearchText = service.name
        showServiceSuggestions = false

        // Try to match category
        if let matchingCategory = categories.first(where: {
            $0.name.lowercased() == service.category.lowercased()
        }) {
            categoryId = matchingCategory.id
        }
    }

    func save(userId: String) async {
        guard isValid else {
            error = "Please fill in all required fields"
            return
        }

        isLoading = true
        error = nil

        do {
            if let editingItem {
                let update = ItemUpdate(
                    name: name,
                    amount: amount,
                    currency: currency,
                    billingCycle: billingCycle,
                    categoryId: categoryId,
                    startDate: DateHelper.formatDate(startDate),
                    nextBillingDate: DateHelper.formatDate(nextBillingDate),
                    reminderDays: reminderDays,
                    notes: notes.isEmpty ? nil : notes,
                    url: url.isEmpty ? nil : url,
                    logoUrl: logoUrl.isEmpty ? nil : logoUrl,
                    trialEndDate: trialEndDate.map { DateHelper.formatDate($0) }
                )
                _ = try await itemService.updateItem(id: editingItem.id, data: update)
            } else {
                let insert = ItemInsert(
                    id: UUID().uuidString,
                    userId: userId,
                    name: name,
                    amount: amount,
                    currency: currency,
                    billingCycle: billingCycle,
                    categoryId: categoryId,
                    startDate: DateHelper.formatDate(startDate),
                    nextBillingDate: DateHelper.formatDate(nextBillingDate),
                    reminderDays: reminderDays,
                    notes: notes.isEmpty ? nil : notes,
                    url: url.isEmpty ? nil : url,
                    logoUrl: logoUrl.isEmpty ? nil : logoUrl,
                    itemType: itemType,
                    status: status,
                    trialEndDate: trialEndDate.map { DateHelper.formatDate($0) }
                )
                _ = try await itemService.createItem(insert)
            }
            isSaved = true
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
