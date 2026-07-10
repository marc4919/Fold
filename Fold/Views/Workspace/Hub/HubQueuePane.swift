import SwiftUI

/// Tab "Cola de atención": decisiones que necesitan al humano.
/// En proyectos reales se derivan del estado de los changes; en demo son de ejemplo.
struct HubQueuePane: View {
    @Environment(AppState.self) private var appState
    let decisions: [QueueDecision]
    let onResolve: (QueueDecision, QueueDecision.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No es una bandeja de notificaciones: cada entrada es una decisión que solo tú puedes tomar. El agente prepara el contexto; tú decides.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if decisions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(decisions) { decision in
                        DecisionCard(decision: decision) { action in
                            onResolve(decision, action)
                        }
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(Color.foldSuccess)
            Text("Nada que decidir")
                .font(.headline)
            Text("Cuando un change necesite tu juicio (plan pendiente de OK, sesión lista para revisar), aparecerá aquí.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

private struct DecisionCard: View {
    let decision: QueueDecision
    let resolve: (QueueDecision.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(decision.kindLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.foldReview)
                Text(decision.scopeLabel)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(decision.authorityLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(LocalizedStringKey(decision.title))
                .font(.title3.weight(.semibold))

            Text(decision.body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !decision.consequences.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(decision.consequenceTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    ForEach(decision.consequences, id: \.self) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("·").foregroundStyle(.tertiary)
                            Text(line)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: .rect(cornerRadius: 8))
            }

            HStack(spacing: 8) {
                ForEach(decision.actions) { action in
                    actionButton(action)
                }
                Spacer()
            }
        }
        .foldCard(padding: 18)
        .foldCardBorder()
    }

    @ViewBuilder
    private func actionButton(_ action: QueueDecision.Action) -> some View {
        switch action.role {
        case .primary:
            Button(action.label) { resolve(action) }
                .buttonStyle(.glassProminent)
        case .secondary:
            Button(action.label) { resolve(action) }
                .buttonStyle(.glass)
        case .ghost:
            Button(action.label) { resolve(action) }
                .buttonStyle(.glass)
                .tint(.secondary)
        case .destructive:
            Button(action.label, role: .destructive) { resolve(action) }
                .buttonStyle(.glass)
                .tint(.foldDanger)
        case .postpone:
            Button(action.label) { resolve(action) }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
    }
}
