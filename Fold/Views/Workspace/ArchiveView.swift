import SwiftUI
import AppKit

/// El archive del proyecto: los changes cerrados, con su registro completo en el repo.
struct ArchiveView: View {
    @Environment(AppState.self) private var appState

    @State private var archived: [OpenSpecService.ArchivedChange] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Archive")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                    Text("Cada change cerrado vive aquí con todos sus artefactos: proposal, exploración, idea, tasks e historia. Es el registro de por qué el software es como es.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if appState.isRealProject {
                    if archived.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 8) {
                            ForEach(archived) { entry in
                                ArchivedRow(entry: entry)
                            }
                        }
                    }
                } else {
                    Text("En la demo hay 14 changes archivados de ejemplo — abre un proyecto real para ver tu archive.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .foldCard()
                }
            }
            .padding(32)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onAppear(perform: reload)
        .onChange(of: appState.openSpecState?.archivedCount) { reload() }
    }

    private func reload() {
        guard let root = appState.projectURL else { return }
        archived = OpenSpecService.readArchive(at: root)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "archivebox")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("Todavía no hay changes archivados")
                .font(.headline)
            Text("Cuando mergees y archives un change, aparecerá aquí con todo su registro.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

private struct ArchivedRow: View {
    @Environment(AppState.self) private var appState
    let entry: OpenSpecService.ArchivedChange

    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([entry.dirURL])
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "archivebox")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .font(.body.weight(.medium))
                    if !entry.summary.isEmpty {
                        Text(entry.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Text(entry.id)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text(entry.dateLabel)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.up.forward.square")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(
            hovering ? AnyShapeStyle(.background.secondary) : AnyShapeStyle(.background.secondary.opacity(0.5)),
            in: .rect(cornerRadius: FoldMetrics.cardRadius)
        )
        .onHover { hovering = $0 }
        .help(String(localized: "Mostrar en Finder"))
    }
}
