import SwiftUI

/// Fullscreen del artefacto del sandbox. Cierra con Esc (sheet nativo).
struct ArtifactFullscreenSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Exploración · artefacto")
                    .font(.headline)
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

            if let session = appState.session {
                SandboxArtifactView(session: session, isFullscreen: true)
                    .padding([.horizontal, .bottom], 16)
            }
        }
        .frame(minWidth: 900, idealWidth: 1000, minHeight: 620, idealHeight: 700)
    }
}
