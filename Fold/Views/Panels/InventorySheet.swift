import SwiftUI

/// El Inventario: las piezas que el proyecto ya tiene, agrupadas por tipo.
/// En proyectos reales se lee del repo (.workspace/skills, CLAUDE.md, agentes activos).
struct InventorySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selected: InventoryPiece?
    @State private var groups: [InventoryGroup] = []

    var body: some View {
        VStack(spacing: 0) {
            if let piece = selected {
                preview(piece)
                    .transition(.opacity)
            } else {
                listing
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 720, idealWidth: 780, minHeight: 540, idealHeight: 600)
        .animation(.smooth(duration: 0.3), value: selected?.id)
        .onAppear {
            if let root = appState.projectURL {
                groups = PiecesService.inventory(at: root, agents: appState.detectedAgents)
            } else {
                groups = SampleData.inventoryGroups
            }
        }
    }

    private var listing: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inventario")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                    Text("Todo lo que el proyecto ya tiene. Pulsa una pieza para ver cómo está definida.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                closeButton
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(title: group.title, pills: ["\(group.pieces.count)"])

                            if group.pieces.isEmpty {
                                Text("Nada forjado todavía — crea la primera pieza desde la Forja.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.vertical, 4)
                            }

                            VStack(spacing: 6) {
                                ForEach(group.pieces) { piece in
                                    Button {
                                        selected = piece
                                    } label: {
                                        HStack(spacing: 10) {
                                            Text(piece.name)
                                                .font(.callout.weight(.medium).monospaced())
                                            Text(piece.detail)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                            Spacer()
                                            ForEach(piece.badges, id: \.self) { badge in
                                                Text(badge)
                                                    .font(.caption2.weight(.semibold))
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 2)
                                                    .background(badgeTint(badge).opacity(0.14), in: .capsule)
                                                    .foregroundStyle(badgeTint(badge))
                                            }
                                            Image(systemName: "chevron.right")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(12)
                                        .background(.background.secondary, in: .rect(cornerRadius: 10))
                                        .contentShape(.rect)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(24)
    }

    private func preview(_ piece: InventoryPiece) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button {
                    selected = nil
                } label: {
                    Label("volver al Inventario", systemImage: "chevron.left")
                        .font(.callout)
                }
                .buttonStyle(.glass)
                Spacer()
                closeButton
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(piece.name)
                    .font(.title3.weight(.semibold).monospaced())
                Text(piece.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text(piece.previewText)
                .font(.caption.monospaced())
                .lineSpacing(3)
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
                .foldCardBorder()
        }
        .padding(24)
    }

    private func badgeTint(_ badge: String) -> Color {
        switch badge {
        case "bloqueante": .foldDanger
        case "core": .foldInfo
        case "default": .foldAction
        default: .foldSuccess
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .keyboardShortcut(.cancelAction)
    }
}

extension InventoryPiece: Equatable {
    static func == (lhs: InventoryPiece, rhs: InventoryPiece) -> Bool {
        lhs.id == rhs.id
    }
}
