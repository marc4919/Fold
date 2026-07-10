import SwiftUI

/// Chip seleccionable (roles del onboarding, filtros de memoria).
/// Pensado para usarse dentro de un `GlassEffectContainer`.
struct SelectableChip: View {
    let label: String
    let isSelected: Bool
    var tint: Color = .accentColor
    var count: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                if let count {
                    Text("\(count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .background {
            if !isSelected {
                Capsule().fill(.quaternary.opacity(0.5))
            }
        }
        .glassEffect(
            isSelected ? .regular.tint(tint.opacity(0.55)).interactive() : .identity,
            in: .capsule
        )
        .animation(.smooth(duration: 0.2), value: isSelected)
        // Selección expuesta como trait: el estado no depende solo del tinte.
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
