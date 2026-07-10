import SwiftUI

/// Paso 1/3: nombre + chips multi-select de rol.
struct OnboardingStepWho: View {
    @Binding var name: String
    @Binding var roles: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Paso 1 de 3")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.foldAction)
                    .textCase(.uppercase)
                Text("¿Quién eres?")
                    .font(.largeTitle.weight(.semibold))
                Text("No tienes que aprenderte nada. Solo dinos cómo llamarte y a qué te dedicas.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            TextField("Tu nombre", text: $name, prompt: Text("Tu nombre"))
                .textFieldStyle(.plain)
                .font(.title2)
                .padding(16)
                .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
                .foldCardBorder()

            VStack(alignment: .leading, spacing: 12) {
                Text("Tu rol — combina los que quieras")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                GlassEffectContainer {
                    FlowChips(items: UserProfile.roleOptions) { role in
                        SelectableChip(label: role, isSelected: roles.contains(role)) {
                            if roles.contains(role) {
                                roles.remove(role)
                            } else {
                                roles.insert(role)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 48)
    }
}

/// Layout fluido sencillo para chips.
struct FlowChips<Item: Hashable, ChipView: View>: View {
    let items: [Item]
    @ViewBuilder let chip: (Item) -> ChipView

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                chip(item)
            }
        }
    }
}

/// Layout que envuelve a la siguiente línea cuando no cabe.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(proposal: proposal, subviews: subviews)
        for (subview, position) in zip(subviews, arrangement.positions) {
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x - spacing)
        }
        return (CGSize(width: totalWidth, height: y + rowHeight), positions)
    }
}
