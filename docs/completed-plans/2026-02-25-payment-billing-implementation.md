# Record Payment UI & Auto-Calc Billing Date Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a "Record Payment" button + sheet in ItemDetailView with auto-advance of billing date, and auto-calculate nextBillingDate from startDate + billingCycle in the item form.

**Architecture:** Payment recording is a sheet in ItemDetailView that calls the existing PaymentService, then advances nextBillingDate via ItemService.updateItem. Auto-calc billing date is reactive logic in ItemFormViewModel triggered by onChange of startDate/billingCycle.

**Tech Stack:** SwiftUI, Supabase Swift SDK

---

### Task 1: Auto-Calculate Next Billing Date in Item Form

**Files:**
- Modify: `SubTrkr/SubTrkr/ViewModels/ItemFormViewModel.swift`

**Step 1: Add a tracking property and auto-calc method**

In `ItemFormViewModel`, after the `editingItem` property (line 29), add:

```swift
private var userEditedNextBillingDate = false
```

**Step 2: Add the computation method**

After the `isValid` computed property (around line 63), add:

```swift
func autoCalcNextBillingDate() {
    guard !isEditing, !userEditedNextBillingDate else { return }
    var date = startDate
    let now = Date.now
    // Roll forward until the date is in the future
    while date <= now {
        date = DateHelper.advanceDate(date, by: billingCycle)
    }
    nextBillingDate = date
}
```

**Step 3: Add onChange hooks in ItemFormView**

In `SubTrkr/SubTrkr/Views/Items/ItemFormView.swift`, on the `billingSection`, add onChange modifiers after the Start Date DatePicker (after line 193) and after the Billing Cycle Picker (after line 181).

Add these two onChange modifiers on the `billingSection` view. Replace the entire `billingSection` computed property:

```swift
private var billingSection: some View {
    Section("Billing") {
        Picker(selection: Binding(
            get: { viewModel.billingCycle },
            set: { viewModel.billingCycle = $0 }
        )) {
            ForEach(BillingCycle.allCases) { cycle in
                Text(cycle.displayName).tag(cycle)
            }
        } label: {
            HStack {
                Image(systemName: "repeat")
                    .foregroundStyle(.brand)
                    .frame(width: 24)
                Text("Billing Cycle")
            }
        }
        .onChange(of: viewModel.billingCycle) { _, _ in
            viewModel.autoCalcNextBillingDate()
        }

        DatePicker(selection: Binding(
            get: { viewModel.startDate },
            set: { viewModel.startDate = $0 }
        ), displayedComponents: .date) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.brand)
                    .frame(width: 24)
                Text("Start Date")
            }
        }
        .onChange(of: viewModel.startDate) { _, _ in
            viewModel.autoCalcNextBillingDate()
        }

        DatePicker(selection: Binding(
            get: { viewModel.nextBillingDate },
            set: {
                viewModel.nextBillingDate = $0
                viewModel.userEditedNextBillingDate = true
            }
        ), displayedComponents: .date) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.brand)
                    .frame(width: 24)
                Text("Next Billing Date")
            }
        }
    }
}
```

Key changes from original:
- `onChange(of: viewModel.billingCycle)` triggers auto-calc
- `onChange(of: viewModel.startDate)` triggers auto-calc
- Next Billing Date setter now also sets `viewModel.userEditedNextBillingDate = true` to prevent overriding manual edits

Note: `userEditedNextBillingDate` needs to be changed from `private` to just `var` so the view can set it:

```swift
var userEditedNextBillingDate = false
```

**Step 4: Verify build succeeds**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add SubTrkr/SubTrkr/ViewModels/ItemFormViewModel.swift SubTrkr/SubTrkr/Views/Items/ItemFormView.swift
git commit -m "feat: auto-calculate next billing date from start date + billing cycle

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Add Record Payment Sheet to ItemDetailView

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Items/ItemDetailView.swift`

**Step 1: Add state properties for the payment sheet**

After the existing `@State` properties (after line 14), add:

```swift
@State private var showPaymentSheet = false
@State private var paymentAmount: Double = 0
@State private var paymentDate = Date.now
@State private var isRecordingPayment = false
```

**Step 2: Add "Record Payment" button to the payment history section**

Replace the `paymentHistorySection` with this version that adds a button:

```swift
private var paymentHistorySection: some View {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Text("Payment History")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.textSecondary)

            Spacer()

            if currentItem.status == .active || currentItem.status == .trial {
                Button {
                    paymentAmount = currentItem.amount
                    paymentDate = Date.now
                    showPaymentSheet = true
                } label: {
                    Label("Record Payment", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.brand)
                }
            }
        }

        if payments.isEmpty {
            Text("No payments recorded yet")
                .font(.caption)
                .foregroundStyle(.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            ForEach(payments.prefix(10)) { payment in
                HStack {
                    if let date = payment.paidDateFormatted {
                        Text({
                            let f = DateFormatter()
                            f.dateStyle = .medium
                            return f.string(from: date)
                        }())
                        .font(.subheadline)
                        .foregroundStyle(.textSecondary)
                    }
                    Spacer()
                    Text(payment.amount.formatted(currency: currentItem.currency))
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundStyle(.textPrimary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .cardStyle(cornerRadius: 14)
}
```

**Step 3: Add the payment sheet**

After the `.sheet(isPresented: $showStatusSheet)` block (after line 74), add the payment sheet:

```swift
.sheet(isPresented: $showPaymentSheet) {
    NavigationStack {
        Form {
            Section("Payment Details") {
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(.brand)
                        .frame(width: 24)
                    TextField("Amount", value: $paymentAmount, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                }

                DatePicker(selection: $paymentDate, displayedComponents: .date) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.brand)
                            .frame(width: 24)
                        Text("Date")
                    }
                }
            }
        }
        .navigationTitle("Record Payment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { showPaymentSheet = false }
                    .foregroundStyle(.brand)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task { await recordPayment() }
                }
                .fontWeight(.semibold)
                .foregroundStyle(.brand)
                .disabled(paymentAmount <= 0 || isRecordingPayment)
            }
        }
    }
    .presentationDetents([.medium])
}
```

**Step 4: Add the recordPayment method**

After the `loadPayments()` method (after line 306), add:

```swift
private func recordPayment() async {
    guard let userId = authService.currentUser?.id.uuidString else { return }
    isRecordingPayment = true

    do {
        // Record the payment
        _ = try await PaymentService().recordPayment(
            userId: userId,
            itemId: currentItem.id,
            amount: paymentAmount,
            paidDate: paymentDate
        )

        // Auto-advance next billing date by one cycle
        if let currentDate = currentItem.nextBillingDateFormatted {
            let nextDate = DateHelper.advanceDate(currentDate, by: currentItem.billingCycle)
            let update = ItemUpdate(nextBillingDate: DateHelper.formatDate(nextDate))
            _ = try await ItemService().updateItem(id: currentItem.id, data: update)
        }

        // Refresh data
        await refreshItem()
        await loadPayments()
        await onUpdate?()
        showPaymentSheet = false
    } catch {
        // Payment failed — sheet stays open so user can retry
    }

    isRecordingPayment = false
}
```

**Step 5: Verify build succeeds**

Run the build command. Expected: `** BUILD SUCCEEDED **`

**Step 6: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Items/ItemDetailView.swift
git commit -m "feat: add Record Payment sheet with auto-advance billing date

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Final Build Verification

**Step 1: Clean build**

```bash
rm -rf /tmp/SubTrkr-build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 2: Review all changes**

```bash
git log --oneline -3
git diff HEAD~2 --stat
```

Verify 2 feature commits: auto-calc billing date, record payment sheet.

---

## Summary

| File | What Changed |
|------|-------------|
| `ViewModels/ItemFormViewModel.swift` | `autoCalcNextBillingDate()` method, `userEditedNextBillingDate` flag |
| `Views/Items/ItemFormView.swift` | `onChange` on startDate, billingCycle, and nextBillingDate pickers |
| `Views/Items/ItemDetailView.swift` | "Record Payment" button, payment sheet, `recordPayment()` with auto-advance |
