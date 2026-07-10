import SwiftUI

/// Cabecera de sección: label en mayúsculas + pills en mono.
struct SectionLabel: View {
    let title: String
    var pills: [String] = []

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.6)
            ForEach(pills, id: \.self) { pill in
                Text(pill)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary.opacity(0.6), in: .capsule)
            }
            Spacer()
        }
    }
}
