import SwiftUI

/// Modal de edición de archivos del change con tabs Editar / Vista previa.
struct FileEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let fileKey: ChangeFileKey

    @State private var text = ""
    @State private var mode = "preview"

    private var file: ChangeFileContent? {
        appState.session?.fileContents[fileKey]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(18)

            Picker("Modo", selection: $mode) {
                Text("Editar").tag("edit")
                Text("Vista previa").tag("preview")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .padding(.bottom, 14)

            Divider()

            Group {
                if mode == "edit" {
                    TextEditor(text: $text)
                        .font(.callout.monospaced())
                        .scrollContentBackground(.hidden)
                        .padding(14)
                } else {
                    ScrollView {
                        MarkdownView(markdown: text)
                            .padding(20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background.secondary.opacity(0.4))

            Divider()

            HStack {
                Spacer()
                Button("Cerrar") { dismiss() }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
                Button("Guardar y cerrar") {
                    guard let session = appState.session, let name = file?.name else {
                        dismiss()
                        return
                    }
                    if session.isReal {
                        // Escribe en el árbol vivo (worktree durante Trabajo).
                        // Si falla, el editor NO se cierra y el borrador se conserva.
                        if let error = session.saveChangeFile(named: name, content: text) {
                            appState.toasts.show(String(localized: "No se pudo guardar: \(error)"))
                            return
                        }
                        appState.refreshRealProject()
                        appState.toasts.show(String(localized: "\(name) guardado en el repo"))
                    } else {
                        session.fileContents[fileKey]?.content = text
                        appState.toasts.show(String(localized: "(demo) \(name) editado solo en memoria"))
                    }
                    dismiss()
                }
                .buttonStyle(.glassProminent)
            }
            .padding(16)
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 560, idealHeight: 640)
        .onAppear { text = file?.content ?? "" }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(file?.name ?? "")
                .font(.headline.monospaced())
            Text(file?.title ?? "")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
