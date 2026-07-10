import SwiftUI
import SwiftData
import AppKit

/// Punto de entrada: marca y estado global a la izquierda, acción a la derecha.
struct ProjectSelectorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersistentProject.lastOpenedAt, order: .reverse) private var recents: [PersistentProject]

    var body: some View {
        HStack(spacing: 0) {
            branding
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    ZStack {
                        Rectangle().fill(.background.secondary.opacity(0.6))
                        RadialGradient(
                            colors: [Color.foldAction.opacity(0.12), .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 520
                        )
                    }
                }

            actions
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Izquierda: marca y estado

    private var branding: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FOLD")
                .font(.caption.weight(.bold).monospaced())
                .kerning(3)
                .foregroundStyle(Color.foldAction)

            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                (Text("Spec-driven\n")
                 + Text("development").foregroundStyle(Color.foldAction).italic()
                 + Text(",\norquestado."))
                    .font(.system(size: 52, weight: .semibold, design: .serif))
                    .lineSpacing(2)

                Text("Define, planifica y revisa software con agentes — sin picar código. Un entorno de pensamiento, en tu repo.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 380, alignment: .leading)
            }

            Spacer()

            HStack(spacing: 36) {
                stat(
                    value: recents.isEmpty ? SampleData.globalStats.openProjects : recents.count,
                    label: String(localized: "proyectos abiertos")
                )
                stat(
                    value: detectedCount,
                    label: String(localized: "agentes detectados")
                )
                stat(
                    value: SampleData.globalStats.totalArchives,
                    label: String(localized: "archives totales")
                )
            }
        }
        .padding(48)
    }

    private var detectedCount: Int {
        let detected = appState.detectedAgents.filter(\.isDetected).count
        return appState.detectedAgents.isEmpty ? SampleData.globalStats.detectedAgents : detected
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(.title.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Derecha: acción

    private var actions: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Proyectos recientes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.6)
                Spacer()
                AppearanceToggleButton()
                    .buttonStyle(.glass)
                Button {
                    appState.activeSheet = .userSettings
                } label: {
                    Label("Tú", systemImage: "person.crop.circle")
                }
                .buttonStyle(.glass)
                .help(String(localized: "Ajustes de usuario"))
            }

            HStack(spacing: 12) {
                entryCard(
                    icon: "plus",
                    title: String(localized: "Abrir proyecto"),
                    subtitle: String(localized: "Selecciona una carpeta del repo. Detectaremos OpenSpec, agentes, y todo lo demás."),
                    action: pickFolder
                )
                entryCard(
                    icon: "folder.badge.plus",
                    title: String(localized: "Crear proyecto"),
                    subtitle: String(localized: "Una carpeta nueva con git y OpenSpec preparados, lista para el primer change."),
                    action: createProject
                )
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(recents) { recent in
                        RealProjectRow(project: recent) {
                            open(url: recent.url)
                        }
                    }

                    if !recents.isEmpty {
                        Text("Demo")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .padding(.top, 10)
                    }

                    DemoProjectRow(project: SampleData.acmeAPI) {
                        appState.pendingProjectURL = nil
                        appState.navigate(to: .setup)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(40)
    }

    private func entryCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.foldAction)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(.background.secondary.opacity(0.5), in: .rect(cornerRadius: FoldMetrics.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FoldMetrics.cardRadius)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(.quaternary)
        )
    }

    /// Crea una carpeta nueva con git inicializado y la abre (el Setup ofrece crear OpenSpec).
    private func createProject() {
        let panel = NSSavePanel()
        panel.title = String(localized: "Crear proyecto")
        panel.prompt = String(localized: "Crear")
        panel.nameFieldLabel = String(localized: "Nombre:")
        panel.nameFieldStringValue = "mi-proyecto"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            appState.toasts.show(String(localized: "No se pudo crear la carpeta: \(error.localizedDescription)"))
            return
        }
        Task {
            _ = await ShellRunner.run("git init -q", cwd: url)
            open(url: url)
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Abrir")
        panel.message = String(localized: "Selecciona la carpeta raíz del repo")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url: url)
    }

    private func open(url: URL) {
        if let existing = recents.first(where: { $0.path == url.path }) {
            existing.lastOpenedAt = .now
        } else {
            modelContext.insert(PersistentProject(path: url.path, name: url.lastPathComponent))
        }
        try? modelContext.save()
        appState.pendingProjectURL = url
        appState.navigate(to: .setup)
    }
}

// MARK: - Filas

private struct RealProjectRow: View {
    let project: PersistentProject
    let open: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                StatusDot(kind: .ready)
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name)
                        .font(.body.weight(.medium))
                    Text(project.displayPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(project.lastOpenedAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(
            hovering ? AnyShapeStyle(.background.secondary) : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: FoldMetrics.cardRadius)
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

private struct DemoProjectRow: View {
    let project: Project
    let open: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: open) {
            HStack(alignment: .center, spacing: 14) {
                StatusDot(kind: .running, pulses: true)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(project.name)
                            .font(.body.weight(.medium))
                        Text("demo")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.foldInfo.opacity(0.14), in: .capsule)
                            .foregroundStyle(Color.foldInfo)
                    }
                    Text(project.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text(project.statusSummary)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(project.relativeTimeLabel)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 6) {
                        Text("\(project.activeChanges.count) activos")
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.foldAction.opacity(0.14), in: .capsule)
                            .foregroundStyle(Color.foldAction)
                        Text("\(project.archivedCount) archivados")
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.quaternary.opacity(0.5), in: .capsule)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(
            hovering ? AnyShapeStyle(.background.secondary) : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: FoldMetrics.cardRadius)
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

#Preview {
    ProjectSelectorView()
        .environment(AppState())
        .modelContainer(for: PersistentProject.self, inMemory: true)
        .frame(width: 1280, height: 800)
}
