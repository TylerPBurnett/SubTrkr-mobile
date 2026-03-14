# Accessibility Audit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make SubTrkr pass Apple App Store accessibility review by adding VoiceOver labels to all interactive/decorative icons and converting all fixed font sizes to Dynamic Type semantic equivalents.

**Architecture:** Two categories of changes, applied file-by-file — (1) VoiceOver: `.accessibilityHidden(true)` on decorative icons, `.accessibilityLabel()` on interactive/informational ones, `.accessibilityElement(children: .combine)` on compound elements; (2) Dynamic Type: replace `.system(size: N)` fixed sizes with semantic equivalents like `.system(.title2)` while preserving `design:` and `weight:`.

**Tech Stack:** SwiftUI, iOS 18+, no test suite (build verification only)

---

## Build command (use after each commit to verify)

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C81C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```

Expected output ends with: `** BUILD SUCCEEDED **`

---

### Task 1: StatusBadge — VoiceOver + Dynamic Type

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Components/StatusBadge.swift`

The badge combines an icon + text to convey status. Wrap the HStack so VoiceOver reads it as a single element. Also fix the two fixed font sizes.

**Step 1: Open the file and make all changes**

Replace the entire `body`:

```swift
var body: some View {
    HStack(spacing: 4) {
        Image(systemName: status.iconName)
            .font(.system(.caption2))
            .accessibilityHidden(true)
        Text(status.displayName)
            .font(.system(.caption, weight: .semibold))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.forStatusMuted(status))
    .foregroundStyle(Color.forStatus(status))
    .clipShape(Capsule())
    .lineLimit(1)
    .minimumScaleFactor(0.75)
    .fixedSize(horizontal: true, vertical: false)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Status: \(status.displayName)")
}
```

Changes made:
- `Image` gets `.accessibilityHidden(true)` (icon is decorative, status communicated by label)
- `.system(size: 9)` → `.system(.caption2)`
- `.system(size: 11, weight: .semibold)` → `.system(.caption, weight: .semibold)`
- `.accessibilityElement(children: .combine)` + `.accessibilityLabel(...)` on the container
- `.lineLimit(1)` + `.minimumScaleFactor(0.75)` + `.fixedSize(horizontal: true, vertical: false)` to handle large accessibility text sizes without breaking the pill layout

**Step 2: Build and verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C81C' \
  -derivedDataPath /tmp/SubTrkr-build build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Components/StatusBadge.swift
git commit -m "fix(a11y): StatusBadge VoiceOver label and Dynamic Type fonts"
```

---

### Task 2: EmptyState — VoiceOver + Dynamic Type

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Components/EmptyState.swift`

**Step 1: Apply changes**

Three changes in the body:

1. After `Image(systemName: icon)`, add `.accessibilityHidden(true)`
2. After `.font(.system(size: 48))`, change to `.font(.system(.largeTitle))`
3. The `+` image inside the Button is decorative because the button has a text label — add `.accessibilityHidden(true)` to it

Result:

```swift
var body: some View {
    VStack(spacing: 16) {
        Image(systemName: icon)
            .font(.system(.largeTitle))
            .foregroundStyle(.textMuted)
            .accessibilityHidden(true)

        VStack(spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }

        if let actionLabel, let action {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .accessibilityHidden(true)
                    Text(actionLabel)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.brand)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
        }
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

**Step 2: Build and verify** (same build command as Task 1)

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Components/EmptyState.swift
git commit -m "fix(a11y): EmptyState hide decorative icon, Dynamic Type font"
```

---

### Task 3: CurrencyText — Dynamic Type

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Components/CurrencyText.swift`

Only the `.large` case uses a fixed size. Change line 22:

**Step 1: Apply change**

```swift
case .large:
    Text(amount.formatted(currency: currency))
        .font(.system(.title2, design: .monospaced))
        .fontWeight(.bold)
```

(`.system(size: 28, weight: .bold, design: .monospaced)` → `.system(.title2, design: .monospaced).fontWeight(.bold)`)

**Step 2: Build and verify**

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Components/CurrencyText.swift
git commit -m "fix(a11y): CurrencyText large style uses Dynamic Type"
```

---

### Task 4: ContentView — VoiceOver + Dynamic Type (launch screen)

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/ContentView.swift`

The launch/loading screen (shown while auth is initializing) has a decorative creditcard icon and a fixed-size title. Read the file first to find the exact lines, then:

**Step 1: Find and update the launch screen section**

The launch screen is inside an `else` branch of the auth loading state. Look for:
```swift
Image(systemName: "creditcard.fill")
    .font(.system(size: 56))
```

Change to:
```swift
Image(systemName: "creditcard.fill")
    .font(.system(.largeTitle))
    .accessibilityHidden(true)
```

And find the app name text with fixed size:
```swift
.font(.system(size: 32, weight: .bold, design: .rounded))
```

Change to:
```swift
.font(.system(.title, design: .rounded))
.fontWeight(.bold)
```

**Step 2: Build and verify**

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Views/ContentView.swift
git commit -m "fix(a11y): ContentView launch screen VoiceOver and Dynamic Type"
```

---

### Task 5: ItemListView — VoiceOver

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Items/ItemListView.swift`

Four changes across two sections of the file.

**Step 1: Fix filterButton (around line 136)**

```swift
private var filterButton: some View {
    Button { showFilters = true } label: {
        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            .foregroundStyle(hasActiveFilters ? .brand : .textSecondary)
    }
    .accessibilityLabel(hasActiveFilters ? "Filter, active" : "Filter")
}
```

**Step 2: Fix addButton (around line 143)**

```swift
private var addButton: some View {
    Button { showAddForm = true } label: {
        Image(systemName: "plus.circle.fill")
            .foregroundStyle(.brand)
    }
    .accessibilityLabel("Add \(viewModel.itemType.displayName.lowercased())")
}
```

**Step 3: Fix FilterSheet — status section checkmarks (around line 228)**

The `checkmark` Image inside the status filter row is decorative (the row itself conveys selection via VoiceOver's selected trait if using a List row). Add `.accessibilityHidden(true)`:

```swift
if viewModel.selectedStatuses.contains(status) {
    Image(systemName: "checkmark")
        .foregroundStyle(.brand)
        .fontWeight(.semibold)
        .accessibilityHidden(true)
}
```

**Step 4: Fix FilterSheet — category and sort checkmarks/icons (around lines 252–283)**

Same pattern for the category checkmark and the sort section's option icon + direction arrow:

```swift
// Category selected checkmark (~line 252)
if viewModel.selectedCategoryIds.contains(category.id) {
    Image(systemName: "checkmark")
        .foregroundStyle(.brand)
        .fontWeight(.semibold)
        .accessibilityHidden(true)
}

// Sort option icon (~line 274)
Image(systemName: option.iconName)
    .foregroundStyle(.textSecondary)
    .frame(width: 24)
    .accessibilityHidden(true)

// Sort direction arrow (~line 281)
if viewModel.sortOption == option {
    Image(systemName: viewModel.sortAscending ? "arrow.up" : "arrow.down")
        .foregroundStyle(.brand)
        .fontWeight(.semibold)
        .accessibilityHidden(true)
}
```

**Step 5: Build and verify**

**Step 6: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Items/ItemListView.swift
git commit -m "fix(a11y): ItemListView filter/add button labels, decorative icon hiding"
```

---

### Task 6: ItemDetailView — VoiceOver + Dynamic Type

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Items/ItemDetailView.swift`

**Step 1: Fix ellipsis.circle menu button (around line 55)**

```swift
} label: {
    Image(systemName: "ellipsis.circle")
        .foregroundStyle(.brand)
}
.accessibilityLabel("More options")
```

**Step 2: Fix hero amount font (around line 145)**

```swift
Text(currentItem.amount.formatted(currency: currentItem.currency))
    .font(.system(.title, design: .monospaced))
    .fontWeight(.heavy)
    .foregroundStyle(.textPrimary)
```

**Step 3: Fix dollarsign and calendar icons in the payment sheet (around lines 88–99)**

```swift
Image(systemName: "dollarsign.circle.fill")
    .foregroundStyle(.brand)
    .frame(width: 24)
    .accessibilityHidden(true)
```

```swift
Image(systemName: "calendar")
    .foregroundStyle(.brand)
    .frame(width: 24)
    .accessibilityHidden(true)
```

**Step 4: Fix status action button icon + font (around lines 222–224)**

The action buttons have both an icon and a text label. Hide the icon; fix the font size:

```swift
VStack(spacing: 6) {
    Image(systemName: StatusActionHelper.icon(for: action))
        .font(.system(.body))
        .accessibilityHidden(true)
    Text(StatusActionHelper.label(for: action))
        .font(.caption2.weight(.medium))
}
```

**Step 5: Fix payment history status icon**

Search for the section that renders payment history rows (around line 325). Find `Image(systemName: entry.status.iconName)` and add `.accessibilityHidden(true)`.

**Step 6: Build and verify**

**Step 7: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Items/ItemDetailView.swift
git commit -m "fix(a11y): ItemDetailView VoiceOver labels and Dynamic Type fonts"
```

---

### Task 7: StatusChangeSheet — VoiceOver

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Items/StatusChangeSheet.swift`

**Step 1: Hide action option icons (around line 45)**

```swift
Image(systemName: StatusActionHelper.icon(for: action))
    .foregroundStyle(StatusActionHelper.color(for: action))
    .frame(width: 24)
    .accessibilityHidden(true)
```

**Step 2: Fix selected checkmark (around line 52)**

```swift
if selectedAction == action {
    Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.brand)
        .accessibilityLabel("Selected")
}
```

**Step 3: Build and verify**

**Step 4: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Items/StatusChangeSheet.swift
git commit -m "fix(a11y): StatusChangeSheet hide decorative icons, label selected state"
```

---

### Task 8: ItemFormView — VoiceOver

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Items/ItemFormView.swift`

All 12 form field icons are purely decorative — adjacent text labels (field names and placeholders) already describe the fields. Add `.accessibilityHidden(true)` to each.

**Step 1: Read the file to identify all SF Symbol images**

Read `SubTrkr/SubTrkr/Views/Items/ItemFormView.swift` and find all `Image(systemName:)` calls. They appear near lines: 82, 124, 131, 144, 165, 177, 189, 221, 240, 256, 265, 285.

**Step 2: Add `.accessibilityHidden(true)` to each**

Pattern to apply to every one:

```swift
Image(systemName: "tag.fill")  // (replace with actual system name)
    .foregroundStyle(.brand)
    .frame(width: 24)
    .accessibilityHidden(true)
```

Do this for all 12 occurrences. The magnifying glass in the search bar (line 82) is also decorative — add `.accessibilityHidden(true)` there too.

**Step 3: Build and verify**

**Step 4: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Items/ItemFormView.swift
git commit -m "fix(a11y): ItemFormView hide all decorative form field icons"
```

---

### Task 9: AuthScreen — VoiceOver + Dynamic Type

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Auth/AuthScreen.swift`

**Step 1: Hide app logo icon + fix its font (around line 29)**

```swift
Image(systemName: "creditcard.fill")
    .font(.system(.largeTitle))
    .foregroundStyle(.brand)
    .accessibilityHidden(true)
```

**Step 2: Fix app title font (around line 34)**

```swift
.font(.system(.title, design: .rounded))
.fontWeight(.bold)
```

**Step 3: Hide error and success state icons (around lines 104, 115)**

```swift
Image(systemName: "exclamationmark.triangle.fill")
    .foregroundStyle(.accentAmber)
    .accessibilityHidden(true)
```

```swift
Image(systemName: "checkmark.circle.fill")
    .foregroundStyle(.brand)
    .accessibilityHidden(true)
```

**Step 4: Hide AuthTextField leading icon**

Search for `AuthTextField` struct (around line 319). Find `Image(systemName: icon)` and add `.accessibilityHidden(true)`.

**Step 5: Build and verify**

**Step 6: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Auth/AuthScreen.swift
git commit -m "fix(a11y): AuthScreen hide decorative icons, Dynamic Type fonts"
```

---

### Task 10: SettingsView — VoiceOver + Dynamic Type

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Settings/SettingsView.swift`

**Step 1: Fix profile avatar font (around line 41)**

```swift
.font(.system(.body, design: .rounded))
.fontWeight(.bold)
```

**Step 2: Fix verification shield icon (around line 51)**

The shield icon is informational (tells the user if their email is verified), so it needs a label, not hiding:

```swift
Image(systemName: authService.isEmailVerified ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
    .font(.caption2)
    .accessibilityLabel(authService.isEmailVerified ? "Email verified" : "Email not verified")
```

**Step 3: Fix color picker checkmarks (around lines 318, 386)**

Search for all `Image(systemName: "checkmark")` inside color picker sections and add `.accessibilityLabel("Selected")` to each:

```swift
Image(systemName: "checkmark")
    .accessibilityLabel("Selected")
```

**Step 4: Build and verify**

**Step 5: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Settings/SettingsView.swift
git commit -m "fix(a11y): SettingsView verification shield label, Dynamic Type font"
```

---

### Task 11: CalendarView — VoiceOver + Dynamic Type

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Dashboard/CalendarView.swift`

This is the most involved task. Three separate components need changes.

**Step 1: CalendarHeader — add button labels (around lines 166–188)**

```swift
Button(action: onPrevious) {
    Image(systemName: "chevron.left")
        .font(.body.weight(.semibold))
        .foregroundStyle(.brand)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
}
.accessibilityLabel("Previous month")

// ... Spacer + title Text ...

Button(action: onNext) {
    Image(systemName: "chevron.right")
        .font(.body.weight(.semibold))
        .foregroundStyle(.brand)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
}
.accessibilityLabel("Next month")
```

**Step 2: CalendarDayCell — add accessibility label and traits (around lines 195–241)**

Add a static formatter and a computed label property to `CalendarDayCell`, then apply to the view:

```swift
struct CalendarDayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let dotColors: [String]

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private var accessibilityDateLabel: String {
        let dateStr = Self.dateFormatter.string(from: day.date)
        let count = dotColors.count
        guard count > 0 else { return dateStr }
        return "\(dateStr), \(count) payment\(count == 1 ? "" : "s") due"
    }

    var body: some View {
        VStack(spacing: 4) {
            // ... existing ZStack and dot indicators unchanged ...
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityDateLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
```

Note: `.isSelected` accessibility trait communicates selection state to VoiceOver.

**Step 3: Hide dot indicator circles**

The colored dots inside `CalendarDayCell` are decorative (their info is in the accessibility label). Wrap the dot `ForEach` in an `accessibilityHidden` container:

```swift
HStack(spacing: 2) {
    ForEach(Array(dotColors.enumerated()), id: \.offset) { _, color in
        Circle()
            .fill(Color(hex: color))
            .frame(width: 4, height: 4)
    }
}
.frame(height: 4)
.accessibilityHidden(true)
```

**Step 4: Hide the day detail empty state icon (around line 122)**

```swift
Image(systemName: "calendar.badge.minus")
    .font(.title2)
    .foregroundStyle(.textMuted)
    .accessibilityHidden(true)
```

**Step 5: MonthSummaryCard — fix Dynamic Type fonts (around lines 291, 303)**

```swift
// Month total
Text(total.formatted(currency: "USD"))
    .font(.system(.headline, design: .monospaced))
    .fontWeight(.heavy)
    .foregroundStyle(.textPrimary)

// Payment count
Text("\(itemCount)")
    .font(.system(.headline, design: .monospaced))
    .fontWeight(.heavy)
    .foregroundStyle(.textPrimary)
```

**Step 6: Build and verify**

**Step 7: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Dashboard/CalendarView.swift
git commit -m "fix(a11y): CalendarView nav labels, day cell accessibility, Dynamic Type"
```

---

### Task 12: DashboardView — VoiceOver + Dynamic Type

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Dashboard/DashboardView.swift`

**Step 1: StatsCard — hide icon, fix Dynamic Type font (around lines 187–197)**

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Image(systemName: icon)
                .font(.system(.caption))
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }

        Text(value)
            .font(.system(.headline, design: .monospaced))
            .fontWeight(.heavy)
            .foregroundStyle(.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

        // ... subtitle unchanged ...
    }
```

**Step 2: Category chart legend — hide dot circles (around line 130)**

```swift
Circle()
    .fill(Color(hex: category.color))
    .frame(width: 10, height: 10)
    .accessibilityHidden(true)
```

**Step 3: Build and verify**

**Step 4: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Dashboard/DashboardView.swift
git commit -m "fix(a11y): DashboardView hide decorative icons, Dynamic Type fonts"
```

---

### Task 13: AnalyticsView — VoiceOver

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Analytics/AnalyticsView.swift`

**Step 1: Error banner — hide warning icon, label dismiss button (around lines 128–141)**

```swift
Image(systemName: "exclamationmark.triangle.fill")
    .foregroundStyle(.accentAmber)
    .accessibilityHidden(true)

// ...

Button {
    viewModel.error = nil
} label: {
    Image(systemName: "xmark")
        .font(.caption2.weight(.bold))
        .foregroundStyle(.textMuted)
}
.accessibilityLabel("Dismiss")
```

**Step 2: Fix Dynamic Type font for analytics values**

Search for `.system(size: 18, weight: .heavy, design: .monospaced)` (around line 674) and change to:

```swift
.font(.system(.body, design: .monospaced))
.fontWeight(.heavy)
```

**Step 3: Hide empty state icon (around line 302)**

```swift
Image(systemName: "chart.line.uptrend.xyaxis")
    .foregroundStyle(.textMuted)
    .accessibilityHidden(true)
```

**Step 4: Hide chart legend dots**

Search for legend `Circle()` fills (around line 440) and add `.accessibilityHidden(true)` to each.

**Step 5: Build and verify**

**Step 6: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Analytics/AnalyticsView.swift
git commit -m "fix(a11y): AnalyticsView hide decorative icons, label dismiss, Dynamic Type"
```

---

### Task 14: Final verification build

**Step 1: Clean build**

```bash
rm -rf /tmp/SubTrkr-build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C81C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 2: Manual VoiceOver spot-check (simulator)**

Install and launch:
```bash
xcrun simctl install 7E4DF3CA-3821-43D5-8444-DB0ECB82C81C \
  /tmp/SubTrkr-build/Build/Products/Debug-iphonesimulator/SubTrkr.app
xcrun simctl launch 7E4DF3CA-3821-43D5-8444-DB0ECB82C81C com.subtrkr.app
```

Enable VoiceOver in the simulator via Settings → Accessibility → VoiceOver, then check:
- [ ] Tab bar items announce correctly
- [ ] ItemList filter and add buttons are announced with labels
- [ ] Status badges announce "Status: Active" (etc.), not two separate elements
- [ ] Calendar prev/next buttons announce "Previous month" / "Next month"
- [ ] Calendar day cells announce date + payment count

**Step 3: Update ROADMAP.md**

Mark accessibility audit as complete in `docs/ROADMAP.md`.
