import SwiftUI
import SwiftTerm

/// Terminal embebida (SwiftTerm): el andamio de la capa 1 para validar
/// spawning y la fontanería de auth — la terminal es un andamio, no el destino.
struct TerminalSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "apple.terminal")
                    .foregroundStyle(.secondary)
                Text("Terminal · \(appState.activeProject?.name ?? "Fold")")
                    .font(.headline)
                Text(appState.projectURL.map { appState.displayPath($0) } ?? "~")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                Spacer()
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
            .padding(14)

            EmbeddedTerminal(workingDirectory: appState.projectURL)
                .clipShape(.rect(cornerRadius: 10))
                .padding([.horizontal, .bottom], 14)
        }
        .frame(minWidth: 860, idealWidth: 960, minHeight: 560, idealHeight: 640)
    }
}

/// Wrapper de `LocalProcessTerminalView` de SwiftTerm con una zsh de login
/// en el directorio del proyecto. Aquí el usuario valida que sus CLIs de
/// agente funcionan igual que en su terminal — misma auth, mismo PATH.
struct EmbeddedTerminal: NSViewRepresentable {
    let workingDirectory: URL?

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: .zero)
        let directory = workingDirectory?.path ?? NSHomeDirectory()
        let command = "cd \(ShellRunner.quote(directory)) && exec /bin/zsh -il"
        var environment = ShellRunner.cleanEnvironment()
        environment["TERM"] = "xterm-256color"
        terminal.startProcess(
            executable: "/bin/zsh",
            args: ["-lc", command],
            environment: environment.map { "\($0.key)=\($0.value)" },
            execName: nil
        )
        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
