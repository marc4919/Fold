import SwiftUI

/// La Forja: crear piezas del workspace. Rejilla ⇄ preview con morphing.
struct ForgeSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selected: ForgePieceKind?
    @State private var pieceName = ""
    @State private var pieceDescription = ""
    @Namespace private var forgeNamespace

    var body: some View {
        VStack(spacing: 0) {
            if let kind = selected {
                preview(kind)
                    .transition(.opacity)
            } else {
                grid
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            Text("No necesitas la Forja para usar la app. Todo tiene defaults que funcionan — entra aquí solo cuando quieras moldear las piezas.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(14)
        }
        .frame(minWidth: 760, idealWidth: 820, minHeight: 560, idealHeight: 600)
        .animation(.smooth(duration: 0.3), value: selected)
    }

    // MARK: - Rejilla

    private var grid: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    (Text("¿Qué quieres ")
                     + Text("forjar").italic().foregroundStyle(Color.foldAction)
                     + Text("?"))
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                    Text("Las piezas con las que tu workspace piensa y trabaja.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                closeButton
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(ForgePieceKind.allCases) { kind in
                    Button {
                        selected = kind
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: kind.icon)
                                .font(.title3)
                                .foregroundStyle(Color.foldAction)
                                .frame(width: 36, height: 36)
                                .background(Color.foldAction.opacity(0.12), in: .rect(cornerRadius: 9))
                                .matchedGeometryEffect(id: kind.id, in: forgeNamespace)

                            HStack(spacing: 6) {
                                Text(kind.title)
                                    .font(.headline)
                                if kind.isAdvanced {
                                    Text("avanzado")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary.opacity(0.6), in: .capsule)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(kind.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)

                            Text(kind.location)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
                        .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
                        .foldCardBorder()
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
    }

    // MARK: - Preview

    private func preview(_ kind: ForgePieceKind) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button {
                    selected = nil
                } label: {
                    Label("volver a la Forja", systemImage: "chevron.left")
                        .font(.callout)
                }
                .buttonStyle(.glass)
                Spacer()
                closeButton
            }

            HStack(spacing: 12) {
                Image(systemName: kind.icon)
                    .font(.title2)
                    .foregroundStyle(Color.foldAction)
                    .frame(width: 44, height: 44)
                    .background(Color.foldAction.opacity(0.12), in: .rect(cornerRadius: 10))
                    .matchedGeometryEffect(id: kind.id, in: forgeNamespace)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.title3.weight(.semibold))
                    Text(kind.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: String(localized: "Así quedaría"), pills: [kind.location])
                    Text(kind.previewExample)
                        .font(.caption.monospaced())
                        .lineSpacing(3)
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
                        .foldCardBorder()
                }

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Nombre de la pieza", text: $pieceName)
                        .textFieldStyle(.plain)
                        .padding(9)
                        .background(.background.secondary, in: .rect(cornerRadius: 8))

                    TextField("Descripción (opcional)", text: $pieceDescription, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2...4)
                        .padding(9)
                        .background(.background.secondary, in: .rect(cornerRadius: 8))

                    Button {
                        createPiece(kind)
                    } label: {
                        HStack {
                            Text("Crear esta pieza")
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(pieceName.trimmingCharacters(in: .whitespaces).isEmpty || kind == .schema)

                    Button("Elegir otra") { selected = nil }
                        .buttonStyle(.glass)
                        .frame(maxWidth: .infinity)

                    Text(kind == .schema
                         ? "Los esquemas personalizados llegarán con la integración ACP."
                         : "Se escribirá como archivo plano en el repo, versionado con git.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 220)
            }
        }
        .padding(24)
    }

    /// Escribe la pieza como archivo plano en el repo.
    private func createPiece(_ kind: ForgePieceKind) {
        let name = pieceName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        guard let root = appState.projectURL else {
            appState.toasts.show(String(localized: "En la demo la Forja no escribe — abre un proyecto real"))
            return
        }
        do {
            let path = try PiecesService.create(
                kind: kind, name: name, description: pieceDescription, at: root
            )
            appState.refreshRealProject()
            appState.toasts.show(String(localized: "\(kind.title) creada en \(path)"))
            pieceName = ""
            pieceDescription = ""
            dismiss()
        } catch {
            appState.toasts.show(error.localizedDescription)
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
