import SwiftUI
import AppKit

/// La memoria del proyecto a pantalla completa: buscable y filtrable.
struct MemoryFullscreenView: View {
    @Environment(AppState.self) private var appState

    @State private var searchText = ""
    @State private var filter: MemoryEntry.Kind?
    @State private var showAddSheet = false

    private var allEntries: [MemoryEntry] {
        appState.memoryEntries
    }

    private var entries: [MemoryEntry] {
        allEntries.filter { entry in
            (filter == nil || entry.kind == filter)
            && (searchText.isEmpty
                || entry.title.localizedCaseInsensitiveContains(searchText)
                || entry.body.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                toolbar

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 330), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(entries) { entry in
                        MemoryCardView(entry: entry)
                    }
                }
                .animation(.smooth(duration: 0.25), value: entries.map(\.id))

                if entries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: allEntries.isEmpty ? "circle.lefthalf.filled" : "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text(allEntries.isEmpty
                             ? "La memoria está vacía. Se irá llenando con cada change archivado — o añade una entrada ahora."
                             : "Nada que coincida con la búsqueda")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                }
            }
            .padding(36)
            .frame(maxWidth: 1180, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background {
            LinearGradient(
                colors: [Color.foldMemory.opacity(0.09), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                appState.navigate(to: .workspace)
            } label: {
                Label(appState.activeProject?.name ?? "acme-api", systemImage: "chevron.left")
                    .font(.callout.monospaced())
            }
            .buttonStyle(.glass)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Memoria del proyecto")
                        .font(.system(size: 42, weight: .semibold, design: .serif))
                        .italic()
                    Text("El cerebro acumulado de `\(appState.activeProject?.name ?? "acme-api")`. Vive en `.workspace/memory/`, `CLAUDE.md` y `openspec/specs/`. Versionado por git, leído por los agentes en cada sesión.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 28) {
                    stat(value: "\(allEntries.count)", label: String(localized: "entradas"))
                    stat(
                        value: appState.isRealProject
                            ? "\(appState.openSpecState?.archivedCount ?? 0)"
                            : "17",
                        label: "archives"
                    )
                    stat(value: appState.isRealProject ? "git" : "8mo", label: String(localized: "de historia"))
                }
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(Color.foldMemory)
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField(
                    "Buscar en convenciones, decisiones, lecciones, specs…",
                    text: $searchText
                )
                .textFieldStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .frame(maxWidth: 420)

            GlassEffectContainer {
                HStack(spacing: 6) {
                    SelectableChip(
                        label: String(localized: "Todo"),
                        isSelected: filter == nil,
                        tint: .foldMemory,
                        count: allEntries.count
                    ) {
                        filter = nil
                    }
                    ForEach(MemoryEntry.Kind.allCases) { kind in
                        SelectableChip(
                            label: kind.label,
                            isSelected: filter == kind,
                            tint: kind.tint,
                            count: allEntries.count(where: { $0.kind == kind })
                        ) {
                            filter = filter == kind ? nil : kind
                        }
                    }
                }
            }

            Spacer()

            Button {
                attachFiles()
            } label: {
                Label("Adjuntar", systemImage: "paperclip")
            }
            .buttonStyle(.glass)
            .tint(.foldMemory)
            .help(String(localized: "Adjuntar archivos a la memoria del proyecto"))

            Button {
                if appState.isRealProject {
                    showAddSheet = true
                } else {
                    appState.toasts.show(String(localized: "En la demo la memoria es de solo lectura — abre un proyecto real"))
                }
            } label: {
                Label("Añadir", systemImage: "plus")
            }
            .buttonStyle(.glassProminent)
            .tint(.foldMemory)
            .sheet(isPresented: $showAddSheet) {
                AddMemorySheet()
            }
        }
    }

    /// Adjuntar archivos reales a .workspace/memory/.
    private func attachFiles() {
        guard let root = appState.projectURL else {
            appState.toasts.show(String(localized: "En la demo la memoria es de solo lectura — abre un proyecto real"))
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Adjuntar")
        panel.message = String(localized: "Los archivos se copian a .workspace/memory/ y los agentes los leerán")
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        do {
            let count = try MemoryService.attach(fileURLs: panel.urls, at: root)
            appState.refreshRealProject()
            appState.toasts.show(String(localized: "\(count) archivo(s) adjuntados a la memoria"))
        } catch {
            appState.toasts.show(String(localized: "No se pudo adjuntar: \(error.localizedDescription)"))
        }
    }
}

/// Alta de una entrada de memoria: se escribe como markdown plano en el repo.
private struct AddMemorySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var body_ = ""
    @State private var kind: MemoryEntry.Kind = .decision

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nueva entrada de memoria")
                .font(.title3.weight(.semibold))

            TextField("Título", text: $title)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(10)
                .background(.background.secondary, in: .rect(cornerRadius: 8))

            Picker("Tipo", selection: $kind) {
                ForEach(MemoryEntry.Kind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextEditor(text: $body_)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 140)
                .background(.background.secondary, in: .rect(cornerRadius: 8))

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
                Button("Guardar en el repo") {
                    save()
                }
                .buttonStyle(.glassProminent)
                .tint(.foldMemory)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private func save() {
        guard let url = appState.projectURL else { return }
        do {
            try MemoryService.add(
                title: title.trimmingCharacters(in: .whitespaces),
                body: body_,
                kind: kind,
                at: url
            )
            appState.refreshRealProject()
            appState.toasts.show(String(localized: "Entrada guardada en .workspace/memory/"))
            dismiss()
        } catch {
            appState.toasts.show(String(localized: "No se pudo guardar: \(error.localizedDescription)"))
        }
    }
}

#Preview {
    MemoryFullscreenView()
        .environment(AppState())
        .frame(width: 1280, height: 800)
}
