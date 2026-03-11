import SwiftUI

struct StatusChangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService

    let item: Item
    var onStatusChanged: (() async -> Void)?

    @State private var selectedAction = ""
    @State private var effectiveDate = Date.now
    @State private var autoResumeDate = Date.now.addingTimeInterval(30 * 86400)
    @State private var reason = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var changeSucceeded = false
    @State private var error: String?
    @State private var itemService = ItemService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Current Status") {
                    HStack {
                        ServiceLogo(
                            url: item.logoURL,
                            name: item.name,
                            categoryColor: item.categoryColor,
                            size: 36
                        )
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                            StatusBadge(status: item.status)
                        }
                    }
                }

                Section("Change To") {
                    ForEach(item.status.availableActions, id: \.self) { action in
                        Button {
                            selectAction(action)
                        } label: {
                            HStack {
                                Image(systemName: StatusActionHelper.icon(for: action))
                                    .foregroundStyle(StatusActionHelper.color(for: action))
                                    .frame(width: 24)
                                    .accessibilityHidden(true)
                                Text(StatusActionHelper.label(for: action))
                                    .foregroundStyle(.textPrimary)
                                Spacer()
                                if selectedAction == action {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.brand)
                                        .accessibilityLabel("Selected")
                                }
                            }
                        }
                    }
                }

                if !selectedAction.isEmpty {
                    if selectedAction == "pause" {
                        Section("Auto-Resume Date (Optional)") {
                            DatePicker("Resume on", selection: $autoResumeDate, displayedComponents: .date)
                        }
                    }

                    if let historicalEffectiveDateSectionTitle {
                        Section(historicalEffectiveDateSectionTitle) {
                            DatePicker(
                                "Effective",
                                selection: $effectiveDate,
                                in: historicalEffectiveDateRange,
                                displayedComponents: .date
                            )
                        }
                    }

                    if selectedAction == "start_trial" {
                        Section("Trial End Date") {
                            DatePicker("Ends on", selection: $effectiveDate, displayedComponents: .date)
                        }
                    }

                    Section("Details (Optional)") {
                        TextField("Reason", text: $reason)
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.accentRed)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Change Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.brand)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Confirm") {
                        Task { await executeChange() }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.brand)
                    .disabled(selectedAction.isEmpty || isLoading)
                }
            }
        }
        .sensoryFeedback(.success, trigger: changeSucceeded)
        .presentationDetents([.medium, .large])
    }

    private func executeChange() async {
        guard let userId = authService.currentUser?.id.uuidString else { return }
        isLoading = true
        error = nil

        let statusData = StatusChangeData(
            action: selectedAction,
            effectiveDate: selectedActionUsesEffectiveDate ? effectiveDate : nil,
            reason: reason.isEmpty ? nil : reason,
            notes: notes.isEmpty ? nil : notes,
            autoResumeDate: selectedAction == "pause" ? autoResumeDate : nil
        )

        do {
            _ = try await itemService.executeStatusChange(
                id: item.id,
                userId: userId,
                statusData: statusData
            )
            await onStatusChanged?()
            changeSucceeded = true
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func selectAction(_ action: String) {
        selectedAction = action

        switch action {
        case "cancel", "edit_cancellation":
            effectiveDate = clampedEffectiveDate(item.cancellationDateFormatted ?? Date.now, for: action)
        case "resume", "reactivate", "convert_trial":
            effectiveDate = clampedEffectiveDate(Date.now, for: action)
        case "start_trial":
            effectiveDate = item.trialEndDateFormatted ?? Date.now
        default:
            break
        }
    }

    private var selectedActionUsesEffectiveDate: Bool {
        switch selectedAction {
        case "cancel", "edit_cancellation", "resume", "reactivate", "convert_trial", "start_trial":
            return true
        default:
            return false
        }
    }

    private var historicalEffectiveDateSectionTitle: String? {
        switch selectedAction {
        case "cancel", "edit_cancellation":
            return "Cancellation Date"
        case "resume":
            return "Resume Date"
        case "reactivate":
            return "Reactivation Date"
        case "convert_trial":
            return "Conversion Date"
        default:
            return nil
        }
    }

    private var historicalEffectiveDateRange: ClosedRange<Date> {
        let lowerBound = min(item.minimumEffectiveDate(for: selectedAction) ?? Date.distantPast, Date.now)
        return lowerBound...Date.now
    }

    private func clampedEffectiveDate(_ preferredDate: Date, for action: String) -> Date {
        let minimumDate = item.minimumEffectiveDate(for: action) ?? Date.distantPast
        return max(minimumDate, min(preferredDate, Date.now))
    }

}
