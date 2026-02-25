import SwiftUI

struct ItemListView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel: ItemListViewModel
    @State private var showAddForm = false
    @State private var selectedItem: Item?
    @State private var itemToDelete: Item?
    @State private var showDeleteAlert = false
    @State private var showFilters = false

    init(itemType: ItemType) {
        _viewModel = State(initialValue: ItemListViewModel(itemType: itemType))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    loadingView
                } else if viewModel.filteredItems.isEmpty {
                    emptyView
                } else {
                    itemsList
                }
            }
            .background(Color.bgBase)
            .navigationTitle(viewModel.itemType.pluralName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        filterButton
                        addButton
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.activeTotal > 0 {
                        Text(viewModel.activeTotal.formatted(currency: "USD") + "/mo")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundStyle(.brand)
                    }
                }
            }
            .searchable(text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.searchText = $0 }
            ), prompt: "Search \(viewModel.itemType.pluralName.lowercased())")
            .refreshable {
                await viewModel.loadData()
            }
            .sheet(isPresented: $showAddForm) {
                ItemFormView(
                    itemType: viewModel.itemType,
                    onSave: { await viewModel.loadData() }
                )
            }
            .sheet(item: $selectedItem) { item in
                ItemDetailView(
                    item: item,
                    onUpdate: { await viewModel.loadData() }
                )
            }
            .sheet(isPresented: $showFilters) {
                FilterSheet(viewModel: viewModel)
            }
            .alert("Delete \(itemToDelete?.name ?? "")?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete {
                        Task { await viewModel.deleteItem(item) }
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Items List

    private var itemsList: some View {
        List {
            ForEach(viewModel.filteredItems) { item in
                ItemRow(item: item)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedItem = item
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            itemToDelete = item
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.bgCard)
                    .frame(height: 72)
                    .shimmer()
            }
        }
        .padding()
    }

    private var emptyView: some View {
        EmptyStateView(
            icon: viewModel.itemType == .subscription ? "arrow.triangle.2.circlepath" : "doc.text",
            title: "No \(viewModel.itemType.pluralName.lowercased()) yet",
            message: "Add your first \(viewModel.itemType.displayName.lowercased()) to start tracking",
            actionLabel: "Add \(viewModel.itemType.displayName)",
            action: { showAddForm = true }
        )
    }

    private var filterButton: some View {
        Button { showFilters = true } label: {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .foregroundStyle(hasActiveFilters ? .brand : .textSecondary)
        }
    }

    private var addButton: some View {
        Button { showAddForm = true } label: {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.brand)
        }
    }

    private var hasActiveFilters: Bool {
        !viewModel.searchText.isEmpty ||
        !viewModel.selectedCategoryIds.isEmpty ||
        viewModel.selectedStatuses != [.active, .trial] ||
        viewModel.sortOption != .nextBillingDate
    }
}

// MARK: - Item Row

struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 14) {
            // Category color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: item.categoryColor))
                .frame(width: 4, height: 48)

            ServiceLogo(
                url: item.logoURL,
                name: item.name,
                categoryColor: item.categoryColor,
                size: 42
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    StatusBadge(status: item.status)

                    if let date = item.nextBillingDateFormatted {
                        Text(DateHelper.relativeDateString(date))
                            .font(.caption2)
                            .foregroundStyle(.textMuted)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(item.amount.formatted(currency: item.currency))
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.textPrimary)

                Text(item.billingCycle.displayName)
                    .font(.caption2)
                    .foregroundStyle(.textMuted)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .cardStyle(cornerRadius: 14)
    }
}

// MARK: - Filter Sheet

struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: ItemListViewModel

    var body: some View {
        NavigationStack {
            List {
                // Status Filters
                Section("Status") {
                    ForEach(ItemStatus.allCases) { status in
                        HStack {
                            StatusBadge(status: status)
                            Spacer()
                            if viewModel.selectedStatuses.contains(status) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.brand)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.toggleStatus(status)
                        }
                    }
                }

                // Category Filters
                if !viewModel.relevantCategories.isEmpty {
                    Section("Category") {
                        ForEach(viewModel.relevantCategories) { category in
                            HStack {
                                Circle()
                                    .fill(category.swiftColor)
                                    .frame(width: 10, height: 10)
                                Text(category.name)
                                    .foregroundStyle(.textPrimary)
                                Spacer()
                                if viewModel.selectedCategoryIds.contains(category.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.brand)
                                        .fontWeight(.semibold)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if viewModel.selectedCategoryIds.contains(category.id) {
                                    viewModel.selectedCategoryIds.remove(category.id)
                                } else {
                                    viewModel.selectedCategoryIds.insert(category.id)
                                }
                            }
                        }
                    }
                }

                // Sort
                Section("Sort By") {
                    ForEach(SortOption.allCases) { option in
                        HStack {
                            Image(systemName: option.iconName)
                                .foregroundStyle(.textSecondary)
                                .frame(width: 24)
                            Text(option.displayName)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            if viewModel.sortOption == option {
                                Image(systemName: viewModel.sortAscending ? "arrow.up" : "arrow.down")
                                    .foregroundStyle(.brand)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if viewModel.sortOption == option {
                                viewModel.sortAscending.toggle()
                            } else {
                                viewModel.sortOption = option
                                viewModel.sortAscending = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { viewModel.clearFilters() }
                        .foregroundStyle(.brand)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.brand)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.05), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: phase)
            )
            .onAppear { phase = 400 }
            .clipped()
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
