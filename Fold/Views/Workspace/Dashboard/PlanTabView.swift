import SwiftUI

/// Tab Plan: proposal, design, tasks, estrategia de ejecución y deltas.
struct PlanTabView: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: ChangeSession

    @State private var promptDraft = ""
    @State private var showLaunchConfirm = false

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 26) {
                    if session.isGeneratingPlan {
                        HStack(spacing: 10) {
                            PulsingDots(tint: .foldAction)
                            Text(session.planProgressText ?? String(localized: "El agente está trabajando en el plan…"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Cancelar") {
                                session.cancelPlanGeneration()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .foldCard()
                    } else {
                        promptSection
                    }
                    Group {
                        proposalSection
                        designSection
                        tasksSection
                        if !session.isReal {
                            ExecStrategyView(session: session)
                        }
                        deltasSection
                    }
                    // Mientras se genera, el plan se mira pero no se toca.
                    .disabled(session.isGeneratingPlan)
                    .opacity(session.isGeneratingPlan ? 0.75 : 1)
                }

                aside
                    .frame(width: 240)
            }
            .padding(32)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    // MARK: - Secciones de archivos

    private var proposalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Proposal", pills: ["proposal.md"])
            clickableText(proposalSummary, fileKey: .proposal)
        }
    }

    private var designSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Design", pills: ["design.md"])
            clickableText(designSummary, fileKey: .design)
        }
    }

    private var proposalSummary: String {
        if session.isReal {
            if let summary = plainSummary(session.fileContents[.proposal]?.content) {
                return summary
            }
            return session.isGeneratingPlan
                ? String(localized: "✍️ El agente está redactando el proposal — aparecerá aquí en cuanto lo escriba…")
                : String(localized: "El proposal está vacío. Haz click para redactar el qué y el por qué del cambio.")
        }
        return "Añadir Sign in with Apple como método de autenticación adicional. La sesión se manejará con `SessionManager`; el identity token se valida contra el JWKS de Apple. Fuera de alcance: Google OAuth y SIWA para web."
    }

    private var designSummary: String {
        if session.isReal {
            if let summary = plainSummary(session.fileContents[.design]?.content) {
                return summary
            }
            return session.isGeneratingPlan
                ? String(localized: "✍️ Las decisiones de diseño llegarán tras el proposal…")
                : String(localized: "Sin decisiones de diseño todavía. Haz click para documentarlas.")
        }
        return "Tres decisiones técnicas: validación JWKS local (no Apple Auth Server), cache en memoria con TTL 1 h y refresh automático, y mapeo de `sub` a un campo nuevo `apple_sub` en la tabla users."
    }

    /// Resumen plano de un markdown: sin headings, recortado.
    private func plainSummary(_ content: String?) -> String? {
        guard let content else { return nil }
        let text = content.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return String(text.prefix(260))
    }

    private func clickableText(_ text: String, fileKey: ChangeFileKey) -> some View {
        Button {
            appState.activeSheet = .fileEditor(fileKey)
        } label: {
            HStack(alignment: .top) {
                Text(LocalizedStringKey(text))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "square.and.pencil")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .foldCard()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Tasks", pills: ["tasks.md · \(session.change.tasks.count)"])

            if session.change.tasks.isEmpty {
                HStack(spacing: 10) {
                    if session.isGeneratingPlan {
                        PulsingDots(tint: .foldAction)
                        Text("Las tasks se escriben al final del plan — irán apareciendo aquí…")
                    } else {
                        Text("Sin tasks todavía. Genera el plan desde la tab Idea, o pídeselas al agente con el prompt de arriba.")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .foldCard()
            }
            VStack(spacing: 0) {
                ForEach(session.change.tasks) { task in
                    HStack(spacing: 12) {
                        Button {
                            session.toggleTask(id: task.id)
                        } label: {
                            Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.done ? AnyShapeStyle(Color.foldSuccess) : AnyShapeStyle(.tertiary))
                        }
                        .buttonStyle(.plain)
                        .help(String(localized: "Marcar task (se escribe en tasks.md)"))
                        Text(LocalizedStringKey(task.title))
                            .font(.callout)
                            .strikethrough(task.done, color: .secondary)
                            .foregroundStyle(task.done ? .secondary : .primary)
                        Spacer()
                        Text(task.id)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                        Text(task.group)
                            .font(.caption2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.quaternary.opacity(0.5), in: .capsule)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, 14)
                    if task.id != session.change.tasks.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
        }
    }

    private var deltasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(
                title: "Deltas",
                pills: [String(localized: "archivos del change · click para editar")]
            )

            VStack(spacing: 6) {
                ForEach(session.change.deltas) { delta in
                    Button {
                        if let key = delta.fileKey {
                            appState.activeSheet = .fileEditor(key)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(delta.kind.rawValue)
                                .font(.caption2.weight(.bold).monospaced())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(deltaTint(delta.kind).opacity(0.15), in: .rect(cornerRadius: 5))
                                .foregroundStyle(deltaTint(delta.kind))
                            Text(delta.path)
                                .font(.callout.monospaced())
                            Text(delta.summary)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(.background.secondary, in: .rect(cornerRadius: 10))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func deltaTint(_ kind: Delta.Kind) -> Color {
        switch kind {
        case .md: .foldMemory
        case .mod: .foldReview
        case .new: .foldSuccess
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: String(localized: "Pídele al agente algo sobre el plan"), pills: [String(localized: "modifica los artefactos de verdad")])

            HStack(spacing: 8) {
                TextField("«Divide la task 1.2 en dos» · «Añade un task de docs»…", text: $promptDraft)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.background.secondary, in: .capsule)
                    .onSubmit(sendPrompt)

                Button(action: sendPrompt) {
                    Image(systemName: "arrow.up")
                        .font(.callout.weight(.bold))
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .disabled(promptDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Text("El agente puede modificar proposal, tasks y deltas. El prompt es efímero: lo que queda es el plan.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func sendPrompt() {
        let instruction = promptDraft.trimmingCharacters(in: .whitespaces)
        guard !instruction.isEmpty else { return }
        if session.isReal {
            session.refinePlan(instruction: instruction)
        } else {
            appState.toasts.show(String(localized: "El agente está ajustando el plan…"))
        }
        promptDraft = ""
    }

    // MARK: - Aside

    private var aside: some View {
        VStack(alignment: .leading, spacing: 14) {
            metaRow(label: String(localized: "Estado"), value: session.state == .planned
                ? String(localized: "Esperando aprobación")
                : String(localized: "Aceptado"))
            metaRow(label: String(localized: "Generado por"), value: "/opsx:propose")
            metaRow(label: "Tasks", value: tasksMeta)
            metaRow(
                label: String(localized: "Specs afectadas"),
                value: "\(session.change.deltas.filter { $0.kind != .md }.count)"
            )

            if session.state == .planned {
                Button {
                    if session.isReal {
                        showLaunchConfirm = true
                    } else {
                        session.advance(to: .implementing)
                    }
                } label: {
                    HStack {
                        Text("Aceptar plan e implementar")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .confirmationDialog(
                    "¿Lanzar la sesión de implementación?",
                    isPresented: $showLaunchConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Lanzar sesión") {
                        session.logEvent(stage: "plan", actor: .human, text: String(localized: "Aceptaste el plan e implementación"))
                        session.advance(to: .implementing)
                    }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text(launchSummary)
                }
            }
        }
        .foldCard()
    }

    private var launchSummary: String {
        let agent = (session.agentBinary as NSString?)?.lastPathComponent ?? "agente"
        let isolation = appState.isolationMode == "worktree"
            ? String(localized: "en una copia aislada del repo")
            : String(localized: "directamente sobre tu working tree")
        return String(localized: "\(agent) implementará \(session.change.tasks.count) tasks \(isolation). Consumirá tokens de tu sesión del CLI.")
    }

    private var tasksMeta: String {
        let done = session.completedTaskCount
        let total = session.change.tasks.count
        if done == 0 { return String(localized: "\(total) pendientes") }
        if done == total { return String(localized: "todas hechas") }
        return "\(done)/\(total)"
    }

    private func metaRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.callout.monospaced())
        }
    }
}
