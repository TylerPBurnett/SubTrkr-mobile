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
                    ForEach(availableActions, id: \.self) { action in
                        Button {
                            selectedAction = action
                        } label: {
                            HStack {
                                Image(systemName: iconForAction(action))
                                    .foregroundStyle(colorForAction(action))
                                    .frame(width: 24)
                                Text(labelForAction(action))
                                    .foregroundStyle(.textPrimary)
                                Spacer()
                                if selectedAction == action {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.brand)
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

                    if selectedAction == "cancel" {
                        Section("Cancellation Date") {
                            DatePicker("Effective", selection: $effectiveDate, displayedComponents: .date)
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

    private var availableActions: [String] {
        switch item.status {
        case .active: return ["pause", "cancel", "archive", "start_trial"]
        case .paused: return ["resume", "cancel", "archive"]
        case .cancelled: return ["reactivate", "archive"]
        case .archived: return ["reactivate"]
        case .trial: return ["convert_trial", "cancel", "archive"]
        }
    }

    private func executeChange() async {
        guard let userId = authService.currentUser?.id.uuidString else { return }
        isLoading = true
        error = nil

        let statusData = StatusChangeData(
            action: selectedAction,
            effectiveDate: (selectedAction == "cancel" || selectedAction == "start_trial") ? effectiveDate : nil,
            reason: reason.isEmpty ? nil : reason,
            notes: notes.isEmpty ? nil : notes,
            autoResumeDate: selectedAction == "pause" ? autoResumeDate : nil
        )

        do {
            _ = try await ItemService().executeStatusChange(
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

    private func iconForAction(_ action: String) -> String {
        switch action {
        case "pause": return "pause.circle.fill"
        case "resume", "reactivate": return "play.circle.fill"
        case "cancel": return "xmark.circle.fill"
        case "archive": return "archivebox.fill"
        case "start_trial": return "clock.fill"
        case "convert_trial": return "checkmark.circle.fill"
        default: return "circle"
        }
    }

    private func colorForAction(_ action: String) -> Color {
        switch action {
        case "pause": return .statusPaused
        case "resume", "reactivate", "convert_trial": return .brand
        case "cancel": return .statusCancelled
        case "archive": return .statusArchived
        case "start_trial": return .statusTrial
        default: return .textSecondary
        }
    }

    private func labelForAction(_ action: String) -> String {
        switch action {
        case "pause": return "Pause"
        case "resume": return "Resume"
        case "reactivate": return "Reactivate"
        case "cancel": return "Cancel"
        case "archive": return "Archive"
        case "start_trial": return "Start Trial"
        case "convert_trial": return "Convert to Active"
        default: return action.capitalized
        }
    }
}
