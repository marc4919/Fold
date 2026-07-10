import SwiftUI
import AppKit

/// Tab Revisión (pre-merge): cambios de la sesión + panel de cierre con las tres voces.
struct ReviewTabView: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: ChangeSession

    @State private var showDiscardConfirm = false
    @State private var showIterateAlert = false
    @State private var iterateFeedback = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                verdictBanner

                changesSection

                closingSection

                actionsRow
            }
            .padding(32)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .confirmationDialog(
            "¿Descartar este change?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Descartar change", role: .destructive) {
                appState.discardActiveChange()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminarán el worktree, la rama y el directorio del change. Las specs vivas no se tocan.")
        }
        .alert("Iterar con feedback", isPresented: $showIterateAlert) {
            TextField("Qué debe corregir o mejorar el agente", text: $iterateFeedback)
            Button("Lanzar run #\(session.runNumber + 1)") {
                let feedback = iterateFeedback.trimmingCharacters(in: .whitespaces)
                guard !feedback.isEmpty else { return }
                session.iterateWork(feedback: feedback)
                iterateFeedback = ""
            }
            Button("Cancelar", role: .cancel) { iterateFeedback = "" }
        } message: {
            Text("El agente vuelve a Trabajo con tu feedback como indicación prioritaria, en la misma sesión.")
        }
    }

    private var verdictBanner: some View {
        HStack(spacing: 12) {
            if session.isPreparingReview {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "checkmark.shield")
                    .font(.title3)
                    .foregroundStyle(Color.foldReview)
            }
            VStack(alignment: .leading, spacing: 2) {
                if session.isReal {
                    Text(session.reviewVerdict ?? String(localized: "Leyendo el diff de la sesión…"))
                        .font(.headline)
                    Text("Revisa el diff y las tres voces antes de mergear. Tú decides — el agente solo prepara la evidencia.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Aprobado parcialmente · 4/5 criterios con evidencia")
                        .font(.headline)
                    Text("El criterio «rotación de claves JWKS verificada» no tiene evidencia en el diff. Te toca juzgar si bloquea el merge.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color.foldReview.opacity(0.08), in: .rect(cornerRadius: FoldMetrics.cardRadius))
        .foldCardBorder(.foldReview)
    }

    // MARK: - Cambios producidos

    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: String(localized: "Cambios producidos por la sesión"))

            HStack(alignment: .top, spacing: 14) {
                if let specs = lane(at: 0) {
                    ReviewLaneView(lane: specs, tint: .foldInfo)
                        .frame(maxWidth: .infinity)
                }
                VStack(spacing: 14) {
                    if let code = lane(at: 1) {
                        ReviewLaneView(lane: code, tint: .foldSuccess)
                    }
                    if let artifacts = lane(at: 2) {
                        ReviewLaneView(lane: artifacts, tint: .foldMemory)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func lane(at index: Int) -> ReviewLane? {
        let lanes = session.effectiveReviewLanes
        return index < lanes.count ? lanes[index] : nil
    }

    // MARK: - Las tres voces

    private var closingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cierre · cómo lo cuentas")
                    .font(.title3.weight(.semibold))
                Text("El agente vivió el ciclo entero y redacta tres versiones del mismo cambio. Tú las revisas, editas y firmas.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 14) {
                ForEach(session.change.closingVoices) { voice in
                    VoiceCard(session: session, voice: voice)
                        .frame(maxWidth: .infinity)
                }
            }

            (Text("Tu firma, no la del agente. ").bold()
             + Text("El commit, el ticket y el mensaje van con tu nombre. Los conectores de Jira/Slack llegarán con ACP — de momento los textos se copian al portapapeles para que los pegues tú."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 10) {
            Button("Descartar", role: .destructive) {
                showDiscardConfirm = true
            }
            .buttonStyle(.glass)
            .tint(.foldDanger)

            Button("Iterar con feedback") {
                if session.isReal {
                    showIterateAlert = true
                } else {
                    appState.toasts.show(String(localized: "(demo) Nueva iteración: mismo change, run #2"))
                }
            }
            .buttonStyle(.glass)

            Spacer()

            Button {
                mergeAndArchive()
            } label: {
                HStack {
                    if session.isMerging {
                        ProgressView()
                            .controlSize(.small)
                        Text("Mergeando…")
                    } else {
                        Text("Mergear con este commit y archivar")
                        Image(systemName: "arrow.right")
                    }
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(session.isMerging)
        }
    }

    /// Merge real (commit + merge del worktree) antes de archivar.
    private func mergeAndArchive() {
        guard session.isReal else {
            session.advance(to: .archived)
            return
        }
        let commitMessage = session.change.closingVoices
            .first(where: { $0.kind == .commit })?.content ?? "feat: \(session.change.title)"
        Task {
            let result = await session.mergeChange(commitMessage: commitMessage)
            if result.ok {
                appState.archiveActiveChange()
                session.advance(to: .archived)
            } else {
                appState.toasts.show(String(localized: "El merge falló: \(result.detail ?? "conflictos") — resuélvelo en tu terminal"))
            }
        }
    }
}

// MARK: - Lane

private struct ReviewLaneView: View {
    let lane: ReviewLane
    let tint: Color

    var body: some View {
        CollapsibleLane(
            iconLetter: lane.iconLetter,
            iconTint: tint,
            title: lane.title,
            countLabel: lane.countLabel
        ) {
            VStack(alignment: .leading, spacing: 6) {
                switch lane.content {
                case .files(let files):
                    ForEach(files) { file in
                        HStack(spacing: 9) {
                            Text(file.kind.rawValue)
                                .font(.caption2.weight(.bold).monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    (file.kind == .new ? Color.foldSuccess : Color.foldReview).opacity(0.14),
                                    in: .rect(cornerRadius: 4)
                                )
                                .foregroundStyle(file.kind == .new ? Color.foldSuccess : Color.foldReview)
                            Text(file.path)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                            Spacer()
                            if file.added > 0 {
                                Text("+\(file.added)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(Color.foldSuccess)
                            }
                            if file.removed > 0 {
                                Text("−\(file.removed)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(Color.foldDanger)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                case .artifacts(let artifacts):
                    ForEach(artifacts) { artifact in
                        HStack(spacing: 9) {
                            Image(systemName: "doc.richtext")
                                .font(.caption)
                                .foregroundStyle(tint)
                            Text(artifact.name)
                                .font(.caption.monospaced())
                            Spacer()
                            Text("\(artifact.phase) · \(artifact.timeLabel)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 3)
                    }
                }

                if let note = lane.note {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Voice card

private struct VoiceCard: View {
    @Environment(AppState.self) private var appState
    let session: ChangeSession
    let voice: ClosingVoice

    @State private var text = ""
    @State private var showConfirm = false

    private var isRegenerating: Bool {
        session.regeneratingVoice == voice.kind
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Text(voice.icon)
                    .font(.caption.weight(.bold).monospaced())
                    .frame(width: 24, height: 24)
                    .background(Color.foldAction.opacity(0.14), in: .rect(cornerRadius: 6))
                    .foregroundStyle(Color.foldAction)
                VStack(alignment: .leading, spacing: 1) {
                    Text(voice.title)
                        .font(.subheadline.weight(.semibold))
                    Text(voice.audience)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if isRegenerating {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let badge = voice.ruleBadge {
                Label(badge, systemImage: "hammer")
                    .font(.caption2.monospaced())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.5), in: .capsule)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $text)
                .font(.caption.monospaced())
                .scrollContentBackground(.hidden)
                .frame(minHeight: 150)
                .padding(8)
                .background(.background, in: .rect(cornerRadius: 8))
                .opacity(isRegenerating ? 0.5 : 1)

            HStack(spacing: 8) {
                Button(voice.primaryActionLabel) {
                    if voice.needsConfirmation {
                        showConfirm = true
                    } else {
                        copyToClipboard()
                    }
                }
                .buttonStyle(.bordered)
                .tint(voice.needsConfirmation ? .foldAction : nil)
                .controlSize(.small)

                Button {
                    session.regenerateVoice(voice.kind)
                } label: {
                    Label("regenerar", systemImage: "arrow.counterclockwise")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .disabled(isRegenerating)

                Spacer()
            }

            Text(voice.footnote)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .foldCard(padding: 14)
        .foldCardBorder()
        .onAppear { text = voice.content }
        .onChange(of: voice.content) {
            // El agente redacta las voces de forma asíncrona tras la sesión.
            text = voice.content
        }
        .confirmationDialog(
            String(localized: "Fold aún no tiene el conector: se copiará al portapapeles para que lo pegues tú."),
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Copiar al portapapeles") {
                copyToClipboard()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        appState.toasts.show(String(localized: "\(voice.title) copiado al portapapeles"))
    }
}
