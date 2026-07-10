import SwiftUI

/// Sandbox del artefacto activo: markdown / visual / frugal, con ampliación.
struct SandboxArtifactView: View {
    @Environment(AppState.self) private var appState
    let session: ChangeSession
    var isFullscreen = false

    @State private var viewMode = "md"

    var body: some View {
        VStack(spacing: 0) {
            head
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            ScrollView {
                content
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
        .foldCardBorder()
    }

    private var realPillName: String {
        session.explorationLog.isEmpty ? "proposal.md" : "exploration.md"
    }

    private var head: some View {
        HStack(spacing: 10) {
            Text(session.isReal ? realPillName : "exploración-siwa")
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.foldInfo.opacity(0.14), in: .capsule)
                .foregroundStyle(Color.foldInfo)

            Text(session.isReal
                 ? (session.explorationLog.isEmpty
                    ? String(localized: "leído del repo")
                    : String(localized: "se actualiza con la exploración"))
                 : "generado hace 1 min")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            if !appState.frugalMode, !session.isReal {
                Picker("Vista", selection: $viewMode) {
                    Text("Markdown").tag("md")
                    Text("Visual").tag("visual")
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .labelsHidden()
                .frame(width: 170)
            }

            if !isFullscreen {
                Button {
                    appState.activeSheet = .artifactFullscreen
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(String(localized: "Ampliar artefacto"))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if session.isReal {
            MarkdownView(markdown: realMarkdown)
        } else if appState.frugalMode {
            frugalContent
        } else if viewMode == "md" {
            MarkdownView(markdown: SampleMarkdown.briefing)
        } else {
            visualContent
        }
    }

    /// En proyectos reales el sandbox es el artefacto vivo de la exploración;
    /// si aún no hay exploración, muestra el proposal del change.
    private var realMarkdown: String {
        if !session.explorationLog.isEmpty {
            return session.explorationLog
        }
        if let proposal = session.fileContents[.proposal]?.content,
           !proposal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return proposal
        }
        return String(localized: "# Sin artefactos todavía\n\nPregunta al agente en el chat: cada intercambio se irá acumulando aquí como briefing del change.")
    }

    // MARK: - Frugal

    private var frugalContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("modo ahorro · sin diagramas ni HTML", systemImage: "leaf")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.5), in: .capsule)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(SampleMarkdown.frugalBriefingPoints, id: \.self) { point in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("·").foregroundStyle(.tertiary)
                        Text(point).font(.callout)
                    }
                }
            }

            Text("El agente responde al grano. Desactiva el ahorro de tokens para recuperar los artefactos enriquecidos.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Visual

    private var visualContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.foldSuccess)
                Text("Approach recomendado: **2 · JWKS local**")
                    .font(.headline)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.foldSuccess.opacity(0.1), in: .rect(cornerRadius: 10))

            HStack(spacing: 10) {
                metric(value: "< 1 ms", label: String(localized: "validación local"))
                metric(value: "1 h", label: String(localized: "TTL del cache JWKS"))
                metric(value: "0", label: String(localized: "dependencias nuevas"))
            }

            VStack(spacing: 8) {
                approachCard(number: 1, name: "Apple Auth Server", verdict: String(localized: "descartado"), detail: String(localized: "Latencia ~200 ms por login y rate limits de Apple."), recommended: false)
                approachCard(number: 2, name: "JWKS local", verdict: String(localized: "recomendado"), detail: String(localized: "Validación de firma en local con el JWKS cacheado. OAuth2/OIDC puro."), recommended: true)
                approachCard(number: 3, name: "SDK de terceros", verdict: String(localized: "descartado"), detail: String(localized: "Rápido de montar, pero dependencia opaca en el camino crítico de auth."), recommended: false)
            }
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 10))
    }

    private func approachCard(number: Int, name: String, verdict: String, detail: String, recommended: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.callout.weight(.bold).monospaced())
                .frame(width: 28, height: 28)
                .background(
                    recommended ? Color.foldSuccess.opacity(0.18) : Color.gray.opacity(0.12),
                    in: .circle
                )
                .foregroundStyle(recommended ? Color.foldSuccess : .secondary)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.body.weight(.medium))
                    Text(verdict)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            (recommended ? Color.foldSuccess : Color.gray).opacity(0.14),
                            in: .capsule
                        )
                        .foregroundStyle(recommended ? Color.foldSuccess : .secondary)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.background, in: .rect(cornerRadius: 10))
        .overlay {
            if recommended {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.foldSuccess.opacity(0.35), lineWidth: 1)
            }
        }
    }
}
