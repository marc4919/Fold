import SwiftUI
import AppKit

/// Card de una entrada de memoria.
struct MemoryCardView: View {
    @Environment(AppState.self) private var appState
    let entry: MemoryEntry

    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(entry.title)
                    .font(.system(.title3, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text(entry.kind.label)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(entry.kind.tint.opacity(0.14), in: .capsule)
                    .foregroundStyle(entry.kind.tint)
            }

            Text(LocalizedStringKey(entry.body))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Text(entry.source)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Text("·")
                    .foregroundStyle(.quaternary)
                Text(entry.dateLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(entry.linkLabel) {
                    openEntry()
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(Color.foldMemory)

                Menu {
                    entryActions
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(String(localized: "Renombrar o eliminar la entrada"))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
        .foldCardBorder(.foldMemory)
        .contextMenu {
            entryActions
        }
        .alert("Renombrar entrada", isPresented: $showRename) {
            TextField("Nuevo nombre", text: $renameText)
            Button("Renombrar") { renameEntry() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se renombra el archivo en .workspace/memory/ y su título.")
        }
        .confirmationDialog(
            "¿Eliminar «\(entry.title)»?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar del repo", role: .destructive) { deleteEntry() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borra el archivo (y su adjunto, si lo tiene). Los agentes dejarán de leerlo.")
        }
    }

    @ViewBuilder
    private var entryActions: some View {
        Button {
            renameText = entry.title
            showRename = true
        } label: {
            Label("Renombrar", systemImage: "pencil")
        }
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("Eliminar", systemImage: "trash")
        }
    }

    private func renameEntry() {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        guard let root = appState.projectURL else {
            appState.toasts.show(String(localized: "En la demo la memoria es de solo lectura"))
            return
        }
        do {
            try MemoryService.rename(entry: entry, to: name, at: root)
            appState.refreshRealProject()
            appState.toasts.show(String(localized: "Entrada renombrada a «\(name)»"))
        } catch {
            appState.toasts.show(String(localized: "No se pudo renombrar: \(error.localizedDescription)"))
        }
    }

    private func deleteEntry() {
        guard let root = appState.projectURL else {
            appState.toasts.show(String(localized: "En la demo la memoria es de solo lectura"))
            return
        }
        do {
            try MemoryService.delete(entry: entry, at: root)
            appState.refreshRealProject()
            appState.toasts.show(String(localized: "«\(entry.title)» eliminada de la memoria"))
        } catch {
            appState.toasts.show(String(localized: "No se pudo eliminar: \(error.localizedDescription)"))
        }
    }

    /// Abre el archivo real de la entrada (en proyectos reales, source es una ruta relativa).
    private func openEntry() {
        guard let root = appState.projectURL else {
            appState.toasts.show(String(localized: "(demo) Abriendo \(entry.source)…"))
            return
        }
        let url = root.appendingPathComponent(entry.source)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            appState.toasts.show(String(localized: "No se encontró \(entry.source)"))
        }
    }
}
