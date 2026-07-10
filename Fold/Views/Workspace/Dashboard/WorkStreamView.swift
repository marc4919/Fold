import SwiftUI

/// Stream de eventos en vivo + tarjeta de sesión + terminal embebida.
struct WorkStreamView: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: ChangeSession

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            stream

            VStack(spacing: 12) {
                sessionCard
                terminalCard
                actions
            }
            .frame(width: 272)
        }
    }

    // MARK: - Stream

    private var stream: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if session.streamEvents.isEmpty {
                        HStack(spacing: 10) {
                            if session.isPaused {
                                Image(systemName: "pause.circle")
                                    .foregroundStyle(Color.foldReview)
                                Text("Sesión pausada — añade una indicación o continúa.")
                            } else {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Esperando la primera señal del agente…")
                            }
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                        .frame(maxWidth: .infinity)
                    }
                    ForEach(session.streamEvents) { event in
                        StreamEventRow(event: event)
                            .id(event.id)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .background(.background.secondary.opacity(0.5), in: .rect(cornerRadius: FoldMetrics.cardRadius))
            .onChange(of: session.streamEvents.count) {
                if let last = session.streamEvents.last {
                    withAnimation(.smooth(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Sesión

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                StatusDot(kind: session.isPaused ? .review : .running, pulses: !session.isPaused)
                Text(session.isPaused
                     ? String(localized: "Pausada · run #\(session.runNumber)")
                     : String(localized: "En curso · run #\(session.runNumber)"))
                    .font(.caption.weight(.semibold))
                Spacer()
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    sessionKey(String(localized: "Tiempo"))
                    // mm:ss en vivo mientras la sesión corre.
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        sessionValue(elapsedLabel(at: context.date))
                    }
                }
                GridRow {
                    sessionKey("Tasks")
                    sessionValue("\(session.completedTaskCount)/\(session.change.tasks.count)")
                }
                GridRow {
                    sessionKey("Tokens")
                    sessionValue(session.sessionTokens)
                }
                GridRow {
                    sessionKey(String(localized: "Archivos"))
                    sessionValue("\(session.streamEvents.filter { $0.fileRow != nil }.count)")
                }
            }
        }
        .foldCard(padding: 14)
    }

    private func elapsedLabel(at date: Date) -> String {
        guard let start = session.sessionStart else { return "0:00" }
        let end = session.sessionEnd ?? date
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func sessionKey(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    private func sessionValue(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium).monospacedDigit())
    }

    // MARK: - Terminal

    private var terminalCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("terminal · \(session.change.agentLabel)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(session.terminalLines.suffix(7).enumerated()), id: \.offset) { index, line in
                    HStack(spacing: 4) {
                        Text(line)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if index == min(session.terminalLines.count, 7) - 1 {
                            BlinkingCursor()
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background(.quaternary.opacity(0.25))
        }
        .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
        .clipShape(.rect(cornerRadius: FoldMetrics.cardRadius))
    }

    // MARK: - Acciones

    @State private var interventionText = ""

    private var actions: some View {
        VStack(spacing: 8) {
            if session.isPaused {
                // Intervención real: el agente está parado esperando tu indicación.
                TextField("Tu indicación para el agente…", text: $interventionText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...4)
                    .padding(10)
                    .background(.background.secondary, in: .rect(cornerRadius: 8))

                Button {
                    session.resumeWork(instruction: interventionText)
                    interventionText = ""
                } label: {
                    HStack {
                        Text(interventionText.trimmingCharacters(in: .whitespaces).isEmpty
                             ? String(localized: "Continuar sin indicación")
                             : String(localized: "Continuar con la indicación"))
                        Image(systemName: "play.fill")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            } else {
                HStack(spacing: 8) {
                    Button {
                        if session.isReal {
                            session.pauseWork()
                        } else {
                            appState.toasts.show(String(localized: "(demo) La intervención real requiere una sesión de agente"))
                        }
                    } label: {
                        Label("Intervenir", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.foldReview)

                    Button(role: .destructive) {
                        Task {
                            await session.stopWorkAndWait()
                            appState.toasts.show(String(localized: "Sesión detenida"))
                        }
                    } label: {
                        Label("Detener", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.foldDanger)
                }
            }

            Button {
                if session.isReal {
                    // Detiene y ESPERA al agente antes de preparar el diff.
                    Task { await session.finishAndReview() }
                } else {
                    session.advance(to: .review)
                }
            } label: {
                HStack {
                    Text(session.isReal ? String(localized: "Terminar sesión y revisar") : String(localized: "simular: sesión termina"))
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
        }
    }
}

private struct StreamEventRow: View {
    let event: StreamEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(event.kind.tint)
                .frame(width: 26, height: 26)
                .background(event.kind.tint.opacity(0.12), in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.kind.metaLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(event.timeLabel)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }

                Text(event.text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                if let file = event.fileRow {
                    HStack(spacing: 8) {
                        Text(file.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
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
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.background, in: .rect(cornerRadius: 6))
                }
            }
        }
    }
}

/// Cursor de terminal parpadeante (estático con Reduce Motion).
struct BlinkingCursor: View {
    @State private var visible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Rectangle()
            .fill(Color.foldSuccess)
            .frame(width: 6, height: 11)
            .opacity(visible ? 1 : 0.15)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
            .accessibilityHidden(true)
    }
}
