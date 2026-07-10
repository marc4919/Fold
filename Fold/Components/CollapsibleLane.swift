import SwiftUI

/// Lane colapsable con cabecera de icono-letra + título + contador
/// (tab Revisión, etapas de historia).
struct CollapsibleLane<Content: View>: View {
    let iconLetter: String
    var iconTint: Color = .secondary
    let title: String
    var countLabel: String?
    var startsExpanded = true
    @ViewBuilder let content: () -> Content

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.smooth(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text(iconLetter)
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(iconTint)
                        .frame(width: 22, height: 22)
                        .background(iconTint.opacity(0.15), in: .rect(cornerRadius: 6))
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if let countLabel {
                        Text(countLabel)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(14)

            if isExpanded {
                content()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .transition(.opacity)
            }
        }
        .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
        .onAppear { isExpanded = startsExpanded }
    }
}
