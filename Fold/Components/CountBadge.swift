import SwiftUI

/// Badge compacto de conteo (tabs, sidebar, listas).
struct CountBadge: View {
    let value: Int
    var tint: Color = .secondary

    var body: some View {
        Text("\(value)")
            .font(.caption2.weight(.semibold).monospacedDigit())
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15), in: .capsule)
    }
}
