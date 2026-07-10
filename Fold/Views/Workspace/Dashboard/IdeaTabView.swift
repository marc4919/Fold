import SwiftUI

/// Tab Idea: la intención del usuario, editable, con el contexto heredado de explorar.
struct IdeaTabView: View {
    @Bindable var session: ChangeSession

    @State private var savePhase: SavedIndicator.Phase = .saved
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 26) {
                    intentionSection
                    if !session.change.ideaContext.isEmpty {
                        contextSection
                    }

                    if session.state == .idea {
                        Button {
                            if session.isReal {
                                session.generatePlan()
                            } else {
                                session.advance(to: .planned)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if session.isGeneratingPlan {
                                    PulsingDots(tint: .white)
                                    Text(session.planProgressText ?? String(localized: "Generando plan…"))
                                } else {
                                    Text("Generar plan")
                                    Image(systemName: "arrow.right")
                                }
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .disabled(session.isGeneratingPlan)
                    }
                }

                aside
                    .frame(width: 230)
            }
            .padding(32)
            .frame(maxWidth: 1040, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    private var intentionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: String(localized: "Intención · editable"), pills: ["idea.md"])

            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $session.change.ideaText)
                    .font(.system(.title3, design: .serif))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(12)
                    .disabled(session.isGeneratingPlan)
                    .opacity(session.isGeneratingPlan ? 0.55 : 1)

                HStack {
                    Spacer()
                    SavedIndicator(phase: savePhase)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
            .foldCardBorder()

            Text("Editable libremente. Es tu intención en tus palabras — el agente la usará como contrato del plan.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .onChange(of: session.change.ideaText) {
            savePhase = .saving
            saveTask?.cancel()
            saveTask = Task {
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else { return }
                session.saveIdeaText()
                savePhase = .saved
            }
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: String(localized: "Contexto desde explorar"), pills: [String(localized: "heredado")])

            VStack(alignment: .leading, spacing: 8) {
                ForEach(session.change.ideaContext, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("·").foregroundStyle(.tertiary)
                        Text(LocalizedStringKey(line))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foldCard()
        }
    }

    private var aside: some View {
        VStack(alignment: .leading, spacing: 14) {
            metaRow(label: String(localized: "Origen"), value: session.change.origin)
            metaRow(
                label: String(localized: "Artefactos"),
                value: session.change.artifacts.isEmpty
                    ? String(localized: "ninguno todavía")
                    : "\(session.change.artifacts.count) · \(session.change.artifacts.first?.name ?? "")"
            )
            metaRow(label: String(localized: "Agente"), value: session.change.agentLabel)
        }
        .foldCard()
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
