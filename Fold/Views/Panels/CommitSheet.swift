import SwiftUI

/// Detalle real de un commit: `git show --stat` del repo del proyecto.
struct CommitSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let sha: String

    @State private var output = ""
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(Color.foldSuccess)
                Text("Commit \(sha)")
                    .font(.headline.monospaced())
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
            .padding(16)

            Divider()

            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(40)
                } else {
                    Text(output)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
            .background(.background.secondary.opacity(0.4))
        }
        .frame(minWidth: 640, idealWidth: 720, minHeight: 420, idealHeight: 520)
        .task {
            guard let root = appState.projectURL else {
                output = String(localized: "(demo) No hay repo real abierto.")
                isLoading = false
                return
            }
            let result = await ShellRunner.run(
                "git show --stat --format=medium \(ShellRunner.quote(sha)) 2>&1",
                cwd: root
            )
            output = result.trimmedOutput.isEmpty
                ? String(localized: "No se encontró el commit \(sha).")
                : result.trimmedOutput
            isLoading = false
        }
    }
}
