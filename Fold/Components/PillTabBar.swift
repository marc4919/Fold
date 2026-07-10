import SwiftUI

/// Tab seleccionable en pill glass.
struct PillTab: Identifiable, Equatable {
    let id: String
    let label: String
    var number: Int?
    var badge: Int?
    var badgeTint: Color = .secondary
    var isCompleted = false
    var isLive = false
}

/// Barra de tabs como pills glass con morphing entre selecciones.
/// Se usa en el Hub (3 tabs) y en el dashboard del change (5 tabs progresivas).
struct PillTabBar: View {
    let tabs: [PillTab]
    @Binding var selection: String

    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(tabs) { tab in
                    pill(tab)
                }
            }
        }
    }

    private func pill(_ tab: PillTab) -> some View {
        let isSelected = selection == tab.id
        return Button {
            withAnimation(.smooth(duration: 0.25)) { selection = tab.id }
        } label: {
            HStack(spacing: 7) {
                if let number = tab.number {
                    if tab.isCompleted, !isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.foldSuccess)
                    } else {
                        Text("\(number)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(isSelected ? .primary : .tertiary)
                    }
                }
                Text(tab.label)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                if let badge = tab.badge {
                    CountBadge(value: badge, tint: tab.badgeTint)
                }
                if tab.isLive {
                    StatusDot(kind: .running, pulses: true, size: 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.tint(Color.foldAction.opacity(0.4)).interactive() : .identity,
            in: .capsule
        )
        .glassEffectID(tab.id, in: glassNamespace)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}
