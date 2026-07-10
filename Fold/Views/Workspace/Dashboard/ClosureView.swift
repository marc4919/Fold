import SwiftUI

/// Tab Cierre (post-merge): el change archivado se celebra y se consolida.
struct ClosureView: View {
    @Environment(AppState.self) private var appState
    let session: ChangeSession

    private var stats: ClosureStats { session.change.closureStats }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero

                statsGrid

                HStack(alignment: .top, spacing: 14) {
                    committedBlock
                        .frame(maxWidth: .infinity)
                    learnedBlock
                        .frame(maxWidth: .infinity)
                }

                actions
            }
            .padding(32)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("change archivado · \(stats.archivedAtLabel)")
                .font(.caption.monospaced())
                .foregroundStyle(Color.foldSuccess)
                .textCase(.uppercase)

            Text(session.change.title)
                .font(.system(size: 36, weight: .semibold, design: .serif))
                .italic()

            Text(session.isReal
                 ? "Mergeado a tu rama con un commit atómico. El archive del change vive en `openspec/changes/archive/` — la sincronización de specs maestras (`/opsx:sync`) llegará con la integración ACP."
                 : "Mergeado a `main` con un commit atómico. Las specs maestras se han actualizado vía `/opsx:sync` y el archive vive en `openspec/changes/archive/`.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.foldSuccess.opacity(0.08), in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.foldSuccess.opacity(0.25), lineWidth: 1)
        )
    }

    private var statsGrid: some View {
        HStack(spacing: 14) {
            stat(value: stats.durationValue, label: String(localized: "duración"), detail: stats.durationDetail)
            stat(value: stats.tokensValue, label: "tokens", detail: stats.tokensDetail)
            stat(value: stats.filesValue, label: String(localized: "archivos"), detail: stats.filesDetail)
        }
    }

    private func stat(value: String, label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .serif))
            Text(detail)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
    }

    private var committedBlock: some View {
        summaryBlock(
            iconLetter: "G",
            tint: .foldSuccess,
            title: String(localized: "Lo que se commiteó"),
            items: stats.committedItems
        ) {
            HStack(spacing: 10) {
                Text(stats.commitSHA)
                    .font(.caption.weight(.bold).monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.foldSuccess.opacity(0.14), in: .rect(cornerRadius: 6))
                    .foregroundStyle(Color.foldSuccess)
                Text(stats.commitMessage)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: .rect(cornerRadius: 8))
        }
    }

    private var learnedBlock: some View {
        summaryBlock(
            iconLetter: "S",
            tint: .foldMemory,
            title: String(localized: "Lo que aprendió el proyecto"),
            items: stats.learnedItems
        ) {
            Text(stats.archivePath)
                .font(.caption.monospaced())
                .foregroundStyle(Color.foldMemory)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: .rect(cornerRadius: 8))
        }
    }

    private func summaryBlock(
        iconLetter: String,
        tint: Color,
        title: String,
        items: [String],
        @ViewBuilder footer: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Text(iconLetter)
                    .font(.caption.weight(.bold).monospaced())
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.14), in: .rect(cornerRadius: 6))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(tint)
                        Text(item)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            footer()
        }
        .foldCard(padding: 16)
        .foldCardBorder(tint)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button("Volver al proyecto") {
                appState.session = nil
                appState.sidebarSelection = .home
            }
            .buttonStyle(.glass)

            Button("Abrir memoria del proyecto") {
                appState.navigate(to: .memory)
            }
            .buttonStyle(.glass)
            .tint(.foldMemory)

            Button("Ver commit en git") {
                if session.isReal, stats.commitSHA != "—" {
                    appState.activeSheet = .commitDetail(stats.commitSHA)
                } else {
                    appState.toasts.show(String(localized: "(demo) Abriendo commit \(stats.commitSHA)…"))
                }
            }
            .buttonStyle(.glass)

            Spacer()

            Button {
                appState.session = nil
                appState.sidebarSelection = .home
            } label: {
                HStack {
                    Text("Empezar otro change")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(.glassProminent)
        }
    }
}
