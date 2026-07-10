import SwiftUI
import Combine

/// Tab Explorar: chat con el agente + sandbox del artefacto activo.
struct ExploreTabView: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: ChangeSession

    @State private var draft = ""

    /// El sandbox solo aparece cuando hay algo que enseñar: hasta entonces,
    /// la conversación ocupa todo el ancho.
    private var hasSandboxContent: Bool {
        if !session.isReal { return true }
        if !session.explorationLog.isEmpty { return true }
        // Un proposal recién creado es solo el esqueleto (# título + headings vacíos).
        if let proposal = session.fileContents[.proposal]?.content {
            let body = proposal.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return body.count > 10
        }
        return false
    }

    var body: some View {
        HStack(spacing: 0) {
            chat
                .frame(maxWidth: hasSandboxContent ? 520 : 760)
                .frame(maxWidth: hasSandboxContent ? nil : .infinity)
                .padding(.trailing, hasSandboxContent ? 14 : 0)

            if hasSandboxContent {
                SandboxArtifactView(session: session)
                    .frame(minWidth: 420, maxWidth: .infinity)
                    .padding(.leading, 14)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.smooth(duration: 0.45), value: hasSandboxContent)
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }

    // MARK: - Chat

    private var chat: some View {
        VStack(spacing: 12) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if session.chatMessages.isEmpty {
                            // Invitación sutil, no un mensaje falso del agente.
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Explora antes de decidir")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("Pregúntale al agente por el código, los riesgos o los approaches posibles. No implementa nada hasta que aterrices la idea.")
                                    .font(.callout)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.top, 32)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(session.chatMessages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.trailing, 8)
                }
                .scrollIndicators(.hidden)
                .onChange(of: session.chatMessages.count) {
                    if let last = session.chatMessages.last {
                        withAnimation(.smooth(duration: 0.3)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            if session.state == .exploring {
                Button {
                    session.landIdea()
                } label: {
                    HStack(spacing: 10) {
                        if session.isLandingIdea {
                            PulsingDots(tint: .white)
                            Text("Sintetizando la exploración…")
                            PulsingDots(tint: .white)
                        } else {
                            Text("Aterrizar idea")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(session.isLandingIdea || session.isAgentThinking)
            }

            inputBar
        }
        .task {
            session.startSeededExplorationIfNeeded()
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Pregunta, matiza o redirige la exploración…", text: $draft)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.background.secondary, in: .capsule)
                .onSubmit(send)
                .disabled(session.isAgentThinking)

            if session.isAgentThinking {
                // Cancelación real de la pregunta en curso.
                Button {
                    session.cancelChat()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.callout.weight(.bold))
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(.foldDanger)
                .help(String(localized: "Detener al agente"))
            } else {
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.callout.weight(.bold))
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func send() {
        session.sendChatMessage(draft)
        draft = ""
    }
}

private struct ChatBubble: View {
    @Environment(AppState.self) private var appState
    let message: ExploreMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(message.author == .user ? String(localized: "tú") : String(localized: "agente"))
                    .font(.caption2.weight(.semibold).monospaced())
                    .foregroundStyle(message.author == .user ? Color.foldAction : Color.foldInfo)
                if message.isDecision {
                    Text("decisión")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.foldAction.opacity(0.18), in: .capsule)
                        .foregroundStyle(Color.foldAction)
                }
            }

            if message.isStreaming, message.text.isEmpty {
                WorkingIndicator()
            } else {
                Text(inlineMarkdown(message.text))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let artifact = message.artifactLink {
                Label(artifact, systemImage: "doc.richtext")
                    .font(.caption.monospaced())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.foldInfo.opacity(0.12), in: .capsule)
                    .foregroundStyle(Color.foldInfo)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            message.isDecision
                ? AnyShapeStyle(Color.foldAction.opacity(0.08))
                : AnyShapeStyle(.background.secondary),
            in: .rect(cornerRadius: FoldMetrics.cardRadius)
        )
        .overlay {
            if message.isDecision {
                RoundedRectangle(cornerRadius: FoldMetrics.cardRadius)
                    .strokeBorder(Color.foldAction.opacity(0.35), lineWidth: 1)
            }
        }
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

/// Frases de actividad que rotan mientras el agente trabaja —
/// para que nunca dé la sensación de estar colgado.
private struct WorkingIndicator: View {
    private static let phrases: [String] = [
        String(localized: "leyendo el repo…"),
        String(localized: "analizando el código…"),
        String(localized: "comparando approaches…"),
        String(localized: "revisando las specs…"),
        String(localized: "hilando la respuesta…"),
    ]

    @State private var index = 0
    private let timer = Timer.publish(every: 2.6, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            PulsingDots(tint: .foldInfo)
            Text(Self.phrases[index])
                .font(.caption)
                .foregroundStyle(.tertiary)
                .contentTransition(.opacity)
                .id(index)
                .transition(.opacity)
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                index = (index + 1) % Self.phrases.count
            }
        }
    }
}
