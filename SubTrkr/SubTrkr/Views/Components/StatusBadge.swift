import SwiftUI

struct StatusBadge: View {
    let status: ItemStatus

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.displayName)
    }
}
